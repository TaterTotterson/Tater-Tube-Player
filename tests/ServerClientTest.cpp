#include "ServerClient.h"

#include <QtTest>

class ServerClientTest final : public QObject
{
    Q_OBJECT

private slots:
    void normalizesServerAddresses();
    void buildsEndpointUrls();
    void rejectsUnsupportedAddresses();
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

QTEST_GUILESS_MAIN(ServerClientTest)
#include "ServerClientTest.moc"

