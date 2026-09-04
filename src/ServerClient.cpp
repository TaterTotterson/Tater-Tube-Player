#include "ServerClient.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSettings>
#include <QUrl>
#include <QUrlQuery>

namespace {
constexpr auto kSettingsServerUrl = "connection/serverUrl";
constexpr auto kSettingsToken = "connection/playerToken";
constexpr auto kSettingsPlayerName = "connection/playerName";
constexpr qint64 kLibraryCacheTtlMs = 5 * 60 * 1000;
}

ServerClient::ServerClient(QObject *parent)
    : QObject(parent)
{
    loadSettings();
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
    QNetworkRequest request{QUrl(endpointUrl(m_serverUrl, "/api/v1/player/home"))};
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
    if (!paired() || m_libraryLoading)
        return;

    m_libraryLoading = true;
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
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (!forceNetwork && !m_libraryRows.isEmpty()
        && now - m_libraryRowsStoredAtMs < kLibraryCacheTtlMs) {
        emit libraryChanged();
        return;
    }

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
    m_libraryRowsStoredAtMs = QDateTime::currentMSecsSinceEpoch();
    m_libraryErrorMessage.clear();
    setOnline(true);
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
    if (!paired() || m_libraryLoading || m_libraryHistory.isEmpty()
        || !item.value(QStringLiteral("streamUrl")).toString().trimmed().isEmpty()) {
        return;
    }

    const LibraryLocation &current = m_libraryHistory.constLast();
    LibraryLocation location;
    location.categoryId = item.value(QStringLiteral("categoryId")).toString().trimmed();
    if (location.categoryId.isEmpty())
        location.categoryId = current.categoryId;
    location.title = item.value(QStringLiteral("title"), QStringLiteral("Library"))
                         .toString().trimmed();
    location.path = item.value(QStringLiteral("path")).toString().trimmed();
    location.sourceIndex = item.contains(QStringLiteral("sourceIndex"))
        ? item.value(QStringLiteral("sourceIndex")).toInt() : current.sourceIndex;
    loadLibraryLocation(location, true);
}

void ServerClient::browseLibraryBack()
{
    if (m_libraryLoading || m_libraryHistory.isEmpty())
        return;
    if (m_libraryHistory.size() == 1) {
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

QString ServerClient::libraryCacheKey(const LibraryLocation &location) const
{
    return QStringLiteral("%1\n%2\n%3\n%4\n%5")
        .arg(m_serverUrl, location.categoryId, QString::number(location.sourceIndex),
             location.path, location.continueWatching ? QStringLiteral("1") : QStringLiteral("0"));
}

void ServerClient::loadLibraryLocation(const LibraryLocation &location, bool pushHistory,
                                       bool forceNetwork)
{
    const QString cacheKey = libraryCacheKey(location);
    const auto cached = m_libraryCache.constFind(cacheKey);
    if (!forceNetwork && cached != m_libraryCache.cend()
        && QDateTime::currentMSecsSinceEpoch() - cached->storedAtMs < kLibraryCacheTtlMs) {
        m_libraryItems = cached->items;
        m_libraryTitle = cached->title;
        m_libraryErrorMessage.clear();
        m_libraryLoading = false;
        if (pushHistory)
            m_libraryHistory.append(location);
        emit libraryChanged();
        return;
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

    m_libraryLoading = true;
    m_libraryErrorMessage.clear();
    emit libraryChanged();
    QNetworkRequest request{url};
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, location, pushHistory] {
                handleLibraryReply(reply, location, pushHistory);
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
    ++m_libraryRowsGeneration;
    m_libraryRowsPending = 0;
    m_libraryRowsStoredAtMs = 0;
    m_liveGuideChannels.clear();
    m_liveGuideErrorMessage.clear();
    m_liveGuideLoading = false;
    m_liveGuideReady = false;
    QSettings settings;
    settings.remove("connection");
    emit connectionChanged();
    emit errorMessageChanged();
    emit homeChanged();
    emit libraryChanged();
    emit liveGuideChanged();
}

void ServerClient::savePlaybackProgress(const QVariantMap &item, qint64 positionMs,
                                        qint64 durationMs, bool completed)
{
    if (!paired())
        return;

    const QString path = item.value(QStringLiteral("path")).toString().trimmed();
    const QString categoryId = item.value(QStringLiteral("categoryId")).toString().trimmed();
    if (path.isEmpty() || categoryId.isEmpty())
        return;

    QJsonObject payload{
        {QStringLiteral("id"), item.value(QStringLiteral("playStateId")).toString()},
        {QStringLiteral("seriesId"), item.value(QStringLiteral("seriesStateId")).toString()},
        {QStringLiteral("title"), item.value(QStringLiteral("title")).toString()},
        {QStringLiteral("mediaType"), item.value(QStringLiteral("mediaType")).toString()},
        {QStringLiteral("categoryId"), categoryId},
        {QStringLiteral("sourceIndex"), item.value(QStringLiteral("sourceIndex")).toInt()},
        {QStringLiteral("path"), path},
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
    query.removeAllQueryItems(QStringLiteral("start"));
    query.addQueryItem(QStringLiteral("transcode"), QStringLiteral("1"));
    query.addQueryItem(QStringLiteral("profile"), profile.trimmed().isEmpty()
                           ? QStringLiteral("hdmi_1080p") : profile.trimmed());
    query.addQueryItem(QStringLiteral("codec"), QStringLiteral("h264"));
    if (startMs > 0) {
        query.addQueryItem(QStringLiteral("start"),
                           QString::number(static_cast<double>(startMs) / 1000.0, 'f', 3));
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
    query.removeAllQueryItems(QStringLiteral("start"));
    query.addQueryItem(QStringLiteral("transcode"), QStringLiteral("audio"));
    query.addQueryItem(QStringLiteral("profile"), profile.trimmed().isEmpty()
                           ? QStringLiteral("hdmi_1080p") : profile.trimmed());
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
}

void ServerClient::saveSettings() const
{
    QSettings settings;
    settings.setValue(kSettingsServerUrl, m_serverUrl);
    settings.setValue(kSettingsToken, m_token);
    settings.setValue(kSettingsPlayerName, m_playerName);
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

    m_serverUrl = baseUrl;
    m_token = token;
    m_libraryCache.clear();
    m_libraryHistory.clear();
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
        m_homeReady = false;
        if (status == 404) {
            m_homeErrorMessage = QStringLiteral(
                "Update Tater Tube Server to a version with the Player Home API.");
        } else {
            m_homeErrorMessage = responseError(body, "The home screen could not be loaded.");
        }
        emit homeChanged();
        return;
    }

    const QJsonObject envelope = QJsonDocument::fromJson(body).object();
    const QJsonObject data = envelope.value("data").toObject();
    if (data.isEmpty()) {
        m_homeReady = false;
        m_homeErrorMessage = QStringLiteral("The server returned an empty home response.");
        emit homeChanged();
        return;
    }

    m_continueWatching = data.value("continueWatching").toArray().toVariantList();
    m_recentlyAdded = data.value("recentlyAdded").toArray().toVariantList();
    m_liveChannels = data.value("liveChannels").toArray().toVariantList();
    m_libraries = data.value("libraries").toArray().toVariantList();
    m_capabilities = data.value("capabilities").toObject().toVariantMap();
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
    emit connectionChanged();
    emit homeChanged();
    loadLibraryRows(false);
}

void ServerClient::handleLibraryReply(QNetworkReply *reply,
                                      const LibraryLocation &location,
                                      bool pushHistory)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    m_libraryLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
        m_libraryErrorMessage = responseError(body, "This library could not be loaded.");
        emit libraryChanged();
        return;
    }

    const QJsonObject data = QJsonDocument::fromJson(body).object().value("data").toObject();
    m_libraryItems = data.value("items").toArray().toVariantList();
    m_libraryTitle = data.value("title").toString().trimmed();
    if (m_libraryTitle.isEmpty())
        m_libraryTitle = location.title.isEmpty() ? QStringLiteral("Library") : location.title;
    m_libraryErrorMessage.clear();
    m_libraryCache.insert(libraryCacheKey(location), LibraryCacheEntry{
        m_libraryItems, m_libraryTitle, QDateTime::currentMSecsSinceEpoch(),
    });
    if (pushHistory)
        m_libraryHistory.append(location);
    setOnline(true);
    emit libraryChanged();
}

void ServerClient::handleLibrariesReply(QNetworkReply *reply)
{
    const QByteArray body = reply->readAll();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool succeeded = reply->error() == QNetworkReply::NoError
        && status >= 200 && status < 300;
    reply->deleteLater();
    m_libraryLoading = false;

    if (!succeeded) {
        if (status == 401 || status == 403) {
            forgetServer();
            setErrorMessage("This player is no longer authorized. Pair it with the server again.");
            return;
        }
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
    emit homeChanged();
    emit libraryChanged();
    loadLibraryRows(true);
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
        m_liveGuideErrorMessage = responseError(body, "The Live TV guide could not be loaded.");
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
        const QVariantList schedule = channel.value(QStringLiteral("schedule")).toList();
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
