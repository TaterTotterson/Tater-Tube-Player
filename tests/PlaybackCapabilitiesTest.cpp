#include "PlaybackCapabilities.h"

#include <QTest>

class PlaybackCapabilitiesTest final : public QObject
{
    Q_OBJECT

private slots:
    void detectsHdrStaticMetadata();
    void detectsDolbyVisionAndHdr10PlusVendorBlocks();
    void detectsHdmiAudioCapabilities();
    void ignoresInvalidEdid();
    void normalizesPhysicalDisplayModes();
};

void PlaybackCapabilitiesTest::detectsHdrStaticMetadata()
{
    QByteArray edid(256, '\0');
    edid[126] = 1;
    edid[128] = 0x02;
    edid[130] = 8;
    edid[132] = static_cast<char>((7 << 5) | 2);
    edid[133] = 0x06;
    edid[134] = 0x0c; // SMPTE ST2084 and HLG EOTFs.

    const QStringList formats = PlaybackCapabilities::hdrFormatsFromEdid(edid);
    QVERIFY(formats.contains(QStringLiteral("hdr10")));
    QVERIFY(formats.contains(QStringLiteral("hlg")));
}

void PlaybackCapabilitiesTest::detectsDolbyVisionAndHdr10PlusVendorBlocks()
{
    QByteArray edid(256, '\0');
    edid[126] = 1;
    edid[128] = 0x02;
    edid[130] = 12;
    edid[132] = static_cast<char>((3 << 5) | 3);
    edid[133] = 0x46;
    edid[134] = static_cast<char>(0xd0);
    edid[135] = 0x00;
    edid[136] = static_cast<char>((3 << 5) | 3);
    edid[137] = static_cast<char>(0x8b);
    edid[138] = static_cast<char>(0x84);
    edid[139] = static_cast<char>(0x90);

    const QStringList formats = PlaybackCapabilities::hdrFormatsFromEdid(edid);
    QVERIFY(formats.contains(QStringLiteral("dolby_vision")));
    QVERIFY(formats.contains(QStringLiteral("hdr10plus")));
    QVERIFY(formats.contains(QStringLiteral("hdr10")));
}

void PlaybackCapabilitiesTest::detectsHdmiAudioCapabilities()
{
    QByteArray edid(256, '\0');
    edid[126] = 1;
    edid[128] = 0x02;
    edid[130] = 23;
    edid[132] = static_cast<char>((1 << 5) | 18);
    const unsigned char formats[] = {1, 2, 7, 10, 11, 12};
    int offset = 133;
    for (const unsigned char format : formats) {
        edid[offset++] = static_cast<char>((format << 3) | 7); // Eight channels.
        edid[offset++] = 0x7f;
        edid[offset++] = 0x07;
    }

    const QVariantMap audio = PlaybackCapabilities::audioCapabilitiesFromEdid(edid);
    QCOMPARE(audio.value(QStringLiteral("max_channels")).toInt(), 8);
    const QStringList passthrough = audio.value(QStringLiteral("passthrough")).toStringList();
    QCOMPARE(passthrough,
             QStringList({QStringLiteral("ac3"), QStringLiteral("dts"),
                          QStringLiteral("dts_hd"), QStringLiteral("eac3"),
                          QStringLiteral("truehd")}));
}

void PlaybackCapabilitiesTest::ignoresInvalidEdid()
{
    QVERIFY(PlaybackCapabilities::hdrFormatsFromEdid(QByteArray(32, '\0')).isEmpty());
}

void PlaybackCapabilitiesTest::normalizesPhysicalDisplayModes()
{
    QCOMPARE(PlaybackCapabilities::normalizedDisplaySizeFromModes(
                 QByteArrayLiteral("1080x1920\n1080x1920\n")),
             QSize(1920, 1080));
    QCOMPARE(PlaybackCapabilities::normalizedDisplaySizeFromModes(
                 QByteArrayLiteral("3840x2160\n1920x1080\n")),
             QSize(3840, 2160));
    QVERIFY(!PlaybackCapabilities::normalizedDisplaySizeFromModes(
                 QByteArrayLiteral("not-a-mode\n")).isValid());
}

QTEST_APPLESS_MAIN(PlaybackCapabilitiesTest)
#include "PlaybackCapabilitiesTest.moc"
