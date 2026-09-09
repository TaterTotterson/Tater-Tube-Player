#pragma once

#include <QObject>
#include <QHash>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QTimer>
#include <QUrl>

class QNetworkReply;
class QTemporaryFile;

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
    Q_PROPERTY(QVariantMap homeHero READ homeHero NOTIFY homeChanged)
    Q_PROPERTY(QStringList homeWarnings READ homeWarnings NOTIFY homeChanged)
    Q_PROPERTY(QVariantList libraryItems READ libraryItems NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList libraryRows READ libraryRows NOTIFY libraryChanged)
    Q_PROPERTY(QString libraryTitle READ libraryTitle NOTIFY libraryChanged)
    Q_PROPERTY(bool libraryLoading READ libraryLoading NOTIFY libraryChanged)
    Q_PROPERTY(bool libraryRowsLoading READ libraryRowsLoading NOTIFY libraryChanged)
    Q_PROPERTY(QString libraryErrorMessage READ libraryErrorMessage NOTIFY libraryChanged)
    Q_PROPERTY(int libraryDepth READ libraryDepth NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList discoverCategories READ discoverCategories NOTIFY discoverChanged)
    Q_PROPERTY(QVariantList discoverItems READ discoverItems NOTIFY discoverChanged)
    Q_PROPERTY(QString discoverTitle READ discoverTitle NOTIFY discoverChanged)
    Q_PROPERTY(QString discoverStage READ discoverStage NOTIFY discoverChanged)
    Q_PROPERTY(bool discoverLoading READ discoverLoading NOTIFY discoverChanged)
    Q_PROPERTY(QString discoverErrorMessage READ discoverErrorMessage NOTIFY discoverChanged)
    Q_PROPERTY(QVariantList recommendations READ recommendations NOTIFY recommendationsChanged)
    Q_PROPERTY(QVariantMap recommendationBatch READ recommendationBatch NOTIFY recommendationsChanged)
    Q_PROPERTY(bool recommendationsLoading READ recommendationsLoading NOTIFY recommendationsChanged)
    Q_PROPERTY(QString recommendationsErrorMessage READ recommendationsErrorMessage NOTIFY recommendationsChanged)
    Q_PROPERTY(bool recommendationSpeechLoading READ recommendationSpeechLoading NOTIFY recommendationSpeechChanged)
    Q_PROPERTY(QString recommendationSpeechErrorMessage READ recommendationSpeechErrorMessage NOTIFY recommendationSpeechChanged)
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
    QVariantMap homeHero() const { return m_homeHero; }
    QStringList homeWarnings() const { return m_homeWarnings; }
    QVariantList libraryItems() const { return m_libraryItems; }
    QVariantList libraryRows() const { return m_libraryRows; }
    QString libraryTitle() const { return m_libraryTitle; }
    bool libraryLoading() const { return m_libraryLoading; }
    bool libraryRowsLoading() const { return m_libraryRowsPending > 0; }
    QString libraryErrorMessage() const { return m_libraryErrorMessage; }
    int libraryDepth() const { return m_libraryHistory.size(); }
    QVariantList discoverCategories() const { return m_discoverCategories; }
    QVariantList discoverItems() const { return m_discoverItems; }
    QString discoverTitle() const { return m_discoverTitle; }
    QString discoverStage() const { return m_discoverStage; }
    bool discoverLoading() const { return m_discoverLoading; }
    QString discoverErrorMessage() const { return m_discoverErrorMessage; }
    QVariantList recommendations() const { return m_recommendations; }
    QVariantMap recommendationBatch() const { return m_recommendationBatch; }
    bool recommendationsLoading() const { return m_recommendationsLoading; }
    QString recommendationsErrorMessage() const { return m_recommendationsErrorMessage; }
    bool recommendationSpeechLoading() const { return m_recommendationSpeechLoading; }
    QString recommendationSpeechErrorMessage() const { return m_recommendationSpeechErrorMessage; }
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
    Q_INVOKABLE void refreshDiscover();
    Q_INVOKABLE void browseDiscover(const QVariantMap &entry);
    Q_INVOKABLE void activateDiscoverItem(const QVariantMap &item);
    Q_INVOKABLE void prepareDiscoverPlayback(const QVariantMap &item);
    Q_INVOKABLE void browseDiscoverBack();
    Q_INVOKABLE void refreshRecommendations();
    Q_INVOKABLE void beginRecommendationSpeech(const QString &batchId);
    Q_INVOKABLE void cancelRecommendationSpeech();
    Q_INVOKABLE void reportViewingEvent(const QVariantMap &item, const QString &kind,
                                        const QString &state, qint64 positionMs,
                                        qint64 durationMs, const QString &sessionId,
                                        qint64 watchedMs = 0);
    Q_INVOKABLE void refreshLiveGuide();
    Q_INVOKABLE void forgetServer();
    Q_INVOKABLE QString playbackProfile(const QVariantMap &capabilities) const;
    Q_INVOKABLE void preparePlayback(const QVariantMap &item, const QString &kind,
                                     const QVariantMap &capabilities);
    Q_INVOKABLE void preparePlaybackWithAudioTrack(const QVariantMap &item,
                                                   const QString &kind,
                                                   const QVariantMap &capabilities,
                                                   int audioTrack);
    Q_INVOKABLE void savePlaybackProgress(const QVariantMap &item, qint64 positionMs,
                                          qint64 durationMs, bool completed = false);
    Q_INVOKABLE void clearPlaybackProgress(const QVariantMap &item);
    Q_INVOKABLE QString playbackTranscodeUrl(const QString &streamUrl,
                                             const QString &profile,
                                             qint64 startMs = 0) const;
    Q_INVOKABLE QString playbackUrlAtPosition(const QString &streamUrl,
                                              qint64 startMs = 0) const;
    Q_INVOKABLE QString playbackToneMappedTranscodeUrl(const QString &streamUrl,
                                                       const QString &profile,
                                                       const QString &sourceVideoRange,
                                                       qint64 startMs = 0) const;
    Q_INVOKABLE QString playbackAudioTranscodeUrl(const QString &streamUrl,
                                                  const QString &profile,
                                                  qint64 startMs = 0) const;
    Q_INVOKABLE QString playbackVideoTranscodeUrl(const QString &streamUrl,
                                                  const QString &profile,
                                                  const QString &audioCodec,
                                                  const QString &audioMode,
                                                  qint64 startMs = 0) const;

    static QString normalizedServerUrl(const QString &rawUrl);
    static QString endpointUrl(const QString &rawUrl, const QString &path);

signals:
    void connectionChanged();
    void busyChanged();
    void errorMessageChanged();
    void homeChanged();
    void libraryChanged();
    void discoverChanged();
    void discoverPlaybackReady(const QVariantMap &item);
    void discoverPlaybackFailed(const QString &message);
    void recommendationsChanged();
    void recommendationSpeechChanged();
    void recommendationSpeechReady(const QUrl &audioUrl);
    void playbackPlanReady(const QVariantMap &plan);
    void playbackPlanFailed(const QString &message);
    void playbackProgressCleared();
    void playbackProgressClearFailed(const QString &message);
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

    struct DiscoverCacheEntry {
        QVariantList items;
        QString title;
        QString mediaType;
        qint64 storedAtMs = 0;
    };

    struct DiscoverPage {
        QVariantList items;
        QString title;
        QString stage;
        QString mediaType;
        QVariantMap pendingItem;
    };

    void loadSettings();
    void saveSettings() const;
    void loadContentCache();
    void saveContentCache() const;
    void clearContentCache() const;
    static QString contentCachePath();
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
                            bool pushHistory, int generation);
    QString libraryCacheKey(const LibraryLocation &location) const;
    static QString discoverFeedCacheKey(const QString &catalog);
    static QString discoverSearchCacheKey(const QString &query,
                                          const QString &mediaType);
    void handleLibrariesReply(QNetworkReply *reply);
    void handleDiscoverCatalogReply(QNetworkReply *reply, int generation);
    void handleDiscoverFeedReply(QNetworkReply *reply, int generation,
                                 const QString &fallbackTitle,
                                 const QString &mediaType,
                                 const QString &cacheKey);
    void handleDiscoverSearchReply(QNetworkReply *reply, int generation,
                                   const QString &mediaType,
                                   const QString &fallbackTitle,
                                   const QString &cacheKey);
    void requestDiscoverPlayback(const QVariantMap &item, int generation,
                                 bool updateDiscoverPage);
    void handleDiscoverPlayReply(QNetworkReply *reply, int generation,
                                 const QVariantMap &sourceItem,
                                 bool updateDiscoverPage);
    void handlePlaybackPlanReply(QNetworkReply *reply, int generation);
    void restoreDiscoverPage(const DiscoverPage &page);
    void resetDiscover();
    void resetRecommendations();
    void handleRecommendationsReply(QNetworkReply *reply, int generation);
    void pollRecommendationSpeech();
    void downloadRecommendationSpeech(int generation);
    void failRecommendationSpeech(const QString &message);
    void cancelRemoteRecommendationSpeech(const QString &requestId,
                                          const QString &serverUrl, const QString &token);
    void sendNextViewingEvent();
    void handleLiveGuideReply(QNetworkReply *reply);
    QString guideArtworkUrl(const QVariantMap &program) const;
    static QVariantMap guideProgram(const QVariantList &schedule, double elapsedSeconds,
                                    bool current);
    void handlePairReply(QNetworkReply *reply, const QString &baseUrl);
    void handleServerInfoReply(QNetworkReply *reply);
    void handleHomeReply(QNetworkReply *reply);
    void applyLocalPlaybackProgress(const QVariantMap &item, qint64 positionMs,
                                    qint64 durationMs, bool completed,
                                    bool persistAndNotify);
    void applyPendingPlaybackProgress();
    void clearLocalPlaybackProgress(const QVariantMap &item);
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
    QVariantMap m_homeHero;
    QStringList m_homeWarnings;
    QVariantList m_libraryItems;
    QVariantList m_libraryRows;
    QString m_libraryTitle;
    QString m_libraryErrorMessage;
    QVector<LibraryLocation> m_libraryHistory;
    QHash<QString, LibraryCacheEntry> m_libraryCache;
    int m_libraryGeneration = 0;
    int m_libraryRowsGeneration = 0;
    int m_libraryRowsPending = 0;
    qint64 m_libraryRowsStoredAtMs = 0;
    QVariantList m_discoverCategories;
    QVariantList m_discoverItems;
    QString m_discoverTitle;
    QString m_discoverStage = QStringLiteral("catalog");
    QString m_discoverMediaType;
    QString m_discoverErrorMessage;
    QVariantMap m_discoverPendingItem;
    QVector<DiscoverPage> m_discoverHistory;
    QHash<QString, DiscoverCacheEntry> m_discoverCache;
    int m_discoverGeneration = 0;
    int m_playbackGeneration = 0;
    QVariantMap m_pendingPlaybackItem;
    qint64 m_pendingPlaybackPositionMs = 0;
    qint64 m_pendingPlaybackDurationMs = 0;
    qint64 m_pendingPlaybackStoredAtMs = 0;
    bool m_pendingPlaybackCompleted = false;
    bool m_discoverLoading = false;
    QVariantList m_recommendations;
    QVariantMap m_recommendationBatch;
    QString m_recommendationsErrorMessage;
    int m_recommendationsGeneration = 0;
    bool m_recommendationsLoading = false;
    QTimer m_recommendationSpeechPollTimer;
    QTimer m_recommendationSpeechDeadline;
    QPointer<QNetworkReply> m_recommendationSpeechReply;
    QPointer<QTemporaryFile> m_recommendationSpeechFile;
    QString m_recommendationSpeechBatchId;
    QString m_recommendationSpeechRequestId;
    QString m_recommendationSpeechErrorMessage;
    int m_recommendationSpeechGeneration = 0;
    bool m_recommendationSpeechCreating = false;
    bool m_recommendationSpeechLoading = false;
    QList<QJsonObject> m_pendingViewingEvents;
    QPointer<QNetworkReply> m_viewingEventReply;
    int m_viewingEventGeneration = 0;
    QVariantList m_liveGuideChannels;
    QString m_liveGuideErrorMessage;
    bool m_online = false;
    bool m_busy = false;
    bool m_homeLoading = false;
    bool m_homeReady = false;
    bool m_libraryLoading = false;
    bool m_librariesLoading = false;
    bool m_liveGuideLoading = false;
    bool m_liveGuideReady = false;
};
