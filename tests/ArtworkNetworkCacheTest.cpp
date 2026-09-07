#include "ArtworkNetworkAccessManagerFactory.h"

#include <QDir>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QTemporaryDir>
#include <QtTest>

#include <memory>

class ArtworkNetworkCacheTest : public QObject
{
    Q_OBJECT

private slots:
    void createsBoundedPersistentDiskCache();
};

void ArtworkNetworkCacheTest::createsBoundedPersistentDiskCache()
{
    QTemporaryDir temporaryDirectory;
    QVERIFY(temporaryDirectory.isValid());

    constexpr qint64 maximumSize = 64LL * 1024LL * 1024LL;
    const QString cacheDirectory = temporaryDirectory.path() + QStringLiteral("/artwork");
    ArtworkNetworkAccessManagerFactory factory(cacheDirectory, maximumSize);
    std::unique_ptr<QNetworkAccessManager> manager(factory.create(nullptr));
    auto *cache = qobject_cast<QNetworkDiskCache *>(manager->cache());

    QVERIFY(cache);
    QCOMPARE(QDir::cleanPath(cache->cacheDirectory()), QDir::cleanPath(cacheDirectory));
    QCOMPARE(cache->maximumCacheSize(), maximumSize);
    QVERIFY(QDir(cacheDirectory).exists());
}

QTEST_GUILESS_MAIN(ArtworkNetworkCacheTest)

#include "ArtworkNetworkCacheTest.moc"
