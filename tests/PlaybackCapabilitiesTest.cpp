#include "PlaybackCapabilities.h"

#include <QTest>

class PlaybackCapabilitiesTest final : public QObject
{
    Q_OBJECT

private slots:
    void detectsHdrStaticMetadata();
    void detectsDolbyVisionAndHdr10PlusVendorBlocks();
    void ignoresInvalidEdid();
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

void PlaybackCapabilitiesTest::ignoresInvalidEdid()
{
    QVERIFY(PlaybackCapabilities::hdrFormatsFromEdid(QByteArray(32, '\0')).isEmpty());
}

QTEST_APPLESS_MAIN(PlaybackCapabilitiesTest)
#include "PlaybackCapabilitiesTest.moc"
