#include "PlaybackCapabilities.h"

#include <QGuiApplication>
#include <QDir>
#include <QFile>
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

bool truthyEnvironmentValue(const QByteArray &value)
{
    const QByteArray normalized = value.trimmed().toLower();
    return normalized == "1" || normalized == "true" || normalized == "yes"
        || normalized == "on" || normalized == "enabled";
}

bool environmentFlag(const char *name, bool fallback)
{
    if (!qEnvironmentVariableIsSet(name))
        return fallback;
    return truthyEnvironmentValue(qgetenv(name));
}

QStringList environmentList(const char *name)
{
    QStringList result;
    const QString value = qEnvironmentVariable(name).trimmed().toLower();
    for (const QString &part : value.split(QLatin1Char(','), Qt::SkipEmptyParts)) {
        QString normalized = part.trimmed();
        normalized.replace(QLatin1Char('-'), QLatin1Char('_'));
        if (normalized == QStringLiteral("dv") || normalized == QStringLiteral("dovi"))
            normalized = QStringLiteral("dolby_vision");
        else if (normalized == QStringLiteral("hdr10+"))
            normalized = QStringLiteral("hdr10plus");
        appendUnique(result, normalized);
    }
    return result;
}

QVariantList environmentIntegerList(const char *name)
{
    QVariantList result;
    for (const QString &part : qEnvironmentVariable(name).split(QLatin1Char(','), Qt::SkipEmptyParts)) {
        bool ok = false;
        const int value = part.trimmed().toInt(&ok);
        if (ok && value > 0 && !result.contains(value))
            result.append(value);
    }
    return result;
}

struct ConnectedDisplayReport {
    QString name;
    QStringList hdrFormats;
    QStringList audioPassthrough;
    int maxAudioChannels = 2;
    QString source;
};

void applyEdidCapabilities(ConnectedDisplayReport &report, const QByteArray &edid)
{
    report.hdrFormats = PlaybackCapabilities::hdrFormatsFromEdid(edid);
    const QVariantMap audio = PlaybackCapabilities::audioCapabilitiesFromEdid(edid);
    report.audioPassthrough = audio.value(QStringLiteral("passthrough")).toStringList();
    report.maxAudioChannels = std::max(
        2, audio.value(QStringLiteral("max_channels"), 2).toInt());
}

ConnectedDisplayReport connectedDisplayReport(const QString &outputConnection)
{
    ConnectedDisplayReport report;
    const QStringList overrideFormats = environmentList("TATER_DISPLAY_HDR_FORMATS");
    if (!overrideFormats.isEmpty()) {
        report.name = qEnvironmentVariable("TATER_DISPLAY_NAME").trimmed();
        report.hdrFormats = overrideFormats;
        report.source = QStringLiteral("override");
        return report;
    }

#if defined(Q_OS_LINUX)
    // In Steam Gaming Mode, Gamescope exposes the EDID for the display it is
    // actively presenting on. Prefer it over DRM connector enumeration so a
    // docked Deck reports the television instead of its internal display.
    const QString gamescopeEdidPath =
        qEnvironmentVariable("GAMESCOPE_PATCHED_EDID_FILE").trimmed();
    if (!gamescopeEdidPath.isEmpty()) {
        QFile gamescopeEdid(gamescopeEdidPath);
        if (gamescopeEdid.open(QIODevice::ReadOnly)) {
            report.name = qEnvironmentVariable("TATER_DISPLAY_NAME").trimmed();
            if (report.name.isEmpty())
                report.name = QStringLiteral("Gamescope display");
            applyEdidCapabilities(report, gamescopeEdid.readAll());
            report.source = QStringLiteral("gamescope_edid");
            return report;
        }
    }

    const QDir drm(QStringLiteral("/sys/class/drm"));
    const QStringList connectors = drm.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &connector : connectors) {
        if (!connector.contains(QLatin1Char('-')))
            continue;
        if (outputConnection == QStringLiteral("hdmi")
            && !connector.contains(QStringLiteral("HDMI"), Qt::CaseInsensitive)
            && !connector.contains(QStringLiteral("DP"), Qt::CaseInsensitive)) {
            continue;
        }
        QFile status(drm.filePath(connector + QStringLiteral("/status")));
        if (!status.open(QIODevice::ReadOnly)
            || status.readAll().trimmed() != QByteArrayLiteral("connected")) {
            continue;
        }
        QFile edid(drm.filePath(connector + QStringLiteral("/edid")));
        if (!edid.open(QIODevice::ReadOnly))
            continue;
        const QByteArray bytes = edid.readAll();
        const QStringList formats = PlaybackCapabilities::hdrFormatsFromEdid(bytes);
        if (formats.isEmpty() && !report.name.isEmpty())
            continue;
        report.name = connector.section(QLatin1Char('-'), 1, -1);
        applyEdidCapabilities(report, bytes);
        report.source = QStringLiteral("edid");
        if (!formats.isEmpty())
            break;
    }
#else
    Q_UNUSED(outputConnection)
#endif
    return report;
}
}

PlaybackCapabilities::PlaybackCapabilities(bool compatibilityMode, bool nativePlayback,
                                           QObject *parent)
    : QObject(parent)
    , m_compatibilityMode(compatibilityMode)
    , m_nativePlayback(nativePlayback)
{
    connect(&m_mediaDevices, &QMediaDevices::audioOutputsChanged,
            this, &PlaybackCapabilities::refresh);
    connect(qGuiApp, &QGuiApplication::screenAdded,
            this, [this](QScreen *) { refresh(); });
    connect(qGuiApp, &QGuiApplication::screenRemoved,
            this, [this](QScreen *) { refresh(); });
    connect(qGuiApp, &QGuiApplication::primaryScreenChanged,
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

    const ConnectedDisplayReport display = connectedDisplayReport(m_outputConnection);
    const bool hdrTransportAvailable = environmentFlag("TATER_DISPLAY_HDR_ENABLED",
        environmentFlag("ENABLE_GAMESCOPE_WSI", false)
            && environmentFlag("STEAM_GAMESCOPE_HDR_SUPPORTED", true));
    const bool hdrEnabled = !display.hdrFormats.isEmpty() && hdrTransportAvailable;
    QStringList videoHDRFormats = environmentList("TATER_VIDEO_HDR_FORMATS");
    if (videoHDRFormats.isEmpty() && hdrEnabled) {
        const QStringList videoCodecs = supportedVideoCodecs();
        if (videoCodecs.contains(QStringLiteral("hevc"))
            || videoCodecs.contains(QStringLiteral("vp9"))
            || videoCodecs.contains(QStringLiteral("av1"))) {
            // Gamescope's native HDR client path is PQ/HDR10. HDR10+ can use its
            // HDR10 base layer, while HLG and Dolby Vision are tone-mapped unless
            // a future/native playback engine explicitly advertises them.
            if (display.hdrFormats.contains(QStringLiteral("hdr10")))
                appendUnique(videoHDRFormats, QStringLiteral("hdr10"));
        }
    }

    QStringList videoCodecs = supportedVideoCodecs();
    QStringList audioCodecs = supportedAudioCodecs();
    if (m_nativePlayback) {
        appendUnique(videoCodecs, QStringLiteral("vc1"));
        appendUnique(videoCodecs, QStringLiteral("prores"));
        appendUnique(audioCodecs, QStringLiteral("dts"));
        appendUnique(audioCodecs, QStringLiteral("dts_hd"));
        appendUnique(audioCodecs, QStringLiteral("truehd"));
        videoCodecs.sort();
        audioCodecs.sort();
    }
    const QStringList passthrough = m_nativePlayback && m_outputConnection == QStringLiteral("hdmi")
        ? display.audioPassthrough : QStringList{};

    return {
        {QStringLiteral("capability_version"), 3},
        {QStringLiteral("platform"), QSysInfo::productType()},
        {QStringLiteral("engine"), m_nativePlayback
            ? QStringLiteral("mpv") : QStringLiteral("qt_multimedia")},
        {QStringLiteral("output_name"), m_outputName},
        {QStringLiteral("output_connection"), m_outputConnection},
        {QStringLiteral("containers"), supportedContainers()},
        {QStringLiteral("video_codecs"), videoCodecs},
        {QStringLiteral("audio_codecs"), audioCodecs},
        {QStringLiteral("audio_passthrough"), passthrough},
        {QStringLiteral("sink_passthrough_codecs"), m_sinkPassthroughCodecs},
        {QStringLiteral("passthrough_available"), !passthrough.isEmpty()},
        {QStringLiteral("audio_downmix"), m_nativePlayback},
        {QStringLiteral("video_hdr_formats"), videoHDRFormats},
        {QStringLiteral("display_hdr_formats"), display.hdrFormats},
        {QStringLiteral("display_hdr_enabled"), hdrEnabled},
        {QStringLiteral("display_name"), display.name},
        {QStringLiteral("display_capability_source"), display.source},
        {QStringLiteral("max_video_bit_depth"), videoHDRFormats.isEmpty() ? 8 : 10},
        {QStringLiteral("dolby_vision_profiles"), environmentIntegerList("TATER_DOLBY_VISION_PROFILES")},
        {QStringLiteral("max_width"), maxWidth},
        {QStringLiteral("max_height"), maxHeight},
        {QStringLiteral("max_audio_channels"), std::max(
             {2, m_defaultAudioOutput.maximumChannelCount(), display.maxAudioChannels})},
        {QStringLiteral("compatibility_mode"), m_compatibilityMode},
    };
}

QStringList PlaybackCapabilities::hdrFormatsFromEdid(const QByteArray &edid)
{
    QStringList result;
    if (edid.size() < 128)
        return result;

    const int availableExtensions = static_cast<int>(edid.size() / 128) - 1;
    const int extensionCount = std::min(
        static_cast<int>(static_cast<unsigned char>(edid[126])), availableExtensions);
    for (int extension = 0; extension < extensionCount; ++extension) {
        const int base = 128 * (extension + 1);
        if (static_cast<unsigned char>(edid[base]) != 0x02)
            continue;
        int end = static_cast<unsigned char>(edid[base + 2]);
        if (end == 0 || end > 127)
            end = 127;
        for (int offset = 4; offset < end;) {
            const unsigned char header = static_cast<unsigned char>(edid[base + offset]);
            const int tag = header >> 5;
            const int length = header & 0x1f;
            if (length == 0 || offset + length >= end)
                break;
            const unsigned char *payload = reinterpret_cast<const unsigned char *>(
                edid.constData() + base + offset + 1);
            if (tag == 7 && length >= 2 && payload[0] == 0x06) {
                const unsigned char eotf = payload[1];
                if ((eotf & 0x04) != 0)
                    appendUnique(result, QStringLiteral("hdr10"));
                if ((eotf & 0x08) != 0)
                    appendUnique(result, QStringLiteral("hlg"));
            }
            if (tag == 3 && length >= 3) {
                if (payload[0] == 0x46 && payload[1] == 0xd0 && payload[2] == 0x00)
                    appendUnique(result, QStringLiteral("dolby_vision"));
                if (payload[0] == 0x8b && payload[1] == 0x84 && payload[2] == 0x90) {
                    appendUnique(result, QStringLiteral("hdr10plus"));
                    appendUnique(result, QStringLiteral("hdr10"));
                }
            }
            offset += length + 1;
        }
    }
    result.sort();
    return result;
}

QVariantMap PlaybackCapabilities::audioCapabilitiesFromEdid(const QByteArray &edid)
{
    QStringList passthrough;
    int maxChannels = 2;
    if (edid.size() < 128) {
        return {{QStringLiteral("passthrough"), passthrough},
                {QStringLiteral("max_channels"), maxChannels}};
    }

    const int availableExtensions = static_cast<int>(edid.size() / 128) - 1;
    const int extensionCount = std::min(
        static_cast<int>(static_cast<unsigned char>(edid[126])), availableExtensions);
    for (int extension = 0; extension < extensionCount; ++extension) {
        const int base = 128 * (extension + 1);
        if (static_cast<unsigned char>(edid[base]) != 0x02)
            continue;
        int end = static_cast<unsigned char>(edid[base + 2]);
        if (end == 0 || end > 127)
            end = 127;
        for (int offset = 4; offset < end;) {
            const unsigned char header = static_cast<unsigned char>(edid[base + offset]);
            const int tag = header >> 5;
            const int length = header & 0x1f;
            if (length == 0 || offset + length >= end)
                break;
            if (tag == 1) {
                for (int index = 0; index + 2 < length; index += 3) {
                    const unsigned char descriptor = static_cast<unsigned char>(
                        edid[base + offset + 1 + index]);
                    const int format = (descriptor >> 3) & 0x0f;
                    maxChannels = std::max(maxChannels, static_cast<int>(descriptor & 0x07) + 1);
                    switch (format) {
                    case 2: appendUnique(passthrough, QStringLiteral("ac3")); break;
                    case 7: appendUnique(passthrough, QStringLiteral("dts")); break;
                    case 10: appendUnique(passthrough, QStringLiteral("eac3")); break;
                    case 11: appendUnique(passthrough, QStringLiteral("dts_hd")); break;
                    case 12: appendUnique(passthrough, QStringLiteral("truehd")); break;
                    default: break;
                    }
                }
            }
            offset += length + 1;
        }
    }
    passthrough.sort();
    return {{QStringLiteral("passthrough"), passthrough},
            {QStringLiteral("max_channels"), maxChannels}};
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
#if defined(Q_OS_LINUX)
    // Qt groups VC-1 with its Windows Media video support and does not expose a
    // separate QMediaFormat enum for it. The Linux FFmpeg backend can decode
    // VC-1 whenever it advertises WMV, so report the concrete ffprobe codec
    // name that Tater Tube Server uses for playback planning.
    if (result.contains(QStringLiteral("wmv")))
        appendUnique(result, QStringLiteral("vc1"));
#endif
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
