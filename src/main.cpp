#include "ServerClient.h"
#include "GamepadInput.h"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>

#ifndef TATER_TUBE_PLAYER_VERSION
#define TATER_TUBE_PLAYER_VERSION "0.0.0"
#endif

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("Tater"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("taterassistant.com"));
    QCoreApplication::setApplicationName(QStringLiteral("Tater Tube Player"));
    QCoreApplication::setApplicationVersion(QStringLiteral(TATER_TUBE_PLAYER_VERSION));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Modern Tater Tube Player"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOption({QStringLiteral("demo"),
                      QStringLiteral("Use deterministic sample content without pairing.")});
    parser.addOption({QStringLiteral("screenshot"),
                      QStringLiteral("Save the initial window to a PNG and exit."),
                      QStringLiteral("path")});
    parser.addOption({QStringLiteral("page"),
                      QStringLiteral("Open a page for design and hardware testing."),
                      QStringLiteral("home|library|live|search"),
                      QStringLiteral("home")});
    parser.addOption({QStringLiteral("play-url"),
                      QStringLiteral("Open a URL directly in the playback screen for testing."),
                      QStringLiteral("url")});
    parser.addOption({QStringLiteral("compatible-playback"),
                      QStringLiteral("Use server-provided H.264/AAC playback for on-demand video.")});
    parser.process(app);

    ServerClient serverClient;
    GamepadInput gamepadInput;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("serverClient"), &serverClient);
    engine.rootContext()->setContextProperty(QStringLiteral("gamepadInput"), &gamepadInput);
    engine.rootContext()->setContextProperty(QStringLiteral("demoMode"),
                                             parser.isSet(QStringLiteral("demo")));
    engine.rootContext()->setContextProperty(QStringLiteral("playbackPreviewUrl"),
                                             parser.value(QStringLiteral("play-url")));
    engine.rootContext()->setContextProperty(QStringLiteral("compatiblePlaybackMode"),
                                             parser.isSet(QStringLiteral("compatible-playback")));
    engine.loadFromModule(QStringLiteral("TaterTube.Player"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty())
        return 1;

    const QString initialPage = parser.value(QStringLiteral("page")).trimmed().toLower();
    if (initialPage == QStringLiteral("home") || initialPage == QStringLiteral("library")
        || initialPage == QStringLiteral("live") || initialPage == QStringLiteral("search")) {
        engine.rootObjects().constFirst()->setProperty("currentPage", initialPage);
    }

    const QString screenshotPath = parser.value(QStringLiteral("screenshot"));
    if (!screenshotPath.isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
        if (!window)
            return 2;
        QTimer::singleShot(1200, &app, [window, screenshotPath, &app] {
            const QImage image = window->grabWindow();
            app.exit(!image.isNull() && image.save(screenshotPath) ? 0 : 3);
        });
    }

    return app.exec();
}
