#include "ArtworkNetworkAccessManagerFactory.h"
#include "ServerClient.h"
#include "GamepadInput.h"
#include "MpvProcessPlayer.h"
#include "PlaybackCapabilities.h"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QImage>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QScreen>
#include <QStandardPaths>
#include <QTimer>

#include <cstdio>
#include <cstring>

#ifndef TATER_TUBE_PLAYER_VERSION
#define TATER_TUBE_PLAYER_VERSION "0.0.0"
#endif

int main(int argc, char *argv[])
{
    // Keep release metadata queryable in headless build and audit environments.
    // Creating QGuiApplication first would require a display plugin even though
    // --version never opens a window.
    for (int index = 1; index < argc; ++index) {
        if (std::strcmp(argv[index], "--version") == 0
            || std::strcmp(argv[index], "-v") == 0) {
            std::printf("Tater Tube Player %s\n", TATER_TUBE_PLAYER_VERSION);
            return 0;
        }
    }

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
                      QStringLiteral("home|library|discover|recommendations|live|search"),
                      QStringLiteral("home")});
    parser.addOption({QStringLiteral("demo-details"),
                      QStringLiteral("Open a fictional title in the demo details panel."),
                      QStringLiteral("title")});
    parser.addOption({QStringLiteral("play-url"),
                      QStringLiteral("Open a URL directly in the playback screen for testing."),
                      QStringLiteral("url")});
    parser.addOption({QStringLiteral("compatible-playback"),
                      QStringLiteral("Use server-provided H.264/AAC playback for on-demand video.")});
    parser.addOption({QStringLiteral("print-capabilities"),
                      QStringLiteral("Print detected playback capabilities and exit.")});
    parser.addOption({QStringLiteral("print-screen-size"),
                      QStringLiteral("Print the primary screen size and exit.")});
    parser.process(app);

    if (parser.isSet(QStringLiteral("print-screen-size"))) {
        const QScreen *screen = QGuiApplication::primaryScreen();
        if (!screen)
            return 4;
        const QSize size = screen->geometry().size();
        std::printf("%d %d\n", size.width(), size.height());
        return 0;
    }

    ServerClient serverClient;
    GamepadInput gamepadInput;
    MpvProcessPlayer mpvPlayer;
    PlaybackCapabilities playbackCapabilities(
        parser.isSet(QStringLiteral("compatible-playback")) && !mpvPlayer.available(),
        mpvPlayer.available());
    if (parser.isSet(QStringLiteral("print-capabilities"))) {
        QTimer::singleShot(750, &app, [&app, &playbackCapabilities] {
            const QByteArray output = QJsonDocument(
                QJsonObject::fromVariantMap(playbackCapabilities.report()))
                                          .toJson(QJsonDocument::Compact);
            fwrite(output.constData(), 1, static_cast<size_t>(output.size()), stdout);
            fputc('\n', stdout);
            app.quit();
        });
        return app.exec();
    }
    const QString artworkCacheDirectory =
        QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
        + QStringLiteral("/artwork");
    ArtworkNetworkAccessManagerFactory artworkNetworkFactory(
        artworkCacheDirectory, 1024LL * 1024LL * 1024LL);
    QQmlApplicationEngine engine;
    engine.setNetworkAccessManagerFactory(&artworkNetworkFactory);
    engine.rootContext()->setContextProperty(QStringLiteral("serverClient"), &serverClient);
    engine.rootContext()->setContextProperty(QStringLiteral("gamepadInput"), &gamepadInput);
    engine.rootContext()->setContextProperty(QStringLiteral("mpvPlayer"), &mpvPlayer);
    engine.rootContext()->setContextProperty(QStringLiteral("playbackCapabilities"),
                                             &playbackCapabilities);
    engine.rootContext()->setContextProperty(QStringLiteral("demoMode"),
                                             parser.isSet(QStringLiteral("demo")));
    engine.rootContext()->setContextProperty(QStringLiteral("playbackPreviewUrl"),
                                             parser.value(QStringLiteral("play-url")));
    engine.rootContext()->setContextProperty(QStringLiteral("compatiblePlaybackMode"),
                                             parser.isSet(QStringLiteral("compatible-playback"))
                                                 && !mpvPlayer.available());
    engine.rootContext()->setContextProperty(QStringLiteral("fullScreenMode"),
                                             !parser.isSet(QStringLiteral("screenshot")));
    engine.loadFromModule(QStringLiteral("TaterTube.Player"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty())
        return 1;

    QObject *rootObject = engine.rootObjects().constFirst();
    const QString initialPage = parser.value(QStringLiteral("page")).trimmed().toLower();
    if (initialPage == QStringLiteral("home") || initialPage == QStringLiteral("library")
        || initialPage == QStringLiteral("discover")
        || initialPage == QStringLiteral("recommendations")
        || initialPage == QStringLiteral("live")
        || initialPage == QStringLiteral("search")) {
        rootObject->setProperty("currentPage", initialPage);
    }

    const QString demoDetailsTitle = parser.value(QStringLiteral("demo-details")).trimmed();
    if (parser.isSet(QStringLiteral("demo")) && !demoDetailsTitle.isEmpty()) {
        QMetaObject::invokeMethod(rootObject, "openDemoDetails", Qt::DirectConnection,
                                  Q_ARG(QVariant, QVariant(demoDetailsTitle)));
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
