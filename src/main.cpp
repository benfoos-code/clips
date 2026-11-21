// clips — browse Omarchy's clipboard history and copy an entry back.

#include <QCoreApplication>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStringList>
#include <QUrl>

#include "backend.h"
#include "cli.h"
#include "theme.h"
#include "translator.h"

int main(int argc, char *argv[]) {
    // Decide before Qt creates any GUI: commands are plain QCoreApplication
    // processes, so scripts and agents never need a display or open a window.
    QStringList raw;
    for (int i = 0; i < argc; ++i)
        raw << QString::fromLocal8Bit(argv[i]);

    if (Cli::isCommand(raw)) {
        QCoreApplication app(argc, argv);
        app.setApplicationName("clips");
        app.setApplicationVersion(Cli::version());
        return Cli::run(app.arguments());
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName("clips");
    app.setApplicationVersion(Cli::version());

    // Matches the window to clips.desktop, so the compositor (Wayland app_id)
    // and the launcher pick up the installed icon.
    app.setDesktopFileName("clips");
    app.setWindowIcon(QIcon::fromTheme("clips"));

    QQuickStyle::setStyle("Material");

    // Installed before anything is translated, and every qsTr() binding is
    // re-evaluated when the Omarchy language changes.
    Translator translator;
    app.installTranslator(&translator);

    Theme theme;

    // --history points the app at another history file, for tests and for
    // looking at a snapshot without touching the live one. It still opens the
    // window when given alone, exactly as before.
    Backend backend(Cli::historyPath(app.arguments()));

    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
