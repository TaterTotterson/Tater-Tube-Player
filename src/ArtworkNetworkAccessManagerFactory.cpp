#include "ArtworkNetworkAccessManagerFactory.h"

#include <QDir>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>

#include <utility>

ArtworkNetworkAccessManagerFactory::ArtworkNetworkAccessManagerFactory(
    QString cacheDirectory, qint64 maximumCacheSize)
    : m_cacheDirectory(QDir::cleanPath(std::move(cacheDirectory)))
    , m_maximumCacheSize(qMax<qint64>(0, maximumCacheSize))
{
}

QNetworkAccessManager *ArtworkNetworkAccessManagerFactory::create(QObject *parent)
{
    auto *manager = new QNetworkAccessManager(parent);
    auto *cache = new QNetworkDiskCache(manager);
    QDir().mkpath(m_cacheDirectory);
    cache->setCacheDirectory(m_cacheDirectory);
    cache->setMaximumCacheSize(m_maximumCacheSize);
    manager->setCache(cache);
    return manager;
}
