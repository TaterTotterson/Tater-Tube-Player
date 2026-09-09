#pragma once

#include <QByteArray>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QList>
#include <QLocalSocket>
#include <QMap>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QTimer>

class MpvProcessPlayer final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playbackStateChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY playbackStateChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool buffering READ buffering NOTIFY bufferingChanged)
    Q_PROPERTY(bool hasVideo READ hasVideo NOTIFY hasVideoChanged)
    Q_PROPERTY(bool subtitlesAvailable READ subtitlesAvailable NOTIFY subtitlesChanged)
    Q_PROPERTY(bool subtitlesEnabled READ subtitlesEnabled NOTIFY subtitlesChanged)
    Q_PROPERTY(QString subtitleLabel READ subtitleLabel NOTIFY subtitlesChanged)
    Q_PROPERTY(bool audioTracksAvailable READ audioTracksAvailable NOTIFY audioTracksChanged)
    Q_PROPERTY(bool multipleAudioTracks READ multipleAudioTracks NOTIFY audioTracksChanged)
    Q_PROPERTY(QString audioTrackLabel READ audioTrackLabel NOTIFY audioTracksChanged)
    Q_PROPERTY(QStringList audioPassthrough READ audioPassthrough
               WRITE setAudioPassthrough NOTIFY audioPassthroughChanged)

public:
    explicit MpvProcessPlayer(QObject *parent = nullptr);
    ~MpvProcessPlayer() override;

    bool available() const { return !m_executable.isEmpty(); }
    QString source() const { return m_source; }
    QString title() const { return m_title; }
    qint64 position() const { return m_position; }
    qint64 duration() const { return m_duration; }
    qreal volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    bool playing() const { return m_playing; }
    bool paused() const { return m_paused; }
    bool loading() const { return m_loading; }
    bool buffering() const { return m_buffering; }
    bool hasVideo() const { return m_hasVideo; }
    bool subtitlesAvailable() const { return !m_subtitleTracks.isEmpty(); }
    bool subtitlesEnabled() const { return m_activeSubtitleId >= 0; }
    QString subtitleLabel() const;
    bool audioTracksAvailable() const { return !m_audioTracks.isEmpty(); }
    bool multipleAudioTracks() const { return m_audioTracks.size() > 1; }
    QString audioTrackLabel() const;
    QStringList audioPassthrough() const { return m_audioPassthrough; }

    void setSource(const QString &source);
    void setTitle(const QString &title);
    void setVolume(qreal volume);
    void setMuted(bool muted);
    void setAudioPassthrough(const QStringList &codecs);

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void setPosition(qint64 positionMs);
    Q_INVOKABLE void setPreferredAudioTrackIndex(int index);
    Q_INVOKABLE void toggleSubtitles();
    Q_INVOKABLE void cycleAudioTrack();
    Q_INVOKABLE void showOverlay(const QString &title, const QString &detail,
                                 const QString &quality, bool live,
                                 bool audioControlActive, bool subtitleControlActive,
                                 qint64 positionOffsetMs);
    Q_INVOKABLE void hideOverlay();

signals:
    void sourceChanged();
    void titleChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void mutedChanged();
    void playbackStateChanged();
    void loadingChanged();
    void bufferingChanged();
    void hasVideoChanged();
    void subtitlesChanged();
    void audioTracksChanged();
    void audioPassthroughChanged();
    void loaded();
    void endOfMedia();
    void closed();
    void backRequested();
    void audioTracksRequested();
    void subtitlesRequested();
    void errorOccurred(const QString &message);

private:
    void startProcess();
    void stopProcess(bool intentional);
    void connectIpc();
    void initializeIpc();
    void sendCommand(const QJsonArray &command);
    void handleIpcMessage(const QJsonObject &message);
    void handleProperty(const QString &name, const QJsonValue &value);
    void setPlaybackState(bool playing, bool paused);
    void setLoading(bool loading);
    void setBuffering(bool buffering);
    void setHasVideo(bool hasVideo);
    void updateTracks(const QJsonValue &value);
    int preferredAudioTrackId() const;
    void renderOverlay();
    QString inputConfigPath() const;
    static QByteArray inputConfigContents();
    QStringList mpvArguments() const;
    static QString bundledPlaybackEngine(const QString &applicationDirectory,
                                         bool waylandOutputAvailable);
    static QString mpvPassthroughName(const QString &codec);
    static QString assEscape(const QString &text);
    static QString formatTime(qint64 milliseconds);

    struct AudioTrack {
        int id = -1;
        QString label;
        QString language;
        QString codec;
        QString title;
        QString channels;
        int channelCount = 0;
        qint64 bitrate = 0;
        bool isDefault = false;

        bool operator==(const AudioTrack &) const = default;
    };

    friend class MpvProcessPlayerTest;

    QString m_executable;
    QString m_source;
    QString m_title;
    QString m_ipcPath;
    QStringList m_audioPassthrough;
    QMap<int, QString> m_subtitleTracks;
    QList<AudioTrack> m_audioTracks;
    QProcess m_process;
    QLocalSocket m_ipc;
    QTimer m_ipcRetry;
    QTimer m_videoReadyTimeout;
    QTimer m_overlayRefresh;
    QByteArray m_ipcBuffer;
    QByteArray m_errorLog;
    qint64 m_position = 0;
    qint64 m_duration = 0;
    qreal m_volume = 0.85;
    bool m_muted = false;
    bool m_playing = false;
    bool m_paused = false;
    bool m_loading = false;
    bool m_buffering = false;
    bool m_hasVideo = false;
    bool m_videoSelected = false;
    bool m_videoOutputConfigured = false;
    bool m_intentionalStop = false;
    bool m_endSignaled = false;
    bool m_overlayVisible = false;
    bool m_overlayLive = false;
    bool m_audioControlActive = false;
    bool m_subtitleControlActive = false;
    bool m_audioSelectionInitialized = false;
    int m_ipcAttempts = 0;
    int m_activeSubtitleId = -1;
    int m_activeAudioId = -1;
    int m_preferredAudioTrackIndex = -1;
    qint64 m_overlayPositionOffsetMs = 0;
    QString m_overlayTitle;
    QString m_overlayDetail;
    QString m_overlayQuality;
};
