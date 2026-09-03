#pragma once

#include <QObject>
#include <QHash>
#include <QNetworkAccessManager>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class QNetworkReply;

class ServerClient final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl NOTIFY connectionChanged)
    Q_PROPERTY(QString serverName READ serverName NOTIFY connectionChanged)
    Q_PROPERTY(QString serverVersion READ serverVersion NOTIFY connectionChanged)
    Q_PROPERTY(QString playerName READ playerName NOTIFY connectionChanged)
    Q_PROPERTY(bool paired READ paired NOTIFY connectionChanged)
    Q_PROPERTY(bool online READ online NOTIFY connectionChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(bool homeLoading READ homeLoading NOTIFY homeChanged)
    Q_PROPERTY(bool homeReady READ homeReady NOTIFY homeChanged)
    Q_PROPERTY(QString homeErrorMessage READ homeErrorMessage NOTIFY homeChanged)
    Q_PROPERTY(QVariantList continueWatching READ continueWatching NOTIFY homeChanged)
    Q_PROPERTY(QVariantList recentlyAdded READ recentlyAdded NOTIFY homeChanged)
    Q_PROPERTY(QVariantList liveChannels READ liveChannels NOTIFY homeChanged)
    Q_PROPERTY(QVariantList libraries READ libraries NOTIFY homeChanged)
    Q_PROPERTY(QVariantMap capabilities READ capabilities NOTIFY homeChanged)
    Q_PROPERTY(QStringList homeWarnings READ homeWarnings NOTIFY homeChanged)
    Q_PROPERTY(QVariantList libraryItems READ libraryItems NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList libraryRows READ libraryRows NOTIFY libraryChanged)
    Q_PROPERTY(QString libraryTitle READ libraryTitle NOTIFY libraryChanged)
    Q_PROPERTY(bool libraryLoading READ libraryLoading NOTIFY libraryChanged)
    Q_PROPERTY(bool libraryRowsLoading READ libraryRowsLoading NOTIFY libraryChanged)
    Q_PROPERTY(QString libraryErrorMessage READ libraryErrorMessage NOTIFY libraryChanged)
    Q_PROPERTY(int libraryDepth READ libraryDepth NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList liveGuideChannels READ liveGuideChannels NOTIFY liveGuideChanged)
    Q_PROPERTY(bool liveGuideLoading READ liveGuideLoading NOTIFY liveGuideChanged)
    Q_PROPERTY(bool liveGuideReady READ liveGuideReady NOTIFY liveGuideChanged)
    Q_PROPERTY(QString liveGuideErrorMessage READ liveGuideErrorMessage NOTIFY liveGuideChanged)

public:
    explicit ServerClient(QObject *parent = nullptr);

    QString serverUrl() const { return m_serverUrl; }
    QString serverName() const { return m_serverName; }
    QString serverVersion() const { return m_serverVersion; }
    QString playerName() const { return m_playerName; }
    bool paired() const { return !m_serverUrl.isEmpty() && !m_token.isEmpty(); }
    bool online() const { return m_online; }
    bool busy() const { return m_busy; }
    QString errorMessage() const { return m_errorMessage; }
    bool homeLoading() const { return m_homeLoading; }
    bool homeReady() const { return m_homeReady; }
    QString homeErrorMessage() const { return m_homeErrorMessage; }
    QVariantList continueWatching() const { return m_continueWatching; }
    QVariantList recentlyAdded() const { return m_recentlyAdded; }
    QVariantList liveChannels() const { return m_liveChannels; }
    QVariantList libraries() const { return m_libraries; }
    QVariantMap capabilities() const { return m_capabilities; }
    QStringList homeWarnings() const { return m_homeWarnings; }
    QVariantList libraryItems() const { return m_libraryItems; }
    QVariantList libraryRows() const { return m_libraryRows; }
    QString libraryTitle() const { return m_libraryTitle; }
    bool libraryLoading() const { return m_libraryLoading; }
    bool libraryRowsLoading() const { return m_libraryRowsPending > 0; }
    QString libraryErrorMessage() const { return m_libraryErrorMessage; }
    int libraryDepth() const { return m_libraryHistory.size(); }
    QVariantList liveGuideChannels() const { return m_liveGuideChannels; }
    bool liveGuideLoading() const { return m_liveGuideLoading; }
    bool liveGuideReady() const { return m_liveGuideReady; }
    QString liveGuideErrorMessage() const { return m_liveGuideErrorMessage; }

    Q_INVOKABLE void pair(const QString &serverUrl, const QString &pin);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshHome();
    Q_INVOKABLE void refreshLibraries();
    Q_INVOKABLE void refreshLibraryRows();
    Q_INVOKABLE void browseLibrary(const QVariantMap &entry);
    Q_INVOKABLE void browseLibraryItem(const QVariantMap &item);
    Q_INVOKABLE void browseLibraryBack();
    Q_INVOKABLE void refreshLibrary();
    Q_INVOKABLE void refreshLiveGuide();
    Q_INVOKABLE void forgetServer();
    Q_INVOKABLE void savePlaybackProgress(const QVariantMap &item, qint64 positionMs,
                                          qint64 durationMs, bool completed = false);
    Q_INVOKABLE QString playbackTranscodeUrl(const QString &streamUrl,
                                             const QString &profile,
                                             qint64 startMs = 0) const;
    Q_INVOKABLE QString playbackAudioTranscodeUrl(const QString &streamUrl,
                                                  const QString &profile,
                                                  qint64 startMs = 0) const;

    static QString normalizedServerUrl(const QString &rawUrl);
    static QString endpointUrl(const QString &rawUrl, const QString &path);

signals:
    void connectionChanged();
    void busyChanged();
    void errorMessageChanged();
    void homeChanged();
    void libraryChanged();
    void liveGuideChanged();
    void pairingCompleted();

private:
    struct LibraryLocation {
        QString categoryId;
        QString title;
        QString path;
        int sourceIndex = -1;
        bool continueWatching = false;
    };

    struct LibraryCacheEntry {
        QVariantList items;
        QString title;
        qint64 storedAtMs = 0;
    };

    void loadSettings();
    void saveSettings() const;
    void setBusy(bool busy);
    void setErrorMessage(const QString &message);
    void setOnline(bool online);
    void setHomeLoading(bool loading);
    void resetHome();
    static LibraryLocation libraryLocationFromEntry(const QVariantMap &entry);
    void loadLibraryRows(bool forceNetwork);
    void handleLibraryRowsReply(QNetworkReply *reply, int generation);
    void loadLibraryLocation(const LibraryLocation &location, bool pushHistory,
                             bool forceNetwork = false);
    void handleLibraryReply(QNetworkReply *reply, const LibraryLocation &location,
                            bool pushHistory);
    QString libraryCacheKey(const LibraryLocation &location) const;
    void handleLibrariesReply(QNetworkReply *reply);
    void handleLiveGuideReply(QNetworkReply *reply);
    static QVariantMap guideProgram(const QVariantList &schedule, double elapsedSeconds,
                                    bool current);
    void handlePairReply(QNetworkReply *reply, const QString &baseUrl);
    void handleServerInfoReply(QNetworkReply *reply);
    void handleHomeReply(QNetworkReply *reply);
    static QString responseError(const QByteArray &body, const QString &fallback);

    QNetworkAccessManager m_network;
    QString m_serverUrl;
    QString m_token;
    QString m_serverName;
    QString m_serverVersion;
    QString m_playerName;
    QString m_errorMessage;
    QString m_homeErrorMessage;
    QVariantList m_continueWatching;
    QVariantList m_recentlyAdded;
    QVariantList m_liveChannels;
    QVariantList m_libraries;
    QVariantMap m_capabilities;
    QStringList m_homeWarnings;
    QVariantList m_libraryItems;
    QVariantList m_libraryRows;
    QString m_libraryTitle;
    QString m_libraryErrorMessage;
    QVector<LibraryLocation> m_libraryHistory;
    QHash<QString, LibraryCacheEntry> m_libraryCache;
    int m_libraryRowsGeneration = 0;
    int m_libraryRowsPending = 0;
    qint64 m_libraryRowsStoredAtMs = 0;
    QVariantList m_liveGuideChannels;
    QString m_liveGuideErrorMessage;
    bool m_online = false;
    bool m_busy = false;
    bool m_homeLoading = false;
    bool m_homeReady = false;
    bool m_libraryLoading = false;
    bool m_liveGuideLoading = false;
    bool m_liveGuideReady = false;
};
