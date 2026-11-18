#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "theme.h"
#include "translator.h"

class ClipsTests : public QObject {
    Q_OBJECT

private slots:
    void parseReadsTextAndImageEntries()
    {
        const QByteArray json = R"([
            {"type": "text", "text": "hello   world\nsecond line"},
            {"type": "image", "path": "/tmp/picture.png", "mime": "image/png", "capturedAt": "Tuesday 03:12"},
            {"type": "bogus"},
            {"type": "text", "text": "   "}
        ])";

        const QVariantList entries = Backend::parse(json);
        QCOMPARE(entries.size(), 2);

        const QVariantMap text = entries.at(0).toMap();
        QCOMPARE(text.value("index").toInt(), 0);
        QCOMPARE(text.value("type").toString(), QString("text"));
        QCOMPARE(text.value("preview").toString(), QString("hello world second line"));
        QCOMPARE(text.value("bytes").toInt(), QByteArray("hello   world\nsecond line").size());

        const QVariantMap image = entries.at(1).toMap();
        QCOMPARE(image.value("index").toInt(), 1);
        QCOMPARE(image.value("type").toString(), QString("image"));
        QCOMPARE(image.value("mime").toString(), QString("image/png"));
        QCOMPARE(image.value("capturedAt").toString(), QString("Tuesday 03:12"));
    }

    void parseKeepsFileIndices()
    {
        // A skipped entry must not shift the indices of the entries after it,
        // because omarchy-clipboard-open addresses the raw file positions.
        const QByteArray json = R"([
            {"type": "bogus"},
            {"type": "text", "text": "second"}
        ])";

        const QVariantList entries = Backend::parse(json);
        QCOMPARE(entries.size(), 1);
        QCOMPARE(entries.at(0).toMap().value("index").toInt(), 1);
    }

    void parseReportsBadJson()
    {
        QString error;
        const QVariantList entries = Backend::parse("{ not json", &error);
        QVERIFY(entries.isEmpty());
        QVERIFY(!error.isEmpty());
    }

    void previewCollapsesWhitespace()
    {
        QCOMPARE(Backend::preview("a\n\n  b\tc"), QString("a b c"));
        QCOMPARE(Backend::preview("   "), QString(""));
    }

    void backendFollowsTheHistoryFile()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath("clipboard-history.json");
        write(path, R"([{"type": "text", "text": "first"}])");

        Backend backend(path);
        QVERIFY(backend.available());
        QCOMPARE(backend.count(), 1);

        write(path, R"([{"type": "text", "text": "second"}, {"type": "text", "text": "first"}])");
        backend.reload();
        QCOMPARE(backend.count(), 2);
        QCOMPARE(backend.entries().at(0).toMap().value("preview").toString(), QString("second"));
    }

    void backendReportsMissingHistory()
    {
        QTemporaryDir dir;
        Backend backend(dir.filePath("missing.json"));
        QVERIFY(!backend.available());
        QCOMPARE(backend.count(), 0);
        QVERIFY(!backend.copyEntry(0));
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QString("black"));
    }

    void themeReadsAccent()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        write(dir.path() + "/theme/colors.toml", "accent = \"#112233\"\n");

        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
    }

    void themeFollowsHyprlandRounding()
    {
        QTemporaryDir dir;
        const QString response = dir.filePath("response.json"), command = dir.filePath("hyprctl");
        write(command, "#!/bin/sh\ncat '" + response.toUtf8() + "'\n");
        QVERIFY(QFile::setPermissions(command, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        write(response, "{\"int\":0}");

        Theme theme(dir.path(), nullptr, command);
        QCOMPARE(theme.radius(), 0);
        write(response, "{\"int\":6}");
        QTRY_COMPARE(theme.radius(), 6);
    }

    void translatorFallsBackToEnglish()
    {
        QTemporaryDir dir;
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("en"));
        QVERIFY(translator.translate("Main", "Clips").isNull());
    }

    void translatorFollowsTheLanguageFile()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "da\n");
        write(dir.path() + "/da.json", R"({"Clips": "Klip", "Search": "Søg"})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("da"));
        QCOMPARE(translator.translate("Main", "Clips"), QString("Klip"));
        QCOMPARE(translator.translate("Main", "Search"), QString("Søg"));
        QVERIFY(translator.translate("Main", "Quit").isNull());
    }

    void translatorPicksPluralForms()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "ru\n");
        write(dir.path() + "/en.json", R"({"%n clips": {"one": "%n clip", "other": "%n clips"}})");
        write(dir.path() + "/ru.json", R"({"%n clips": {"one": "%n клип", "few": "%n клипа", "many": "%n клипов", "other": "%n клипа"}})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.translate("Main", "%n clips", nullptr, 21), QString("%n клип"));
        QCOMPARE(translator.translate("Main", "%n clips", nullptr, 22), QString("%n клипа"));
        QCOMPARE(translator.translate("Main", "%n clips", nullptr, 25), QString("%n клипов"));
        QCOMPARE(Translator::pluralCategory("da", 1), QString("one"));
        QCOMPARE(Translator::pluralCategory("ja", 1), QString("other"));
    }

private:
    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }
};

QTEST_MAIN(ClipsTests)
#include "clips_tests.moc"
