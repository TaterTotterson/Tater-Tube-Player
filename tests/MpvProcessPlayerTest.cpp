#include "MpvProcessPlayer.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

class MpvProcessPlayerTest final : public QObject
{
    Q_OBJECT

private slots:
    void prefersBestEnglishAudioTrack();
    void honorsServerSelectedAudioTrack();
    void fallsBackToBestUnlabeledAudioTrack();
    void exposesCompactAudioLabels();
    void selectsBundledEngineWithoutColdStartProbe();
    void configuresNetworkReadAhead();
    void selectsGamescopeCompatibleVideoOutput();
};

void MpvProcessPlayerTest::prefersBestEnglishAudioTrack()
{
    MpvProcessPlayer player;
    player.updateTracks(QJsonArray{
        QJsonObject{{"type", "audio"}, {"id", 2}, {"lang", "jpn"},
                    {"codec", "truehd"}, {"demux-channel-count", 8},
                    {"default", true}},
        QJsonObject{{"type", "audio"}, {"id", 3}, {"lang", "eng"},
                    {"codec", "aac"}, {"demux-channel-count", 2}},
        QJsonObject{{"type", "audio"}, {"id", 4}, {"lang", "en-US"},
                    {"codec", "truehd"}, {"demux-channel-count", 8},
                    {"demux-channels", "7.1"}},
        QJsonObject{{"type", "audio"}, {"id", 5}, {"lang", "eng"},
                    {"title", "Director commentary"}, {"codec", "truehd"},
                    {"demux-channel-count", 8}},
    });

    QCOMPARE(player.m_audioTracks.size(), 4);
    QCOMPARE(player.preferredAudioTrackId(), 4);
}

void MpvProcessPlayerTest::fallsBackToBestUnlabeledAudioTrack()
{
    MpvProcessPlayer player;
    player.updateTracks(QJsonArray{
        QJsonObject{{"type", "audio"}, {"id", 2}, {"codec", "aac"},
                    {"demux-channel-count", 2}, {"default", true}},
        QJsonObject{{"type", "audio"}, {"id", 3}, {"codec", "dts-hd"},
                    {"demux-channel-count", 6}},
    });

    QCOMPARE(player.preferredAudioTrackId(), 3);
}

void MpvProcessPlayerTest::honorsServerSelectedAudioTrack()
{
    MpvProcessPlayer player;
    player.updateTracks(QJsonArray{
        QJsonObject{{"type", "audio"}, {"id", 2}, {"lang", "eng"},
                    {"codec", "truehd"}, {"demux-channel-count", 8}},
        QJsonObject{{"type", "audio"}, {"id", 7}, {"lang", "spa"},
                    {"codec", "aac"}, {"demux-channel-count", 2}},
    });

    player.setPreferredAudioTrackIndex(1);
    QCOMPARE(player.preferredAudioTrackId(), 7);
}

void MpvProcessPlayerTest::exposesCompactAudioLabels()
{
    MpvProcessPlayer player;
    player.updateTracks(QJsonArray{
        QJsonObject{{"type", "audio"}, {"id", 7}, {"lang", "eng"},
                    {"codec", "truehd"}, {"demux-channel-count", 8},
                    {"demux-channels", "7.1"}},
        QJsonObject{{"type", "sub"}, {"id", 8}, {"lang", "spa"}},
    });
    player.m_activeAudioId = 7;

    QCOMPARE(player.audioTrackLabel(), QStringLiteral("EN • TRUEHD • 7.1"));
    QVERIFY(player.audioTracksAvailable());
    QVERIFY(!player.multipleAudioTracks());
    QVERIFY(player.subtitlesAvailable());
}

void MpvProcessPlayerTest::selectsBundledEngineWithoutColdStartProbe()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString executable = directory.filePath(QStringLiteral("tater-mpv"));
    QFile file(executable);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("not a real executable\n");
    file.close();
    QVERIFY(QFile::setPermissions(executable, QFileDevice::ReadOwner
                                 | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    QCOMPARE(MpvProcessPlayer::bundledPlaybackEngine(directory.path(), true), executable);
    QVERIFY(MpvProcessPlayer::bundledPlaybackEngine(directory.path(), false).isEmpty());
}

void MpvProcessPlayerTest::configuresNetworkReadAhead()
{
    MpvProcessPlayer player;
    const QStringList arguments = player.mpvArguments();
    QVERIFY(arguments.contains(QStringLiteral("--cache=yes")));
    QVERIFY(arguments.contains(QStringLiteral("--cache-pause-initial=yes")));
    QVERIFY(arguments.contains(QStringLiteral("--demuxer-readahead-secs=20")));
    QVERIFY(arguments.contains(QStringLiteral("--demuxer-max-bytes=256MiB")));
    QVERIFY(!arguments.contains(QStringLiteral("--osc=no")));
}

void MpvProcessPlayerTest::selectsGamescopeCompatibleVideoOutput()
{
    const QByteArray previous = qgetenv("GAMESCOPE_WAYLAND_DISPLAY");
    qputenv("GAMESCOPE_WAYLAND_DISPLAY", QByteArrayLiteral("gamescope-test"));
    MpvProcessPlayer player;
    const QStringList arguments = player.mpvArguments();
    if (previous.isNull())
        qunsetenv("GAMESCOPE_WAYLAND_DISPLAY");
    else
        qputenv("GAMESCOPE_WAYLAND_DISPLAY", previous);

    QVERIFY(arguments.contains(QStringLiteral("--vo=sdl")));
    QVERIFY(arguments.contains(QStringLiteral("--hwdec=vaapi-copy")));
    QVERIFY(!arguments.contains(QStringLiteral("--gpu-context=waylandvk")));
}

QTEST_GUILESS_MAIN(MpvProcessPlayerTest)
#include "MpvProcessPlayerTest.moc"
