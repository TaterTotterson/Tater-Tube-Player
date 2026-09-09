#include "ServerClient.h"

#include <QDateTime>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QUrl>
#include <QUrlQuery>

#include <algorithm>
#include <limits>

namespace {
constexpr auto kSettingsServerUrl = "connection/serverUrl";
constexpr auto kSettingsToken = "connection/playerToken";
constexpr auto kSettingsPlayerName = "connection/playerName";
constexpr qint64 kContentCacheMaxAgeMs = 30LL * 24 * 60 * 60 * 1000;
constexpr int kContentCacheVersion = 1;
constexpr int kMaximumCachedLibraryPages = 48;
constexpr int kMaximumCachedDiscoverPages = 48;
constexpr qint64 kMaximumRecommendationAudioBytes = 8 * 1024 * 1024;

void restrictSettingsToCurrentUser(QSettings &settings)
{
#if defined(Q_OS_UNIX)
    settings.sync();
    const QString fileName = settings.fileName();
    if (!fileName.isEmpty()) {
        QFile::setPermissions(fileName,
                              QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    }
#else
    Q_UNUSED(settings);
#endif
}

QNetworkRequest taterJSONRequest(const QString &server, const QString &path,
                                 const QString &token)
{
    QNetworkRequest request{QUrl(ServerClient::endpointUrl(server, path))};
    request.setRawHeader("Authorization", QByteArray("Bearer ") + token.toUtf8());
    request.setRawHeader("Accept", "application/json");
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    // The paired server owns these endpoints; never forward its credential to a redirect.
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::ManualRedirectPolicy);
    request.setTransferTimeout(15000);
    return request;
}

bool taterReplySucceeded(const QNetworkReply *reply)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    return reply->error() == QNetworkReply::NoError && status >= 200 && status < 300;
}

bool validSpeechRequestID(const QString &id)
{
    static const QRegularExpression safeID(QStringLiteral("^[A-Za-z0-9_-]{1,128}$"));
    return safeID.match(id).hasMatch();
}

QString viewingIdentity(const QString &value)
{
    return QString::fromLatin1(QCryptographicHash::hash(
        value.toUtf8(), QCryptographicHash::Sha256).toHex());
}

QVariantList discoverCategoriesFromCatalog(const QJsonArray &categories)
{
    for (const QJsonValue &categoryValue : categories) {
        const QJsonObject category = categoryValue.toObject();
        if (category.value(QStringLiteral("id")).toString() != QStringLiteral("stream"))
            continue;
        for (const QJsonValue &childValue : category.value(QStringLiteral("children")).toArray()) {
            const QJsonObject child = childValue.toObject();
            if (child.value(QStringLiteral("type")).toString()
                    == QStringLiteral("discoverRoot")) {
                return child.value(QStringLiteral("children")).toArray().toVariantList();
            }
        }
    }
    return {};
}

int librarySeasonNumber(const QVariant &value)
{
    const QVariantMap item = value.toMap();
    static const QRegularExpression seasonPattern(
        QStringLiteral(R"(^(?:season[\s._-]*|s)(\d{1,3})$)"),
        QRegularExpression::CaseInsensitiveOption);
    const QStringList candidates{
        item.value(QStringLiteral("path")).toString().replace('\\', '/').section('/', -1),
        item.value(QStringLiteral("title")).toString(),
    };
    for (const QString &candidate : candidates) {
        const QRegularExpressionMatch match = seasonPattern.match(candidate.trimmed());
        if (match.hasMatch())
            return match.captured(1).toInt();
    }
    return std::numeric_limits<int>::max();
}

void sortLibrarySeasons(QVariantList &items)
{
    if (items.size() < 2 || !std::all_of(items.cbegin(), items.cend(), [](const QVariant &value) {
            return value.toMap().value(QStringLiteral("mediaType")).toString()
                       .compare(QStringLiteral("season"), Qt::CaseInsensitive) == 0;
        })) {
        return;
    }

    std::stable_sort(items.begin(), items.end(), [](const QVariant &left, const QVariant &right) {
        const int leftNumber = librarySeasonNumber(left);
        const int rightNumber = librarySeasonNumber(right);
        if (leftNumber != rightNumber)
            return leftNumber < rightNumber;
        return QString::localeAwareCompare(
                   left.toMap().value(QStringLiteral("title")).toString(),
                   right.toMap().value(QStringLiteral("title")).toString()) < 0;
    });
}

QString normalizedPlayStateCategory(QString value)
{
    value = value.trimmed().toLower();
    if (value.startsWith(QStringLiteral("local:")))
        value.remove(0, 6);
    return value;
}

QString normalizedPlayStatePath(QString value)
{
    return value.trimmed().replace('\\', '/');
}

QStringList playStateIDs(const QVariantMap &item)
{
    QStringList ids;
    for (const QString &key : {QStringLiteral("seriesStateId"),
                               QStringLiteral("playStateId")}) {
        const QString id = item.value(key).toString().trimmed();
        if (!id.isEmpty() && !ids.contains(id))
            ids.append(id);
    }
    return ids;
}

bool playStateMatches(const QVariantMap &candidate, const QVariantMap &target)
{
    const QStringList targetIDs = playStateIDs(target);
    const QStringList candidateIDs = playStateIDs(candidate);
    for (const QString &id : targetIDs) {
        if (candidateIDs.contains(id))
            return true;
    }

    const QString targetPath = normalizedPlayStatePath(
        target.value(QStringLiteral("path")).toString());
    const QString candidatePath = normalizedPlayStatePath(
        candidate.value(QStringLiteral("path")).toString());
    if (targetPath.isEmpty() || targetPath != candidatePath)
        return false;
    return normalizedPlayStateCategory(
               target.value(QStringLiteral("categoryId")).toString())
            == normalizedPlayStateCategory(
                candidate.value(QStringLiteral("categoryId")).toString())
        && target.value(QStringLiteral("sourceIndex")).toInt()
            == candidate.value(QStringLiteral("sourceIndex")).toInt();
}

bool scrubPlaybackProgress(QVariantMap &candidate, const QVariantMap &target)
{
    bool changed = false;
    const QVariantMap resumeItem = candidate.value(QStringLiteral("resumeItem")).toMap();
    if ((!resumeItem.isEmpty() && playStateMatches(resumeItem, target))
        || playStateMatches(candidate, target)) {
        for (const QString &key : {QStringLiteral("viewOffset"),
                                   QStringLiteral("viewOffsetSeconds"),
                                   QStringLiteral("progressPercent"),
                                   QStringLiteral("resumeTitle"),
                                   QStringLiteral("resumeItem")}) {
            changed = candidate.remove(key) > 0 || changed;
        }
    }
    return changed;
}

bool scrubPlaybackProgress(QVariantList &items, const QVariantMap &target,
                           bool removeMatchingItems)
{
    bool changed = false;
    for (qsizetype index = items.size(); index-- > 0;) {
        QVariantMap candidate = items.at(index).toMap();
        const QVariantMap resumeItem = candidate.value(QStringLiteral("resumeItem")).toMap();
        const bool matches = playStateMatches(candidate, target)
            || (!resumeItem.isEmpty() && playStateMatches(resumeItem, target));
        if (removeMatchingItems && matches) {
            items.removeAt(index);
            changed = true;
            continue;
        }
        if (scrubPlaybackProgress(candidate, target)) {
            items[index] = candidate;
            changed = true;
        }
    }
    return changed;
}

void setPlaybackProgressFields(QVariantMap &item, qint64 positionMs,
                               qint64 durationMs)
{
    const qint64 safePositionMs = qMax<qint64>(0, positionMs);
    const qint64 safeDurationMs = qMax<qint64>(0, durationMs);
    item.insert(QStringLiteral("viewOffset"), safePositionMs);
    item.insert(QStringLiteral("viewOffsetSeconds"), safePositionMs / 1000.0);
    if (safeDurationMs > 0) {
        item.insert(QStringLiteral("durationSeconds"), safeDurationMs / 1000.0);
        item.insert(QStringLiteral("progressPercent"),
                    qBound(0.0, safePositionMs * 100.0 / safeDurationMs, 100.0));
    }
}

bool updatePlaybackProgress(QVariantMap &candidate, const QVariantMap &target,
                            qint64 positionMs, qint64 durationMs)
{
    QVariantMap resumeItem = candidate.value(QStringLiteral("resumeItem")).toMap();
    const bool resumeMatches = !resumeItem.isEmpty()
        && playStateMatches(resumeItem, target);
    const bool candidateMatches = playStateMatches(candidate, target);
    if (!resumeMatches && !candidateMatches)
        return false;

    if (resumeMatches) {
        setPlaybackProgressFields(resumeItem, positionMs, durationMs);
        candidate.insert(QStringLiteral("resumeItem"), resumeItem);
    }
    setPlaybackProgressFields(candidate, positionMs, durationMs);
    return true;
}

bool updatePlaybackProgress(QVariantList &items, const QVariantMap &target,
                            qint64 positionMs, qint64 durationMs)
{
    bool changed = false;
    for (qsizetype index = 0; index < items.size(); ++index) {
        QVariantMap candidate = items.at(index).toMap();
        if (!updatePlaybackProgress(candidate, target, positionMs, durationMs))
            continue;
        items[index] = candidate;
        changed = true;
    }
    return changed;
}
}

ServerClient::ServerClient(QObject *parent)
    : QObject(parent)
{
    m_recommendationSpeechPollTimer.setSingleShot(true);
    connect(&m_recommendationSpeechPollTimer, &QTimer::timeout,
            this, &ServerClient::pollRecommendationSpeech);
    m_recommendationSpeechDeadline.setSingleShot(true);
    m_recommendationSpeechDeadline.setInterval(90000);
    connect(&m_recommendationSpeechDeadline, &QTimer::timeout, this, [this] {
        failRecommendationSpeech(QStringLiteral("Tater's voice is taking a little too long. Try again."));
    });
    loadSettings();
    loadContentCache();
    if (paired())
        refresh();
}

QString ServerClient::normalizedServerUrl(const QString &rawUrl)
{
    QString candidate = rawUrl.trimmed();
    if (candidate.isEmpty())
        return {};

    if (!candidate.contains("://"))
        candidate.prepend("http://");

    QUrl url(candidate);
    if (!url.isValid() || url.host().isEmpty())
        return {};
    if (url.scheme().compare("http", Qt::CaseInsensitive) != 0
        && url.scheme().compare("https", Qt::CaseInsensitive) != 0) {
        return {};
    }

    QString path = url.path();
    while (path.endsWith('/') && path.size() > 1)
        path.chop(1);
    if (path.endsWith("/api", Qt::CaseInsensitive))
        path.chop(4);
    if (path == "/")
        path.clear();

    url.setPath(path);
    url.setQuery(QString{});
    url.setFragment({});
    return url.toString(QUrl::StripTrailingSlash);
}

QString ServerClient::endpointUrl(const QString &rawUrl, const QString &path)
{
    const QString base = normalizedServerUrl(rawUrl);
    if (base.isEmpty())
        return {};

    QUrl url(base);
    QString basePath = url.path();
    while (basePath.endsWith('/'))
        basePath.chop(1);

    QString endpoint = path.trimmed();
    if (!endpoint.startsWith('/'))
        endpoint.prepend('/');
    url.setPath(basePath + endpoint);
    return url.toString();
}

void ServerClient::pair(const QString &serverUrl, const QString &pin)
{
    if (m_busy)
        return;

    const QString baseUrl = normalizedServerUrl(serverUrl);
    const QString cleanPin = pin.trimmed();
    if (baseUrl.isEmpty()) {
        setErrorMessage("Enter a valid Tater Tube Server address.");
        return;
    }
    if (!QRegularExpression(QStringLiteral("^\\d{6}$")).match(cleanPin).hasMatch()) {
        setErrorMessage("Enter the six-digit pairing code from your server.");
        return;
    }

    setErrorMessage({});
    setBusy(true);

    QNetworkRequest request(QUrl(endpointUrl(baseUrl, "/api/tater/players/pair")));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Accept", "application/json");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);

    const QJsonObject payload{
        {QStringLiteral("pin"), cleanPin},
        {QStringLiteral("name"), QStringLiteral("Tater Tube Player")},
    };
    QNetworkReply *reply = m_network.post(
        request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, baseUrl] { handlePairReply(reply, baseUrl); });
}

void ServerClient::refresh()
{
    if (!paired() || m_busy)
        return;

    setBusy(true);
    setErrorMessage({});
    QNetworkRequest request(QUrl(endpointUrl(m_serverUrl, "/api/tater/server")));
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply] { handleServerInfoReply(reply); });
    refreshHome();
}

void ServerClient::refreshHome()
{
    if (!paired() || m_homeLoading)
        return;

    m_homeErrorMessage.clear();
    setHomeLoading(true);
    QUrl homeUrl(endpointUrl(m_serverUrl, "/api/v1/player/home"));
    QUrlQuery homeQuery;
    homeQuery.addQueryItem(QStringLiteral("include_live"), QStringLiteral("0"));
    homeUrl.setQuery(homeQuery);
    QNetworkRequest request{homeUrl};
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply] { handleHomeReply(reply); });
}

void ServerClient::refreshLibraries()
{
    if (!paired() || m_librariesLoading)
        return;

    m_librariesLoading = true;
    m_libraryErrorMessage.clear();
    emit libraryChanged();
    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/tater/usenet/catalog"))};
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply] { handleLibrariesReply(reply); });
}

void ServerClient::refreshLibraryRows()
{
    if (!paired())
        return;
    loadLibraryRows(true);
}

ServerClient::LibraryLocation ServerClient::libraryLocationFromEntry(const QVariantMap &entry)
{
    LibraryLocation location;
    location.categoryId = entry.value(QStringLiteral("id")).toString().trimmed();
    if (location.categoryId.isEmpty())
        location.categoryId = entry.value(QStringLiteral("categoryId")).toString().trimmed();
    location.title = entry.value(QStringLiteral("title"), QStringLiteral("Library"))
                         .toString().trimmed();
    location.path = entry.value(QStringLiteral("path")).toString().trimmed();
    location.sourceIndex = entry.contains(QStringLiteral("sourceIndex"))
        ? entry.value(QStringLiteral("sourceIndex")).toInt() : -1;
    location.continueWatching = entry.value(QStringLiteral("type")).toString()
                                    .compare(QStringLiteral("continue"), Qt::CaseInsensitive) == 0;
    return location;
}

void ServerClient::loadLibraryRows(bool forceNetwork)
{
    Q_UNUSED(forceNetwork)
    if (m_libraryRowsPending > 0)
        return;

    ++m_libraryRowsGeneration;
    const int generation = m_libraryRowsGeneration;
    m_libraryRowsPending = 1;
    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/v1/player/library"))};
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, generation] { handleLibraryRowsReply(reply, generation); });
    emit libraryChanged();
}

void ServerClient::handleLibraryRowsReply(QNetworkReply *reply, int generation)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    if (generation != m_libraryRowsGeneration)
        return;
    m_libraryRowsPending = 0;
    if (!succeeded && (status == 401 || status == 403)) {
        forgetServer();
        setErrorMessage("This player is no longer authorized. Pair it with the server again.");
        return;
    }

    if (!succeeded) {
        if (m_libraryRows.isEmpty())
            m_libraryErrorMessage = responseError(
                body, QStringLiteral("Your library shelves could not be loaded."));
        emit libraryChanged();
        return;
    }

    const QJsonObject data = QJsonDocument::fromJson(body).object()
                                 .value("data").toObject();
    m_libraryRows = data.value("rows").toArray().toVariantList();
    applyPendingPlaybackProgress();
    m_libraryRowsStoredAtMs = QDateTime::currentMSecsSinceEpoch();
    m_libraryErrorMessage.clear();
    setOnline(true);
    saveContentCache();
    emit libraryChanged();
}

void ServerClient::browseLibrary(const QVariantMap &entry)
{
    if (!paired() || m_libraryLoading)
        return;

    const LibraryLocation location = libraryLocationFromEntry(entry);
    if (!location.continueWatching && location.categoryId.isEmpty()) {
        m_libraryErrorMessage = QStringLiteral("This library does not have a browsable server ID.");
        emit libraryChanged();
        return;
    }

    m_libraryHistory.clear();
    loadLibraryLocation(location, true);
}

void ServerClient::browseLibraryItem(const QVariantMap &item)
{
    if (!paired() || m_libraryLoading
        || !item.value(QStringLiteral("streamUrl")).toString().trimmed().isEmpty()) {
        return;
    }

    LibraryLocation location;
    location.categoryId = item.value(QStringLiteral("categoryId")).toString().trimmed();
    if (location.categoryId.isEmpty() && !m_libraryHistory.isEmpty())
        location.categoryId = m_libraryHistory.constLast().categoryId;
    if (location.categoryId.isEmpty()) {
        m_libraryErrorMessage = QStringLiteral("This item does not have a browsable server ID.");
        emit libraryChanged();
        return;
    }
    location.title = item.value(QStringLiteral("title"), QStringLiteral("Library"))
                         .toString().trimmed();
    location.path = item.value(QStringLiteral("path")).toString().trimmed();
    location.sourceIndex = item.contains(QStringLiteral("sourceIndex"))
        ? item.value(QStringLiteral("sourceIndex")).toInt()
        : (m_libraryHistory.isEmpty() ? -1 : m_libraryHistory.constLast().sourceIndex);
    if (m_libraryHistory.isEmpty())
        m_libraryItems.clear();
    loadLibraryLocation(location, true);
}

void ServerClient::browseLibraryBack()
{
    if (m_libraryLoading || m_libraryHistory.isEmpty())
        return;
    if (m_libraryHistory.size() == 1) {
        ++m_libraryGeneration;
        m_libraryHistory.clear();
        m_libraryItems.clear();
        m_libraryTitle.clear();
        m_libraryErrorMessage.clear();
        emit libraryChanged();
        return;
    }

    m_libraryHistory.removeLast();
    loadLibraryLocation(m_libraryHistory.constLast(), false);
}

void ServerClient::refreshLibrary()
{
    if (!m_libraryHistory.isEmpty() && !m_libraryLoading)
        loadLibraryLocation(m_libraryHistory.constLast(), false, true);
}

void ServerClient::refreshDiscover()
{
    if (!paired() || m_discoverLoading)
        return;
    if (m_capabilities.contains(QStringLiteral("newznab"))
        && !m_capabilities.value(QStringLiteral("newznab")).toBool()) {
        resetDiscover();
        m_discoverErrorMessage = QStringLiteral(
            "Discover is available when NZB streaming is enabled on your server.");
        emit discoverChanged();
        return;
    }

    const int generation = ++m_discoverGeneration;
    const bool showingCatalog = m_discoverStage == QStringLiteral("catalog");
    m_discoverLoading = showingCatalog && m_discoverCategories.isEmpty();
    m_discoverErrorMessage.clear();
    if (showingCatalog) {
        m_discoverItems.clear();
        m_discoverTitle = QStringLiteral("Discover");
        m_discoverHistory.clear();
        m_discoverPendingItem.clear();
    }
    emit discoverChanged();

    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/tater/usenet/catalog"))};
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, generation] { handleDiscoverCatalogReply(reply, generation); });
}

void ServerClient::browseDiscover(const QVariantMap &entry)
{
    if (!paired() || m_discoverLoading)
        return;

    const QString catalog = entry.value(QStringLiteral("id")).toString().trimmed();
    if (catalog.isEmpty()) {
        m_discoverErrorMessage = QStringLiteral("This Discover collection is unavailable.");
        emit discoverChanged();
        return;
    }

    const QString title = entry.value(QStringLiteral("fullTitle"),
                                      entry.value(QStringLiteral("title")))
                              .toString().trimmed();
    const QString mediaType = entry.value(QStringLiteral("category")).toString().trimmed();
    const QString cacheKey = discoverFeedCacheKey(catalog);
    const auto cached = m_discoverCache.constFind(cacheKey);
    const int generation = ++m_discoverGeneration;
    m_discoverLoading = cached == m_discoverCache.cend();
    m_discoverErrorMessage.clear();
    m_discoverItems = cached == m_discoverCache.cend() ? QVariantList{} : cached->items;
    m_discoverTitle = cached == m_discoverCache.cend()
        ? (title.isEmpty() ? QStringLiteral("Discover") : title)
        : cached->title;
    m_discoverStage = QStringLiteral("titles");
    m_discoverMediaType = cached == m_discoverCache.cend()
        ? mediaType : cached->mediaType;
    m_discoverHistory.clear();
    m_discoverPendingItem.clear();
    emit discoverChanged();

    QUrl url(endpointUrl(m_serverUrl, "/api/tater/usenet/discover"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("catalog"), catalog);
    url.setQuery(query);
    QNetworkRequest request{url};
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, generation, title, mediaType, cacheKey] {
                handleDiscoverFeedReply(reply, generation, title, mediaType, cacheKey);
            });
}

void ServerClient::activateDiscoverItem(const QVariantMap &item)
{
    if (!paired() || m_discoverLoading || item.isEmpty())
        return;

    if (m_discoverStage == QStringLiteral("titles")) {
        const QString searchQuery = item.value(QStringLiteral("searchQuery"),
                                               item.value(QStringLiteral("title")))
                                        .toString().trimmed();
        if (searchQuery.size() < 3) {
            m_discoverErrorMessage = QStringLiteral("This title could not be searched.");
            emit discoverChanged();
            return;
        }

        m_discoverHistory.append(DiscoverPage{m_discoverItems, m_discoverTitle,
                                                m_discoverStage, m_discoverMediaType,
                                                m_discoverPendingItem});
        m_discoverPendingItem = item;
        const QString mediaType = item.value(QStringLiteral("mediaType"),
                                             m_discoverMediaType)
                                      .toString().trimmed();
        const QString fallbackTitle = QStringLiteral("Results for %1")
                                          .arg(item.value(QStringLiteral("title"))
                                                   .toString().trimmed());
        const QString cacheKey = discoverSearchCacheKey(searchQuery, mediaType);
        const auto cached = m_discoverCache.constFind(cacheKey);
        const int generation = ++m_discoverGeneration;
        m_discoverLoading = cached == m_discoverCache.cend();
        m_discoverErrorMessage.clear();
        m_discoverItems = cached == m_discoverCache.cend() ? QVariantList{} : cached->items;
        m_discoverTitle = cached == m_discoverCache.cend()
            ? fallbackTitle : cached->title;
        m_discoverStage = QStringLiteral("results");
        m_discoverMediaType = cached == m_discoverCache.cend()
            ? mediaType : cached->mediaType;
        emit discoverChanged();

        QUrl url(endpointUrl(m_serverUrl, "/api/tater/usenet/search"));
        QUrlQuery query;
        query.addQueryItem(QStringLiteral("q"), searchQuery);
        url.setQuery(query);
        QNetworkRequest request{url};
        request.setRawHeader("Accept", "application/json");
        request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                             QNetworkRequest::NoLessSafeRedirectPolicy);
        request.setTransferTimeout(30000);
        QNetworkReply *reply = m_network.get(request);
        connect(reply, &QNetworkReply::finished, this,
                [this, reply, generation, mediaType, fallbackTitle, cacheKey] {
                    handleDiscoverSearchReply(reply, generation, mediaType, fallbackTitle,
                                              cacheKey);
                });
        return;
    }

    if (m_discoverStage == QStringLiteral("streams")) {
        if (!item.value(QStringLiteral("streamUrl")).toString().trimmed().isEmpty()) {
            QVariantMap playable = item;
            const QString discoverTitle = playable.value(
                QStringLiteral("discoverTitle")).toString().trimmed();
            if (!discoverTitle.isEmpty())
                playable.insert(QStringLiteral("title"), discoverTitle);
            emit discoverPlaybackReady(playable);
        }
        return;
    }

    if (m_discoverStage != QStringLiteral("results"))
        return;

    const QString nzbUrl = item.value(QStringLiteral("nzbUrl")).toString().trimmed();
    if (nzbUrl.isEmpty()) {
        m_discoverErrorMessage = QStringLiteral("This result does not include an NZB link.");
        emit discoverChanged();
        return;
    }

    const int generation = ++m_discoverGeneration;
    m_discoverLoading = true;
    m_discoverErrorMessage.clear();
    m_discoverPendingItem = item;
    emit discoverChanged();

    requestDiscoverPlayback(item, generation, true);
}

void ServerClient::prepareDiscoverPlayback(const QVariantMap &item)
{
    if (!paired() || item.isEmpty()) {
        emit discoverPlaybackFailed(QStringLiteral(
            "Pair this player before opening a Discover title."));
        return;
    }
    if (item.value(QStringLiteral("nzbUrl")).toString().trimmed().isEmpty()) {
        emit discoverPlaybackFailed(QStringLiteral(
            "This Discover title no longer has a playable source."));
        return;
    }
    requestDiscoverPlayback(item, 0, false);
}

void ServerClient::requestDiscoverPlayback(const QVariantMap &item, int generation,
                                           bool updateDiscoverPage)
{
    const QString nzbUrl = item.value(QStringLiteral("nzbUrl")).toString().trimmed();

    const QJsonObject payload{
        {QStringLiteral("nzb_url"), nzbUrl},
        {QStringLiteral("title"), item.value(
             QStringLiteral("discoverSourceTitle"),
             item.value(QStringLiteral("title"))).toString()},
        {QStringLiteral("category"), item.value(QStringLiteral("category")).toString()},
        {QStringLiteral("timeout"), 300},
    };
    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/tater/usenet/play"))};
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(315000);
    QNetworkReply *reply = m_network.post(
        request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, generation, item, updateDiscoverPage] {
                handleDiscoverPlayReply(reply, generation, item, updateDiscoverPage);
            });
}

void ServerClient::browseDiscoverBack()
{
    if (m_discoverStage == QStringLiteral("catalog"))
        return;

    ++m_discoverGeneration;
    m_discoverLoading = false;
    m_discoverErrorMessage.clear();
    if (!m_discoverHistory.isEmpty()) {
        const DiscoverPage page = m_discoverHistory.takeLast();
        restoreDiscoverPage(page);
    } else {
        m_discoverItems.clear();
        m_discoverTitle = QStringLiteral("Discover");
        m_discoverStage = QStringLiteral("catalog");
        m_discoverMediaType.clear();
        m_discoverPendingItem.clear();
    }
    emit discoverChanged();
}

QString ServerClient::libraryCacheKey(const LibraryLocation &location) const
{
    return QStringLiteral("%1\n%2\n%3\n%4\n%5")
        .arg(m_serverUrl, location.categoryId, QString::number(location.sourceIndex),
             location.path, location.continueWatching ? QStringLiteral("1") : QStringLiteral("0"));
}

QString ServerClient::discoverFeedCacheKey(const QString &catalog)
{
    return QStringLiteral("feed\n%1").arg(catalog.trimmed().toLower());
}

QString ServerClient::discoverSearchCacheKey(const QString &query,
                                              const QString &mediaType)
{
    return QStringLiteral("search\n%1\n%2")
        .arg(mediaType.trimmed().toLower(), query.trimmed().toLower());
}

void ServerClient::loadLibraryLocation(const LibraryLocation &location, bool pushHistory,
                                       bool forceNetwork)
{
    Q_UNUSED(forceNetwork)
    const QString cacheKey = libraryCacheKey(location);
    const auto cached = m_libraryCache.constFind(cacheKey);
    const bool hasCachedPage = cached != m_libraryCache.cend();
    const int generation = ++m_libraryGeneration;
    if (hasCachedPage) {
        m_libraryItems = cached->items;
        m_libraryTitle = cached->title;
        m_libraryErrorMessage.clear();
        m_libraryLoading = false;
        if (pushHistory)
            m_libraryHistory.append(location);
        emit libraryChanged();
    } else {
        m_libraryItems.clear();
        m_libraryTitle = location.title;
        m_libraryLoading = true;
        m_libraryErrorMessage.clear();
        emit libraryChanged();
    }

    QUrl url(endpointUrl(m_serverUrl, location.continueWatching
        ? QStringLiteral("/api/tater/playstate/continue")
        : QStringLiteral("/api/tater/usenet/items")));
    if (!location.continueWatching) {
        QUrlQuery query;
        query.addQueryItem(QStringLiteral("category_id"), location.categoryId);
        if (location.categoryId.startsWith(QStringLiteral("local-discover:")))
            query.addQueryItem(QStringLiteral("full"), QStringLiteral("1"));
        if (location.sourceIndex >= 0)
            query.addQueryItem(QStringLiteral("source"), QString::number(location.sourceIndex));
        if (!location.path.isEmpty())
            query.addQueryItem(QStringLiteral("path"), location.path);
        if (!location.title.isEmpty())
            query.addQueryItem(QStringLiteral("title"), location.title);
        url.setQuery(query);
    }

    QNetworkRequest request{url};
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, location, pushHistory, hasCachedPage, generation] {
                handleLibraryReply(reply, location, pushHistory && !hasCachedPage, generation);
            });
}

void ServerClient::refreshRecommendations()
{
    if (!paired() || m_recommendationsLoading)
        return;
    if (m_capabilities.contains(QStringLiteral("taterLink"))
        && !m_capabilities.value(QStringLiteral("taterLink")).toBool()) {
        resetRecommendations();
        emit recommendationsChanged();
        return;
    }

    const int generation = ++m_recommendationsGeneration;
    m_recommendationsLoading = true;
    m_recommendationsErrorMessage.clear();
    emit recommendationsChanged();

    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/tater/recommendations"))};
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, generation] { handleRecommendationsReply(reply, generation); });
}

void ServerClient::beginRecommendationSpeech(const QString &batchId)
{
    const QString requestedBatch = batchId.trimmed();
    if (!paired() || !m_capabilities.value(QStringLiteral("taterLink")).toBool()
        || requestedBatch.isEmpty()) {
        return;
    }
    if (m_recommendationSpeechBatchId == requestedBatch
        && (m_recommendationSpeechLoading || m_recommendationSpeechFile)) {
        return;
    }

    cancelRecommendationSpeech();
    const int generation = m_recommendationSpeechGeneration;
    const QString server = m_serverUrl;
    const QString token = m_token;
    m_recommendationSpeechBatchId = requestedBatch;
    m_recommendationSpeechLoading = true;
    m_recommendationSpeechCreating = true;
    m_recommendationSpeechDeadline.start();
    emit recommendationSpeechChanged();

    const QJsonObject payload{
        {QStringLiteral("profile_id"), QStringLiteral("household")},
        {QStringLiteral("batch_id"), requestedBatch},
        {QStringLiteral("briefing_kind"), QStringLiteral("recommendations")},
        {QStringLiteral("local_hour"), QTime::currentTime().hour()},
    };
    QNetworkReply *reply = m_network.post(
        taterJSONRequest(server, QStringLiteral("/api/tater/tts/requests"), token),
        QJsonDocument(payload).toJson(QJsonDocument::Compact));
    m_recommendationSpeechReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation, server, token] {
        const QByteArray body = reply->readAll();
        const bool succeeded = taterReplySucceeded(reply);
        const QJsonObject data = QJsonDocument::fromJson(body).object()
                                     .value(QStringLiteral("data")).toObject();
        const QString requestId = data.value(QStringLiteral("id")).toString();
        reply->deleteLater();
        if (generation != m_recommendationSpeechGeneration) {
            // A create already in flight can finish after the user leaves the page.
            if (succeeded && validSpeechRequestID(requestId))
                cancelRemoteRecommendationSpeech(requestId, server, token);
            return;
        }
        m_recommendationSpeechReply.clear();
        m_recommendationSpeechCreating = false;
        if (!succeeded || !validSpeechRequestID(requestId)) {
            failRecommendationSpeech(responseError(
                body, QStringLiteral("Tater's voice is unavailable right now.")));
            return;
        }
        m_recommendationSpeechRequestId = requestId;
        m_recommendationSpeechPollTimer.start(100);
    });
}

void ServerClient::cancelRemoteRecommendationSpeech(const QString &requestId,
                                                    const QString &server,
                                                    const QString &token)
{
    if (!validSpeechRequestID(requestId) || server.isEmpty() || token.isEmpty())
        return;
    QNetworkReply *reply = m_network.deleteResource(taterJSONRequest(
        server, QStringLiteral("/api/tater/tts/requests/%1").arg(requestId), token));
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}

void ServerClient::cancelRecommendationSpeech()
{
    ++m_recommendationSpeechGeneration;
    m_recommendationSpeechPollTimer.stop();
    m_recommendationSpeechDeadline.stop();
    if (m_recommendationSpeechReply && !m_recommendationSpeechCreating)
        m_recommendationSpeechReply->abort();
    // Leave an in-flight create connected so its returned ID can be canceled.
    m_recommendationSpeechReply.clear();
    m_recommendationSpeechCreating = false;
    cancelRemoteRecommendationSpeech(m_recommendationSpeechRequestId, m_serverUrl, m_token);
    m_recommendationSpeechRequestId.clear();
    m_recommendationSpeechBatchId.clear();
    m_recommendationSpeechLoading = false;
    m_recommendationSpeechErrorMessage.clear();
    delete m_recommendationSpeechFile.data();
    m_recommendationSpeechFile.clear();
    emit recommendationSpeechChanged();
}

void ServerClient::failRecommendationSpeech(const QString &message)
{
    cancelRecommendationSpeech();
    m_recommendationSpeechErrorMessage = message;
    emit recommendationSpeechChanged();
}

void ServerClient::pollRecommendationSpeech()
{
    if (!m_recommendationSpeechLoading || m_recommendationSpeechRequestId.isEmpty())
        return;
    const int generation = m_recommendationSpeechGeneration;
    QNetworkReply *reply = m_network.get(taterJSONRequest(m_serverUrl,
        QStringLiteral("/api/tater/tts/requests/%1").arg(m_recommendationSpeechRequestId),
        m_token));
    m_recommendationSpeechReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation] {
        const QByteArray body = reply->readAll();
        const bool succeeded = taterReplySucceeded(reply);
        reply->deleteLater();
        if (generation != m_recommendationSpeechGeneration)
            return;
        m_recommendationSpeechReply.clear();
        if (!succeeded) {
            failRecommendationSpeech(responseError(
                body, QStringLiteral("Tater's voice could not be loaded. Try again.")));
            return;
        }
        const QJsonObject data = QJsonDocument::fromJson(body).object()
                                     .value(QStringLiteral("data")).toObject();
        const QString status = data.value(QStringLiteral("status")).toString().toLower();
        if (status == QStringLiteral("ready")) {
            downloadRecommendationSpeech(generation);
        } else if (status == QStringLiteral("pending") || status == QStringLiteral("processing")
                   || status == QStringLiteral("claimed")) {
            m_recommendationSpeechPollTimer.start(250);
        } else {
            const QString error = data.value(QStringLiteral("error")).toString().trimmed();
            failRecommendationSpeech(error.isEmpty()
                ? QStringLiteral("Tater's voice is unavailable right now.") : error);
        }
    });
}

void ServerClient::downloadRecommendationSpeech(int generation)
{
    // Derive the audio route from the validated request ID, not an arbitrary response URL.
    QNetworkRequest request = taterJSONRequest(m_serverUrl,
        QStringLiteral("/api/tater/tts/requests/%1/audio").arg(m_recommendationSpeechRequestId),
        m_token);
    request.setRawHeader("Accept", "audio/wav");
    QNetworkReply *reply = m_network.get(request);
    reply->setReadBufferSize(kMaximumRecommendationAudioBytes + 1);
    m_recommendationSpeechReply = reply;
    connect(reply, &QNetworkReply::readyRead, this, [this, reply, generation] {
        if (generation == m_recommendationSpeechGeneration
            && (reply->bytesAvailable() > kMaximumRecommendationAudioBytes
                || reply->header(QNetworkRequest::ContentLengthHeader).toLongLong()
                    > kMaximumRecommendationAudioBytes)) {
            failRecommendationSpeech(QStringLiteral("Tater's voice returned an invalid audio file."));
        }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation] {
        const bool succeeded = taterReplySucceeded(reply);
        const QByteArray audio = reply->readAll();
        reply->deleteLater();
        if (generation != m_recommendationSpeechGeneration)
            return;
        m_recommendationSpeechReply.clear();
        if (!succeeded || audio.size() < 12 || audio.size() > kMaximumRecommendationAudioBytes
            || audio.left(4) != "RIFF" || audio.mid(8, 4) != "WAVE") {
            failRecommendationSpeech(QStringLiteral("Tater's voice could not be played. Try again."));
            return;
        }
        auto *file = new QTemporaryFile(
            QDir::temp().filePath(QStringLiteral("tater-picks-XXXXXX.wav")), this);
        if (!file->open() || file->write(audio) != audio.size() || !file->flush()) {
            delete file;
            failRecommendationSpeech(QStringLiteral("Tater's voice could not be saved for playback."));
            return;
        }
        file->close();
        m_recommendationSpeechFile = file;
        m_recommendationSpeechDeadline.stop();
        m_recommendationSpeechLoading = false;
        emit recommendationSpeechChanged();
        emit recommendationSpeechReady(QUrl::fromLocalFile(file->fileName()));
    });
}

void ServerClient::reportViewingEvent(const QVariantMap &item, const QString &kind,
                                      const QString &state, qint64 positionMs,
                                      qint64 durationMs, const QString &sessionId,
                                      qint64 watchedMs)
{
    if (!paired() || !m_capabilities.value(QStringLiteral("taterLink")).toBool()
        || sessionId.trimmed().isEmpty() || watchedMs <= 0) {
        return;
    }
    const QString normalizedState = state.trimmed().toLower();
    const QStringList validStates{QStringLiteral("started"), QStringLiteral("progress"),
        QStringLiteral("paused"), QStringLiteral("completed"), QStringLiteral("stopped")};
    if (!validStates.contains(normalizedState))
        return;
    const QString normalizedKind = kind.trimmed().toLower();
    const bool live = normalizedKind == QStringLiteral("live")
        || normalizedKind == QStringLiteral("tube_tv")
        || normalizedKind == QStringLiteral("tubetv")
        || normalizedKind == QStringLiteral("channel");
    const QVariantMap media = live ? item.value(QStringLiteral("now")).toMap() : item;
    if (media.isEmpty())
        return;
    QString mediaType = media.value(QStringLiteral("mediaType")).toString().trimmed().toLower();
    const QString programKind = media.value(QStringLiteral("kind")).toString().trimmed().toLower();
    if (mediaType.isEmpty())
        mediaType = programKind;
    const QStringList breaks{QStringLiteral("commercial"), QStringLiteral("commercials"),
        QStringLiteral("ad"), QStringLiteral("bumper"), QStringLiteral("break"),
        QStringLiteral("spot"), QStringLiteral("tater_bumper"),
        QStringLiteral("commercial_break")};
    if (breaks.contains(mediaType) || breaks.contains(programKind)
        || media.value(QStringLiteral("isBreak")).toBool()) {
        return;
    }

    const QString title = media.value(QStringLiteral("title")).toString().trimmed().left(500);
    if (title.isEmpty())
        return;
    const QString path = normalizedPlayStatePath(media.value(QStringLiteral("path")).toString());
    const QString category = normalizedPlayStateCategory(media.value(QStringLiteral("categoryId")).toString());
    QString seriesTitle = media.value(QStringLiteral("seriesTitle"),
        media.value(QStringLiteral("series_title"))).toString().trimmed();
    int season = media.value(QStringLiteral("season"), media.value(QStringLiteral("seasonNumber"))).toInt();
    int episode = media.value(QStringLiteral("episode"), media.value(QStringLiteral("episodeNumber"))).toInt();
    static const QRegularExpression episodePattern(QStringLiteral(R"((?:^|[ ._/-])S(\d{1,3})[ ._-]*E(\d{1,4})(?:$|[ ._/-]))"),
        QRegularExpression::CaseInsensitiveOption);
    QRegularExpressionMatch episodeMatch = episodePattern.match(title);
    if (!episodeMatch.hasMatch())
        episodeMatch = episodePattern.match(path);
    if (episodeMatch.hasMatch()) {
        if (season <= 0) season = episodeMatch.captured(1).toInt();
        if (episode <= 0) episode = episodeMatch.captured(2).toInt();
    }
    const bool isEpisode = mediaType == QStringLiteral("episode")
        || mediaType == QStringLiteral("tv") || mediaType == QStringLiteral("series")
        || mediaType == QStringLiteral("show") || mediaType == QStringLiteral("tvshow")
        || category == QStringLiteral("tv") || episode > 0;
    if (isEpisode) {
        mediaType = QStringLiteral("episode");
        if (seriesTitle.isEmpty() && path.contains('/'))
            seriesTitle = path.section('/', 0, 0);
        if (season <= 0) {
            static const QRegularExpression seasonPattern(QStringLiteral(R"((?:^|/)Season[ ._-]*(\d{1,3})(?:/|$))"),
                QRegularExpression::CaseInsensitiveOption);
            const QRegularExpressionMatch match = seasonPattern.match(path);
            if (match.hasMatch()) season = match.captured(1).toInt();
        }
    } else if (mediaType.isEmpty() || mediaType == QStringLiteral("video")) {
        mediaType = QStringLiteral("movie");
    }
    if (mediaType != QStringLiteral("movie") && mediaType != QStringLiteral("episode"))
        return;

    const QString source = live ? QStringLiteral("tube_tv") : QStringLiteral("local_media");
    QString identity = media.value(QStringLiteral("playStateId")).toString();
    if (!path.isEmpty()) {
        identity = category + QChar('|')
            + QString::number(media.value(QStringLiteral("sourceIndex")).toInt())
            + QChar('|') + path;
    }
    if (identity.isEmpty())
        identity = mediaType + QChar('|') + title + QChar('|') + seriesTitle;
    const QString mediaId = QStringLiteral("local:") + viewingIdentity(identity);
    const QString eventId = QStringLiteral("player:") + viewingIdentity(
        sessionId + QChar('|') + source + QChar('|') + mediaId);
    QJsonObject metadata{
        {QStringLiteral("watched_ms"), static_cast<double>(qMax<qint64>(0, watchedMs))},
        {QStringLiteral("action"), normalizedState},
        {QStringLiteral("year"), media.value(QStringLiteral("date")).toString().left(40)},
        {QStringLiteral("genres"), QJsonArray::fromVariantList(media.value(QStringLiteral("genres")).toList())},
    };
    if (live) {
        metadata.insert(QStringLiteral("channel_number"), item.value(QStringLiteral("number")).toString().left(40));
        metadata.insert(QStringLiteral("channel_name"), item.value(QStringLiteral("title")).toString().left(500));
    }
    const QJsonObject payload{
        {QStringLiteral("event_id"), eventId},
        {QStringLiteral("profile_id"), QStringLiteral("household")},
        {QStringLiteral("source"), source},
        {QStringLiteral("media_id"), mediaId},
        {QStringLiteral("media_type"), mediaType},
        {QStringLiteral("title"), title},
        {QStringLiteral("series_title"), seriesTitle.left(500)},
        {QStringLiteral("season"), qMax(0, season)},
        {QStringLiteral("episode"), qMax(0, episode)},
        {QStringLiteral("position_ms"), static_cast<double>(qMax<qint64>(0, positionMs))},
        {QStringLiteral("duration_ms"), static_cast<double>(qMax<qint64>(0, durationMs))},
        {QStringLiteral("state"), normalizedState},
        {QStringLiteral("occurred_at"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
        {QStringLiteral("metadata"), metadata},
    };
    // Coalesce unsent heartbeats, and serialize updates so a late progress response
    // cannot overwrite this viewing session's final stopped/completed state.
    for (QJsonObject &pending : m_pendingViewingEvents) {
        if (pending.value(QStringLiteral("event_id")).toString() == eventId) {
            pending = payload;
            return;
        }
    }
    if (m_pendingViewingEvents.size() >= 32)
        m_pendingViewingEvents.removeFirst();
    m_pendingViewingEvents.append(payload);
    sendNextViewingEvent();
}

void ServerClient::sendNextViewingEvent()
{
    if (!m_capabilities.value(QStringLiteral("taterLink")).toBool()) {
        m_pendingViewingEvents.clear();
        return;
    }
    if (m_viewingEventReply || m_pendingViewingEvents.isEmpty() || !paired())
        return;
    const int generation = m_viewingEventGeneration;
    const QJsonObject payload = m_pendingViewingEvents.takeFirst();
    QNetworkReply *reply = m_network.post(taterJSONRequest(m_serverUrl,
        QStringLiteral("/api/tater/viewing/events"), m_token),
        QJsonDocument(payload).toJson(QJsonDocument::Compact));
    m_viewingEventReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation] {
        reply->deleteLater();
        if (generation != m_viewingEventGeneration)
            return;
        m_viewingEventReply.clear();
        sendNextViewingEvent();
    });
}

void ServerClient::refreshLiveGuide()
{
    if (!paired() || m_liveGuideLoading)
        return;

    m_liveGuideLoading = true;
    m_liveGuideErrorMessage.clear();
    emit liveGuideChanged();
    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/tater/tv/lineup"))};
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply] { handleLiveGuideReply(reply); });
}

void ServerClient::forgetServer()
{
    cancelRecommendationSpeech();
    ++m_viewingEventGeneration;
    m_pendingViewingEvents.clear();
    if (m_viewingEventReply) {
        m_viewingEventReply->abort();
        m_viewingEventReply.clear();
    }
    m_serverUrl.clear();
    m_token.clear();
    m_serverName.clear();
    m_serverVersion.clear();
    m_playerName.clear();
    m_online = false;
    m_errorMessage.clear();
    resetHome();
    m_libraryItems.clear();
    m_libraryRows.clear();
    m_libraryTitle.clear();
    m_libraryErrorMessage.clear();
    m_libraryHistory.clear();
    m_libraryCache.clear();
    ++m_libraryGeneration;
    ++m_libraryRowsGeneration;
    m_libraryRowsPending = 0;
    m_libraryRowsStoredAtMs = 0;
    m_librariesLoading = false;
    resetDiscover();
    m_discoverCache.clear();
    resetRecommendations();
    m_liveGuideChannels.clear();
    m_liveGuideErrorMessage.clear();
    m_liveGuideLoading = false;
    m_liveGuideReady = false;
    QSettings settings;
    settings.remove("connection");
    clearContentCache();
    emit connectionChanged();
    emit errorMessageChanged();
    emit homeChanged();
    emit libraryChanged();
    emit discoverChanged();
    emit recommendationsChanged();
    emit liveGuideChanged();
}

void ServerClient::savePlaybackProgress(const QVariantMap &item, qint64 positionMs,
                                        qint64 durationMs, bool completed)
{
    if (!paired())
        return;

    const QString path = item.value(QStringLiteral("path")).toString().trimmed();
    const QString categoryId = item.value(QStringLiteral("categoryId")).toString().trimmed();
    const QString playStateId = item.value(QStringLiteral("playStateId")).toString().trimmed();
    const QString nzbUrl = item.value(QStringLiteral("nzbUrl")).toString().trimmed();
    const bool discoverItem = !playStateId.isEmpty() && !nzbUrl.isEmpty();
    if (!discoverItem && (path.isEmpty() || categoryId.isEmpty()))
        return;

    m_pendingPlaybackItem = item;
    m_pendingPlaybackPositionMs = qMax<qint64>(0, positionMs);
    m_pendingPlaybackDurationMs = qMax<qint64>(0, durationMs);
    m_pendingPlaybackCompleted = completed;
    m_pendingPlaybackStoredAtMs = QDateTime::currentMSecsSinceEpoch();
    applyLocalPlaybackProgress(item, positionMs, durationMs, completed, true);

    QJsonObject payload{
        {QStringLiteral("id"), playStateId},
        {QStringLiteral("seriesId"), item.value(QStringLiteral("seriesStateId")).toString()},
        {QStringLiteral("title"), item.value(QStringLiteral("title")).toString()},
        {QStringLiteral("mediaType"), item.value(QStringLiteral("mediaType")).toString()},
        {QStringLiteral("category"), item.value(QStringLiteral("category")).toString()},
        {QStringLiteral("categoryId"), categoryId},
        {QStringLiteral("sourceIndex"), item.value(QStringLiteral("sourceIndex")).toInt()},
        {QStringLiteral("path"), path},
        {QStringLiteral("nzbUrl"), nzbUrl},
        {QStringLiteral("discoverStreamIndex"),
         item.value(QStringLiteral("discoverStreamIndex")).toInt()},
        {QStringLiteral("discoverSourceTitle"),
         item.value(QStringLiteral("discoverSourceTitle")).toString()},
        {QStringLiteral("poster"), item.value(QStringLiteral("poster")).toString()},
        {QStringLiteral("backdrop"), item.value(QStringLiteral("backdrop")).toString()},
        {QStringLiteral("description"), item.value(QStringLiteral("description")).toString()},
        {QStringLiteral("date"), item.value(QStringLiteral("date")).toString()},
        {QStringLiteral("positionMs"), static_cast<double>(qMax<qint64>(0, positionMs))},
        {QStringLiteral("durationMs"), static_cast<double>(qMax<qint64>(0, durationMs))},
        {QStringLiteral("completed"), completed},
    };

    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/tater/playstate"))};
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = m_network.post(
        request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}

void ServerClient::applyLocalPlaybackProgress(const QVariantMap &item,
                                              qint64 positionMs,
                                              qint64 durationMs,
                                              bool completed,
                                              bool persistAndNotify)
{
    bool homeDataChanged = false;
    bool libraryDataChanged = false;
    bool discoverDataChanged = false;
    bool recommendationsDataChanged = false;
    bool cachedDataChanged = false;

    if (completed) {
        homeDataChanged = scrubPlaybackProgress(m_continueWatching, item, true);
    } else if (positionMs > 0) {
        const bool foundInContinue = updatePlaybackProgress(
            m_continueWatching, item, positionMs, durationMs);
        homeDataChanged = foundInContinue;
        if (!foundInContinue) {
            QVariantMap resumeItem = item;
            setPlaybackProgressFields(resumeItem, positionMs, durationMs);
            m_continueWatching.prepend(resumeItem);
            homeDataChanged = true;
        }
    }

    if (completed) {
        homeDataChanged = scrubPlaybackProgress(m_recentlyAdded, item, false)
            || homeDataChanged;
        const bool browsingContinue = !m_libraryHistory.isEmpty()
            && m_libraryHistory.constLast().continueWatching;
        libraryDataChanged = scrubPlaybackProgress(
            m_libraryItems, item, browsingContinue);
        recommendationsDataChanged = scrubPlaybackProgress(
            m_recommendations, item, false);
        discoverDataChanged = scrubPlaybackProgress(m_discoverItems, item, false);
    } else {
        homeDataChanged = updatePlaybackProgress(
            m_recentlyAdded, item, positionMs, durationMs) || homeDataChanged;
        libraryDataChanged = updatePlaybackProgress(
            m_libraryItems, item, positionMs, durationMs);
        recommendationsDataChanged = updatePlaybackProgress(
            m_recommendations, item, positionMs, durationMs);
        discoverDataChanged = updatePlaybackProgress(
            m_discoverItems, item, positionMs, durationMs);
    }

    for (qsizetype rowIndex = m_libraryRows.size(); rowIndex-- > 0;) {
        QVariantMap row = m_libraryRows.at(rowIndex).toMap();
        QVariantList items = row.value(QStringLiteral("items")).toList();
        const bool continueRow = row.value(QStringLiteral("entry")).toMap()
                                     .value(QStringLiteral("type")).toString()
                                     .compare(QStringLiteral("continue"),
                                              Qt::CaseInsensitive) == 0;
        bool changed = completed
            ? scrubPlaybackProgress(items, item, continueRow)
            : updatePlaybackProgress(items, item, positionMs, durationMs);
        if (!completed && continueRow && !changed && positionMs > 0) {
            QVariantMap resumeItem = item;
            setPlaybackProgressFields(resumeItem, positionMs, durationMs);
            items.prepend(resumeItem);
            changed = true;
        }
        if (!changed)
            continue;
        libraryDataChanged = true;
        if (continueRow && items.isEmpty()) {
            m_libraryRows.removeAt(rowIndex);
            continue;
        }
        row.insert(QStringLiteral("items"), items);
        m_libraryRows[rowIndex] = row;
    }

    for (auto it = m_libraryCache.begin(); it != m_libraryCache.end(); ++it) {
        const bool continuePage = it.key().endsWith(QStringLiteral("\n1"));
        if (completed) {
            cachedDataChanged = scrubPlaybackProgress(
                it->items, item, continuePage) || cachedDataChanged;
        } else {
            const bool changed = updatePlaybackProgress(
                it->items, item, positionMs, durationMs);
            cachedDataChanged = changed || cachedDataChanged;
            if (continuePage && !changed && positionMs > 0) {
                QVariantMap resumeItem = item;
                setPlaybackProgressFields(resumeItem, positionMs, durationMs);
                it->items.prepend(resumeItem);
                cachedDataChanged = true;
            }
        }
    }
    for (auto it = m_discoverCache.begin(); it != m_discoverCache.end(); ++it) {
        if (completed)
            cachedDataChanged = scrubPlaybackProgress(
                it->items, item, false) || cachedDataChanged;
        else
            cachedDataChanged = updatePlaybackProgress(
                it->items, item, positionMs, durationMs) || cachedDataChanged;
    }

    if (!persistAndNotify)
        return;
    if (homeDataChanged || libraryDataChanged || discoverDataChanged
        || recommendationsDataChanged || cachedDataChanged) {
        saveContentCache();
    }
    if (homeDataChanged)
        emit homeChanged();
    if (libraryDataChanged)
        emit libraryChanged();
    if (discoverDataChanged)
        emit discoverChanged();
    if (recommendationsDataChanged)
        emit recommendationsChanged();
}

void ServerClient::applyPendingPlaybackProgress()
{
    constexpr qint64 kPendingProgressLifetimeMs = 30000;
    if (m_pendingPlaybackItem.isEmpty()
        || QDateTime::currentMSecsSinceEpoch() - m_pendingPlaybackStoredAtMs
            > kPendingProgressLifetimeMs) {
        return;
    }
    applyLocalPlaybackProgress(m_pendingPlaybackItem,
                               m_pendingPlaybackPositionMs,
                               m_pendingPlaybackDurationMs,
                               m_pendingPlaybackCompleted, false);
}

void ServerClient::clearPlaybackProgress(const QVariantMap &item)
{
    if (!paired()) {
        emit playbackProgressClearFailed(
            QStringLiteral("Pair this player before clearing watch progress."));
        return;
    }

    const QString path = item.value(QStringLiteral("path")).toString().trimmed();
    const QString categoryId = item.value(QStringLiteral("categoryId")).toString().trimmed();
    const QString playStateId = item.value(QStringLiteral("playStateId")).toString().trimmed();
    const QString seriesStateId = item.value(QStringLiteral("seriesStateId")).toString().trimmed();
    if ((playStateId.isEmpty() && seriesStateId.isEmpty())
        && (path.isEmpty() || categoryId.isEmpty())) {
        emit playbackProgressClearFailed(
            QStringLiteral("This item does not have saved watch progress."));
        return;
    }

    const QJsonObject payload{
        {QStringLiteral("id"), playStateId},
        {QStringLiteral("seriesId"), seriesStateId},
        {QStringLiteral("mediaType"), item.value(QStringLiteral("mediaType")).toString()},
        {QStringLiteral("categoryId"), categoryId},
        {QStringLiteral("sourceIndex"), item.value(QStringLiteral("sourceIndex")).toInt()},
        {QStringLiteral("path"), path},
    };

    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/tater/playstate"))};
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(15000);
    QNetworkReply *reply = m_network.sendCustomRequest(
        request, QByteArrayLiteral("DELETE"),
        QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, item] {
        const QByteArray body = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const bool succeeded = reply->error() == QNetworkReply::NoError
            && status >= 200 && status < 300;
        reply->deleteLater();
        if (!succeeded) {
            emit playbackProgressClearFailed(responseError(
                body, QStringLiteral("Watch progress could not be cleared.")));
            return;
        }

        m_pendingPlaybackItem = item;
        m_pendingPlaybackPositionMs = 0;
        m_pendingPlaybackDurationMs = 0;
        m_pendingPlaybackCompleted = true;
        m_pendingPlaybackStoredAtMs = QDateTime::currentMSecsSinceEpoch();
        clearLocalPlaybackProgress(item);
        emit playbackProgressCleared();
        refreshHome();
        refreshLibraryRows();
        refreshLibrary();
    });
}

void ServerClient::clearLocalPlaybackProgress(const QVariantMap &item)
{
    scrubPlaybackProgress(m_continueWatching, item, true);
    scrubPlaybackProgress(m_recentlyAdded, item, false);
    const bool browsingContinue = !m_libraryHistory.isEmpty()
        && m_libraryHistory.constLast().continueWatching;
    scrubPlaybackProgress(m_libraryItems, item, browsingContinue);
    scrubPlaybackProgress(m_recommendations, item, false);
    scrubPlaybackProgress(m_discoverItems, item, false);

    for (qsizetype rowIndex = m_libraryRows.size(); rowIndex-- > 0;) {
        QVariantMap row = m_libraryRows.at(rowIndex).toMap();
        QVariantList items = row.value(QStringLiteral("items")).toList();
        const bool continueRow = row.value(QStringLiteral("entry")).toMap()
                                     .value(QStringLiteral("type")).toString()
                                     .compare(QStringLiteral("continue"),
                                              Qt::CaseInsensitive) == 0;
        if (scrubPlaybackProgress(items, item, continueRow)) {
            if (continueRow && items.isEmpty()) {
                m_libraryRows.removeAt(rowIndex);
                continue;
            }
            row.insert(QStringLiteral("items"), items);
            m_libraryRows[rowIndex] = row;
        }
    }
    for (auto it = m_libraryCache.begin(); it != m_libraryCache.end(); ++it)
        scrubPlaybackProgress(it->items, item, it.key().endsWith(QStringLiteral("\n1")));
    for (auto it = m_discoverCache.begin(); it != m_discoverCache.end(); ++it)
        scrubPlaybackProgress(it->items, item, false);

    saveContentCache();
    emit homeChanged();
    emit libraryChanged();
    emit discoverChanged();
    emit recommendationsChanged();
}

QString ServerClient::playbackProfile(const QVariantMap &capabilities) const
{
    const int width = capabilities.value(QStringLiteral("max_width")).toInt();
    const int height = capabilities.value(QStringLiteral("max_height")).toInt();
    const int longEdge = std::max(width, height);
    const int shortEdge = std::min(width, height);
    if (longEdge >= 3840 && shortEdge >= 2160)
        return QStringLiteral("hdmi_4k");
    if (longEdge >= 1920 && shortEdge >= 1080)
        return QStringLiteral("hdmi_1080p");
    return QStringLiteral("hdmi_720p");
}

void ServerClient::preparePlayback(const QVariantMap &item, const QString &kind,
                                   const QVariantMap &capabilities)
{
    preparePlaybackWithAudioTrack(item, kind, capabilities, -1);
}

void ServerClient::preparePlaybackWithAudioTrack(const QVariantMap &item,
                                                 const QString &kind,
                                                 const QVariantMap &capabilities,
                                                 int audioTrack)
{
    const QString streamUrl = item.value(QStringLiteral("streamUrl")).toString().trimmed();
    if (!paired() || streamUrl.isEmpty()) {
        emit playbackPlanFailed(QStringLiteral("Playback details are unavailable."));
        return;
    }

    const int generation = ++m_playbackGeneration;
    QJsonObject payload{
        {QStringLiteral("stream_url"), streamUrl},
        {QStringLiteral("media_type"), kind.trimmed().toLower()},
        {QStringLiteral("profile"), playbackProfile(capabilities)},
        {QStringLiteral("capabilities"), QJsonObject::fromVariantMap(capabilities)},
    };
    if (audioTrack >= 0)
        payload.insert(QStringLiteral("audio_track"), audioTrack);
    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/v1/player/playback/sessions"))};
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(20000);
    QNetworkReply *reply = m_network.post(
        request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, generation] { handlePlaybackPlanReply(reply, generation); });
}

QString ServerClient::playbackTranscodeUrl(const QString &streamUrl,
                                           const QString &profile,
                                           qint64 startMs) const
{
    QUrl url(streamUrl);
    if (!url.isValid() || url.scheme().isEmpty())
        return {};

    QUrlQuery query(url);
    query.removeAllQueryItems(QStringLiteral("direct"));
    query.removeAllQueryItems(QStringLiteral("transcode"));
    query.removeAllQueryItems(QStringLiteral("profile"));
    query.removeAllQueryItems(QStringLiteral("codec"));
    query.removeAllQueryItems(QStringLiteral("audio_codec"));
    query.removeAllQueryItems(QStringLiteral("start"));
    query.removeAllQueryItems(QStringLiteral("tater_video_mode"));
    query.removeAllQueryItems(QStringLiteral("tater_audio_mode"));
    query.removeAllQueryItems(QStringLiteral("tater_audio_codec"));
    query.addQueryItem(QStringLiteral("transcode"), QStringLiteral("1"));
    query.addQueryItem(QStringLiteral("profile"), profile.trimmed().isEmpty()
                           ? QStringLiteral("hdmi_1080p") : profile.trimmed());
    query.addQueryItem(QStringLiteral("codec"), QStringLiteral("h264"));
    query.addQueryItem(QStringLiteral("tater_video_mode"), QStringLiteral("transcode"));
    query.addQueryItem(QStringLiteral("tater_audio_mode"), QStringLiteral("transcode"));
    query.addQueryItem(QStringLiteral("tater_audio_codec"), QStringLiteral("aac"));
    if (startMs > 0) {
        query.addQueryItem(QStringLiteral("start"),
                           QString::number(static_cast<double>(startMs) / 1000.0, 'f', 3));
    }
    url.setQuery(query);
    return url.toString(QUrl::FullyEncoded);
}

QString ServerClient::playbackUrlAtPosition(const QString &streamUrl, qint64 startMs) const
{
    QUrl url(streamUrl);
    if (!url.isValid() || url.scheme().isEmpty())
        return {};

    QUrlQuery query(url);
    query.removeAllQueryItems(QStringLiteral("start"));
    if (startMs > 0) {
        query.addQueryItem(QStringLiteral("start"),
                           QString::number(static_cast<double>(startMs) / 1000.0, 'f', 3));
    }
    url.setQuery(query);
    return url.toString(QUrl::FullyEncoded);
}

QString ServerClient::playbackToneMappedTranscodeUrl(const QString &streamUrl,
                                                      const QString &profile,
                                                      const QString &sourceVideoRange,
                                                      qint64 startMs) const
{
    QUrl url(playbackTranscodeUrl(streamUrl, profile, startMs));
    if (!url.isValid() || url.scheme().isEmpty())
        return {};

    QUrlQuery query(url);
    QString sourceRange = sourceVideoRange.trimmed().toLower();
    if (sourceRange.isEmpty())
        sourceRange = query.queryItemValue(QStringLiteral("tater_source_video_range")).trimmed().toLower();
    if (!sourceRange.isEmpty() && sourceRange != QStringLiteral("sdr")) {
        query.removeAllQueryItems(QStringLiteral("tater_source_video_range"));
        query.removeAllQueryItems(QStringLiteral("tater_output_video_range"));
        query.removeAllQueryItems(QStringLiteral("tater_tone_map"));
        query.addQueryItem(QStringLiteral("tater_source_video_range"), sourceRange);
        query.addQueryItem(QStringLiteral("tater_output_video_range"), QStringLiteral("sdr"));
        query.addQueryItem(QStringLiteral("tater_tone_map"), QStringLiteral("1"));
    }
    url.setQuery(query);
    return url.toString(QUrl::FullyEncoded);
}

QString ServerClient::playbackAudioTranscodeUrl(const QString &streamUrl,
                                                const QString &profile,
                                                qint64 startMs) const
{
    QUrl url(streamUrl);
    if (!url.isValid() || url.scheme().isEmpty())
        return {};

    QUrlQuery query(url);
    query.removeAllQueryItems(QStringLiteral("direct"));
    query.removeAllQueryItems(QStringLiteral("transcode"));
    query.removeAllQueryItems(QStringLiteral("profile"));
    query.removeAllQueryItems(QStringLiteral("codec"));
    query.removeAllQueryItems(QStringLiteral("audio_codec"));
    query.removeAllQueryItems(QStringLiteral("start"));
    query.removeAllQueryItems(QStringLiteral("tater_video_mode"));
    query.removeAllQueryItems(QStringLiteral("tater_audio_mode"));
    query.removeAllQueryItems(QStringLiteral("tater_audio_codec"));
    query.addQueryItem(QStringLiteral("transcode"), QStringLiteral("audio"));
    query.addQueryItem(QStringLiteral("profile"), profile.trimmed().isEmpty()
                           ? QStringLiteral("hdmi_1080p") : profile.trimmed());
    query.addQueryItem(QStringLiteral("tater_video_mode"), QStringLiteral("direct"));
    query.addQueryItem(QStringLiteral("tater_audio_mode"), QStringLiteral("transcode"));
    query.addQueryItem(QStringLiteral("tater_audio_codec"), QStringLiteral("aac"));
    if (startMs > 0) {
        query.addQueryItem(QStringLiteral("start"),
                           QString::number(static_cast<double>(startMs) / 1000.0, 'f', 3));
    }
    url.setQuery(query);
    return url.toString(QUrl::FullyEncoded);
}

QString ServerClient::playbackVideoTranscodeUrl(const QString &streamUrl,
                                                const QString &profile,
                                                const QString &audioCodec,
                                                const QString &audioMode,
                                                qint64 startMs) const
{
    QUrl url(streamUrl);
    if (!url.isValid() || url.scheme().isEmpty())
        return {};

    QUrlQuery query(url);
    query.removeAllQueryItems(QStringLiteral("direct"));
    query.removeAllQueryItems(QStringLiteral("transcode"));
    query.removeAllQueryItems(QStringLiteral("profile"));
    query.removeAllQueryItems(QStringLiteral("codec"));
    query.removeAllQueryItems(QStringLiteral("audio_codec"));
    query.removeAllQueryItems(QStringLiteral("start"));
    query.removeAllQueryItems(QStringLiteral("tater_video_mode"));
    query.removeAllQueryItems(QStringLiteral("tater_audio_mode"));
    query.removeAllQueryItems(QStringLiteral("tater_audio_codec"));
    query.addQueryItem(QStringLiteral("transcode"), QStringLiteral("video"));
    query.addQueryItem(QStringLiteral("profile"), profile.trimmed().isEmpty()
                           ? QStringLiteral("hdmi_1080p") : profile.trimmed());
    query.addQueryItem(QStringLiteral("codec"), QStringLiteral("h264"));
    query.addQueryItem(QStringLiteral("tater_video_mode"), QStringLiteral("transcode"));
    query.addQueryItem(QStringLiteral("tater_audio_mode"),
                       audioMode.trimmed().compare(QStringLiteral("bitstream"),
                                                   Qt::CaseInsensitive) == 0
                           ? QStringLiteral("bitstream") : QStringLiteral("direct"));
    if (!audioCodec.trimmed().isEmpty())
        query.addQueryItem(QStringLiteral("audio_codec"), audioCodec.trimmed().toLower());
    if (!audioCodec.trimmed().isEmpty())
        query.addQueryItem(QStringLiteral("tater_audio_codec"), audioCodec.trimmed().toLower());
    if (startMs > 0) {
        query.addQueryItem(QStringLiteral("start"),
                           QString::number(static_cast<double>(startMs) / 1000.0, 'f', 3));
    }
    url.setQuery(query);
    return url.toString(QUrl::FullyEncoded);
}

void ServerClient::loadSettings()
{
    QSettings settings;
    m_serverUrl = normalizedServerUrl(settings.value(kSettingsServerUrl).toString());
    m_token = settings.value(kSettingsToken).toString().trimmed();
    m_playerName = settings.value(kSettingsPlayerName).toString().trimmed();
    restrictSettingsToCurrentUser(settings);
}

void ServerClient::saveSettings() const
{
    QSettings settings;
    settings.setValue(kSettingsServerUrl, m_serverUrl);
    settings.setValue(kSettingsToken, m_token);
    settings.setValue(kSettingsPlayerName, m_playerName);
    restrictSettingsToCurrentUser(settings);
}

QString ServerClient::contentCachePath()
{
    const QString directory = QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation);
    return directory.isEmpty()
        ? QString{}
        : QDir(directory).filePath(QStringLiteral("content-cache-v1.json"));
}

void ServerClient::loadContentCache()
{
    if (!paired())
        return;

    QFile file(contentCachePath());
    if (!file.open(QIODevice::ReadOnly))
        return;

    QJsonParseError parseError;
    const QJsonObject cache = QJsonDocument::fromJson(file.readAll(), &parseError).object();
    if (parseError.error != QJsonParseError::NoError
        || cache.value(QStringLiteral("version")).toInt() != kContentCacheVersion
        || normalizedServerUrl(cache.value(QStringLiteral("serverUrl")).toString())
            != m_serverUrl) {
        return;
    }

    const qint64 savedAtMs = cache.value(QStringLiteral("savedAtMs")).toVariant().toLongLong();
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (savedAtMs <= 0 || now - savedAtMs > kContentCacheMaxAgeMs)
        return;

    const QJsonObject home = cache.value(QStringLiteral("home")).toObject();
    m_continueWatching = home.value(QStringLiteral("continueWatching")).toArray().toVariantList();
    m_recentlyAdded = home.value(QStringLiteral("recentlyAdded")).toArray().toVariantList();
    m_liveChannels = home.value(QStringLiteral("liveChannels")).toArray().toVariantList();
    m_libraries = home.value(QStringLiteral("libraries")).toArray().toVariantList();
    m_capabilities = home.value(QStringLiteral("capabilities")).toObject().toVariantMap();
    m_homeHero = home.value(QStringLiteral("hero")).toObject().toVariantMap();
    for (const QJsonValue &warning : home.value(QStringLiteral("warnings")).toArray()) {
        const QString message = warning.toString().trimmed();
        if (!message.isEmpty())
            m_homeWarnings.append(message);
    }
    m_homeReady = home.value(QStringLiteral("ready")).toBool()
        || !m_continueWatching.isEmpty() || !m_recentlyAdded.isEmpty()
        || !m_liveChannels.isEmpty() || !m_libraries.isEmpty();

    const QJsonObject library = cache.value(QStringLiteral("library")).toObject();
    m_libraryRows = library.value(QStringLiteral("rows")).toArray().toVariantList();
    m_libraryRowsStoredAtMs = library.value(QStringLiteral("rowsStoredAtMs"))
                                  .toVariant().toLongLong();
    for (const QJsonValue &value : library.value(QStringLiteral("pages")).toArray()) {
        const QJsonObject page = value.toObject();
        const QString key = page.value(QStringLiteral("key")).toString();
        if (key.isEmpty())
            continue;
        m_libraryCache.insert(key, LibraryCacheEntry{
            page.value(QStringLiteral("items")).toArray().toVariantList(),
            page.value(QStringLiteral("title")).toString(),
            page.value(QStringLiteral("storedAtMs")).toVariant().toLongLong(),
        });
    }

    const QJsonObject discover = cache.value(QStringLiteral("discover")).toObject();
    m_discoverCategories = discover.value(QStringLiteral("categories"))
                               .toArray().toVariantList();
    for (const QJsonValue &value : discover.value(QStringLiteral("pages")).toArray()) {
        const QJsonObject page = value.toObject();
        const QString key = page.value(QStringLiteral("key")).toString();
        if (key.isEmpty())
            continue;
        m_discoverCache.insert(key, DiscoverCacheEntry{
            page.value(QStringLiteral("items")).toArray().toVariantList(),
            page.value(QStringLiteral("title")).toString(),
            page.value(QStringLiteral("mediaType")).toString(),
            page.value(QStringLiteral("storedAtMs")).toVariant().toLongLong(),
        });
    }

    const QJsonObject recommendations = cache.value(QStringLiteral("recommendations")).toObject();
    m_recommendations = recommendations.value(QStringLiteral("items")).toArray().toVariantList();
    m_recommendationBatch = recommendations.value(QStringLiteral("batch"))
                                .toObject().toVariantMap();

    const QJsonObject guide = cache.value(QStringLiteral("guide")).toObject();
    m_liveGuideChannels = guide.value(QStringLiteral("channels")).toArray().toVariantList();
    m_liveGuideReady = guide.value(QStringLiteral("ready")).toBool()
        || !m_liveGuideChannels.isEmpty();
}

void ServerClient::saveContentCache() const
{
    if (!paired())
        return;

    const QString path = contentCachePath();
    if (path.isEmpty())
        return;
    if (!QDir().mkpath(QFileInfo(path).absolutePath()))
        return;

    QJsonObject home{
        {QStringLiteral("ready"), m_homeReady},
        {QStringLiteral("continueWatching"), QJsonArray::fromVariantList(m_continueWatching)},
        {QStringLiteral("recentlyAdded"), QJsonArray::fromVariantList(m_recentlyAdded)},
        {QStringLiteral("liveChannels"), QJsonArray::fromVariantList(m_liveChannels)},
        {QStringLiteral("libraries"), QJsonArray::fromVariantList(m_libraries)},
        {QStringLiteral("capabilities"), QJsonObject::fromVariantMap(m_capabilities)},
        {QStringLiteral("hero"), QJsonObject::fromVariantMap(m_homeHero)},
        {QStringLiteral("warnings"), QJsonArray::fromStringList(m_homeWarnings)},
    };

    QVector<QString> libraryKeys;
    libraryKeys.reserve(m_libraryCache.size());
    for (auto it = m_libraryCache.cbegin(); it != m_libraryCache.cend(); ++it)
        libraryKeys.append(it.key());
    std::sort(libraryKeys.begin(), libraryKeys.end(), [this](const QString &left,
                                                             const QString &right) {
        return m_libraryCache.value(left).storedAtMs
            > m_libraryCache.value(right).storedAtMs;
    });
    QJsonArray libraryPages;
    for (int index = 0;
         index < libraryKeys.size() && index < kMaximumCachedLibraryPages; ++index) {
        const QString &key = libraryKeys.at(index);
        const LibraryCacheEntry page = m_libraryCache.value(key);
        libraryPages.append(QJsonObject{
            {QStringLiteral("key"), key},
            {QStringLiteral("items"), QJsonArray::fromVariantList(page.items)},
            {QStringLiteral("title"), page.title},
            {QStringLiteral("storedAtMs"), page.storedAtMs},
        });
    }

    QVector<QString> discoverKeys;
    discoverKeys.reserve(m_discoverCache.size());
    for (auto it = m_discoverCache.cbegin(); it != m_discoverCache.cend(); ++it)
        discoverKeys.append(it.key());
    std::sort(discoverKeys.begin(), discoverKeys.end(), [this](const QString &left,
                                                               const QString &right) {
        return m_discoverCache.value(left).storedAtMs
            > m_discoverCache.value(right).storedAtMs;
    });
    QJsonArray discoverPages;
    for (int index = 0;
         index < discoverKeys.size() && index < kMaximumCachedDiscoverPages; ++index) {
        const QString &key = discoverKeys.at(index);
        const DiscoverCacheEntry page = m_discoverCache.value(key);
        discoverPages.append(QJsonObject{
            {QStringLiteral("key"), key},
            {QStringLiteral("items"), QJsonArray::fromVariantList(page.items)},
            {QStringLiteral("title"), page.title},
            {QStringLiteral("mediaType"), page.mediaType},
            {QStringLiteral("storedAtMs"), page.storedAtMs},
        });
    }

    const QJsonObject cache{
        {QStringLiteral("version"), kContentCacheVersion},
        {QStringLiteral("serverUrl"), m_serverUrl},
        {QStringLiteral("savedAtMs"), QDateTime::currentMSecsSinceEpoch()},
        {QStringLiteral("home"), home},
        {QStringLiteral("library"), QJsonObject{
            {QStringLiteral("rows"), QJsonArray::fromVariantList(m_libraryRows)},
            {QStringLiteral("rowsStoredAtMs"), m_libraryRowsStoredAtMs},
            {QStringLiteral("pages"), libraryPages},
        }},
        {QStringLiteral("discover"), QJsonObject{
            {QStringLiteral("categories"), QJsonArray::fromVariantList(m_discoverCategories)},
            {QStringLiteral("pages"), discoverPages},
        }},
        {QStringLiteral("recommendations"), QJsonObject{
            {QStringLiteral("batch"), QJsonObject::fromVariantMap(m_recommendationBatch)},
            {QStringLiteral("items"), QJsonArray::fromVariantList(m_recommendations)},
        }},
        {QStringLiteral("guide"), QJsonObject{
            {QStringLiteral("ready"), m_liveGuideReady},
            {QStringLiteral("channels"), QJsonArray::fromVariantList(m_liveGuideChannels)},
        }},
    };

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(cache).toJson(QJsonDocument::Compact));
    file.commit();
}

void ServerClient::clearContentCache() const
{
    const QString path = contentCachePath();
    if (!path.isEmpty())
        QFile::remove(path);
}

void ServerClient::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void ServerClient::setErrorMessage(const QString &message)
{
    if (m_errorMessage == message)
        return;
    m_errorMessage = message;
    emit errorMessageChanged();
}

void ServerClient::setOnline(bool online)
{
    if (m_online == online)
        return;
    m_online = online;
    emit connectionChanged();
}

void ServerClient::setHomeLoading(bool loading)
{
    if (m_homeLoading == loading)
        return;
    m_homeLoading = loading;
    emit homeChanged();
}

void ServerClient::resetHome()
{
    m_homeLoading = false;
    m_homeReady = false;
    m_homeErrorMessage.clear();
    m_continueWatching.clear();
    m_recentlyAdded.clear();
    m_liveChannels.clear();
    m_libraries.clear();
    m_capabilities.clear();
    m_homeHero.clear();
    m_homeWarnings.clear();
}

void ServerClient::handlePairReply(QNetworkReply *reply, const QString &baseUrl)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    setBusy(false);

    if (!succeeded) {
        setOnline(false);
        setErrorMessage(responseError(body, "Pairing failed. Check the server and code."));
        return;
    }

    const QJsonObject envelope = QJsonDocument::fromJson(body).object();
    const QJsonObject data = envelope.value("data").toObject();
    const QString token = data.value("token").toString().trimmed();
    if (token.isEmpty()) {
        setErrorMessage("The server did not return a player token.");
        return;
    }

    cancelRecommendationSpeech();
    ++m_viewingEventGeneration;
    m_pendingViewingEvents.clear();
    if (m_viewingEventReply) {
        m_viewingEventReply->abort();
        m_viewingEventReply.clear();
    }
    m_serverUrl = baseUrl;
    m_token = token;
    clearContentCache();
    resetHome();
    m_libraryCache.clear();
    m_libraryHistory.clear();
    resetDiscover();
    m_discoverCache.clear();
    resetRecommendations();
    m_liveGuideChannels.clear();
    m_liveGuideReady = false;
    m_playerName = data.value("player_name").toString().trimmed();
    if (m_playerName.isEmpty())
        m_playerName = QStringLiteral("Tater Tube Player");
    saveSettings();
    setOnline(true);
    emit connectionChanged();
    emit pairingCompleted();
    refresh();
}

void ServerClient::handleServerInfoReply(QNetworkReply *reply)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    setBusy(false);

    if (!succeeded) {
        setOnline(false);
        setErrorMessage(responseError(body, "Tater Tube Server is unavailable."));
        return;
    }

    const QJsonObject envelope = QJsonDocument::fromJson(body).object();
    const QJsonObject data = envelope.value("data").toObject();
    m_serverName = data.value("name").toString(QStringLiteral("Tater Tube Server"));
    m_serverVersion = data.value("version").toString();
    setOnline(true);
    emit connectionChanged();
    if (!m_homeLoading && !m_homeReady)
        refreshHome();
}

void ServerClient::handleHomeReply(QNetworkReply *reply)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    setHomeLoading(false);

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        if (!m_homeReady) {
            if (status == 404) {
                m_homeErrorMessage = QStringLiteral(
                    "Update Tater Tube Server to a version with the Player Home API.");
            } else {
                m_homeErrorMessage = responseError(
                    body, "The home screen could not be loaded.");
            }
        }
        emit homeChanged();
        return;
    }

    const QJsonObject envelope = QJsonDocument::fromJson(body).object();
    const QJsonObject data = envelope.value("data").toObject();
    if (data.isEmpty()) {
        if (!m_homeReady)
            m_homeErrorMessage = QStringLiteral("The server returned an empty home response.");
        emit homeChanged();
        return;
    }

    m_continueWatching = data.value("continueWatching").toArray().toVariantList();
    m_recentlyAdded = data.value("recentlyAdded").toArray().toVariantList();
    m_liveChannels = data.value("liveChannels").toArray().toVariantList();
    m_libraries = data.value("libraries").toArray().toVariantList();
    m_capabilities = data.value("capabilities").toObject().toVariantMap();
    m_homeHero = data.value("hero").toObject().toVariantMap();
    applyPendingPlaybackProgress();
    if (m_capabilities.contains(QStringLiteral("newznab"))
        && !m_capabilities.value(QStringLiteral("newznab")).toBool()) {
        resetDiscover();
        m_discoverCache.clear();
        emit discoverChanged();
    }
    const bool taterLinked = m_capabilities.value(QStringLiteral("taterLink")).toBool();
    if (!taterLinked) {
        resetRecommendations();
        emit recommendationsChanged();
    }
    m_homeWarnings.clear();
    for (const QJsonValue &warning : data.value("warnings").toArray()) {
        const QString message = warning.toString().trimmed();
        if (!message.isEmpty())
            m_homeWarnings.append(message);
    }
    const QString homeServerName = data.value("serverName").toString().trimmed();
    const QString homeServerVersion = data.value("serverVersion").toString().trimmed();
    if (!homeServerName.isEmpty())
        m_serverName = homeServerName;
    if (!homeServerVersion.isEmpty())
        m_serverVersion = homeServerVersion;
    m_homeErrorMessage.clear();
    m_homeReady = true;
    setOnline(true);
    saveContentCache();
    emit connectionChanged();
    emit homeChanged();
    loadLibraryRows(false);
    if (m_capabilities.value(QStringLiteral("tubeTV")).toBool()) {
        refreshLiveGuide();
    } else if (!m_liveGuideChannels.isEmpty() || m_liveGuideReady) {
        m_liveGuideChannels.clear();
        m_liveGuideErrorMessage.clear();
        m_liveGuideReady = false;
        emit liveGuideChanged();
    }
    if (taterLinked)
        refreshRecommendations();
}

void ServerClient::handleLibraryReply(QNetworkReply *reply,
                                      const LibraryLocation &location,
                                      bool pushHistory,
                                      int generation)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    if (generation != m_libraryGeneration)
        return;
    const bool wasLoading = m_libraryLoading;
    m_libraryLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        if (m_libraryItems.isEmpty())
            m_libraryErrorMessage = responseError(body, "This library could not be loaded.");
        emit libraryChanged();
        return;
    }

    const QJsonObject data = QJsonDocument::fromJson(body).object().value("data").toObject();
    QVariantList refreshedItems = data.value("items").toArray().toVariantList();
    sortLibrarySeasons(refreshedItems);
    QString refreshedTitle = data.value("title").toString().trimmed();
    if (refreshedTitle.isEmpty())
        refreshedTitle = location.title.isEmpty() ? QStringLiteral("Library") : location.title;

    // A cached page is already on screen while this request refreshes it. Avoid
    // resetting the QML model (and all of its artwork delegates) when the server
    // returned the exact same collection.
    if (!wasLoading && refreshedItems == m_libraryItems
        && refreshedTitle == m_libraryTitle) {
        m_libraryErrorMessage.clear();
        if (pushHistory)
            m_libraryHistory.append(location);
        setOnline(true);
        return;
    }

    m_libraryItems = refreshedItems;
    m_libraryTitle = refreshedTitle;
    m_libraryErrorMessage.clear();
    applyPendingPlaybackProgress();
    m_libraryCache.insert(libraryCacheKey(location), LibraryCacheEntry{
        m_libraryItems, m_libraryTitle, QDateTime::currentMSecsSinceEpoch(),
    });
    if (pushHistory)
        m_libraryHistory.append(location);
    setOnline(true);
    saveContentCache();
    emit libraryChanged();
}

void ServerClient::handleLibrariesReply(QNetworkReply *reply)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    m_librariesLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        if (m_libraries.isEmpty())
            m_libraryErrorMessage = responseError(body, "Your libraries could not be loaded.");
        emit libraryChanged();
        return;
    }

    const QJsonArray categories = QJsonDocument::fromJson(body).object()
                                      .value("data").toObject()
                                      .value("categories").toArray();
    QVariantList localLibraries;
    for (const QJsonValue &value : categories) {
        const QJsonObject category = value.toObject();
        if (category.value("type").toString() == QStringLiteral("localRoot")) {
            localLibraries = category.value("children").toArray().toVariantList();
            break;
        }
    }
    m_libraries = localLibraries;
    m_libraryErrorMessage.clear();
    setOnline(true);
    saveContentCache();
    emit homeChanged();
    emit libraryChanged();
    loadLibraryRows(true);
}

void ServerClient::handleDiscoverCatalogReply(QNetworkReply *reply, int generation)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    if (generation != m_discoverGeneration)
        return;
    m_discoverLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        if (m_discoverStage == QStringLiteral("catalog")
            && m_discoverCategories.isEmpty()) {
            m_discoverErrorMessage = responseError(
                body, QStringLiteral("Discover could not be loaded."));
        }
        emit discoverChanged();
        return;
    }

    const QJsonArray categories = QJsonDocument::fromJson(body).object()
                                      .value(QStringLiteral("data")).toObject()
                                      .value(QStringLiteral("categories")).toArray();
    m_discoverCategories = discoverCategoriesFromCatalog(categories);
    if (m_discoverStage == QStringLiteral("catalog")) {
        if (m_discoverCategories.isEmpty()) {
            m_discoverErrorMessage = QStringLiteral(
                "Discover is available when NZB streaming is enabled and configured.");
        } else {
            m_discoverErrorMessage.clear();
        }
    }
    setOnline(true);
    saveContentCache();
    emit discoverChanged();
}

void ServerClient::handleDiscoverFeedReply(QNetworkReply *reply, int generation,
                                           const QString &fallbackTitle,
                                           const QString &mediaType,
                                           const QString &cacheKey)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    if (generation != m_discoverGeneration)
        return;
    m_discoverLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        if (m_discoverItems.isEmpty()) {
            m_discoverErrorMessage = responseError(
                body, QStringLiteral("This Discover collection could not be loaded."));
        }
        emit discoverChanged();
        return;
    }

    const QJsonObject data = QJsonDocument::fromJson(body).object()
                                 .value(QStringLiteral("data")).toObject();
    m_discoverItems = data.value(QStringLiteral("items")).toArray().toVariantList();
    m_discoverTitle = data.value(QStringLiteral("title")).toString().trimmed();
    if (m_discoverTitle.isEmpty())
        m_discoverTitle = fallbackTitle.isEmpty() ? QStringLiteral("Discover") : fallbackTitle;
    m_discoverMediaType = mediaType;
    m_discoverErrorMessage.clear();
    applyPendingPlaybackProgress();
    m_discoverCache.insert(cacheKey, DiscoverCacheEntry{
        m_discoverItems, m_discoverTitle, m_discoverMediaType,
        QDateTime::currentMSecsSinceEpoch(),
    });
    setOnline(true);
    saveContentCache();
    emit discoverChanged();
}

void ServerClient::handleDiscoverSearchReply(QNetworkReply *reply, int generation,
                                             const QString &mediaType,
                                             const QString &fallbackTitle,
                                             const QString &cacheKey)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    if (generation != m_discoverGeneration)
        return;
    m_discoverLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        if (m_discoverItems.isEmpty()) {
            m_discoverErrorMessage = responseError(
                body, QStringLiteral("No NZB results could be loaded for this title."));
        }
        emit discoverChanged();
        return;
    }

    const QJsonObject data = QJsonDocument::fromJson(body).object()
                                 .value(QStringLiteral("data")).toObject();
    QVariantList items = data.value(QStringLiteral("items")).toArray().toVariantList();
    for (QVariant &value : items) {
        QVariantMap item = value.toMap();
        const QString itemMediaType = item.value(QStringLiteral("mediaType"))
                                          .toString().trimmed().toLower();
        if (itemMediaType.isEmpty() || itemMediaType == QStringLiteral("nzb"))
            item.insert(QStringLiteral("mediaType"), mediaType);
        const QString discoverTitle = m_discoverPendingItem.value(
            QStringLiteral("title")).toString().trimmed();
        if (!discoverTitle.isEmpty())
            item.insert(QStringLiteral("discoverTitle"), discoverTitle);
        for (const QString &key : {QStringLiteral("poster"), QStringLiteral("backdrop"),
                                   QStringLiteral("description"), QStringLiteral("date")}) {
            if (item.value(key).toString().trimmed().isEmpty()
                && !m_discoverPendingItem.value(key).toString().trimmed().isEmpty()) {
                item.insert(key, m_discoverPendingItem.value(key));
            }
        }
        value = item;
    }
    m_discoverItems = items;
    m_discoverTitle = data.value(QStringLiteral("title")).toString().trimmed();
    if (m_discoverTitle.isEmpty())
        m_discoverTitle = fallbackTitle;
    m_discoverMediaType = mediaType;
    m_discoverErrorMessage.clear();
    applyPendingPlaybackProgress();
    m_discoverCache.insert(cacheKey, DiscoverCacheEntry{
        m_discoverItems, m_discoverTitle, m_discoverMediaType,
        QDateTime::currentMSecsSinceEpoch(),
    });
    setOnline(true);
    saveContentCache();
    emit discoverChanged();
}

void ServerClient::handleDiscoverPlayReply(QNetworkReply *reply, int generation,
                                           const QVariantMap &sourceItem,
                                           bool updateDiscoverPage)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    if (updateDiscoverPage && generation != m_discoverGeneration)
        return;
    if (updateDiscoverPage)
        m_discoverLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        const QString message = responseError(
            body, status == 408
                ? QStringLiteral("The server is still preparing this stream. Try it again shortly.")
                : QStringLiteral("The NZB stream could not be prepared."));
        if (updateDiscoverPage) {
            m_discoverErrorMessage = message;
            emit discoverChanged();
        } else {
            emit discoverPlaybackFailed(message);
        }
        return;
    }

    QJsonObject response = QJsonDocument::fromJson(body).object();
    if (response.value(QStringLiteral("data")).isObject())
        response = response.value(QStringLiteral("data")).toObject();
    const QString playStateId = response.value(
        QStringLiteral("_tater_play_state_id")).toString().trimmed();
    const QString safeNzbUrl = response.value(
        QStringLiteral("_tater_nzb_url")).toString().trimmed();
    const QVariantList streams = response.value(QStringLiteral("streams"))
                                     .toArray().toVariantList();
    QVariantList playableStreams;
    for (qsizetype streamIndex = 0; streamIndex < streams.size(); ++streamIndex) {
        const QVariant &value = streams.at(streamIndex);
        const QVariantMap stream = value.toMap();
        const QString streamUrl = stream.value(QStringLiteral("streamUrl"),
                                               stream.value(QStringLiteral("url")))
                                      .toString().trimmed();
        if (streamUrl.isEmpty())
            continue;
        QVariantMap playable = sourceItem;
        for (auto it = stream.cbegin(); it != stream.cend(); ++it)
            playable.insert(it.key(), it.value());
        playable.insert(QStringLiteral("streamUrl"), streamUrl);
        playable.insert(QStringLiteral("type"), QStringLiteral("nzbStream"));
        playable.insert(QStringLiteral("categoryId"), QStringLiteral("discover"));
        playable.insert(QStringLiteral("discoverStreamIndex"), streamIndex);
        if (playable.value(QStringLiteral("discoverSourceTitle")).toString()
                .trimmed().isEmpty()) {
            playable.insert(QStringLiteral("discoverSourceTitle"),
                            sourceItem.value(QStringLiteral("title")));
        }
        if (!playStateId.isEmpty())
            playable.insert(QStringLiteral("playStateId"), playStateId);
        if (!safeNzbUrl.isEmpty())
            playable.insert(QStringLiteral("nzbUrl"), safeNzbUrl);
        if (playable.value(QStringLiteral("title")).toString().trimmed().isEmpty())
            playable.insert(QStringLiteral("title"), QStringLiteral("Tater Tube Stream"));
        playableStreams.append(playable);
    }

    if (playableStreams.isEmpty()) {
        const QString message = QStringLiteral("The server did not return a playable file.");
        if (updateDiscoverPage) {
            m_discoverErrorMessage = message;
            emit discoverChanged();
        } else {
            emit discoverPlaybackFailed(message);
        }
        return;
    }
    if (!updateDiscoverPage || playableStreams.size() == 1) {
        int selectedIndex = sourceItem.value(
            QStringLiteral("discoverStreamIndex"), 0).toInt();
        selectedIndex = qBound(0, selectedIndex, playableStreams.size() - 1);
        if (updateDiscoverPage) {
            m_discoverErrorMessage.clear();
            emit discoverChanged();
        }
        QVariantMap playable = playableStreams.at(selectedIndex).toMap();
        const QString displayTitle = updateDiscoverPage
            ? playable.value(QStringLiteral("discoverTitle")).toString().trimmed()
            : sourceItem.value(QStringLiteral("title")).toString().trimmed();
        if (!displayTitle.isEmpty())
            playable.insert(QStringLiteral("title"), displayTitle);
        emit discoverPlaybackReady(playable);
        return;
    }

    m_discoverHistory.append(DiscoverPage{m_discoverItems, m_discoverTitle,
                                            m_discoverStage, m_discoverMediaType,
                                            sourceItem});
    m_discoverItems = playableStreams;
    m_discoverTitle = QStringLiteral("Choose a file");
    m_discoverStage = QStringLiteral("streams");
    m_discoverPendingItem = sourceItem;
    m_discoverErrorMessage.clear();
    emit discoverChanged();
}

void ServerClient::handlePlaybackPlanReply(QNetworkReply *reply, int generation)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    if (generation != m_playbackGeneration)
        return;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            emit playbackPlanFailed(
                QStringLiteral("This player is no longer authorized."));
            return;
        }
        emit playbackPlanFailed(responseError(
            body, status == 404
                ? QStringLiteral("This server uses legacy playback planning.")
                : QStringLiteral("The server could not prepare a playback plan.")));
        return;
    }

    QJsonObject response = QJsonDocument::fromJson(body).object();
    if (response.value(QStringLiteral("data")).isObject())
        response = response.value(QStringLiteral("data")).toObject();
    QVariantMap plan = response.toVariantMap();
    if (plan.value(QStringLiteral("stream_url")).toString().trimmed().isEmpty()) {
        emit playbackPlanFailed(QStringLiteral("The server returned an empty playback plan."));
        return;
    }
    emit playbackPlanReady(plan);
}

void ServerClient::restoreDiscoverPage(const DiscoverPage &page)
{
    m_discoverItems = page.items;
    m_discoverTitle = page.title;
    m_discoverStage = page.stage;
    m_discoverMediaType = page.mediaType;
    m_discoverPendingItem = page.pendingItem;
}

void ServerClient::resetDiscover()
{
    ++m_discoverGeneration;
    m_discoverCategories.clear();
    m_discoverItems.clear();
    m_discoverTitle = QStringLiteral("Discover");
    m_discoverStage = QStringLiteral("catalog");
    m_discoverMediaType.clear();
    m_discoverErrorMessage.clear();
    m_discoverPendingItem.clear();
    m_discoverHistory.clear();
    m_discoverLoading = false;
}

void ServerClient::resetRecommendations()
{
    cancelRecommendationSpeech();
    ++m_recommendationsGeneration;
    m_recommendations.clear();
    m_recommendationBatch.clear();
    m_recommendationsErrorMessage.clear();
    m_recommendationsLoading = false;
}

void ServerClient::handleRecommendationsReply(QNetworkReply *reply, int generation)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    if (generation != m_recommendationsGeneration)
        return;
    m_recommendationsLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        m_recommendationsErrorMessage = responseError(
            body, QStringLiteral("Tater's recommendations could not be loaded."));
        emit recommendationsChanged();
        return;
    }

    const QJsonObject data = QJsonDocument::fromJson(body).object()
                                 .value(QStringLiteral("data")).toObject();
    QVariantList recommendations;
    for (const QJsonValue &value : data.value(QStringLiteral("items")).toArray()) {
        const QJsonObject row = value.toObject();
        QVariantMap item = row.value(QStringLiteral("launch")).toObject().toVariantMap();
        const bool retroModule = item.value(QStringLiteral("type")).toString()
            .compare(QStringLiteral("module"), Qt::CaseInsensitive) == 0;
        const bool hasStream = !item.value(QStringLiteral("streamUrl")).toString().trimmed().isEmpty();
        const bool hasLocalTarget = item.value(QStringLiteral("categoryId")).toString()
                .startsWith(QStringLiteral("local:"))
            && !item.value(QStringLiteral("path")).toString().trimmed().isEmpty();
        if (retroModule && !hasStream && !hasLocalTarget)
            continue;
        if (item.value(QStringLiteral("title")).toString().trimmed().isEmpty())
            item.insert(QStringLiteral("title"), row.value(QStringLiteral("title")).toString());
        if (item.value(QStringLiteral("mediaType")).toString().trimmed().isEmpty()) {
            item.insert(QStringLiteral("mediaType"),
                        row.value(QStringLiteral("media_type")).toString());
        }
        if (item.value(QStringLiteral("poster")).toString().trimmed().isEmpty()) {
            const QString artwork = guideArtworkUrl(item);
            if (!artwork.isEmpty())
                item.insert(QStringLiteral("poster"), artwork);
        }
        const QString reason = row.value(QStringLiteral("reason")).toString().trimmed();
        item.insert(QStringLiteral("recommendationId"),
                    row.value(QStringLiteral("id")).toString());
        item.insert(QStringLiteral("recommendationReason"), reason);
        item.insert(QStringLiteral("recommendationRank"),
                    row.value(QStringLiteral("rank")).toInt());
        item.insert(QStringLiteral("recommendationSource"),
                    row.value(QStringLiteral("source")).toString());
        if (item.value(QStringLiteral("description")).toString().trimmed().isEmpty()
            && !reason.isEmpty()) {
            item.insert(QStringLiteral("description"), reason);
        }
        recommendations.append(item);
    }

    m_recommendations = recommendations;
    m_recommendationBatch = data.value(QStringLiteral("batch")).toObject().toVariantMap();
    m_recommendationsErrorMessage.clear();
    applyPendingPlaybackProgress();
    setOnline(true);
    saveContentCache();
    emit recommendationsChanged();
}

QVariantMap ServerClient::guideProgram(const QVariantList &schedule,
                                       double elapsedSeconds, bool current)
{
    for (const QVariant &value : schedule) {
        QVariantMap program = value.toMap();
        const double start = program.value(QStringLiteral("start")).toDouble();
        const double end = program.value(QStringLiteral("end")).toDouble();
        const bool matches = current
            ? start <= elapsedSeconds && elapsedSeconds < end
            : start > elapsedSeconds;
        if (!matches)
            continue;
        if (current && end > start) {
            program.insert(QStringLiteral("progressPercent"),
                           qBound(0.0, ((elapsedSeconds - start) / (end - start)) * 100.0,
                                  100.0));
        }
        return program;
    }
    return {};
}

QString ServerClient::guideArtworkUrl(const QVariantMap &program) const
{
    const QString existing = program.value(QStringLiteral("poster")).toString().trimmed();
    if (!existing.isEmpty())
        return existing;

    const QString categoryId = program.value(QStringLiteral("categoryId")).toString().trimmed();
    const QString path = program.value(QStringLiteral("path")).toString().trimmed();
    if (categoryId.isEmpty() || path.isEmpty())
        return {};

    QUrl url(endpointUrl(m_serverUrl, QStringLiteral("/api/v1/player/artwork/local")));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("category_id"), categoryId);
    query.addQueryItem(QStringLiteral("source"),
                       QString::number(program.value(QStringLiteral("sourceIndex")).toInt()));
    query.addQueryItem(QStringLiteral("path"), path);
    query.addQueryItem(QStringLiteral("player_token"), m_token);
    url.setQuery(query);
    return url.toString();
}

void ServerClient::handleLiveGuideReply(QNetworkReply *reply)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    m_liveGuideLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        if (m_liveGuideChannels.isEmpty()) {
            m_liveGuideErrorMessage = responseError(
                body, "The Live TV guide could not be loaded.");
        }
        emit liveGuideChanged();
        return;
    }

    const QJsonObject data = QJsonDocument::fromJson(body).object().value("data").toObject();
    const QDateTime startedAt = QDateTime::fromString(data.value("startedAt").toString(),
                                                      Qt::ISODateWithMs);
    QDateTime serverNow = QDateTime::fromString(data.value("serverNow").toString(),
                                                Qt::ISODateWithMs);
    if (!serverNow.isValid())
        serverNow = QDateTime::currentDateTimeUtc();
    const double elapsedSeconds = startedAt.isValid()
        ? static_cast<double>(startedAt.msecsTo(serverNow)) / 1000.0 : 0.0;

    m_liveGuideChannels.clear();
    const QVariantList channels = data.value("channels").toArray().toVariantList();
    for (const QVariant &value : channels) {
        QVariantMap channel = value.toMap();
        QVariantList schedule = channel.value(QStringLiteral("schedule")).toList();
        for (QVariant &programValue : schedule) {
            QVariantMap program = programValue.toMap();
            const QString poster = guideArtworkUrl(program);
            if (!poster.isEmpty())
                program.insert(QStringLiteral("poster"), poster);

            const double start = program.value(QStringLiteral("start")).toDouble();
            const double end = program.value(QStringLiteral("end")).toDouble();
            if (start <= elapsedSeconds && elapsedSeconds < end && end > start) {
                program.insert(QStringLiteral("progressPercent"),
                               qBound(0.0,
                                      ((elapsedSeconds - start) / (end - start)) * 100.0,
                                      100.0));
            }
            programValue = program;
        }
        channel.insert(QStringLiteral("schedule"), schedule);
        const QVariantMap now = guideProgram(schedule, elapsedSeconds, true);
        const QVariantMap next = guideProgram(schedule, elapsedSeconds, false);
        if (!now.isEmpty())
            channel.insert(QStringLiteral("now"), now);
        if (!next.isEmpty())
            channel.insert(QStringLiteral("next"), next);
        channel.insert(QStringLiteral("guideElapsedSeconds"), elapsedSeconds);
        if (startedAt.isValid())
            channel.insert(QStringLiteral("guideStartedAtMs"), startedAt.toMSecsSinceEpoch());
        channel.insert(QStringLiteral("guideServerNowMs"), serverNow.toMSecsSinceEpoch());
        m_liveGuideChannels.append(channel);
    }
    m_liveGuideErrorMessage.clear();
    m_liveGuideReady = true;
    setOnline(true);
    saveContentCache();
    emit liveGuideChanged();
}

QString ServerClient::responseError(const QByteArray &body, const QString &fallback)
{
    const QJsonObject envelope = QJsonDocument::fromJson(body).object();
    const QJsonObject error = envelope.value("error").toObject();
    QString message = error.value("message").toString().trimmed();
    if (message.isEmpty())
        message = envelope.value("message").toString().trimmed();
    return message.isEmpty() ? fallback : message;
}
