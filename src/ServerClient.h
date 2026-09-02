#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

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

    Q_INVOKABLE void pair(const QString &serverUrl, const QString &pin);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshHome();
    Q_INVOKABLE void forgetServer();

    static QString normalizedServerUrl(const QString &rawUrl);
    static QString endpointUrl(const QString &rawUrl, const QString &path);

signals:
    void connectionChanged();
    void busyChanged();
    void errorMessageChanged();
    void homeChanged();
    void pairingCompleted();

private:
    void loadSettings();
    void saveSettings() const;
    void setBusy(bool busy);
    void setErrorMessage(const QString &message);
    void setOnline(bool online);
    void setHomeLoading(bool loading);
    void resetHome();
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
    bool m_online = false;
    bool m_busy = false;
    bool m_homeLoading = false;
    bool m_homeReady = false;
};
