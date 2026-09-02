#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QString>

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

    Q_INVOKABLE void pair(const QString &serverUrl, const QString &pin);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void forgetServer();

    static QString normalizedServerUrl(const QString &rawUrl);
    static QString endpointUrl(const QString &rawUrl, const QString &path);

signals:
    void connectionChanged();
    void busyChanged();
    void errorMessageChanged();
    void pairingCompleted();

private:
    void loadSettings();
    void saveSettings() const;
    void setBusy(bool busy);
    void setErrorMessage(const QString &message);
    void setOnline(bool online);
    void handlePairReply(QNetworkReply *reply, const QString &baseUrl);
    void handleServerInfoReply(QNetworkReply *reply);
    static QString responseError(const QByteArray &body, const QString &fallback);

    QNetworkAccessManager m_network;
    QString m_serverUrl;
    QString m_token;
    QString m_serverName;
    QString m_serverVersion;
    QString m_playerName;
    QString m_errorMessage;
    bool m_online = false;
    bool m_busy = false;
};

