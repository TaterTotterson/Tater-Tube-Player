#include "PlaybackCapabilities.h"

#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMediaFormat>
#include <QProcess>
#include <QScreen>
#include <QSysInfo>
#include <QTimer>

#include <algorithm>

namespace {
void appendUnique(QStringList &values, const QString &value)
{
    if (!value.isEmpty() && !values.contains(value))
        values.append(value);
}

QString pulseCodec(const QString &format)
{
    const QString normalized = format.trimmed().toLower();
    if (normalized.contains(QStringLiteral("truehd")))
        return QStringLiteral("truehd");
    if (normalized.contains(QStringLiteral("eac3"))
        || normalized.contains(QStringLiteral("e-ac3"))) {
        return QStringLiteral("eac3");
    }
    if (normalized.contains(QStringLiteral("ac3")))
        return QStringLiteral("ac3");
    if (normalized.contains(QStringLiteral("dts")))
        return QStringLiteral("dts");
    return {};
}
}

PlaybackCapabilities::PlaybackCapabilities(bool compatibilityMode, QObject *parent)
    : QObject(parent)
    , m_compatibilityMode(compatibilityMode)
{
    connect(&m_mediaDevices, &QMediaDevices::audioOutputsChanged,
            this, &PlaybackCapabilities::refresh);
    connect(qGuiApp, &QGuiApplication::screenAdded,
            this, [this](QScreen *) { refresh(); });
    connect(qGuiApp, &QGuiApplication::screenRemoved,
            this, [this](QScreen *) { refresh(); });
    refresh();
}

QVariantMap PlaybackCapabilities::report() const
{
    int maxWidth = 1920;
    int maxHeight = 1080;
    if (QScreen *screen = QGuiApplication::primaryScreen()) {
        const QSize pixels = screen->size() * screen->devicePixelRatio();
        maxWidth = std::max(pixels.width(), pixels.height());
        maxHeight = std::min(pixels.width(), pixels.height());
    }

    return {
        {QStringLiteral("platform"), QSysInfo::productType()},
        {QStringLiteral("engine"), QStringLiteral("qt_multimedia")},
        {QStringLiteral("output_name"), m_outputName},
        {QStringLiteral("output_connection"), m_outputConnection},
        {QStringLiteral("containers"), supportedContainers()},
        {QStringLiteral("video_codecs"), supportedVideoCodecs()},
        {QStringLiteral("audio_codecs"), supportedAudioCodecs()},
        // Qt Multimedia decodes to PCM. Keep sink passthrough formats separate so
        // the shared server contract is ready for native Apple TV/Google TV and
        // a future Steam playback engine that can send encoded audio unchanged.
        {QStringLiteral("audio_passthrough"), QStringList{}},
        {QStringLiteral("sink_passthrough_codecs"), m_sinkPassthroughCodecs},
        {QStringLiteral("passthrough_available"), false},
        {QStringLiteral("max_width"), maxWidth},
        {QStringLiteral("max_height"), maxHeight},
        {QStringLiteral("max_audio_channels"),
         std::max(2, m_defaultAudioOutput.maximumChannelCount())},
        {QStringLiteral("compatibility_mode"), m_compatibilityMode},
    };
}

void PlaybackCapabilities::refresh()
{
    const QAudioDevice nextOutput = QMediaDevices::defaultAudioOutput();
    const QString nextName = nextOutput.isNull()
        ? QStringLiteral("System audio") : nextOutput.description().trimmed();
    const QString nextConnection = detectedConnection(
        QString::fromUtf8(nextOutput.id()), nextName);
    const bool changed = nextOutput != m_defaultAudioOutput
        || nextName != m_outputName || nextConnection != m_outputConnection;

    m_defaultAudioOutput = nextOutput;
    m_outputName = nextName;
    m_outputConnection = nextConnection;
    if (changed)
        emit capabilitiesChanged();
    probePulseOutput();
}

void PlaybackCapabilities::probePulseOutput()
{
#if defined(Q_OS_LINUX)
    const int generation = ++m_probeGeneration;
    auto *process = new QProcess(this);
    process->setProgram(QStringLiteral("pactl"));
    process->setArguments({QStringLiteral("--format=json"), QStringLiteral("info")});
    connect(process, &QProcess::finished, this,
            [this, process, generation](int exitCode, QProcess::ExitStatus status) {
        const QByteArray payload = process->readAllStandardOutput();
        process->deleteLater();
        if (generation != m_probeGeneration || status != QProcess::NormalExit || exitCode != 0)
            return;
        const QJsonObject info = QJsonDocument::fromJson(payload).object();
        probePulseSinks(info.value(QStringLiteral("default_sink_name")).toString(), generation);
    });
    process->start();
    QTimer::singleShot(2500, process, [process] {
        if (process->state() != QProcess::NotRunning)
            process->kill();
    });
#else
    m_sinkPassthroughCodecs.clear();
#endif
}

void PlaybackCapabilities::probePulseSinks(const QString &defaultSinkName, int generation)
{
    auto *process = new QProcess(this);
    process->setProgram(QStringLiteral("pactl"));
    process->setArguments({QStringLiteral("--format=json"), QStringLiteral("list"),
                           QStringLiteral("sinks")});
    connect(process, &QProcess::finished, this,
            [this, process, defaultSinkName, generation](int exitCode,
                                                         QProcess::ExitStatus status) {
        const QByteArray payload = process->readAllStandardOutput();
        process->deleteLater();
        if (generation != m_probeGeneration || status != QProcess::NormalExit || exitCode != 0)
            return;
        applyPulseSink(payload, defaultSinkName, generation);
    });
    process->start();
    QTimer::singleShot(2500, process, [process] {
        if (process->state() != QProcess::NotRunning)
            process->kill();
    });
}

void PlaybackCapabilities::applyPulseSink(const QByteArray &payload,
                                           const QString &defaultSinkName,
                                           int generation)
{
    if (generation != m_probeGeneration)
        return;
    const QJsonArray sinks = QJsonDocument::fromJson(payload).array();
    QJsonObject selected;
    for (const QJsonValue &value : sinks) {
        const QJsonObject sink = value.toObject();
        if (sink.value(QStringLiteral("name")).toString() == defaultSinkName) {
            selected = sink;
            break;
        }
    }
    if (selected.isEmpty())
        return;

    QStringList passthrough;
    for (const QJsonValue &value : selected.value(QStringLiteral("formats")).toArray())
        appendUnique(passthrough, pulseCodec(value.toString()));
    passthrough.sort();

    const QString pulseName = selected.value(QStringLiteral("description")).toString().trimmed();
    const QString pulseConnection = detectedConnection(
        selected.value(QStringLiteral("name")).toString(), pulseName);
    const bool changed = passthrough != m_sinkPassthroughCodecs
        || (!pulseName.isEmpty() && pulseName != m_outputName)
        || pulseConnection != m_outputConnection;
    m_sinkPassthroughCodecs = passthrough;
    if (!pulseName.isEmpty())
        m_outputName = pulseName;
    m_outputConnection = pulseConnection;
    if (changed)
        emit capabilitiesChanged();
}

QString PlaybackCapabilities::detectedConnection(const QString &id,
                                                  const QString &description) const
{
    const QString value = (id + QLatin1Char(' ') + description).toLower();
    if (value.contains(QStringLiteral("hdmi"))
        || value.contains(QStringLiteral("displayport"))
        || value.contains(QStringLiteral("display port"))) {
        return QStringLiteral("hdmi");
    }
    if (value.contains(QStringLiteral("bluetooth")) || value.contains(QStringLiteral("bluez")))
        return QStringLiteral("bluetooth");
    if (value.contains(QStringLiteral("headphone")) || value.contains(QStringLiteral("headset")))
        return QStringLiteral("headphones");
    if (value.contains(QStringLiteral("speaker")))
        return QStringLiteral("speaker");
    return QStringLiteral("unknown");
}

QStringList PlaybackCapabilities::supportedContainers()
{
    QMediaFormat format;
    QStringList result;
    for (const QMediaFormat::FileFormat value : format.supportedFileFormats(QMediaFormat::Decode)) {
        switch (value) {
        case QMediaFormat::MPEG4:
        case QMediaFormat::QuickTime:
            appendUnique(result, QStringLiteral("mp4"));
            break;
        case QMediaFormat::Matroska:
            appendUnique(result, QStringLiteral("mkv"));
            break;
        case QMediaFormat::WebM:
            appendUnique(result, QStringLiteral("webm"));
            break;
        case QMediaFormat::Mpeg4Audio:
        case QMediaFormat::AAC:
            appendUnique(result, QStringLiteral("aac"));
            break;
        case QMediaFormat::MP3:
            appendUnique(result, QStringLiteral("mp3"));
            break;
        case QMediaFormat::FLAC:
            appendUnique(result, QStringLiteral("flac"));
            break;
        case QMediaFormat::Wave:
            appendUnique(result, QStringLiteral("wav"));
            break;
        default:
            break;
        }
    }
    result.sort();
    return result;
}

QStringList PlaybackCapabilities::supportedVideoCodecs()
{
    QMediaFormat format;
    QStringList result;
    for (const QMediaFormat::VideoCodec value : format.supportedVideoCodecs(QMediaFormat::Decode)) {
        switch (value) {
        case QMediaFormat::VideoCodec::H264: appendUnique(result, QStringLiteral("h264")); break;
        case QMediaFormat::VideoCodec::H265: appendUnique(result, QStringLiteral("hevc")); break;
        case QMediaFormat::VideoCodec::VP8: appendUnique(result, QStringLiteral("vp8")); break;
        case QMediaFormat::VideoCodec::VP9: appendUnique(result, QStringLiteral("vp9")); break;
        case QMediaFormat::VideoCodec::AV1: appendUnique(result, QStringLiteral("av1")); break;
        case QMediaFormat::VideoCodec::MPEG1: appendUnique(result, QStringLiteral("mpeg1video")); break;
        case QMediaFormat::VideoCodec::MPEG2: appendUnique(result, QStringLiteral("mpeg2video")); break;
        case QMediaFormat::VideoCodec::MPEG4: appendUnique(result, QStringLiteral("mpeg4")); break;
        case QMediaFormat::VideoCodec::Theora: appendUnique(result, QStringLiteral("theora")); break;
        case QMediaFormat::VideoCodec::WMV: appendUnique(result, QStringLiteral("wmv")); break;
        case QMediaFormat::VideoCodec::MotionJPEG: appendUnique(result, QStringLiteral("mjpeg")); break;
        default: break;
        }
    }
    result.sort();
    return result;
}

QStringList PlaybackCapabilities::supportedAudioCodecs()
{
    QMediaFormat format;
    QStringList result;
    for (const QMediaFormat::AudioCodec value : format.supportedAudioCodecs(QMediaFormat::Decode)) {
        switch (value) {
        case QMediaFormat::AudioCodec::MP3: appendUnique(result, QStringLiteral("mp3")); break;
        case QMediaFormat::AudioCodec::AAC: appendUnique(result, QStringLiteral("aac")); break;
        case QMediaFormat::AudioCodec::AC3: appendUnique(result, QStringLiteral("ac3")); break;
        case QMediaFormat::AudioCodec::EAC3: appendUnique(result, QStringLiteral("eac3")); break;
        case QMediaFormat::AudioCodec::FLAC: appendUnique(result, QStringLiteral("flac")); break;
        case QMediaFormat::AudioCodec::DolbyTrueHD: appendUnique(result, QStringLiteral("truehd")); break;
        case QMediaFormat::AudioCodec::Opus: appendUnique(result, QStringLiteral("opus")); break;
        case QMediaFormat::AudioCodec::Vorbis: appendUnique(result, QStringLiteral("vorbis")); break;
        case QMediaFormat::AudioCodec::Wave: appendUnique(result, QStringLiteral("pcm")); break;
        case QMediaFormat::AudioCodec::WMA: appendUnique(result, QStringLiteral("wma")); break;
        case QMediaFormat::AudioCodec::ALAC: appendUnique(result, QStringLiteral("alac")); break;
        default: break;
        }
    }
    result.sort();
    return result;
}
