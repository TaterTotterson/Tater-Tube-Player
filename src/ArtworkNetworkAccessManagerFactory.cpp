#include "ArtworkNetworkAccessManagerFactory.h"

#include <QDir>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QNetworkRequest>

#include <utility>

namespace {

class ArtworkNetworkAccessManager final : public QNetworkAccessManager
{
public:
    explicit ArtworkNetworkAccessManager(QObject *parent)
        : QNetworkAccessManager(parent)
    {
    }

protected:
    QNetworkReply *createRequest(Operation operation, const QNetworkRequest &request,
                                 QIODevice *outgoingData) override
    {
        QNetworkRequest cachedRequest(request);
        if (operation == GetOperation || operation == HeadOperation) {
            cachedRequest.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                                       QNetworkRequest::PreferCache);
            cachedRequest.setAttribute(QNetworkRequest::CacheSaveControlAttribute, true);
        }
        return QNetworkAccessManager::createRequest(operation, cachedRequest, outgoingData);
    }
};

} // namespace

ArtworkNetworkAccessManagerFactory::ArtworkNetworkAccessManagerFactory(
    QString cacheDirectory, qint64 maximumCacheSize)
    : m_cacheDirectory(QDir::cleanPath(std::move(cacheDirectory)))
    , m_maximumCacheSize(qMax<qint64>(0, maximumCacheSize))
{
}

QNetworkAccessManager *ArtworkNetworkAccessManagerFactory::create(QObject *parent)
{
    auto *manager = new ArtworkNetworkAccessManager(parent);
    auto *cache = new QNetworkDiskCache(manager);
    QDir().mkpath(m_cacheDirectory);
    cache->setCacheDirectory(m_cacheDirectory);
    cache->setMaximumCacheSize(m_maximumCacheSize);
    manager->setCache(cache);
    return manager;
}
