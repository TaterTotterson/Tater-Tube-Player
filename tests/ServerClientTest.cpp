#include "ServerClient.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QStandardPaths>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QtTest>

#include <functional>
#include <memory>

namespace {
struct FixtureResponse {
    QByteArray body = R"({"success":true,"data":{}})";
    QByteArray contentType = "application/json";
    QByteArray status = "200 OK";
    QByteArray extraHeaders;
    int delayMs = 0;
};

class TaterNetworkFixture {
public:
    QTcpServer server;
    std::unique_ptr<QSettings> settings;
    QList<QByteArray> requests;
    bool taterLink = true;
    std::function<FixtureResponse(const QByteArray &)> handle;

    TaterNetworkFixture()
    {
        QCoreApplication::setOrganizationName(QStringLiteral("TaterPlayerTests"));
        QCoreApplication::setApplicationName(QStringLiteral("ServerClientTest"));
        QFile::remove(QDir(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation))
            .filePath(QStringLiteral("content-cache-v1.json")));
        server.listen(QHostAddress::LocalHost, 0);
        settings = std::make_unique<QSettings>();
        settings->clear();
        settings->setValue(QStringLiteral("connection/serverUrl"),
            QStringLiteral("http://127.0.0.1:%1").arg(server.serverPort()));
        settings->setValue(QStringLiteral("connection/playerToken"), QStringLiteral("private-test-token"));
        // The INI backend used on SteamOS does not guarantee that a short-lived
        // QSettings instance is visible to the client until it is explicitly synced.
        settings->sync();
        QObject::connect(&server, &QTcpServer::newConnection, &server, [this] {
            while (QTcpSocket *socket = server.nextPendingConnection()) {
                QObject::connect(socket, &QTcpSocket::readyRead, socket,
                    [this, socket, buffer = QByteArray{}]() mutable {
                    buffer += socket->readAll();
                    const qsizetype split = buffer.indexOf("\r\n\r\n");
                    if (split < 0 || socket->property("responded").toBool())
                        return;
                    int contentLength = 0;
                    for (QByteArray header : buffer.left(split).split('\n')) {
                        if (header.toLower().startsWith("content-length:"))
                            contentLength = header.mid(15).trimmed().toInt();
                    }
                    if (buffer.size() < split + 4 + contentLength)
                        return;
                    socket->setProperty("responded", true);
                    requests.append(buffer);
                    FixtureResponse response;
                    if (buffer.startsWith("GET /api/v1/player/home ")) {
                        response.body = QByteArrayLiteral("{\"success\":true,\"data\":{\"protocolVersion\":\"1\",\"capabilities\":{\"taterLink\":")
                            + (taterLink ? "true" : "false") + "}}}";
                    } else if (handle) {
                        response = handle(buffer);
                    }
                    QTimer::singleShot(response.delayMs, socket, [socket, response] {
                        if (socket->state() != QAbstractSocket::ConnectedState)
                            return;
                        socket->write("HTTP/1.1 " + response.status + "\r\nContent-Type: "
                            + response.contentType + "\r\nContent-Length: "
                            + QByteArray::number(response.body.size()) + "\r\n"
                            + response.extraHeaders + "Connection: close\r\n\r\n" + response.body);
                        socket->disconnectFromHost();
                    });
                });
            }
        });
    }

    ~TaterNetworkFixture() { settings->clear(); }

    QList<QByteArray> matching(const QByteArray &prefix) const
    {
        QList<QByteArray> found;
        for (const QByteArray &request : requests) {
            if (request.startsWith(prefix)) found.append(request);
        }
        return found;
    }

    static QJsonObject payload(const QByteArray &request)
    {
        return QJsonDocument::fromJson(request.mid(request.indexOf("\r\n\r\n") + 4)).object();
    }
};
}

class ServerClientTest final : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void normalizesServerAddresses();
    void buildsEndpointUrls();
    void rejectsUnsupportedAddresses();
    void selectsPlaybackProfileForDisplay();
    void loadsVersionedHome();
    void addsPlaybackTranscodeParameters();
    void preservesPlaybackPlanWhenSeeking();
    void addsToneMappingToHDRFallback();
    void addsAudioOnlyTranscodeParameters();
    void addsVideoOnlyTranscodeParameters();
    void postsPlaybackProgress();
    void clearsPlaybackProgress();
    void reportsViewingHistoryForMoviesEpisodesAndTubeTV();
    void gatesTaterFeaturesOnTaterLink();
    void suppliesArtworkForOlderRecommendationResponses();
    void omitsUnsupportedRetroModulesFromRecommendations();
    void downloadsRecommendationSpeechWithAuthentication();
    void cancelsLateSpeechRequestsWithoutPlayingStaleAudio();
    void cancelsPendingRecommendationSpeech();
    void rejectsInvalidAndRedirectedRecommendationAudio_data();
    void rejectsInvalidAndRedirectedRecommendationAudio();

private:
    QTemporaryDir m_settingsDirectory;
};

void ServerClientTest::initTestCase()
{
    QVERIFY(m_settingsDirectory.isValid());
    QSettings::setDefaultFormat(QSettings::IniFormat);
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope,
                       m_settingsDirectory.path());
}

void ServerClientTest::selectsPlaybackProfileForDisplay()
{
    ServerClient client;
    QCOMPARE(client.playbackProfile({
        {QStringLiteral("max_width"), 3840},
        {QStringLiteral("max_height"), 2160},
    }), QStringLiteral("hdmi_4k"));
    QCOMPARE(client.playbackProfile({
        {QStringLiteral("max_width"), 1920},
        {QStringLiteral("max_height"), 1080},
    }), QStringLiteral("hdmi_1080p"));
    QCOMPARE(client.playbackProfile({
        {QStringLiteral("max_width"), 1280},
        {QStringLiteral("max_height"), 800},
    }), QStringLiteral("hdmi_720p"));
}

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
                    body = R"({"success":true,"data":{"protocolVersion":"1","serverName":"Test Tater Server","serverVersion":"9.9.9","capabilities":{"localMedia":true,"newznab":true,"tubeTV":true,"commercials":true,"taterLink":true},"hero":{"personalized":true,"eyebrow":"TATER LINK  •  PICKED FOR YOU","message":"Friday night calls for a cozy mystery from your library.","assistantName":"Totty"},"continueWatching":[{"title":"Resume Me","mediaType":"movie","progressPercent":25,"poster":"http://tube.test/poster.jpg"}],"recentlyAdded":[{"title":"New Show","mediaType":"show","categoryId":"local:tv","sourceIndex":0,"path":"New Show","date":"2026"}],"liveChannels":[{"number":"12","title":"Cartoons","logoUrl":"http://tube.test/logo/12.png","now":{"title":"Galaxy Rangers","progressPercent":50},"next":{"title":"Creature Feature"}}],"libraries":[{"id":"local:movies","title":"Movies"}],"warnings":["Sample warning"]}})";
                } else if (request.startsWith("GET /api/tater/recommendations ")) {
                    body = R"({"success":true,"data":{"profile_id":"household","batch":{"id":"batch-one","assistant_name":"Totty","summary":"A cozy mystery fits what you have been watching lately."},"items":[{"id":"pick-one","rank":1,"title":"Moonrise Manor","media_type":"movie","source":"local_media","reason":"A warm mystery with the same relaxed pace.","launch":{"title":"Moonrise Manor","type":"localFile","mediaType":"movie","categoryId":"local:movies","sourceIndex":0,"path":"Moonrise Manor/movie.mkv","streamUrl":"http://tube.test/moonrise","poster":"http://tube.test/moonrise.jpg"}}]}})";
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
                    body = R"({"success":true,"data":{"startedAt":"2026-09-02T12:00:00Z","serverNow":"2026-09-02T12:00:30Z","channels":[{"number":"12","title":"Cartoons","streamUrl":"http://tube.test/live/12","logoUrl":"http://tube.test/logo/12.png","schedule":[{"title":"Playing Now","kind":"movie","categoryId":"local:movies","sourceIndex":2,"path":"Playing Now/movie.mkv","start":0,"end":60},{"title":"Up Next","kind":"movie","categoryId":"local:movies","sourceIndex":2,"path":"Up Next/movie.mkv","start":60,"end":120}]}]}})";
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
    const QString cachePath = QDir(QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation)).filePath(QStringLiteral("content-cache-v1.json"));
    QFile::remove(cachePath);
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
    QTRY_COMPARE_WITH_TIMEOUT(client.recommendations().size(), 1, 3000);
    QCOMPARE(client.recommendationBatch().value("assistant_name").toString(),
             QStringLiteral("Totty"));
    QCOMPARE(client.recommendationBatch().value("summary").toString(),
             QStringLiteral("A cozy mystery fits what you have been watching lately."));
    const QVariantMap recommendation = client.recommendations().first().toMap();
    QCOMPARE(recommendation.value("title").toString(), QStringLiteral("Moonrise Manor"));
    QCOMPARE(recommendation.value("recommendationId").toString(),
             QStringLiteral("pick-one"));
    QCOMPARE(recommendation.value("recommendationReason").toString(),
             QStringLiteral("A warm mystery with the same relaxed pace."));
    QCOMPARE(recommendation.value("streamUrl").toString(),
             QStringLiteral("http://tube.test/moonrise"));
    QVERIFY(requests.contains("GET /api/tater/recommendations "));
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

    client.preparePlaybackWithAudioTrack({
        {QStringLiteral("streamUrl"), QStringLiteral("http://tube.test/movie")},
    }, QStringLiteral("movie"), {
        {QStringLiteral("video_codecs"), QStringList{QStringLiteral("h264")}},
        {QStringLiteral("audio_codecs"), QStringList{QStringLiteral("eac3")}},
    }, 2);
    QTRY_COMPARE_WITH_TIMEOUT(planSpy.count(), 2, 3000);
    QVERIFY(requests.contains("\"audio_track\":2"));

    client.browseDiscoverBack();
    QCOMPARE(client.discoverStage(), QStringLiteral("titles"));
    QCOMPARE(client.discoverItems().size(), 1);

    client.refreshLiveGuide();
    QTRY_VERIFY_WITH_TIMEOUT(client.liveGuideReady(), 3000);
    QCOMPARE(client.liveGuideChannels().size(), 1);
    const QVariantMap channel = client.liveGuideChannels().first().toMap();
    QCOMPARE(channel.value("logoUrl").toString(),
             QStringLiteral("http://tube.test/logo/12.png"));
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

    const qsizetype cachedItemRequestCount = requests.count("GET /api/tater/usenet/items?");
    const qsizetype cachedDiscoverRequestCount = requests.count(
        "GET /api/tater/usenet/discover?");
    ServerClient cachedClient;
    QVERIFY(cachedClient.homeReady());
    QCOMPARE(cachedClient.continueWatching().size(), 1);
    QCOMPARE(cachedClient.libraryRows().size(), 2);
    QCOMPARE(cachedClient.discoverCategories().size(), 6);
    QCOMPARE(cachedClient.recommendations().size(), 1);
    QCOMPARE(cachedClient.liveGuideChannels().size(), 1);

    QTest::qWait(150);
    QSignalSpy cachedLibraryChanges(&cachedClient, &ServerClient::libraryChanged);
    cachedClient.browseLibrary(allMoviesShelf.value("entry").toMap());
    QCOMPARE(cachedClient.libraryDepth(), 1);
    QCOMPARE(cachedClient.libraryItems().size(), 3);
    QVERIFY(!cachedClient.libraryLoading());
    QCOMPARE(cachedLibraryChanges.count(), 1);
    QTRY_VERIFY_WITH_TIMEOUT(
        requests.count("GET /api/tater/usenet/items?") > cachedItemRequestCount, 3000);
    QTest::qWait(100);
    QCOMPARE(cachedClient.libraryDepth(), 1);
    QCOMPARE(cachedLibraryChanges.count(), 1);

    cachedClient.browseDiscover(cachedClient.discoverCategories().first().toMap());
    QCOMPARE(cachedClient.discoverStage(), QStringLiteral("titles"));
    QCOMPARE(cachedClient.discoverItems().size(), 1);
    QVERIFY(!cachedClient.discoverLoading());
    QTRY_VERIFY_WITH_TIMEOUT(
        requests.count("GET /api/tater/usenet/discover?") > cachedDiscoverRequestCount, 3000);

    settings.clear();
    QFile::remove(cachePath);
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

void ServerClientTest::preservesPlaybackPlanWhenSeeking()
{
    ServerClient client;
    const QString planned = client.playbackUrlAtPosition(
        QStringLiteral("http://tube.local/movie?transcode=video&tater_tone_map=1&tater_source_video_range=hdr10&tater_output_video_range=sdr&start=1.000"),
        12345);
    const QUrlQuery query{QUrl(planned)};

    QCOMPARE(query.queryItemValue(QStringLiteral("transcode")), QStringLiteral("video"));
    QCOMPARE(query.queryItemValue(QStringLiteral("tater_tone_map")), QStringLiteral("1"));
    QCOMPARE(query.queryItemValue(QStringLiteral("tater_source_video_range")), QStringLiteral("hdr10"));
    QCOMPARE(query.queryItemValue(QStringLiteral("tater_output_video_range")), QStringLiteral("sdr"));
    QCOMPARE(query.queryItemValue(QStringLiteral("start")), QStringLiteral("12.345"));
}

void ServerClientTest::addsToneMappingToHDRFallback()
{
    ServerClient client;
    const QString fallback = client.playbackToneMappedTranscodeUrl(
        QStringLiteral("http://tube.local/movie?player_token=test&tater_source_video_range=dolby_vision&tater_output_video_range=dolby_vision"),
        QStringLiteral("hdmi_1080p"), QStringLiteral("dolby_vision"), 0);
    const QUrlQuery query{QUrl(fallback)};

    QCOMPARE(query.queryItemValue(QStringLiteral("transcode")), QStringLiteral("1"));
    QCOMPARE(query.queryItemValue(QStringLiteral("tater_tone_map")), QStringLiteral("1"));
    QCOMPARE(query.queryItemValue(QStringLiteral("tater_source_video_range")), QStringLiteral("dolby_vision"));
    QCOMPARE(query.queryItemValue(QStringLiteral("tater_output_video_range")), QStringLiteral("sdr"));
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

    QCOMPARE(client.continueWatching().size(), 1);
    const QVariantMap optimisticItem = client.continueWatching().constFirst().toMap();
    QCOMPARE(optimisticItem.value(QStringLiteral("title")).toString(),
             QStringLiteral("Test Movie"));
    QCOMPARE(optimisticItem.value(QStringLiteral("viewOffset")).toLongLong(), 12345);
    QCOMPARE(optimisticItem.value(QStringLiteral("viewOffsetSeconds")).toDouble(), 12.345);
    QCOMPARE(optimisticItem.value(QStringLiteral("progressPercent")).toDouble(), 20.575);

    QTRY_VERIFY_WITH_TIMEOUT(requests.contains("POST /api/tater/playstate "), 3000);
    QVERIFY(requests.contains("Authorization: Bearer progress-token"));
    QVERIFY(requests.contains("\"categoryId\":\"local:movies\""));
    QVERIFY(requests.contains("\"durationMs\":60000"));
    QVERIFY(requests.contains("\"path\":\"Test Movie.mkv\""));
    QVERIFY(requests.contains("\"positionMs\":12345"));
    QTRY_VERIFY_WITH_TIMEOUT(!client.homeLoading(), 3000);
    QCOMPARE(client.continueWatching().size(), 1);
    QCOMPARE(client.continueWatching().constFirst().toMap()
                 .value(QStringLiteral("viewOffset")).toLongLong(), 12345);

    client.savePlaybackProgress({
        {QStringLiteral("playStateId"), QStringLiteral("local:state")},
        {QStringLiteral("title"), QStringLiteral("Test Movie")},
        {QStringLiteral("mediaType"), QStringLiteral("movie")},
        {QStringLiteral("categoryId"), QStringLiteral("local:movies")},
        {QStringLiteral("sourceIndex"), 0},
        {QStringLiteral("path"), QStringLiteral("Test Movie.mkv")},
    }, 60000, 60000, true);
    QCOMPARE(client.continueWatching().size(), 0);
    client.refreshHome();
    QTRY_VERIFY_WITH_TIMEOUT(!client.homeLoading(), 3000);
    QCOMPARE(client.continueWatching().size(), 0);

    settings.clear();
}

void ServerClientTest::clearsPlaybackProgress()
{
    QTcpServer server;
    QVERIFY(server.listen(QHostAddress::LocalHost, 0));
    QByteArray requests;
    bool stateCleared = false;

    connect(&server, &QTcpServer::newConnection, &server, [&] {
        while (QTcpSocket *socket = server.nextPendingConnection()) {
            connect(socket, &QTcpSocket::readyRead, socket, [&, socket] {
                const QByteArray request = socket->readAll();
                if (!request.contains("\r\n\r\n"))
                    return;
                requests.append(request);
                QByteArray body;
                if (request.startsWith("DELETE /api/tater/playstate ")) {
                    stateCleared = true;
                    body = R"({"success":true,"data":{"cleared":true}})";
                } else if (request.startsWith("GET /api/v1/player/home ")) {
                    body = stateCleared
                        ? QByteArrayLiteral(R"({"success":true,"data":{"protocolVersion":"1","continueWatching":[],"recentlyAdded":[],"liveChannels":[],"libraries":[]}})")
                        : QByteArrayLiteral(R"({"success":true,"data":{"protocolVersion":"1","continueWatching":[{"title":"Resume Episode","mediaType":"episode","playStateId":"local:state","seriesStateId":"local:series","categoryId":"local:tv","sourceIndex":0,"path":"Show/Season 01/Episode.mkv","streamUrl":"http://tube.test/episode","viewOffset":12345,"progressPercent":25}],"recentlyAdded":[],"liveChannels":[],"libraries":[]}})");
                } else {
                    body = R"({"success":true,"data":{}})";
                }
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
    settings.setValue(QStringLiteral("connection/playerToken"), QStringLiteral("clear-token"));

    ServerClient client;
    QTRY_VERIFY_WITH_TIMEOUT(client.homeReady(), 3000);
    QCOMPARE(client.continueWatching().size(), 1);
    QSignalSpy clearedSpy(&client, &ServerClient::playbackProgressCleared);
    client.clearPlaybackProgress({
        {QStringLiteral("playStateId"), QStringLiteral("local:state")},
        {QStringLiteral("seriesStateId"), QStringLiteral("local:series")},
        {QStringLiteral("mediaType"), QStringLiteral("episode")},
        {QStringLiteral("categoryId"), QStringLiteral("local:tv")},
        {QStringLiteral("sourceIndex"), 0},
        {QStringLiteral("path"), QStringLiteral("Show/Season 01/Episode.mkv")},
    });

    QTRY_COMPARE_WITH_TIMEOUT(clearedSpy.count(), 1, 3000);
    QCOMPARE(client.continueWatching().size(), 0);
    QVERIFY(requests.contains("DELETE /api/tater/playstate "));
    QVERIFY(requests.contains("Authorization: Bearer clear-token"));
    QVERIFY(requests.contains("\"seriesId\":\"local:series\""));
    QVERIFY(requests.contains("\"path\":\"Show/Season 01/Episode.mkv\""));

    settings.clear();
}

void ServerClientTest::reportsViewingHistoryForMoviesEpisodesAndTubeTV()
{
    TaterNetworkFixture fixture;
    ServerClient client;
    QTRY_VERIFY2_WITH_TIMEOUT(client.homeReady(), qPrintable(QStringLiteral(
        "paired=%1 url=%2 listening=%3 homeError=%4 clientError=%5 requests=%6 settings=%7 loadedUrl=%8")
        .arg(client.paired()).arg(client.serverUrl()).arg(fixture.server.isListening())
        .arg(client.homeErrorMessage(), client.errorMessage())
        .arg(fixture.requests.size()).arg(QSettings().fileName())
        .arg(QSettings().value(QStringLiteral("connection/serverUrl")).toString())), 3000);
    const QVariantMap movie{
        {"title", "Moonrise Manor"}, {"mediaType", "movie"},
        {"categoryId", "local:movies"}, {"sourceIndex", 2},
        {"path", "Moonrise Manor/movie.mkv"},
        {"streamUrl", "https://user:password@private.test/movie?player_token=secret"},
        {"poster", "https://private.test/poster?player_token=secret"},
    };
    client.reportViewingEvent(movie, "movie", "started", 0, 6000000, "movie-session", 0);
    client.reportViewingEvent(movie, "movie", "started", 5000, 6000000, "movie-session", 1000);
    QTRY_COMPARE_WITH_TIMEOUT(fixture.matching("POST /api/tater/viewing/events ").size(), 1, 3000);
    client.reportViewingEvent(movie, "movie", "progress", 65000, 6000000, "movie-session", 31000);
    client.reportViewingEvent(movie, "movie", "stopped", 66000, 6000000, "movie-session", 32000);
    QTRY_VERIFY_WITH_TIMEOUT(!fixture.matching("POST /api/tater/viewing/events ").isEmpty()
        && TaterNetworkFixture::payload(fixture.matching("POST /api/tater/viewing/events ").last())
            .value("state").toString() == "stopped", 3000);
    QList<QByteArray> events = fixture.matching("POST /api/tater/viewing/events ");
    const QJsonObject started = TaterNetworkFixture::payload(events.first());
    const QJsonObject stopped = TaterNetworkFixture::payload(events.last());
    QCOMPARE(started.value("event_id"), stopped.value("event_id"));
    QCOMPARE(stopped.value("source").toString(), QStringLiteral("local_media"));
    QCOMPARE(stopped.value("media_type").toString(), QStringLiteral("movie"));
    QCOMPARE(stopped.value("position_ms").toInt(), 66000);
    QCOMPARE(stopped.value("metadata").toObject().value("watched_ms").toInt(), 32000);
    for (const QByteArray &event : events) {
        QVERIFY(event.contains("Authorization: Bearer private-test-token"));
        const QByteArray body = event.mid(event.indexOf("\r\n\r\n") + 4);
        QVERIFY(!body.contains("private.test"));
        QVERIFY(!body.contains("secret"));
        QVERIFY(!body.contains("movie.mkv"));
    }

    const QVariantMap episode{
        {"title", "Orbit S02E03"}, {"mediaType", "episode"},
        {"categoryId", "local:tv"}, {"path", "Orbit/Season 02/Orbit S02E03.mkv"},
    };
    client.reportViewingEvent(episode, "episode", "completed", 1200000, 1200000,
        "episode-session", 1195000);
    QTRY_VERIFY_WITH_TIMEOUT(TaterNetworkFixture::payload(
        fixture.matching("POST /api/tater/viewing/events ").last()).value("title").toString()
        == "Orbit S02E03", 3000);
    const QJsonObject episodeEvent = TaterNetworkFixture::payload(
        fixture.matching("POST /api/tater/viewing/events ").last());
    QCOMPARE(episodeEvent.value("series_title").toString(), QStringLiteral("Orbit"));
    QCOMPARE(episodeEvent.value("season").toInt(), 2);
    QCOMPARE(episodeEvent.value("episode").toInt(), 3);
    QCOMPARE(episodeEvent.value("media_type").toString(), QStringLiteral("episode"));

    QVariantMap channel{{"number", "07"}, {"title", "Sci-Fi Movies"}, {"now", movie}};
    client.reportViewingEvent(channel, "live", "progress", 100000, 6000000,
        "channel-session:program-one", 30000);
    QTRY_VERIFY_WITH_TIMEOUT(TaterNetworkFixture::payload(
        fixture.matching("POST /api/tater/viewing/events ").last()).value("source").toString()
        == "tube_tv", 3000);
    const QJsonObject liveEvent = TaterNetworkFixture::payload(
        fixture.matching("POST /api/tater/viewing/events ").last());
    QCOMPARE(liveEvent.value("title").toString(), QStringLiteral("Moonrise Manor"));
    QCOMPARE(liveEvent.value("media_id"), started.value("media_id"));
    QVERIFY(liveEvent.value("event_id") != started.value("event_id"));
    QCOMPARE(liveEvent.value("metadata").toObject().value("channel_number").toString(), QStringLiteral("07"));
    const qsizetype count = fixture.matching("POST /api/tater/viewing/events ").size();
    channel.insert("now", QVariantMap{{"title", "Buy Potatoes"}, {"kind", "commercial"}});
    client.reportViewingEvent(channel, "live", "progress", 10000, 30000, "commercial", 10000);
    channel.insert("now", QVariantMap{{"title", "Tater Tube"}, {"kind", "tater_bumper"}, {"mediaType", "movie"}});
    client.reportViewingEvent(channel, "live", "progress", 10000, 30000, "bumper", 10000);
    channel.insert("now", QVariantMap{{"title", "Commercial break"}, {"kind", "commercial_break"}, {"mediaType", "movie"}});
    client.reportViewingEvent(channel, "live", "progress", 10000, 30000, "break", 10000);
    QTest::qWait(80);
    QCOMPARE(fixture.matching("POST /api/tater/viewing/events ").size(), count);
}

void ServerClientTest::gatesTaterFeaturesOnTaterLink()
{
    TaterNetworkFixture fixture;
    fixture.taterLink = false;
    ServerClient client;
    QTRY_VERIFY_WITH_TIMEOUT(client.homeReady(), 3000);
    client.beginRecommendationSpeech("batch-one");
    client.reportViewingEvent({{"title", "Movie"}, {"mediaType", "movie"}},
        "movie", "progress", 10000, 100000, "session", 10000);
    QTest::qWait(80);
    QVERIFY(fixture.matching("POST /api/tater/tts/").isEmpty());
    QVERIFY(fixture.matching("POST /api/tater/viewing/").isEmpty());
    QVERIFY(!client.recommendationSpeechLoading());
}

void ServerClientTest::suppliesArtworkForOlderRecommendationResponses()
{
    TaterNetworkFixture fixture;
    fixture.handle = [](const QByteArray &request) {
        FixtureResponse response;
        if (request.startsWith("GET /api/tater/recommendations ")) {
            response.body = R"({"success":true,"data":{"batch":{"id":"batch-one","summary":"Tonight's picks"},"items":[{"id":"old-pick","title":"Movie","media_type":"movie","launch":{"categoryId":"local:movies","sourceIndex":2,"path":"Movie/Movie.mkv"}},{"id":"new-pick","title":"Show","media_type":"series","launch":{"categoryId":"local:tv","path":"Show","poster":"https://art.test/existing.jpg"}}]}})";
        }
        return response;
    };
    ServerClient client;
    QTRY_COMPARE_WITH_TIMEOUT(client.recommendations().size(), 2, 3000);
    const QUrl poster(client.recommendations().first().toMap().value("poster").toString());
    QCOMPARE(poster.host(), QStringLiteral("127.0.0.1"));
    QCOMPARE(poster.path(), QStringLiteral("/api/v1/player/artwork/local"));
    const QUrlQuery query(poster);
    QCOMPARE(query.queryItemValue("path"), QStringLiteral("Movie/Movie.mkv"));
    QCOMPARE(query.queryItemValue("source"), QStringLiteral("2"));
    QCOMPARE(query.queryItemValue("player_token"), QStringLiteral("private-test-token"));
    QCOMPARE(client.recommendations().last().toMap().value("poster").toString(),
        QStringLiteral("https://art.test/existing.jpg"));
}

void ServerClientTest::omitsUnsupportedRetroModulesFromRecommendations()
{
    TaterNetworkFixture fixture;
    fixture.handle = [](const QByteArray &request) {
        FixtureResponse response;
        if (request.startsWith("GET /api/tater/recommendations ")) {
            response.body = R"({"success":true,"data":{"batch":{"id":"batch-one"},"items":[{"id":"local-pick","title":"Movie","media_type":"movie","launch":{"type":"localFile","categoryId":"local:movies","path":"Movie/Movie.mkv"}},{"id":"retro-ota","title":"Over the Air","source":"over_the_air","media_type":"live","launch":{"type":"module","mediaType":"live","moduleId":"com.240mp.ota"}},{"id":"playable-stream","title":"Live Stream","media_type":"live","launch":{"type":"module","streamUrl":"https://stream.test/live"}}]}})";
        }
        return response;
    };
    ServerClient client;
    QTRY_COMPARE_WITH_TIMEOUT(client.recommendations().size(), 2, 3000);
    QCOMPARE(client.recommendations().first().toMap().value("recommendationId").toString(),
        QStringLiteral("local-pick"));
    QCOMPARE(client.recommendations().last().toMap().value("recommendationId").toString(),
        QStringLiteral("playable-stream"));
}

void ServerClientTest::downloadsRecommendationSpeechWithAuthentication()
{
    TaterNetworkFixture fixture;
    const QByteArray audio = QByteArrayLiteral("RIFF") + QByteArray(4, '\0') + "WAVEfmt test audio";
    fixture.handle = [audio](const QByteArray &request) {
        FixtureResponse response;
        if (request.startsWith("POST /api/tater/tts/requests ")) {
            response.body = R"({"success":true,"data":{"id":"speech-one","status":"pending"}})";
        } else if (request.startsWith("GET /api/tater/tts/requests/speech-one ")) {
            response.body = R"({"success":true,"data":{"status":"ready","audio_url":"https://untrusted.test/steal-token"}})";
        } else if (request.startsWith("GET /api/tater/tts/requests/speech-one/audio ")) {
            response.body = audio;
            response.contentType = "audio/wav";
        }
        return response;
    };
    ServerClient client;
    QTRY_VERIFY_WITH_TIMEOUT(client.homeReady(), 3000);
    QSignalSpy ready(&client, &ServerClient::recommendationSpeechReady);
    client.beginRecommendationSpeech("batch-one");
    QVERIFY(client.recommendationSpeechLoading());
    QTRY_COMPARE_WITH_TIMEOUT(ready.count(), 1, 3000);
    QVERIFY(!client.recommendationSpeechLoading());
    QVERIFY(client.recommendationSpeechErrorMessage().isEmpty());
    const QUrl url = ready.first().first().toUrl();
    QVERIFY(url.isLocalFile());
    QVERIFY(!url.toString().contains("token"));
    QFile file(url.toLocalFile());
    QVERIFY(file.open(QIODevice::ReadOnly));
    QCOMPARE(file.readAll(), audio);
    file.close();
    const QJsonObject payload = TaterNetworkFixture::payload(
        fixture.matching("POST /api/tater/tts/requests ").first());
    QCOMPARE(payload.value("batch_id").toString(), QStringLiteral("batch-one"));
    QCOMPARE(payload.value("briefing_kind").toString(), QStringLiteral("recommendations"));
    QVERIFY(payload.value("local_hour").toInt(-1) >= 0);
    for (const QByteArray &request : fixture.requests) {
        if (request.contains("/api/tater/tts/")) {
            QVERIFY(request.contains("Authorization: Bearer private-test-token"));
            QVERIFY(!request.left(request.indexOf('\n')).contains("token"));
            QVERIFY(!request.contains("untrusted.test"));
        }
    }
    client.beginRecommendationSpeech("batch-one");
    QCOMPARE(fixture.matching("POST /api/tater/tts/requests ").size(), 1);
    client.cancelRecommendationSpeech();
    QVERIFY(!QFile::exists(url.toLocalFile()));
    QTRY_COMPARE_WITH_TIMEOUT(fixture.matching("DELETE /api/tater/tts/requests/speech-one ").size(), 1, 3000);
}

void ServerClientTest::cancelsLateSpeechRequestsWithoutPlayingStaleAudio()
{
    TaterNetworkFixture fixture;
    int creates = 0;
    fixture.handle = [&creates](const QByteArray &request) {
        FixtureResponse response;
        if (request.startsWith("POST /api/tater/tts/requests ")) {
            ++creates;
            response.body = creates == 1
                ? QByteArrayLiteral(R"({"success":true,"data":{"id":"old-speech","status":"pending"}})")
                : QByteArrayLiteral(R"({"success":true,"data":{"id":"new-speech","status":"pending"}})");
            response.delayMs = creates == 1 ? 250 : 0;
        } else if (request.startsWith("GET /api/tater/tts/requests/new-speech ")) {
            response.body = R"({"success":true,"data":{"status":"ready"}})";
        } else if (request.startsWith("GET /api/tater/tts/requests/new-speech/audio ")) {
            response.body = "RIFF0000WAVEnew speech";
            response.contentType = "audio/wav";
        }
        return response;
    };
    ServerClient client;
    QTRY_VERIFY_WITH_TIMEOUT(client.homeReady(), 3000);
    QSignalSpy ready(&client, &ServerClient::recommendationSpeechReady);
    client.beginRecommendationSpeech("old-batch");
    QTRY_COMPARE_WITH_TIMEOUT(creates, 1, 3000);
    client.cancelRecommendationSpeech();
    client.beginRecommendationSpeech("new-batch");
    QTRY_COMPARE_WITH_TIMEOUT(ready.count(), 1, 3000);
    QTRY_COMPARE_WITH_TIMEOUT(fixture.matching("DELETE /api/tater/tts/requests/old-speech ").size(), 1, 3000);
    QVERIFY(fixture.matching("GET /api/tater/tts/requests/old-speech ").isEmpty());
    QCOMPARE(ready.count(), 1);
    QVERIFY(client.recommendationSpeechErrorMessage().isEmpty());
    client.cancelRecommendationSpeech();
}

void ServerClientTest::cancelsPendingRecommendationSpeech()
{
    TaterNetworkFixture fixture;
    fixture.handle = [](const QByteArray &request) {
        FixtureResponse response;
        if (request.startsWith("POST /api/tater/tts/requests "))
            response.body = R"({"success":true,"data":{"id":"pending-speech"}})";
        else if (request.startsWith("GET /api/tater/tts/requests/pending-speech "))
            response.body = R"({"success":true,"data":{"status":"pending"}})";
        return response;
    };
    ServerClient client;
    QTRY_VERIFY_WITH_TIMEOUT(client.homeReady(), 3000);
    QSignalSpy ready(&client, &ServerClient::recommendationSpeechReady);
    client.beginRecommendationSpeech("batch-one");
    QTRY_VERIFY_WITH_TIMEOUT(!fixture.matching("GET /api/tater/tts/requests/pending-speech ").isEmpty(), 3000);
    client.cancelRecommendationSpeech();
    QTRY_COMPARE_WITH_TIMEOUT(fixture.matching("DELETE /api/tater/tts/requests/pending-speech ").size(), 1, 3000);
    const qsizetype polls = fixture.matching("GET /api/tater/tts/requests/pending-speech ").size();
    QTest::qWait(350);
    QCOMPARE(fixture.matching("GET /api/tater/tts/requests/pending-speech ").size(), polls);
    QCOMPARE(ready.count(), 0);
    QVERIFY(!client.recommendationSpeechLoading());
}

void ServerClientTest::rejectsInvalidAndRedirectedRecommendationAudio_data()
{
    QTest::addColumn<bool>("redirect");
    QTest::newRow("invalid-audio") << false;
    QTest::newRow("redirect") << true;
}

void ServerClientTest::rejectsInvalidAndRedirectedRecommendationAudio()
{
    QFETCH(bool, redirect);
    TaterNetworkFixture fixture;
    fixture.handle = [redirect](const QByteArray &request) {
        FixtureResponse response;
        if (request.startsWith("POST /api/tater/tts/requests ")) {
            response.body = R"({"success":true,"data":{"id":"bad-speech"}})";
        } else if (request.startsWith("GET /api/tater/tts/requests/bad-speech ")) {
            response.body = R"({"success":true,"data":{"status":"ready"}})";
        } else if (request.startsWith("GET /api/tater/tts/requests/bad-speech/audio ")) {
            response.body = "<html>Not audio</html>";
            if (redirect) {
                response.status = "302 Found";
                response.extraHeaders = "Location: /unexpected-redirect\r\n";
            }
        }
        return response;
    };
    ServerClient client;
    QTRY_VERIFY_WITH_TIMEOUT(client.homeReady(), 3000);
    QSignalSpy ready(&client, &ServerClient::recommendationSpeechReady);
    client.beginRecommendationSpeech("batch-one");
    QTRY_VERIFY_WITH_TIMEOUT(!client.recommendationSpeechErrorMessage().isEmpty(), 3000);
    QCOMPARE(ready.count(), 0);
    QVERIFY(!client.recommendationSpeechLoading());
    QVERIFY(fixture.matching("GET /unexpected-redirect").isEmpty());
    QTRY_COMPARE_WITH_TIMEOUT(fixture.matching("DELETE /api/tater/tts/requests/bad-speech ").size(), 1, 3000);
}

QTEST_GUILESS_MAIN(ServerClientTest)
#include "ServerClientTest.moc"
