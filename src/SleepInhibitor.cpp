#include "SleepInhibitor.h"

#include <QCoreApplication>

#if defined(Q_OS_LINUX)
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QVariantMap>
#endif

SleepInhibitor::SleepInhibitor(QObject *parent)
    : QObject(parent)
{
}

SleepInhibitor::~SleepInhibitor()
{
    release();
}

void SleepInhibitor::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    emit activeChanged();
    if (m_active)
        acquire();
    else
        release();
}

void SleepInhibitor::acquire()
{
    const quint64 generation = ++m_generation;
#if defined(Q_OS_LINUX)
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        acquireScreenSaverFallback(generation);
        return;
    }

    QVariantMap options{
        {QStringLiteral("handle_token"),
         QStringLiteral("tater_%1_%2")
             .arg(QCoreApplication::applicationPid()).arg(generation)},
        {QStringLiteral("reason"), QStringLiteral("Video playback")},
    };
    QDBusMessage request = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.portal.Desktop"),
        QStringLiteral("/org/freedesktop/portal/desktop"),
        QStringLiteral("org.freedesktop.portal.Inhibit"),
        QStringLiteral("Inhibit"));
    // Portal flags: inhibit suspend (4) and idle/screensaver activation (8).
    request << QString{} << quint32{12} << options;
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(request), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, generation] {
        const QDBusPendingReply<QDBusObjectPath> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()) {
            acquireScreenSaverFallback(generation);
            return;
        }
        const QString path = reply.value().path();
        if (!m_active || generation != m_generation) {
            closePortalRequest(path);
            return;
        }
        m_portalRequestPath = path;
    });
#else
    Q_UNUSED(generation)
#endif
}

void SleepInhibitor::release()
{
    ++m_generation;
    if (!m_portalRequestPath.isEmpty()) {
        closePortalRequest(m_portalRequestPath);
        m_portalRequestPath.clear();
    }
    if (m_screenSaverCookie != 0) {
        releaseScreenSaverCookie(m_screenSaverCookie);
        m_screenSaverCookie = 0;
    }
}

void SleepInhibitor::acquireScreenSaverFallback(quint64 generation)
{
#if defined(Q_OS_LINUX)
    if (!m_active || generation != m_generation)
        return;
    QDBusMessage request = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.ScreenSaver"),
        QStringLiteral("/ScreenSaver"),
        QStringLiteral("org.freedesktop.ScreenSaver"),
        QStringLiteral("Inhibit"));
    request << QStringLiteral("Tater Tube Player") << QStringLiteral("Video playback");
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(request), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, generation] {
        const QDBusPendingReply<quint32> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError())
            return;
        const quint32 cookie = reply.value();
        if (!m_active || generation != m_generation) {
            releaseScreenSaverCookie(cookie);
            return;
        }
        m_screenSaverCookie = cookie;
    });
#else
    Q_UNUSED(generation)
#endif
}

void SleepInhibitor::closePortalRequest(const QString &path)
{
#if defined(Q_OS_LINUX)
    if (path.isEmpty())
        return;
    const QDBusMessage request = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.portal.Desktop"), path,
        QStringLiteral("org.freedesktop.portal.Request"),
        QStringLiteral("Close"));
    QDBusConnection::sessionBus().asyncCall(request);
#else
    Q_UNUSED(path)
#endif
}

void SleepInhibitor::releaseScreenSaverCookie(quint32 cookie)
{
#if defined(Q_OS_LINUX)
    if (cookie == 0)
        return;
    QDBusMessage request = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.ScreenSaver"),
        QStringLiteral("/ScreenSaver"),
        QStringLiteral("org.freedesktop.ScreenSaver"),
        QStringLiteral("UnInhibit"));
    request << cookie;
    QDBusConnection::sessionBus().asyncCall(request);
#else
    Q_UNUSED(cookie)
#endif
}
