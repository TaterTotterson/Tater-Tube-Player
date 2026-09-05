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
    void addsPlaybackTranscodeParameters();
    void addsAudioOnlyTranscodeParameters();
    void addsVideoOnlyTranscodeParameters();
    void postsPlaybackProgress();
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
                    body = R"({"success":true,"data":{"protocolVersion":"1","serverName":"Test Tater Server","serverVersion":"9.9.9","capabilities":{"localMedia":true,"newznab":true,"tubeTV":true,"commercials":true,"taterLink":true},"hero":{"personalized":true,"eyebrow":"TATER LINK  •  PICKED FOR YOU","message":"Friday night calls for a cozy mystery from your library.","assistantName":"Totty"},"continueWatching":[{"title":"Resume Me","mediaType":"movie","progressPercent":25,"poster":"http://tube.test/poster.jpg"}],"recentlyAdded":[{"title":"New Show","mediaType":"show","categoryId":"local:tv","sourceIndex":0,"path":"New Show","date":"2026"}],"liveChannels":[{"number":"12","title":"Cartoons","now":{"title":"Galaxy Rangers","progressPercent":50},"next":{"title":"Creature Feature"}}],"libraries":[{"id":"local:movies","title":"Movies"}],"warnings":["Sample warning"]}})";
                } else if (request.startsWith("GET /api/v1/player/library ")) {
                    body = R"({"success":true,"data":{"rows":[{"title":"Movies","entry":{"id":"local:movies","type":"local","title":"Movies"},"items":[{"title":"Shelf Preview","type":"localFile","mediaType":"movie","categoryId":"local:movies","sourceIndex":0,"path":"Preview.mkv","streamUrl":"http://tube.test/preview"}]},{"title":"All Movies","entry":{"id":"local-discover:movies","type":"localDiscover","title":"All Movies"},"items":[{"title":"Discovery Preview","type":"localFile","mediaType":"movie","categoryId":"local:movies","sourceIndex":0,"path":"DiscoveryPreview.mkv","streamUrl":"http://tube.test/discovery-preview"}]}]}})";
                } else if (request.startsWith("GET /api/tater/usenet/catalog ")) {
                    body = R"({"success":true,"data":{"categories":[{"type":"tubeTv","title":"Tube TV"},{"id":"stream","type":"group","title":"Stream","children":[{"type":"discoverRoot","title":"Discover","children":[{"id":"movie:top","type":"discover","title":"Popular Movies","category":"movie"},{"id":"movie:year:2026","type":"discover","title":"New Movies","category":"movie"},{"id":"movie:imdbrating","type":"discover","title":"Featured Movies","category":"movie"},{"id":"series:top","type":"discover","title":"Popular TV","category":"series"},{"id":"series:year:2026","type":"discover","title":"New TV","category":"series"},{"id":"series:imdbrating","type":"discover","title":"Featured TV","category":"series"}]}]},{"type":"localRoot","title":"Local","children":[{"type":"continue","title":"Continue Watching"},{"id":"local:movies","type":"local","title":"Movies"}]}]}})";
                } else if (request.startsWith("GET /api/tater/usenet/items?")) {
                    if (request.contains("full=1")) {
                        body = R"({"success":true,"data":{"title":"All Movies","items":[{"title":"Movie One","mediaType":"movie","streamUrl":"http://tube.test/one"},{"title":"Movie Two","mediaType":"movie","streamUrl":"http://tube.test/two"},{"title":"Movie Three","mediaType":"movie","streamUrl":"http://tube.test/three"}]}})";
                    } else if (request.contains("New")) {
                        body = R"({"success":true,"data":{"title":"New Show","items":[{"title":"Season 10","type":"localFolder","mediaType":"season","categoryId":"local:tv","sourceIndex":0,"path":"New Show/Season 10"},{"title":"Season 2","type":"localFolder","mediaType":"season","categoryId":"local:tv","sourceIndex":0,"path":"New Show/Season 02"},{"title":"Season 1","type":"localFolder","mediaType":"season","categoryId":"local:tv","sourceIndex":0,"path":"New Show/Season 01"}]}})";
                    } else {
                        body = R"({"success":true,"data":{"title":"Movies","items":[{"title":"A Folder","type":"localFolder","mediaType":"folder","categoryId":"local:movies","sourceIndex":0,"path":"Folder"},{"title":"Playable Movie","type":"localFile","mediaType":"movie","categoryId":"local:movies","sourceIndex":0,"path":"Movie.mkv","streamUrl":"http://tube.test/movie"}]}})";
                    }
                } else if (request.startsWith("GET /api/tater/usenet/discover?")) {
                    body = R"({"success":true,"data":{"title":"Popular Movies","items":[{"title":"Discover Me","type":"discovery","mediaType":"movie","searchQuery":"Discover Me 2026","date":"2026","poster":"http://tube.test/discover.jpg"}]}})";
                } else if (request.startsWith("GET /api/tater/usenet/search?")) {
                    body = R"({"success":true,"data":{"title":"Search: Discover Me 2026","items":[{"title":"Discover.Me.2026.1080p","type":"nzb","mediaType":"nzb","nzbUrl":"http://indexer.test/get/one","sizeText":"8.2 GB"},{"title":"Discover.Me.2026.720p","type":"nzb","nzbUrl":"http://indexer.test/get/two","sizeText":"4.1 GB"}]}})";
                } else if (request.startsWith("POST /api/tater/usenet/play ")) {
                    body = R"({"streams":[{"title":"Discover Me 2026","url":"http://tube.test/api/files/stream?player_token=test-token"}],"queue_status":"streamable"})";
                } else if (request.startsWith("POST /api/v1/player/playback/sessions ")) {
                    body = R"({"success":true,"data":{"stream_url":"http://tube.test/movie?transcode=video","mode":"video_transcode","video_mode":"transcode","audio_mode":"direct","video_codec":"h264","audio_codec":"eac3","quality_label":"Video H.264 • Audio Direct — Dolby Digital Plus","source":{"video_codec":"hevc","audio_codec":"eac3"}}})";
                } else if (request.startsWith("GET /api/tater/tv/lineup ")) {
                    body = R"({"success":true,"data":{"startedAt":"2026-09-02T12:00:00Z","serverNow":"2026-09-02T12:00:30Z","channels":[{"number":"12","title":"Cartoons","streamUrl":"http://tube.test/live/12","schedule":[{"title":"Playing Now","kind":"movie","categoryId":"local:movies","sourceIndex":2,"path":"Playing Now/movie.mkv","start":0,"end":60},{"title":"Up Next","kind":"movie","categoryId":"local:movies","sourceIndex":2,"path":"Up Next/movie.mkv","start":60,"end":120}]}]}})";
                } else {
                    body = R"({"success":false,"error":{"message":"Not found"}})";
                }

                const QByteArray status = request.startsWith("GET /api/")
                        || request.startsWith("POST /api/")
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
    QVERIFY(client.capabilities().value("newznab").toBool());
    QVERIFY(client.capabilities().value("taterLink").toBool());
    QVERIFY(client.homeHero().value("personalized").toBool());
    QCOMPARE(client.homeHero().value("assistantName").toString(), QStringLiteral("Totty"));
    QCOMPARE(client.homeWarnings(), QStringList{QStringLiteral("Sample warning")});
    QVERIFY(requests.contains("Authorization: Bearer test-token"));
    QTRY_COMPARE_WITH_TIMEOUT(client.libraryRows().size(), 2, 3000);
    QTRY_VERIFY_WITH_TIMEOUT(!client.libraryRowsLoading(), 3000);
    const QVariantMap movieShelf = client.libraryRows().first().toMap();
    QCOMPARE(movieShelf.value("title").toString(), QStringLiteral("Movies"));
    QCOMPARE(movieShelf.value("items").toList().size(), 1);

    const qsizetype homeItemRequestCount = requests.count("GET /api/tater/usenet/items?");
    client.browseLibraryItem(client.recentlyAdded().first().toMap());
    QTRY_COMPARE_WITH_TIMEOUT(client.libraryDepth(), 1, 3000);
    QVERIFY(requests.count("GET /api/tater/usenet/items?") > homeItemRequestCount);
    QCOMPARE(client.libraryItems().size(), 3);
    QCOMPARE(client.libraryItems().at(0).toMap().value("title").toString(), QStringLiteral("Season 1"));
    QCOMPARE(client.libraryItems().at(1).toMap().value("title").toString(), QStringLiteral("Season 2"));
    QCOMPARE(client.libraryItems().at(2).toMap().value("title").toString(), QStringLiteral("Season 10"));
    client.browseLibraryBack();
    QCOMPARE(client.libraryDepth(), 0);

    client.refreshLibraries();
    QTRY_VERIFY_WITH_TIMEOUT(requests.contains("GET /api/tater/usenet/catalog "), 3000);
    QTRY_COMPARE_WITH_TIMEOUT(client.libraries().size(), 2, 3000);
    client.browseLibrary(client.libraries().last().toMap());
    QTRY_COMPARE_WITH_TIMEOUT(client.libraryDepth(), 1, 3000);
    QCOMPARE(client.libraryTitle(), QStringLiteral("Movies"));
    QCOMPARE(client.libraryItems().size(), 2);
    QCOMPARE(client.libraryItems().last().toMap().value("title").toString(),
             QStringLiteral("Playable Movie"));
    client.browseLibraryBack();
    QCOMPARE(client.libraryDepth(), 0);

    const qsizetype itemRequestCount = requests.count("GET /api/tater/usenet/items?");
    client.browseLibrary(client.libraries().last().toMap());
    QCOMPARE(client.libraryDepth(), 1);
    QCOMPARE(client.libraryItems().size(), 2);
    QCOMPARE(requests.count("GET /api/tater/usenet/items?"), itemRequestCount);
    client.refreshLibrary();
    QTRY_VERIFY_WITH_TIMEOUT(
        requests.count("GET /api/tater/usenet/items?") > itemRequestCount, 3000);
    QTRY_VERIFY_WITH_TIMEOUT(!client.libraryLoading(), 3000);
    client.browseLibraryBack();
    QCOMPARE(client.libraryDepth(), 0);

    const QVariantMap allMoviesShelf = client.libraryRows().last().toMap();
    client.browseLibrary(allMoviesShelf.value("entry").toMap());
    QTRY_COMPARE_WITH_TIMEOUT(client.libraryItems().size(), 3, 3000);
    QCOMPARE(client.libraryTitle(), QStringLiteral("All Movies"));
    QVERIFY(requests.contains("full=1"));

    client.refreshDiscover();
    QTRY_COMPARE_WITH_TIMEOUT(client.discoverCategories().size(), 6, 3000);
    QCOMPARE(client.discoverStage(), QStringLiteral("catalog"));
    client.browseDiscover(client.discoverCategories().first().toMap());
    QTRY_COMPARE_WITH_TIMEOUT(client.discoverItems().size(), 1, 3000);
    QCOMPARE(client.discoverStage(), QStringLiteral("titles"));
    QCOMPARE(client.discoverTitle(), QStringLiteral("Popular Movies"));
    QVERIFY(requests.contains("GET /api/tater/usenet/discover?"));

    client.activateDiscoverItem(client.discoverItems().first().toMap());
    QTRY_COMPARE_WITH_TIMEOUT(client.discoverItems().size(), 2, 3000);
    QCOMPARE(client.discoverStage(), QStringLiteral("results"));
    QCOMPARE(client.discoverItems().first().toMap().value("mediaType").toString(),
             QStringLiteral("movie"));
    QVERIFY(requests.contains("GET /api/tater/usenet/search?"));

    QSignalSpy playbackSpy(&client, &ServerClient::discoverPlaybackReady);
    client.activateDiscoverItem(client.discoverItems().first().toMap());
    QTRY_COMPARE_WITH_TIMEOUT(playbackSpy.count(), 1, 3000);
    const QVariantMap preparedItem = playbackSpy.first().first().toMap();
    QCOMPARE(preparedItem.value("streamUrl").toString(),
             QStringLiteral("http://tube.test/api/files/stream?player_token=test-token"));
    QVERIFY(requests.contains("POST /api/tater/usenet/play "));

    QSignalSpy planSpy(&client, &ServerClient::playbackPlanReady);
    client.preparePlayback({
        {QStringLiteral("streamUrl"), QStringLiteral("http://tube.test/movie")},
    }, QStringLiteral("movie"), {
        {QStringLiteral("output_name"), QStringLiteral("Living Room TV")},
        {QStringLiteral("video_codecs"), QStringList{QStringLiteral("h264")}},
        {QStringLiteral("audio_codecs"), QStringList{QStringLiteral("eac3")}},
    });
    QTRY_COMPARE_WITH_TIMEOUT(planSpy.count(), 1, 3000);
    const QVariantMap plan = planSpy.first().first().toMap();
    QCOMPARE(plan.value(QStringLiteral("mode")).toString(), QStringLiteral("video_transcode"));
    QCOMPARE(plan.value(QStringLiteral("audio_mode")).toString(), QStringLiteral("direct"));
    QVERIFY(requests.contains("POST /api/v1/player/playback/sessions "));
    QVERIFY(requests.contains("Living Room TV"));

    client.browseDiscoverBack();
    QCOMPARE(client.discoverStage(), QStringLiteral("titles"));
    QCOMPARE(client.discoverItems().size(), 1);

    client.refreshLiveGuide();
    QTRY_VERIFY_WITH_TIMEOUT(client.liveGuideReady(), 3000);
    QCOMPARE(client.liveGuideChannels().size(), 1);
    const QVariantMap channel = client.liveGuideChannels().first().toMap();
    QCOMPARE(channel.value("now").toMap().value("title").toString(),
             QStringLiteral("Playing Now"));
    QCOMPARE(channel.value("next").toMap().value("title").toString(),
             QStringLiteral("Up Next"));
    QCOMPARE(channel.value("now").toMap().value("progressPercent").toDouble(), 50.0);
    const QVariantMap scheduledNow = channel.value("schedule").toList().first().toMap();
    QCOMPARE(scheduledNow.value("progressPercent").toDouble(), 50.0);
    const QUrl guidePoster(scheduledNow.value("poster").toString());
    const QUrlQuery guidePosterQuery(guidePoster);
    QCOMPARE(guidePoster.path(), QStringLiteral("/api/v1/player/artwork/local"));
    QCOMPARE(guidePosterQuery.queryItemValue(QStringLiteral("category_id")),
             QStringLiteral("local:movies"));
    QCOMPARE(guidePosterQuery.queryItemValue(QStringLiteral("source")), QStringLiteral("2"));
    QCOMPARE(guidePosterQuery.queryItemValue(QStringLiteral("path")),
             QStringLiteral("Playing Now/movie.mkv"));
    QCOMPARE(guidePosterQuery.queryItemValue(QStringLiteral("player_token")),
             QStringLiteral("test-token"));
    QCOMPARE(channel.value("guideElapsedSeconds").toDouble(), 30.0);
    QVERIFY(channel.value("guideStartedAtMs").toLongLong() > 0);

    settings.clear();
}

void ServerClientTest::addsPlaybackTranscodeParameters()
{
    ServerClient client;
    const QString fallback = client.playbackTranscodeUrl(
        QStringLiteral("http://tube.local/api/tater/local/stream?player_token=a%20b&direct=1"),
        QStringLiteral("hdmi_720p"), 12345);
    const QUrl url(fallback);
    const QUrlQuery query(url);

    QCOMPARE(query.queryItemValue(QStringLiteral("player_token")), QStringLiteral("a b"));
    QCOMPARE(query.queryItemValue(QStringLiteral("transcode")), QStringLiteral("1"));
    QCOMPARE(query.queryItemValue(QStringLiteral("profile")), QStringLiteral("hdmi_720p"));
    QCOMPARE(query.queryItemValue(QStringLiteral("codec")), QStringLiteral("h264"));
    QCOMPARE(query.queryItemValue(QStringLiteral("start")), QStringLiteral("12.345"));
    QVERIFY(!query.hasQueryItem(QStringLiteral("direct")));
}

void ServerClientTest::addsAudioOnlyTranscodeParameters()
{
    ServerClient client;
    const QString fallback = client.playbackAudioTranscodeUrl(
        QStringLiteral("http://tube.local/api/tater/local/stream?player_token=a%20b&direct=1&codec=hevc"),
        QStringLiteral("hdmi_1080p"), 12345);
    const QUrl url(fallback);
    const QUrlQuery query(url);

    QCOMPARE(query.queryItemValue(QStringLiteral("player_token")), QStringLiteral("a b"));
    QCOMPARE(query.queryItemValue(QStringLiteral("transcode")), QStringLiteral("audio"));
    QCOMPARE(query.queryItemValue(QStringLiteral("profile")), QStringLiteral("hdmi_1080p"));
    QCOMPARE(query.queryItemValue(QStringLiteral("start")), QStringLiteral("12.345"));
    QVERIFY(!query.hasQueryItem(QStringLiteral("direct")));
    QVERIFY(!query.hasQueryItem(QStringLiteral("codec")));
}

void ServerClientTest::addsVideoOnlyTranscodeParameters()
{
    ServerClient client;
    const QString fallback = client.playbackVideoTranscodeUrl(
        QStringLiteral("http://tube.local/api/tater/local/stream?player_token=a%20b&direct=1"),
        QStringLiteral("hdmi_4k"), QStringLiteral("truehd"),
        QStringLiteral("bitstream"), 12345);
    const QUrl url(fallback);
    const QUrlQuery query(url);

    QCOMPARE(query.queryItemValue(QStringLiteral("player_token")), QStringLiteral("a b"));
    QCOMPARE(query.queryItemValue(QStringLiteral("transcode")), QStringLiteral("video"));
    QCOMPARE(query.queryItemValue(QStringLiteral("profile")), QStringLiteral("hdmi_4k"));
    QCOMPARE(query.queryItemValue(QStringLiteral("codec")), QStringLiteral("h264"));
    QCOMPARE(query.queryItemValue(QStringLiteral("audio_codec")), QStringLiteral("truehd"));
    QCOMPARE(query.queryItemValue(QStringLiteral("tater_audio_mode")), QStringLiteral("bitstream"));
    QCOMPARE(query.queryItemValue(QStringLiteral("start")), QStringLiteral("12.345"));
    QVERIFY(!query.hasQueryItem(QStringLiteral("direct")));
}

void ServerClientTest::postsPlaybackProgress()
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
                const QByteArray body = R"({"success":true,"data":{"saved":true}})";
                socket->write(QByteArrayLiteral("HTTP/1.1 200 OK\r\n")
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
    settings.setValue(QStringLiteral("connection/playerToken"), QStringLiteral("progress-token"));

    ServerClient client;
    client.savePlaybackProgress({
        {QStringLiteral("playStateId"), QStringLiteral("local:state")},
        {QStringLiteral("title"), QStringLiteral("Test Movie")},
        {QStringLiteral("mediaType"), QStringLiteral("movie")},
        {QStringLiteral("categoryId"), QStringLiteral("local:movies")},
        {QStringLiteral("sourceIndex"), 0},
        {QStringLiteral("path"), QStringLiteral("Test Movie.mkv")},
    }, 12345, 60000, false);

    QTRY_VERIFY_WITH_TIMEOUT(requests.contains("POST /api/tater/playstate "), 3000);
    QVERIFY(requests.contains("Authorization: Bearer progress-token"));
    QVERIFY(requests.contains("\"categoryId\":\"local:movies\""));
    QVERIFY(requests.contains("\"durationMs\":60000"));
    QVERIFY(requests.contains("\"path\":\"Test Movie.mkv\""));
    QVERIFY(requests.contains("\"positionMs\":12345"));

    settings.clear();
}

QTEST_GUILESS_MAIN(ServerClientTest)
#include "ServerClientTest.moc"
