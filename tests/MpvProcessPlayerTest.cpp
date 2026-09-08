#include "MpvProcessPlayer.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QtTest>

class MpvProcessPlayerTest final : public QObject
{
    Q_OBJECT

private slots:
    void prefersBestEnglishAudioTrack();
    void honorsServerSelectedAudioTrack();
    void fallsBackToBestUnlabeledAudioTrack();
    void exposesCompactAudioLabels();
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

QTEST_GUILESS_MAIN(MpvProcessPlayerTest)
#include "MpvProcessPlayerTest.moc"
