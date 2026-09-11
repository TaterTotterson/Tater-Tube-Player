#pragma once

#include <QObject>
#include <QString>

class SleepInhibitor final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit SleepInhibitor(QObject *parent = nullptr);
    ~SleepInhibitor() override;

    bool active() const { return m_active; }
    void setActive(bool active);

signals:
    void activeChanged();

private:
    void acquire();
    void release();
    void acquireLogindInhibit(quint64 generation);
    void acquireScreenSaverFallback(quint64 generation);
    static void closePortalRequest(const QString &path);
    static void releaseScreenSaverCookie(quint32 cookie);

    bool m_active = false;
    quint64 m_generation = 0;
    QString m_portalRequestPath;
    quint32 m_screenSaverCookie = 0;
    int m_logindFileDescriptor = -1;
};
