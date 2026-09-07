#pragma once

#include <QQmlNetworkAccessManagerFactory>
#include <QString>
#include <QtGlobal>

class QNetworkAccessManager;

class ArtworkNetworkAccessManagerFactory final : public QQmlNetworkAccessManagerFactory
{
public:
    explicit ArtworkNetworkAccessManagerFactory(QString cacheDirectory,
                                                qint64 maximumCacheSize);

    QNetworkAccessManager *create(QObject *parent) override;

private:
    QString m_cacheDirectory;
    qint64 m_maximumCacheSize;
};
