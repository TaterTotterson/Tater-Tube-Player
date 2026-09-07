#include <QFile>
#include <QJSEngine>
#include <QtTest>

class ViewingHistoryTest final : public QObject
{
    Q_OBJECT
private slots:
    void initTestCase();
    void countsPlaybackWithoutCountingSeeksStallsOrSleep();
    void followsLiveProgramsAndSkipsCommercialBreaks();
    void rejectsExpiredHomeGuideEntries();
    void keepsPausedLiveProgramWhenBroadcastGuideAdvances();
    void retainsOnDemandEpisodeIdentity();
private:
    QJSEngine engine;
};

void ViewingHistoryTest::initTestCase()
{
    QFile script(QStringLiteral(TATER_PLAYER_QML_DIR "/ViewingHistory.js"));
    QVERIFY(script.open(QIODevice::ReadOnly));
    QString source = QString::fromUtf8(script.readAll());
    source.remove(QStringLiteral(".pragma library"));
    const auto result = engine.evaluate(source);
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
}

void ViewingHistoryTest::countsPlaybackWithoutCountingSeeksStallsOrSleep()
{
    QCOMPARE(engine.evaluate("observedWatchMs(1000, 5000, 2000, 6000, true)").toInt(), 1000);
    QCOMPARE(engine.evaluate("observedWatchMs(1000, 5000, 2000, 600000, true)").toInt(), 0);
    QCOMPARE(engine.evaluate("observedWatchMs(1000, 5000, 2000, 5000, true)").toInt(), 0);
    QCOMPARE(engine.evaluate("observedWatchMs(1000, 5000, 2000, 1000, true)").toInt(), 0);
    QCOMPARE(engine.evaluate("observedWatchMs(1000, 5000, 2000, 6000, false)").toInt(), 0);
    QCOMPARE(engine.evaluate("observedWatchMs(1000, 5000, 3601000, 3605000, true)").toInt(), 0);
}

void ViewingHistoryTest::followsLiveProgramsAndSkipsCommercialBreaks()
{
    engine.evaluate(R"(
        var tuned = {number: "7", title: "SCI-FI MOVIES"};
        var guide = [{number: "7", title: "SCI-FI MOVIES", guideServerNowMs: 100000,
            guideElapsedSeconds: 5, schedule: [
                {title: "First Movie", kind: "movie", path: "first.mkv", start: 0, end: 10},
                {title: "Buy Snacks", kind: "commercial", start: 10, end: 15},
                {title: "Tater Station ID", kind: "tater_bumper", start: 15, end: 20},
                {title: "New Episode", kind: "episode", path: "Show/S01E02.mkv", start: 20, end: 80}
            ]}];
        var first = snapshot(tuned, true, guide, 100000, 5000, 0);
        var next = snapshot(tuned, true, guide, 120000, 25000, 0);
    )");
    QCOMPARE(engine.evaluate("first.item.now.title").toString(), QStringLiteral("First Movie"));
    QCOMPARE(engine.evaluate("first.positionMs").toInt(), 5000);
    QCOMPARE(engine.evaluate("first.durationMs").toInt(), 10000);
    QCOMPARE(engine.evaluate("first.item.title").toString(), QStringLiteral("SCI-FI MOVIES"));
    QVERIFY(engine.evaluate("snapshot(tuned, true, guide, 106000, 11000, 0)").isNull());
    QVERIFY(engine.evaluate("snapshot(tuned, true, guide, 111000, 16000, 0)").isNull());
    QCOMPARE(engine.evaluate("next.item.now.title").toString(), QStringLiteral("New Episode"));
    QCOMPARE(engine.evaluate("next.positionMs").toInt(), 5000);
    QVERIFY(engine.evaluate("next.key !== first.key").toBool());
    QVERIFY(engine.evaluate("snapshot(tuned, true, guide, 200000, 105000, 0)").isNull());
}

void ViewingHistoryTest::rejectsExpiredHomeGuideEntries()
{
    engine.evaluate(R"(
        var home = {number: "3", title: "Movies", now: {title: "Movie", kind: "movie",
            startsAt: "2026-09-07T12:00:00Z", endsAt: "2026-09-07T13:00:00Z"}};
    )");
    auto current = engine.evaluate("snapshot(home, true, [], Date.parse('2026-09-07T12:30:00Z'), 0, 0)");
    QVERIFY(!current.isNull());
    QCOMPARE(current.property("positionMs").toInt(), 1800000);
    QCOMPARE(current.property("durationMs").toInt(), 3600000);
    QVERIFY(engine.evaluate("snapshot(home, true, [], Date.parse('2026-09-07T13:01:00Z'), 0, 0)").isNull());
    QVERIFY(engine.evaluate("snapshot(home, true, [], Date.parse('2026-09-07T11:59:00Z'), 0, 0)").isNull());
}

void ViewingHistoryTest::keepsPausedLiveProgramWhenBroadcastGuideAdvances()
{
    engine.evaluate(R"(
        var pausedChannel = {number: '7'};
        var freshGuide = [{number: '7', guideServerNowMs: 130000,
            guideElapsedSeconds: 30, schedule: [
                {title: 'Buffered Movie', kind: 'movie', start: 0, end: 20},
                {title: 'Broadcast Ad', kind: 'commercial', start: 20, end: 40}
            ]}];
        // The refreshed guide says an ad is on air; the paused player is still 10s into the movie.
        var pausedSnapshot = snapshot(pausedChannel, true, freshGuide, 110000, 10000, 0);
    )");
    QCOMPARE(engine.evaluate("pausedSnapshot.item.now.title").toString(), QStringLiteral("Buffered Movie"));
    QCOMPARE(engine.evaluate("pausedSnapshot.positionMs").toInt(), 10000);
}

void ViewingHistoryTest::retainsOnDemandEpisodeIdentity()
{
    auto episode = engine.evaluate(R"(snapshot({title: 'Episode Two', mediaType: 'episode',
        seriesTitle: 'Harbor Street', path: 'Harbor Street/Season 1/S01E02.mkv'},
        false, [], 10000, 30000, 1200000))");
    QCOMPARE(episode.property("kind").toString(), QStringLiteral("episode"));
    QCOMPARE(episode.property("item").property("seriesTitle").toString(), QStringLiteral("Harbor Street"));
    QCOMPARE(episode.property("positionMs").toInt(), 30000);
    QCOMPARE(episode.property("durationMs").toInt(), 1200000);
}

QTEST_GUILESS_MAIN(ViewingHistoryTest)
#include "ViewingHistoryTest.moc"
