#include "MpvProcessPlayer.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QProcessEnvironment>
#include <QSaveFile>
#include <QStandardPaths>

#include <algorithm>
#include <limits>

namespace {
constexpr int kMaximumErrorLogBytes = 32 * 1024;

QString normalizedTrackLanguage(const QString &value)
{
    QString language = value.trimmed().toLower();
    language.replace(QLatin1Char('_'), QLatin1Char('-'));
    if (language == QStringLiteral("english") || language == QStringLiteral("eng"))
        return QStringLiteral("en");
    if (language.startsWith(QStringLiteral("eng-")))
        language.replace(0, 3, QStringLiteral("en"));
    return language;
}

bool isEnglishTrack(const QString &language)
{
    const QString normalized = normalizedTrackLanguage(language);
    return normalized == QStringLiteral("en")
        || normalized.startsWith(QStringLiteral("en-"));
}

QString audioCodecLabel(const QString &value)
{
    QString codec = value.trimmed().toLower();
    codec.replace(QLatin1Char('_'), QLatin1Char('-'));
    if (codec.contains(QStringLiteral("truehd")))
        return QStringLiteral("TRUEHD");
    if (codec.contains(QStringLiteral("dts-hd")) || codec.contains(QStringLiteral("dtshd")))
        return QStringLiteral("DTS-HD");
    if (codec == QStringLiteral("eac3") || codec == QStringLiteral("e-ac-3"))
        return QStringLiteral("EAC3");
    if (codec == QStringLiteral("ac3") || codec == QStringLiteral("ac-3"))
        return QStringLiteral("AC3");
    if (codec.startsWith(QStringLiteral("pcm")))
        return QStringLiteral("PCM");
    return codec.toUpper();
}

int audioCodecRank(const QString &value)
{
    const QString codec = audioCodecLabel(value);
    if (codec == QStringLiteral("TRUEHD") || codec == QStringLiteral("DTS-HD")
        || codec == QStringLiteral("FLAC") || codec == QStringLiteral("ALAC")
        || codec == QStringLiteral("PCM"))
        return 9;
    if (codec == QStringLiteral("EAC3") || codec == QStringLiteral("OPUS"))
        return 7;
    if (codec == QStringLiteral("DTS") || codec == QStringLiteral("AC3"))
        return 6;
    if (codec == QStringLiteral("AAC"))
        return 5;
    if (codec == QStringLiteral("MP3"))
        return 3;
    return 1;
}

QString audioChannelLabel(int count, const QString &layout)
{
    QString compact = layout.trimmed().toLower();
    if (compact.contains(QStringLiteral("7.1")))
        return QStringLiteral("7.1");
    if (compact.contains(QStringLiteral("5.1")))
        return QStringLiteral("5.1");
    switch (count) {
    case 1: return QStringLiteral("MONO");
    case 2: return QStringLiteral("STEREO");
    case 6: return QStringLiteral("5.1");
    case 8: return QStringLiteral("7.1");
    default:
        return count > 0 ? QString::number(count) + QStringLiteral("CH") : QString{};
    }
}

bool playbackEngineStarts(const QString &executable)
{
    if (executable.isEmpty())
        return false;
    QProcess probe;
    probe.setProgram(executable);
    probe.setArguments({QStringLiteral("--no-config"), QStringLiteral("--version")});
    probe.start();
    return probe.waitForFinished(2000)
        && probe.exitStatus() == QProcess::NormalExit && probe.exitCode() == 0;
}
}

MpvProcessPlayer::MpvProcessPlayer(QObject *parent)
    : QObject(parent)
{
#if defined(Q_OS_LINUX)
    const bool waylandOutputAvailable =
        qEnvironmentVariableIsSet("GAMESCOPE_WAYLAND_DISPLAY")
        || qEnvironmentVariableIsSet("WAYLAND_DISPLAY");
    m_executable = bundledPlaybackEngine(QCoreApplication::applicationDirPath(),
                                         waylandOutputAvailable);
    if (m_executable.isEmpty()) {
        const QString system = QStandardPaths::findExecutable(QStringLiteral("mpv"));
        if (playbackEngineStarts(system))
            m_executable = system;
    }
#endif

    m_ipcRetry.setInterval(60);
    m_videoReadyTimeout.setSingleShot(true);
    m_videoReadyTimeout.setInterval(2500);
    m_overlayRefresh.setInterval(250);
    connect(&m_ipcRetry, &QTimer::timeout, this, &MpvProcessPlayer::connectIpc);
    connect(&m_overlayRefresh, &QTimer::timeout, this, &MpvProcessPlayer::renderOverlay);
    connect(&m_videoReadyTimeout, &QTimer::timeout, this, [this] {
        if (m_process.state() == QProcess::NotRunning || m_hasVideo)
            return;
        emit errorOccurred(QStringLiteral("Native video output could not start."));
    });
    connect(&m_ipc, &QLocalSocket::connected, this, &MpvProcessPlayer::initializeIpc);
    connect(&m_ipc, &QLocalSocket::readyRead, this, [this] {
        m_ipcBuffer += m_ipc.readAll();
        while (true) {
            const qsizetype newline = m_ipcBuffer.indexOf('\n');
            if (newline < 0)
                break;
            const QByteArray line = m_ipcBuffer.left(newline).trimmed();
            m_ipcBuffer.remove(0, newline + 1);
            if (!line.isEmpty())
                handleIpcMessage(QJsonDocument::fromJson(line).object());
        }
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        m_errorLog += m_process.readAllStandardError();
        if (m_errorLog.size() > kMaximumErrorLogBytes)
            m_errorLog = m_errorLog.right(kMaximumErrorLogBytes);
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            setLoading(false);
            emit errorOccurred(QStringLiteral("The native playback engine could not start."));
        }
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
        m_ipcRetry.stop();
        m_videoReadyTimeout.stop();
        m_overlayRefresh.stop();
        m_overlayVisible = false;
        m_ipc.abort();
        if (!m_ipcPath.isEmpty())
            QFile::remove(m_ipcPath);
        setLoading(false);
        setBuffering(false);
        setPlaybackState(false, false);
        const bool intentional = m_intentionalStop;
        m_intentionalStop = false;
        if (intentional)
            return;
        if (m_endSignaled)
            return;
        if (exitStatus == QProcess::NormalExit && exitCode == 0) {
            emit closed();
            return;
        }
        QString detail = QString::fromUtf8(m_errorLog).trimmed();
        const QStringList lines = detail.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        if (!lines.isEmpty())
            detail = lines.constLast().trimmed();
        emit errorOccurred(detail.isEmpty()
            ? QStringLiteral("Native playback stopped unexpectedly.") : detail);
    });
}

MpvProcessPlayer::~MpvProcessPlayer()
{
    stopProcess(true);
    if (!m_ipcPath.isEmpty())
        QFile::remove(m_ipcPath);
}

void MpvProcessPlayer::setSource(const QString &source)
{
    const QString next = source.trimmed();
    if (m_source == next)
        return;
    m_source = next;
    emit sourceChanged();
}

void MpvProcessPlayer::setTitle(const QString &title)
{
    const QString next = title.trimmed();
    if (m_title == next)
        return;
    m_title = next;
    emit titleChanged();
}

void MpvProcessPlayer::setVolume(qreal volume)
{
    const qreal next = std::clamp(volume, 0.0, 1.0);
    if (qFuzzyCompare(m_volume, next))
        return;
    m_volume = next;
    emit volumeChanged();
    if (m_process.state() != QProcess::NotRunning)
        sendCommand({QStringLiteral("set_property"), QStringLiteral("volume"), m_volume * 100.0});
}

void MpvProcessPlayer::setMuted(bool muted)
{
    if (m_muted == muted)
        return;
    m_muted = muted;
    emit mutedChanged();
    if (m_process.state() != QProcess::NotRunning)
        sendCommand({QStringLiteral("set_property"), QStringLiteral("mute"), m_muted});
}

void MpvProcessPlayer::setAudioPassthrough(const QStringList &codecs)
{
    QStringList next;
    for (const QString &codec : codecs) {
        const QString normalized = codec.trimmed().toLower();
        if (!normalized.isEmpty() && !next.contains(normalized))
            next.append(normalized);
    }
    next.sort();
    if (m_audioPassthrough == next)
        return;
    m_audioPassthrough = next;
    emit audioPassthroughChanged();
}

void MpvProcessPlayer::play()
{
    if (!available() || m_source.isEmpty()) {
        emit errorOccurred(QStringLiteral("Native playback is unavailable."));
        return;
    }
    if (m_process.state() == QProcess::NotRunning) {
        startProcess();
        return;
    }
    sendCommand({QStringLiteral("set_property"), QStringLiteral("pause"), false});
    setPlaybackState(true, false);
}

void MpvProcessPlayer::pause()
{
    if (m_process.state() == QProcess::NotRunning)
        return;
    sendCommand({QStringLiteral("set_property"), QStringLiteral("pause"), true});
    setPlaybackState(false, true);
}

void MpvProcessPlayer::stop()
{
    stopProcess(true);
}

void MpvProcessPlayer::setPosition(qint64 positionMs)
{
    if (m_process.state() == QProcess::NotRunning)
        return;
    const double seconds = std::max<qint64>(0, positionMs) / 1000.0;
    sendCommand({QStringLiteral("set_property"), QStringLiteral("time-pos"), seconds});
}

void MpvProcessPlayer::setPreferredAudioTrackIndex(int index)
{
    m_preferredAudioTrackIndex = std::max(-1, index);
    m_audioSelectionInitialized = false;
    if (m_audioTracks.isEmpty())
        return;
    m_audioSelectionInitialized = true;
    const int preferred = preferredAudioTrackId();
    if (preferred >= 0)
        sendCommand({QStringLiteral("set_property"), QStringLiteral("aid"), preferred});
}

void MpvProcessPlayer::toggleSubtitles()
{
    if (m_process.state() == QProcess::NotRunning || m_subtitleTracks.isEmpty())
        return;
    if (m_activeSubtitleId < 0) {
        sendCommand({QStringLiteral("set_property"), QStringLiteral("sid"),
                     m_subtitleTracks.constBegin().key()});
        return;
    }

    auto current = m_subtitleTracks.constFind(m_activeSubtitleId);
    if (current != m_subtitleTracks.cend())
        ++current;
    if (current == m_subtitleTracks.cend()) {
        sendCommand({QStringLiteral("set_property"), QStringLiteral("sid"),
                     QStringLiteral("no")});
    } else {
        sendCommand({QStringLiteral("set_property"), QStringLiteral("sid"),
                     current.key()});
    }
}

void MpvProcessPlayer::cycleAudioTrack()
{
    if (m_process.state() == QProcess::NotRunning || m_audioTracks.size() < 2)
        return;
    auto current = std::find_if(m_audioTracks.cbegin(), m_audioTracks.cend(),
                                [this](const AudioTrack &track) {
                                    return track.id == m_activeAudioId;
                                });
    if (current == m_audioTracks.cend() || ++current == m_audioTracks.cend())
        current = m_audioTracks.cbegin();
    sendCommand({QStringLiteral("set_property"), QStringLiteral("aid"), current->id});
}

void MpvProcessPlayer::showOverlay(const QString &title, const QString &detail,
                                   const QString &quality, bool live,
                                   bool audioControlActive, bool subtitleControlActive,
                                   qint64 positionOffsetMs)
{
    m_overlayTitle = title.trimmed();
    m_overlayDetail = detail.trimmed();
    m_overlayQuality = quality.trimmed();
    m_overlayLive = live;
    m_audioControlActive = audioControlActive;
    m_subtitleControlActive = subtitleControlActive;
    m_overlayPositionOffsetMs = std::max<qint64>(0, positionOffsetMs);
    m_overlayVisible = true;
    m_overlayRefresh.start();
    renderOverlay();
}

void MpvProcessPlayer::hideOverlay()
{
    m_overlayVisible = false;
    m_audioControlActive = false;
    m_subtitleControlActive = false;
    m_overlayRefresh.stop();
    sendCommand({QStringLiteral("osd-overlay"), 41, QStringLiteral("none"),
                 QString{}});
}

QString MpvProcessPlayer::subtitleLabel() const
{
    return m_activeSubtitleId >= 0
        ? m_subtitleTracks.value(m_activeSubtitleId, QStringLiteral("Subtitles"))
        : QStringLiteral("Off");
}

QString MpvProcessPlayer::audioTrackLabel() const
{
    const auto current = std::find_if(m_audioTracks.cbegin(), m_audioTracks.cend(),
                                      [this](const AudioTrack &track) {
                                          return track.id == m_activeAudioId;
                                      });
    return current == m_audioTracks.cend() ? QStringLiteral("Audio") : current->label;
}

void MpvProcessPlayer::startProcess()
{
    stopProcess(true);
    m_position = 0;
    m_duration = 0;
    emit positionChanged();
    emit durationChanged();
    setHasVideo(false);
    m_videoSelected = false;
    m_videoOutputConfigured = false;
    m_subtitleTracks.clear();
    m_activeSubtitleId = -1;
    emit subtitlesChanged();
    m_audioTracks.clear();
    m_activeAudioId = -1;
    m_audioSelectionInitialized = false;
    emit audioTracksChanged();
    m_overlayVisible = false;
    m_overlayRefresh.stop();
    setBuffering(false);
    setLoading(true);
    setPlaybackState(false, false);
    m_errorLog.clear();
    m_ipcBuffer.clear();
    m_endSignaled = false;
    m_intentionalStop = false;
    m_ipcAttempts = 0;

    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    QDir().mkpath(runtime);
    m_ipcPath = QDir(runtime).filePath(QStringLiteral("tater-mpv-%1.sock")
        .arg(QCoreApplication::applicationPid()));
    QFile::remove(m_ipcPath);

    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    const QString gamescopeWayland = environment.value(
        QStringLiteral("GAMESCOPE_WAYLAND_DISPLAY")).trimmed();
    if (!gamescopeWayland.isEmpty())
        environment.insert(QStringLiteral("WAYLAND_DISPLAY"), gamescopeWayland);
    if (QFileInfo(m_executable).fileName() == QStringLiteral("tater-mpv")) {
        const QString libraryDirectory = QDir(QFileInfo(m_executable).absolutePath())
                                             .absoluteFilePath(QStringLiteral("../lib"));
        const QString existingLibraryPath = environment.value(
            QStringLiteral("LD_LIBRARY_PATH"));
        environment.insert(QStringLiteral("LD_LIBRARY_PATH"),
                           existingLibraryPath.isEmpty()
                               ? libraryDirectory
                               : libraryDirectory + QLatin1Char(':') + existingLibraryPath);
    }
    m_process.setProcessEnvironment(environment);
    m_process.setProgram(m_executable);
    m_process.setArguments(mpvArguments());
    m_process.start();
    m_ipcRetry.start();
}

void MpvProcessPlayer::stopProcess(bool intentional)
{
    m_ipcRetry.stop();
    m_videoReadyTimeout.stop();
    if (m_overlayVisible)
        hideOverlay();
    m_ipc.abort();
    if (m_process.state() == QProcess::NotRunning)
        return;
    m_intentionalStop = intentional;
    m_process.terminate();
    if (!m_process.waitForFinished(350)) {
        m_process.kill();
        m_process.waitForFinished(350);
    }
    setPlaybackState(false, false);
    setLoading(false);
    setBuffering(false);
}

void MpvProcessPlayer::connectIpc()
{
    if (m_process.state() == QProcess::NotRunning) {
        m_ipcRetry.stop();
        return;
    }
    if (m_ipc.state() == QLocalSocket::ConnectedState
        || m_ipc.state() == QLocalSocket::ConnectingState) {
        return;
    }
    if (++m_ipcAttempts > 100) {
        m_ipcRetry.stop();
        return;
    }
    m_ipc.abort();
    m_ipc.connectToServer(m_ipcPath);
}

void MpvProcessPlayer::initializeIpc()
{
    m_ipcRetry.stop();
    const QStringList properties{
        QStringLiteral("time-pos"), QStringLiteral("duration"), QStringLiteral("pause"),
        QStringLiteral("paused-for-cache"), QStringLiteral("volume"), QStringLiteral("mute"),
        QStringLiteral("vid"), QStringLiteral("vo-configured"),
        QStringLiteral("track-list"), QStringLiteral("sid"), QStringLiteral("aid"),
    };
    int id = 1;
    for (const QString &property : properties)
        sendCommand({QStringLiteral("observe_property"), id++, property});
    sendCommand({QStringLiteral("set_property"), QStringLiteral("volume"), m_volume * 100.0});
    sendCommand({QStringLiteral("set_property"), QStringLiteral("mute"), m_muted});
    sendCommand({QStringLiteral("set_property"), QStringLiteral("sid"),
                 QStringLiteral("no")});
    if (m_overlayVisible)
        renderOverlay();
}

void MpvProcessPlayer::sendCommand(const QJsonArray &command)
{
    if (m_ipc.state() != QLocalSocket::ConnectedState)
        return;
    QJsonObject request{{QStringLiteral("command"), command}};
    m_ipc.write(QJsonDocument(request).toJson(QJsonDocument::Compact) + '\n');
    m_ipc.flush();
}

void MpvProcessPlayer::handleIpcMessage(const QJsonObject &message)
{
    const QString event = message.value(QStringLiteral("event")).toString();
    if (event == QStringLiteral("property-change")) {
        handleProperty(message.value(QStringLiteral("name")).toString(),
                       message.value(QStringLiteral("data")));
    } else if (event == QStringLiteral("file-loaded")) {
        setLoading(false);
        setPlaybackState(true, false);
        if (!m_hasVideo)
            m_videoReadyTimeout.start();
        emit loaded();
    } else if (event == QStringLiteral("playback-restart")) {
        setLoading(false);
        setBuffering(false);
    } else if (event == QStringLiteral("end-file")) {
        const QString reason = message.value(QStringLiteral("reason")).toString();
        if (reason == QStringLiteral("eof") && !m_endSignaled) {
            m_endSignaled = true;
            setPlaybackState(false, false);
            emit endOfMedia();
        } else if (reason == QStringLiteral("error")) {
            m_endSignaled = true;
            const QString detail = message.value(QStringLiteral("file_error")).toString();
            emit errorOccurred(detail.isEmpty()
                ? QStringLiteral("Native playback could not open this media.") : detail);
        }
    }
}

void MpvProcessPlayer::handleProperty(const QString &name, const QJsonValue &value)
{
    if (name == QStringLiteral("time-pos") && value.isDouble()) {
        const qint64 next = qRound64(value.toDouble() * 1000.0);
        if (m_position != next) {
            m_position = next;
            emit positionChanged();
        }
    } else if (name == QStringLiteral("duration") && value.isDouble()) {
        const qint64 next = qRound64(value.toDouble() * 1000.0);
        if (m_duration != next) {
            m_duration = next;
            emit durationChanged();
        }
    } else if (name == QStringLiteral("pause") && value.isBool()) {
        const bool isPaused = value.toBool();
        setPlaybackState(!isPaused, isPaused);
    } else if (name == QStringLiteral("paused-for-cache") && value.isBool()) {
        setBuffering(value.toBool());
    } else if (name == QStringLiteral("volume") && value.isDouble()) {
        const qreal next = std::clamp(value.toDouble() / 100.0, 0.0, 1.0);
        if (!qFuzzyCompare(m_volume, next)) {
            m_volume = next;
            emit volumeChanged();
        }
    } else if (name == QStringLiteral("mute") && value.isBool()) {
        const bool next = value.toBool();
        if (m_muted != next) {
            m_muted = next;
            emit mutedChanged();
        }
    } else if (name == QStringLiteral("vid")) {
        m_videoSelected = (value.isDouble() && value.toInt() > 0)
            || (value.isString() && value.toString() != QStringLiteral("no"));
        setHasVideo(m_videoSelected && m_videoOutputConfigured);
    } else if (name == QStringLiteral("vo-configured") && value.isBool()) {
        m_videoOutputConfigured = value.toBool();
        setHasVideo(m_videoSelected && m_videoOutputConfigured);
    } else if (name == QStringLiteral("track-list")) {
        updateTracks(value);
    } else if (name == QStringLiteral("sid")) {
        int next = -1;
        if (value.isDouble() && value.toInt() > 0)
            next = value.toInt();
        if (m_activeSubtitleId != next) {
            m_activeSubtitleId = next;
            emit subtitlesChanged();
            renderOverlay();
        }
    } else if (name == QStringLiteral("aid")) {
        int next = -1;
        if (value.isDouble() && value.toInt() > 0)
            next = value.toInt();
        if (m_activeAudioId != next) {
            m_activeAudioId = next;
            emit audioTracksChanged();
            renderOverlay();
        }
    }
}

void MpvProcessPlayer::updateTracks(const QJsonValue &value)
{
    QMap<int, QString> subtitleTracks;
    QList<AudioTrack> audioTracks;
    const QJsonArray values = value.toArray();
    for (const QJsonValue &entry : values) {
        const QJsonObject track = entry.toObject();
        const int id = track.value(QStringLiteral("id")).toInt(-1);
        if (id < 0)
            continue;
        const QString type = track.value(QStringLiteral("type")).toString();
        if (type == QStringLiteral("sub")) {
            QString label = track.value(QStringLiteral("title")).toString().trimmed();
            const QString language = normalizedTrackLanguage(
                track.value(QStringLiteral("lang")).toString());
            if (label.isEmpty())
                label = language.isEmpty() ? QStringLiteral("Subtitles") : language.toUpper();
            else if (!language.isEmpty() && !label.contains(language, Qt::CaseInsensitive))
                label += QStringLiteral(" • ") + language.toUpper();
            subtitleTracks.insert(id, label);
        } else if (type == QStringLiteral("audio")) {
            AudioTrack audio;
            audio.id = id;
            audio.title = track.value(QStringLiteral("title")).toString().trimmed();
            audio.language = normalizedTrackLanguage(
                track.value(QStringLiteral("lang")).toString());
            audio.codec = track.value(QStringLiteral("codec")).toString().trimmed();
            audio.channelCount = track.value(
                QStringLiteral("demux-channel-count")).toInt();
            audio.channels = audioChannelLabel(audio.channelCount,
                track.value(QStringLiteral("demux-channels")).toString());
            audio.bitrate = qRound64(track.value(
                QStringLiteral("demux-bitrate")).toDouble());
            audio.isDefault = track.value(QStringLiteral("default")).toBool();

            QStringList labelParts;
            if (!audio.language.isEmpty())
                labelParts.append(audio.language.toUpper());
            const QString codecLabel = audioCodecLabel(audio.codec);
            if (!codecLabel.isEmpty())
                labelParts.append(codecLabel);
            if (!audio.channels.isEmpty())
                labelParts.append(audio.channels);
            const QString titleLower = audio.title.toLower();
            if (titleLower.contains(QStringLiteral("atmos")))
                labelParts.append(QStringLiteral("ATMOS"));
            else if (titleLower.contains(QStringLiteral("dts:x")))
                labelParts.append(QStringLiteral("DTS:X"));
            if (titleLower.contains(QStringLiteral("commentary")))
                labelParts.append(QStringLiteral("COMMENTARY"));
            else if (titleLower.contains(QStringLiteral("descriptive"))
                     || titleLower.contains(QStringLiteral("description")))
                labelParts.append(QStringLiteral("DESCRIPTIVE"));
            if (labelParts.isEmpty())
                labelParts.append(audio.title.isEmpty()
                    ? QStringLiteral("Track %1").arg(audioTracks.size() + 1)
                    : audio.title.left(22));
            audio.label = labelParts.join(QStringLiteral(" • "));
            audioTracks.append(audio);
        }
    }

    if (subtitleTracks != m_subtitleTracks) {
        m_subtitleTracks = subtitleTracks;
        if (!m_subtitleTracks.contains(m_activeSubtitleId))
            m_activeSubtitleId = -1;
        emit subtitlesChanged();
    }

    const bool audioChanged = audioTracks != m_audioTracks;
    if (audioChanged) {
        m_audioTracks = audioTracks;
        if (std::none_of(m_audioTracks.cbegin(), m_audioTracks.cend(),
                         [this](const AudioTrack &track) {
                             return track.id == m_activeAudioId;
                         })) {
            m_activeAudioId = -1;
        }
        emit audioTracksChanged();
    }

    if (!m_audioSelectionInitialized && !m_audioTracks.isEmpty()) {
        m_audioSelectionInitialized = true;
        const int preferred = preferredAudioTrackId();
        if (preferred >= 0)
            sendCommand({QStringLiteral("set_property"), QStringLiteral("aid"), preferred});
    }
    renderOverlay();
}

int MpvProcessPlayer::preferredAudioTrackId() const
{
    if (m_preferredAudioTrackIndex >= 0
        && m_preferredAudioTrackIndex < m_audioTracks.size()) {
        return m_audioTracks.at(m_preferredAudioTrackIndex).id;
    }
    qint64 bestScore = std::numeric_limits<qint64>::min();
    int bestId = -1;
    for (const AudioTrack &track : m_audioTracks) {
        qint64 score = 0;
        if (isEnglishTrack(track.language))
            score += 1'000'000;
        else if (track.language.isEmpty())
            score += 100'000;
        if (track.isDefault)
            score += 25'000;
        const QString description = track.title.toLower();
        if (description.contains(QStringLiteral("commentary"))
            || description.contains(QStringLiteral("descriptive"))
            || description.contains(QStringLiteral("description"))) {
            score -= 200'000;
        }
        score += static_cast<qint64>(track.channelCount) * 10'000;
        score += static_cast<qint64>(audioCodecRank(track.codec)) * 1'000;
        score += std::min<qint64>(track.bitrate / 1000, 20'000);
        if (bestId < 0 || score > bestScore) {
            bestScore = score;
            bestId = track.id;
        }
    }
    return bestId;
}

void MpvProcessPlayer::renderOverlay()
{
    if (!m_overlayVisible || m_ipc.state() != QLocalSocket::ConnectedState)
        return;

    const qint64 position = std::max<qint64>(0, m_position + m_overlayPositionOffsetMs);
    const qint64 duration = std::max<qint64>(0, m_duration + m_overlayPositionOffsetMs);
    const qreal progress = m_overlayLive || duration <= 0
        ? 0.0 : std::clamp(static_cast<qreal>(position) / duration, 0.0, 1.0);
    const int progressLeft = 82;
    const int progressRight = 1838;
    const int progressEnd = progressLeft
        + qRound((progressRight - progressLeft) * progress);

    QString subtitleText;
    if (m_subtitleTracks.isEmpty())
        subtitleText = QStringLiteral("Y  CC  NONE");
    else if (m_activeSubtitleId < 0)
        subtitleText = QStringLiteral("Y  CC  OFF");
    else
        subtitleText = QStringLiteral("Y  CC  %1").arg(subtitleLabel()).left(19);
    const QString audioText = m_audioTracks.isEmpty()
        ? QStringLiteral("X  AUDIO  NONE")
        : QStringLiteral("X  AUDIO  %1").arg(audioTrackLabel()).left(33);

    const QString quality = m_overlayQuality.left(94);
    const bool transcoding = quality.contains(QStringLiteral("TRANSCODE"),
                                               Qt::CaseInsensitive);
    const int statusLeft = 82;
    const int statusTop = 934;
    const int statusBottom = 968;
    const int statusRight = statusLeft
        + std::clamp(static_cast<int>(quality.size()) * 10 + 54, 230, 1120);

    const QString panel = QStringLiteral(
        "{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H1D1917&\\1a&H28&\\p1}"
        "m 48 840 l 1872 840 b 1886 840 1898 852 1898 866 "
        "l 1898 1024 b 1898 1038 1886 1050 1872 1050 "
        "l 48 1050 b 34 1050 22 1038 22 1024 "
        "l 22 866 b 22 852 34 840 48 840{\\p0}");
    const QString progressTrack = QStringLiteral(
        "{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H605A55&\\1a&H18&\\p1}"
        "m %1 986 l %2 986 l %2 994 l %1 994{\\p0}")
        .arg(progressLeft).arg(progressRight);
    QStringList events{panel};
    events.append(QStringLiteral(
        "{\\an7\\pos(82,866)\\fnSans Serif\\fs34\\b1\\bord0\\shad0"
        "\\1c&HF3F6F6&}%1").arg(assEscape(m_overlayTitle.left(72))));

    QString detail = m_overlayDetail;
    if (m_paused)
        detail += QStringLiteral("  •  PAUSED");
    events.append(QStringLiteral(
        "{\\an7\\pos(84,908)\\fnSans Serif\\fs18\\b1\\bord0\\shad0"
        "\\1c&HB4AFAA&}%1").arg(assEscape(detail.left(92))));

    const QString statusColor = transcoding
        ? QStringLiteral("&H1F78FF&") : QStringLiteral("&H37332F&");
    const QString statusTextColor = transcoding
        ? QStringLiteral("&HF3F6F6&") : QStringLiteral("&H1F78FF&");
    events.append(QStringLiteral(
        "{\\an7\\pos(0,0)\\bord0\\shad0\\1c%1\\1a&H48&\\p1}"
        "m %2 %3 l %4 %3 b %5 %3 %6 %7 %6 %8 "
        "l %6 %9 b %6 %10 %5 %11 %4 %11 "
        "l %2 %11 b %12 %11 %13 %10 %13 %9 "
        "l %13 %8 b %13 %7 %12 %3 %2 %3{\\p0}")
        .arg(statusColor)
        .arg(statusLeft + 11).arg(statusTop).arg(statusRight - 11)
        .arg(statusRight - 5).arg(statusRight).arg(statusTop + 5)
        .arg(statusTop + 11).arg(statusBottom - 11).arg(statusBottom - 5)
        .arg(statusBottom).arg(statusLeft + 5).arg(statusLeft));
    events.append(QStringLiteral(
        "{\\an5\\pos(%1,%2)\\fnSans Serif\\fs16\\b1\\bord0\\shad0"
        "\\1c%3}%4").arg((statusLeft + statusRight) / 2)
        .arg((statusTop + statusBottom) / 2)
        .arg(statusTextColor, assEscape(quality)));

    const bool audioAvailable = !m_audioTracks.isEmpty();
    const QString audioChipColor = m_audioControlActive
        ? QStringLiteral("&H1F78FF&") : QStringLiteral("&H37332F&");
    const QString audioChipAlpha = m_audioControlActive
        ? QStringLiteral("&H28&") : QStringLiteral("&H70&");
    const QString audioChipTextColor = m_audioControlActive
        ? QStringLiteral("&H11100F&")
        : (audioAvailable ? QStringLiteral("&HF3F6F6&") : QStringLiteral("&H77726D&"));
    events.append(QStringLiteral(
        "{\\an7\\pos(0,0)\\bord0\\shad0\\1c%1\\1a%2\\p1}"
        "m 1398 872 l 1670 872 b 1680 872 1688 880 1688 890 "
        "l 1688 906 b 1688 916 1680 924 1670 924 "
        "l 1398 924 b 1388 924 1380 916 1380 906 "
        "l 1380 890 b 1380 880 1388 872 1398 872{\\p0}")
        .arg(audioChipColor, audioChipAlpha));
    events.append(QStringLiteral(
        "{\\an5\\pos(1534,898)\\fnSans Serif\\fs15\\b1\\bord0\\shad0"
        "\\1c%1}%2").arg(audioChipTextColor, assEscape(audioText)));

    const bool subtitleAvailable = !m_subtitleTracks.isEmpty();
    const QString subtitleChipColor = m_subtitleControlActive
        ? QStringLiteral("&H1F78FF&") : QStringLiteral("&H37332F&");
    const QString subtitleChipAlpha = m_subtitleControlActive
        ? QStringLiteral("&H28&") : QStringLiteral("&H70&");
    const QString subtitleChipTextColor = m_subtitleControlActive
        ? QStringLiteral("&H11100F&")
        : (subtitleAvailable ? QStringLiteral("&HF3F6F6&") : QStringLiteral("&H77726D&"));
    events.append(QStringLiteral(
        "{\\an7\\pos(0,0)\\bord0\\shad0\\1c%1\\1a%2\\p1}"
        "m 1718 872 l 1844 872 b 1854 872 1862 880 1862 890 "
        "l 1862 906 b 1862 916 1854 924 1844 924 "
        "l 1718 924 b 1708 924 1700 916 1700 906 "
        "l 1700 890 b 1700 880 1708 872 1718 872{\\p0}")
        .arg(subtitleChipColor, subtitleChipAlpha));
    events.append(QStringLiteral(
        "{\\an5\\pos(1781,898)\\fnSans Serif\\fs15\\b1\\bord0\\shad0"
        "\\1c%1}%2").arg(subtitleChipTextColor, assEscape(subtitleText)));

    events.append(progressTrack);
    if (m_overlayLive) {
        events.append(QStringLiteral(
            "{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H1F78FF&\\p1}"
            "m 82 986 l 1838 986 l 1838 994 l 82 994{\\p0}"));
    } else if (progressEnd > progressLeft) {
        events.append(QStringLiteral(
            "{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H1F78FF&\\p1}"
            "m %1 986 l %2 986 l %2 994 l %1 994{\\p0}")
            .arg(progressLeft).arg(progressEnd));
    }

    events.append(QStringLiteral(
        "{\\an7\\pos(82,1005)\\fnSans Serif\\fs17\\b1\\bord0\\shad0"
        "\\1c&HF3F6F6&}%1").arg(m_overlayLive
            ? QStringLiteral("LIVE") : assEscape(formatTime(position))));
    events.append(QStringLiteral(
        "{\\an9\\pos(1838,1005)\\fnSans Serif\\fs17\\b0\\bord0\\shad0"
        "\\1c&HB4AFAA&}%1").arg(m_overlayLive
            ? QStringLiteral("ON AIR") : assEscape(formatTime(duration))));

    sendCommand({QStringLiteral("osd-overlay"), 41, QStringLiteral("ass-events"),
                 events.join(QLatin1Char('\n')), 1920, 1080, 20});
}

QString MpvProcessPlayer::assEscape(const QString &text)
{
    QString escaped = text;
    escaped.replace(QLatin1Char('\\'), QStringLiteral("\\\\"));
    escaped.replace(QLatin1Char('{'), QStringLiteral("\\{"));
    escaped.replace(QLatin1Char('}'), QStringLiteral("\\}"));
    escaped.replace(QLatin1Char('\r'), QLatin1Char(' '));
    escaped.replace(QLatin1Char('\n'), QStringLiteral("\\N"));
    return escaped;
}

QString MpvProcessPlayer::formatTime(qint64 milliseconds)
{
    const qint64 totalSeconds = std::max<qint64>(0, milliseconds / 1000);
    const qint64 hours = totalSeconds / 3600;
    const qint64 minutes = (totalSeconds % 3600) / 60;
    const qint64 seconds = totalSeconds % 60;
    if (hours > 0) {
        return QStringLiteral("%1:%2:%3").arg(hours)
            .arg(minutes, 2, 10, QLatin1Char('0'))
            .arg(seconds, 2, 10, QLatin1Char('0'));
    }
    return QStringLiteral("%1:%2").arg(minutes)
        .arg(seconds, 2, 10, QLatin1Char('0'));
}

void MpvProcessPlayer::setPlaybackState(bool playing, bool paused)
{
    if (m_playing == playing && m_paused == paused)
        return;
    m_playing = playing;
    m_paused = paused;
    emit playbackStateChanged();
    renderOverlay();
}

void MpvProcessPlayer::setLoading(bool loading)
{
    if (m_loading == loading)
        return;
    m_loading = loading;
    emit loadingChanged();
}

void MpvProcessPlayer::setBuffering(bool buffering)
{
    if (m_buffering == buffering)
        return;
    m_buffering = buffering;
    emit bufferingChanged();
}

void MpvProcessPlayer::setHasVideo(bool hasVideo)
{
    if (m_hasVideo == hasVideo)
        return;
    m_hasVideo = hasVideo;
    if (m_hasVideo)
        m_videoReadyTimeout.stop();
    emit hasVideoChanged();
}

QString MpvProcessPlayer::inputConfigPath() const
{
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(directory);
    const QString path = QDir(directory).filePath(QStringLiteral("mpv-input.conf"));
    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        file.write("ESC quit\nBACKSPACE quit\nq quit\nSPACE cycle pause\n"
                   "LEFT seek -10 exact\nRIGHT seek 10 exact\n"
                   "UP add volume 5\nDOWN add volume -5\n");
        file.commit();
    }
    return path;
}

QStringList MpvProcessPlayer::mpvArguments() const
{
    QStringList arguments{
        QStringLiteral("--no-config"),
        QStringLiteral("--cache=yes"),
        QStringLiteral("--cache-pause=yes"),
        QStringLiteral("--cache-pause-initial=yes"),
        QStringLiteral("--cache-pause-wait=1"),
        QStringLiteral("--demuxer-readahead-secs=20"),
        QStringLiteral("--demuxer-max-bytes=256MiB"),
        QStringLiteral("--fullscreen=yes"),
        QStringLiteral("--force-window=yes"),
        QStringLiteral("--keep-open=no"),
        QStringLiteral("--osc=no"),
        QStringLiteral("--input-default-bindings=no"),
        QStringLiteral("--input-conf=%1").arg(inputConfigPath()),
        QStringLiteral("--input-ipc-server=%1").arg(m_ipcPath),
        QStringLiteral("--hwdec=auto-safe"),
        QStringLiteral("--vo=gpu-next"),
        QStringLiteral("--target-colorspace-hint=auto"),
        QStringLiteral("--tone-mapping=auto"),
        QStringLiteral("--audio-channels=auto-safe"),
        QStringLiteral("--alang=eng,en"),
        QStringLiteral("--sid=no"),
        QStringLiteral("--osd-color=#fff4ec"),
        QStringLiteral("--osd-border-color=#d0180b04"),
        QStringLiteral("--osd-bar=yes"),
        QStringLiteral("--osd-on-seek=bar"),
        QStringLiteral("--osd-bar-align-y=0.88"),
        QStringLiteral("--osd-bar-w=72"),
        QStringLiteral("--osd-bar-h=2"),
        QStringLiteral("--title=Tater Tube Player"),
        QStringLiteral("--force-media-title=%1").arg(
            m_title.isEmpty() ? QStringLiteral("Tater Tube") : m_title),
    };
    if (qEnvironmentVariableIsSet("GAMESCOPE_WAYLAND_DISPLAY")) {
        arguments.append(QStringLiteral("--gpu-api=vulkan"));
        arguments.append(QStringLiteral("--gpu-context=waylandvk"));
    }

    QStringList passthrough;
    for (const QString &codec : m_audioPassthrough) {
        const QString mpvCodec = mpvPassthroughName(codec);
        if (!mpvCodec.isEmpty() && !passthrough.contains(mpvCodec))
            passthrough.append(mpvCodec);
    }
    if (!passthrough.isEmpty())
        arguments.append(QStringLiteral("--audio-spdif=%1").arg(passthrough.join(QLatin1Char(','))));
    arguments.append(QStringLiteral("--"));
    arguments.append(m_source);
    return arguments;
}

QString MpvProcessPlayer::bundledPlaybackEngine(const QString &applicationDirectory,
                                                bool waylandOutputAvailable)
{
    if (!waylandOutputAvailable)
        return {};
    const QString bundled = QDir(applicationDirectory).filePath(
        QStringLiteral("tater-mpv"));
    return QFileInfo(bundled).isExecutable() ? bundled : QString{};
}

QString MpvProcessPlayer::mpvPassthroughName(const QString &codec)
{
    QString normalized = codec.trimmed().toLower();
    normalized.replace(QLatin1Char('_'), QLatin1Char('-'));
    if (normalized == QStringLiteral("dtshd"))
        normalized = QStringLiteral("dts-hd");
    const QStringList supported{
        QStringLiteral("ac3"), QStringLiteral("dts"), QStringLiteral("dts-hd"),
        QStringLiteral("eac3"), QStringLiteral("truehd"),
    };
    return supported.contains(normalized) ? normalized : QString{};
}
