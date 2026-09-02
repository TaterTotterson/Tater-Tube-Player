#include "ServerClient.h"

#include <QSettings>
#include <QTcpServer>
#include <QTcpSocket>
#include <QtTest>

class ServerClientTest final : public QObject
{
    Q_OBJECT

private slots:
    void normalizesServerAddresses();
    void buildsEndpointUrls();
    void rejectsUnsupportedAddresses();
    void loadsVersionedHome();
};

void ServerClientTest::normalizesServerAddresses()
{
    QCOMPARE(ServerClient::normalizedServerUrl(" 192.168.1.50:8080/ "),
             QString("http://192.168.1.50:8080"));
    QCOMPARE(ServerClient::normalizedServerUrl("https://tube.example.test/api/"),
             QString("https://tube.example.test"));
}

void ServerClientTest::buildsEndpointUrls()
{
    QCOMPARE(ServerClient::endpointUrl("tube.local:8080", "/api/tater/server"),
             QString("http://tube.local:8080/api/tater/server"));
    QCOMPARE(ServerClient::endpointUrl("https://example.test/base", "api/tater/server"),
             QString("https://example.test/base/api/tater/server"));
}

void ServerClientTest::rejectsUnsupportedAddresses()
{
    QVERIFY(ServerClient::normalizedServerUrl({}).isEmpty());
    QVERIFY(ServerClient::normalizedServerUrl("file:///tmp/server").isEmpty());
    QVERIFY(ServerClient::normalizedServerUrl("not a host").isEmpty());
}

void ServerClientTest::loadsVersionedHome()
{
    QTcpServer server;
    QVERIFY(server.listen(QHostAddress::LocalHost, 0));
    QByteArray requests;

    connect(&server, &QTcpServer::newConnection, &server, [&] {
        while (QTcpSocket *socket = server.nextPendingConnection()) {
            connect(socket, &QTcpSocket::readyRead, socket, [&, socket] {
                const QByteArray request = socket->readAll();
                if (!request.contains("\r\n\r\n"))
                    return;
                requests.append(request);

                QByteArray body;
                if (request.startsWith("GET /api/tater/server ")) {
                    body = R"({"success":true,"data":{"name":"Test Tater Server","version":"9.9.9"}})";
                } else if (request.startsWith("GET /api/v1/player/home ")) {
                    body = R"({"success":true,"data":{"protocolVersion":"1","serverName":"Test Tater Server","serverVersion":"9.9.9","capabilities":{"localMedia":true,"tubeTV":true,"commercials":true},"continueWatching":[{"title":"Resume Me","mediaType":"movie","progressPercent":25,"poster":"http://tube.test/poster.jpg"}],"recentlyAdded":[{"title":"New Movie","date":"2026"}],"liveChannels":[{"number":"12","title":"Cartoons","now":{"title":"Galaxy Rangers","progressPercent":50},"next":{"title":"Creature Feature"}}],"libraries":[{"id":"local:movies","title":"Movies"}],"warnings":["Sample warning"]}})";
                } else {
                    body = R"({"success":false,"error":{"message":"Not found"}})";
                }

                const QByteArray status = request.startsWith("GET /api/")
                    ? QByteArrayLiteral("HTTP/1.1 200 OK\r\n")
                    : QByteArrayLiteral("HTTP/1.1 404 Not Found\r\n");
                socket->write(status
                              + "Content-Type: application/json\r\nContent-Length: "
                              + QByteArray::number(body.size())
                              + "\r\nConnection: close\r\n\r\n" + body);
                socket->disconnectFromHost();
            });
        }
    });

    QCoreApplication::setOrganizationName(QStringLiteral("TaterPlayerTests"));
    QCoreApplication::setApplicationName(QStringLiteral("ServerClientTest"));
    QSettings settings;
    settings.clear();
    settings.setValue(QStringLiteral("connection/serverUrl"),
                      QStringLiteral("http://127.0.0.1:%1").arg(server.serverPort()));
    settings.setValue(QStringLiteral("connection/playerToken"), QStringLiteral("test-token"));
    settings.setValue(QStringLiteral("connection/playerName"), QStringLiteral("Test Player"));

    ServerClient client;
    QTRY_VERIFY_WITH_TIMEOUT(client.homeReady(), 3000);
    QCOMPARE(client.serverName(), QStringLiteral("Test Tater Server"));
    QCOMPARE(client.continueWatching().size(), 1);
    QCOMPARE(client.continueWatching().first().toMap().value("title").toString(),
             QStringLiteral("Resume Me"));
    QCOMPARE(client.liveChannels().first().toMap().value("number").toString(),
             QStringLiteral("12"));
    QVERIFY(client.capabilities().value("commercials").toBool());
    QCOMPARE(client.homeWarnings(), QStringList{QStringLiteral("Sample warning")});
    QVERIFY(requests.contains("Authorization: Bearer test-token"));

    settings.clear();
}

QTEST_GUILESS_MAIN(ServerClientTest)
#include "ServerClientTest.moc"
