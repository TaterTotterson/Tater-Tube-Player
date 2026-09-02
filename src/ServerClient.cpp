#include "ServerClient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSettings>
#include <QUrl>

namespace {
constexpr auto kSettingsServerUrl = "connection/serverUrl";
constexpr auto kSettingsToken = "connection/playerToken";
constexpr auto kSettingsPlayerName = "connection/playerName";
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
    url.setQuery({});
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
        {QStringLiteral("name"), QStringLiteral("Tater Tube")},
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
    QSettings settings;
    settings.remove("connection");
    emit connectionChanged();
    emit errorMessageChanged();
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
    m_playerName = data.value("player_name").toString().trimmed();
    if (m_playerName.isEmpty())
        m_playerName = QStringLiteral("Tater Tube");
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
