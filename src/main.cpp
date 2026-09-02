#include "ServerClient.h"

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
    QCoreApplication::setApplicationName(QStringLiteral("Tater Tube"));
    QCoreApplication::setApplicationVersion(QStringLiteral(TATER_TUBE_PLAYER_VERSION));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Modern Tater Tube Server player"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOption({QStringLiteral("demo"),
                      QStringLiteral("Use deterministic sample content without pairing.")});
    parser.addOption({QStringLiteral("screenshot"),
                      QStringLiteral("Save the initial window to a PNG and exit."),
                      QStringLiteral("path")});
    parser.process(app);

    ServerClient serverClient;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("serverClient"), &serverClient);
    engine.rootContext()->setContextProperty(QStringLiteral("demoMode"),
                                             parser.isSet(QStringLiteral("demo")));
    engine.loadFromModule(QStringLiteral("TaterTube.Player"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty())
        return 1;

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
