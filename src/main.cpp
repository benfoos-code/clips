// clips — browse Omarchy's clipboard history and copy an entry back.

#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStringList>
#include <QUrl>

#include "backend.h"
#include "theme.h"
#include "translator.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("clips");
    app.setApplicationVersion("0.1.0");

    // Matches the window to clips.desktop, so the compositor (Wayland app_id)
    // and the launcher pick up the installed icon.
    app.setDesktopFileName("clips");
    app.setWindowIcon(QIcon::fromTheme("clips"));

    QQuickStyle::setStyle("Material");

    // --history points the app at another history file, for tests and for
    // looking at a snapshot without touching the live one.
    QString historyPath;
    const QStringList arguments = app.arguments();
    for (int i = 1; i + 1 < arguments.size(); ++i)
        if (arguments.at(i) == QLatin1String("--history"))
            historyPath = arguments.at(i + 1);

    // Installed before anything is translated, and every qsTr() binding is
    // re-evaluated when the Omarchy language changes.
    Translator translator;
    app.installTranslator(&translator);

    Theme theme;
    Backend backend(historyPath);

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
