#include "cli.h"

#include "backend.h"

#include <QCommandLineParser>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStringList>
#include <cstdio>

namespace {

void print(FILE *stream, const QString &text) {
    fprintf(stream, "%s\n", qPrintable(text));
    fflush(stream);
}

void print(const QJsonObject &object) {
    const QByteArray json = QJsonDocument(object).toJson(QJsonDocument::Indented);
    fwrite(json.constData(), 1, json.size(), stdout);
    fflush(stdout);
}

int fail(const QString &message) {
    // Agents read the first line, so errors must never span one.
    QString oneLine = message;
    oneLine.replace(QLatin1Char('\n'), QLatin1Char(' ')).replace(QLatin1Char('\r'), QLatin1Char(' '));
    print(stderr, oneLine);
    return 1;
}

// One line, short enough for a terminal column but long enough to identify a
// clip. Backend::preview already collapses whitespace and caps at 500 chars.
QString shorten(const QString &text) {
    const QString one = Backend::preview(text);
    return one.size() > 120 ? one.left(119) + QChar(0x2026) : one;
}

// The GUI hands omarchy-clipboard-open the raw position in the history file.
// Skipped entries mean that position is not the same as the list position, so
// resolve the index the agent saw to the entry it actually means.
int positionOf(const QVariantList &entries, int index) {
    for (int i = 0; i < entries.size(); ++i)
        if (entries.at(i).toMap().value("index").toInt() == index)
            return i;
    return -1;
}

struct Command {
    QCommandLineParser parser;

    Command(const QString &name, const QString &description, bool positional = true) {
        parser.setApplicationDescription(description);
        parser.addHelpOption();
        parser.addOption({"history", "Read another clipboard history file", "path"});
        if (positional)
            parser.addPositionalArgument(name, description, "<" + name + ">");
    }

    void json() { parser.addOption({"json", "Print machine-readable JSON"}); }
    void limit() { parser.addOption({"limit", "Show at most N entries, newest first", "N"}); }
    void history(const QString &description) {
        parser.addPositionalArgument("history", description, "[history]");
    }

    QString argument(int i) const { return parser.positionalArguments().value(i); }
    QString path() const { return parser.value("history"); }

    // parse() instead of process() so bad options give one line on stderr and
    // never print Qt's multi-line usage banner.
    bool parse(const QStringList &arguments, QString *error, bool *helped) {
        *helped = false;
        if (!parser.parse(arguments)) {
            *error = parser.errorText();
            return false;
        }
        if (parser.isSet(QStringLiteral("help"))) {
            print(stdout, parser.helpText());
            *helped = true;
        }
        return true;
    }

    bool maxEntries(int *limit, QString *error) const {
        *limit = -1;
        const QString value = parser.value("limit");
        if (value.isEmpty())
            return true;
        bool ok = false;
        const int number = value.toInt(&ok);
        if (!ok || number < 0) {
            *error = QStringLiteral("--limit must be a non-negative number.");
            return false;
        }
        *limit = number;
        return true;
    }
};

bool parseIndex(const QString &value, int *index, QString *error) {
    bool ok = false;
    const int number = value.toInt(&ok);
    if (value.isEmpty() || !ok || number < 0) {
        *error = QStringLiteral("Give a clip index, as shown by clips list.");
        return false;
    }
    *index = number;
    return true;
}

int listingCommand(const QStringList &arguments, bool search) {
    Command command(search ? QStringLiteral("search") : QStringLiteral("list"),
                    search ? QStringLiteral("Print the clips matching a query.")
                           : QStringLiteral("Print the clipboard history, newest first."),
                    search);
    command.json();
    command.limit();

    QString parseError;
    bool helped = false;
    if (!command.parse(arguments, &parseError, &helped))
        return fail(parseError);
    if (helped)
        return 0;

    if (search && command.argument(1).isEmpty())
        return fail("Name a search query.");

    int limit = -1;
    QString error;
    if (!command.maxEntries(&limit, &error))
        return fail(error);

    const QVariantList entries = Cli::load(command.path(), &error);
    if (!error.isEmpty())
        return fail(error);

    const QVariantList shown = Cli::filter(entries, search ? command.argument(1) : QString(), limit, &error);
    if (!error.isEmpty())
        return fail(error);

    if (command.parser.isSet("json"))
        print(Cli::listing(shown));
    else
        print(stdout, Cli::human(shown));
    return 0;
}

int latestCommand(const QStringList &arguments) {
    Command command("latest", "Print the newest clip.", false);
    command.json();

    QString parseError;
    bool helped = false;
    if (!command.parse(arguments, &parseError, &helped))
        return fail(parseError);
    if (helped)
        return 0;

    QString error;
    const QVariantList entries = Cli::load(command.path(), &error);
    if (!error.isEmpty())
        return fail(error);

    const QVariantList newest = entries.isEmpty() ? entries : entries.mid(0, 1);
    if (command.parser.isSet("json"))
        print(Cli::listing(newest));
    else
        print(stdout, Cli::human(newest));
    return 0;
}

int copyCommand(const QStringList &arguments) {
    Command command("copy", "Copy a clip back to the clipboard with wl-copy.");

    QString parseError;
    bool helped = false;
    if (!command.parse(arguments, &parseError, &helped))
        return fail(parseError);
    if (helped)
        return 0;

    int index = -1;
    QString error;
    if (!parseIndex(command.argument(1), &index, &error))
        return fail(error);

    const QVariantList entries = Cli::load(command.path(), &error);
    if (!error.isEmpty())
        return fail(error);
    const int position = positionOf(entries, index);
    if (position < 0)
        return fail(QString("No clip with index %1.").arg(index));

    // Mirrors Backend::copyEntry, including image bytes and their MIME type.
    const QVariantMap entry = entries.at(position).toMap();
    QByteArray payload;
    QStringList options;
    if (entry.value("type").toString() == QLatin1String("image")) {
        const QString path = entry.value("path").toString();
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly))
            return fail(QString("Could not read %1").arg(path));
        payload = file.readAll();
        options << QStringLiteral("--type") << entry.value("mime").toString();
    } else {
        payload = entry.value("text").toString().toUtf8();
    }

    const QString wlCopy = QStandardPaths::findExecutable("wl-copy");
    if (wlCopy.isEmpty())
        return fail("wl-copy is not installed.");

    QProcess process;
    process.start(wlCopy, options);
    if (!process.waitForStarted(2000))
        return fail("Could not start wl-copy.");
    process.write(payload);
    process.closeWriteChannel();
    if (!process.waitForFinished(5000) || process.exitStatus() != QProcess::NormalExit
        || process.exitCode() != 0)
        return fail("wl-copy failed.");

    print(stdout, QString("Copied %1: %2").arg(index).arg(Cli::preview(entry)));
    return 0;
}

int openCommand(const QStringList &arguments) {
    Command command("open", "Open a clip with Omarchy's opener.");

    QString parseError;
    bool helped = false;
    if (!command.parse(arguments, &parseError, &helped))
        return fail(parseError);
    if (helped)
        return 0;

    int index = -1;
    QString error;
    if (!parseIndex(command.argument(1), &index, &error))
        return fail(error);

    const QVariantList entries = Cli::load(command.path(), &error);
    if (!error.isEmpty())
        return fail(error);
    const int position = positionOf(entries, index);
    if (position < 0)
        return fail(QString("No clip with index %1.").arg(index));

    const QString opener = QStandardPaths::findExecutable("omarchy-clipboard-open");
    if (opener.isEmpty())
        return fail("omarchy-clipboard-open is not available.");
    if (!QProcess::startDetached(opener, {QStringLiteral("--history-index"), QString::number(index)}))
        return fail("Could not open the entry.");

    print(stdout, QString("Opened %1: %2").arg(index).arg(Cli::preview(entries.at(position).toMap())));
    return 0;
}

int skillCommand(const QStringList &arguments) {
    Command command("skill", "Print the agent skill, or install it with: skill install", false);
    command.parser.addPositionalArgument("install", "Install to ~/.agents/skills/clips and link into ~/.claude/skills",
                                         "[install]");

    QString parseError;
    bool helped = false;
    if (!command.parse(arguments, &parseError, &helped))
        return fail(parseError);
    if (helped)
        return 0;

    QFile bundled(":/skill.md");
    if (!bundled.open(QIODevice::ReadOnly))
        return fail("Could not read the bundled skill.");
    const QByteArray text = bundled.readAll();

    const QString action = command.argument(1);
    if (action.isEmpty()) {
        fwrite(text.constData(), 1, text.size(), stdout);
        return 0;
    }
    if (action != QLatin1String("install"))
        return fail("Use clips skill to print the skill, or clips skill install.");

    // One shared copy, linked into Claude Code, found directly by other agents.
    const QDir home = QDir::home();
    const QString directory = home.filePath(".agents/skills/clips");
    const QString target = directory + QStringLiteral("/SKILL.md");
    QSaveFile file(target);
    if (!QDir().mkpath(directory) || !file.open(QIODevice::WriteOnly) || file.write(text) < 0 || !file.commit())
        return fail("Could not write " + target);
    print(stdout, "Installed " + target);

    if (!home.exists(".claude"))
        return 0;
    const QString link = home.filePath(".claude/skills/clips");
    const QFileInfo existing(link);
    if (existing.isSymLink()) {
        if (!QFile::remove(link))
            return fail("Could not replace " + link);
    } else if (existing.exists()) {
        return fail(link + " exists and is not a link; leaving it alone.");
    }
    if (!home.mkpath(".claude/skills") || !QFile::link("../../.agents/skills/clips", link))
        return fail("Could not link " + link);
    print(stdout, "Linked " + link);
    return 0;
}

// --history may come before the command, so find the first real word rather
// than assuming argv[1] is the command.
QString commandWord(const QStringList &arguments) {
    for (int i = 1; i < arguments.size(); ++i) {
        const QString argument = arguments.at(i);
        if (argument == QLatin1String("--history")) {
            ++i;
            continue;
        }
        if (!argument.startsWith(QLatin1Char('-')))
            return argument;
    }
    return {};
}

int helpCommand(const QStringList &arguments) {
    const int helpIndex = arguments.indexOf(QStringLiteral("help"));
    const QString topic = helpIndex >= 0 && helpIndex + 1 < arguments.size()
                              ? arguments.at(helpIndex + 1)
                              : QString();
    if (Cli::isCliCommand(topic) && topic != QLatin1String("help") && !topic.startsWith(QLatin1Char('-'))) {
        const QStringList forwarded = {arguments.value(0), topic, QStringLiteral("--help")};
        return Cli::run(forwarded);
    }
    print(stdout, QStringLiteral("Usage: clips [command] [options]\n\n") + Cli::cliSummary());
    return 0;
}

} // namespace

bool Cli::isCommand(const QStringList &arguments) {
    static const QStringList commands = {"list", "search", "copy", "open", "latest", "skill", "help"};
    for (int i = 1; i < arguments.size(); ++i) {
        const QString argument = arguments.at(i);
        if (argument == QLatin1String("--history")) {
            ++i;
            continue;
        }
        if (argument.startsWith(QLatin1String("--history=")))
            continue;
        if (commands.contains(argument))
            return true;
        if (argument == QLatin1String("--help") || argument == QLatin1String("-h")
            || argument == QLatin1String("--version") || argument == QLatin1String("-v")
            || argument == QLatin1String("--json") || argument.startsWith(QLatin1String("--limit")))
            return true;
    }
    return false;
}

bool Cli::isCliCommand(const QString &word) {
    static const QStringList commands = {"list", "search", "copy", "open", "latest", "skill", "help"};
    return commands.contains(word) || word == QLatin1String("--help") || word == QLatin1String("-h")
           || word == QLatin1String("--version") || word == QLatin1String("-v");
}

QString Cli::historyPath(const QStringList &arguments) {
    for (int i = 1; i < arguments.size(); ++i) {
        const QString argument = arguments.at(i);
        if (argument == QLatin1String("--history") && i + 1 < arguments.size())
            return arguments.at(i + 1);
        if (argument.startsWith(QLatin1String("--history=")))
            return argument.mid(argument.indexOf(QLatin1Char('=')) + 1);
    }
    return {};
}

QVariantList Cli::load(const QString &path, QString *error) {
    const QString history = path.isEmpty()
                                ? QDir::homePath() + QStringLiteral("/.local/state/omarchy/clipboard-history.json")
                                : path;
    QFile file(history);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error)
            *error = QStringLiteral("Clipboard history not found: %1").arg(history);
        return {};
    }
    QString parseError;
    const QVariantList entries = Backend::parse(file.readAll(), &parseError);
    if (!parseError.isEmpty()) {
        if (error)
            *error = QStringLiteral("Could not read the clipboard history: %1").arg(parseError);
        return {};
    }
    return entries;
}

QVariantList Cli::filter(const QVariantList &entries, const QString &query, int limit, QString *error) {
    if (limit == 0) {
        if (error)
            error->clear();
        return {};
    }
    const QString needle = query.trimmed().toLower();
    QVariantList matches;
    for (const QVariant &value : entries) {
        const QVariantMap entry = value.toMap();
        if (!needle.isEmpty() && !entry.value("search").toString().contains(needle))
            continue;
        matches.append(value);
        if (limit > 0 && matches.size() >= limit)
            break;
    }
    return matches;
}

QString Cli::preview(const QVariantMap &entry) {
    if (entry.value("type").toString() == QLatin1String("image"))
        return entry.value("path").toString();
    return shorten(entry.value("text").toString());
}

QString Cli::time(const QVariantMap &entry) {
    // Omarchy stores a capturedAt only for images. The field is always present
    // so agents never have to guess whether a key is missing or empty.
    return entry.value("capturedAt").toString();
}

QJsonObject Cli::listing(const QVariantList &entries) {
    QJsonArray array;
    for (const QVariant &value : entries) {
        const QVariantMap entry = value.toMap();
        array.append(QJsonObject{{QStringLiteral("index"), entry.value("index").toInt()},
                                 {QStringLiteral("time"), time(entry)},
                                 {QStringLiteral("type"), entry.value("type").toString()},
                                 {QStringLiteral("preview"), preview(entry)}});
    }
    return QJsonObject{{QStringLiteral("entries"), array}, {QStringLiteral("count"), array.size()}};
}

QString Cli::human(const QVariantList &entries) {
    QString out = QStringLiteral("%1  %2  %3  %4\n")
                      .arg(QStringLiteral("IDX"), -4)
                      .arg(QStringLiteral("TIME"), -16)
                      .arg(QStringLiteral("TYPE"), -5)
                      .arg(QStringLiteral("PREVIEW"));
    for (const QVariant &value : entries) {
        const QVariantMap entry = value.toMap();
        const QString when = time(entry).isEmpty() ? QStringLiteral("—") : time(entry);
        out += QStringLiteral("%1  %2  %3  %4\n")
                   .arg(QString::number(entry.value("index").toInt()), -4)
                   .arg(when, -16)
                   .arg(entry.value("type").toString(), -5)
                   .arg(preview(entry));
    }
    const int count = entries.size();
    out += QStringLiteral("\n%1 clip%2\n").arg(count).arg(count == 1 ? QString() : QStringLiteral("s"));
    return out;
}

QString Cli::cliSummary() {
    return QStringLiteral("Read-only commands (no window, --history works with all of them):\n"
                          "  list [--limit N] [--json]        Show the history, newest first\n"
                          "  search <query> [--json]          Filter by text, image type, or image time\n"
                          "  copy <index>                     Copy a clip back with wl-copy\n"
                          "  open <index>                     Open a clip with omarchy-clipboard-open\n"
                          "  latest [--json]                  Show only the newest clip\n"
                          "  skill [install]                  Print the agent skill, or install it\n"
                          "  help [command]                   Show this, or a command's options\n"
                          "  --version                        Print the version\n"
                          "\n"
                          "Global option: --history <path>    Inspect a saved history without touching the live one\n");
}

int Cli::run(const QStringList &arguments) {
    if (arguments.contains(QStringLiteral("--help")) || arguments.contains(QStringLiteral("-h"))) {
        if (commandWord(arguments).isEmpty()) {
            print(stdout, cliSummary());
            return 0;
        }
    }
    if (commandWord(arguments).isEmpty()
        && (arguments.contains(QStringLiteral("--version")) || arguments.contains(QStringLiteral("-v")))) {
        print(stdout, QStringLiteral("clips %1").arg(QString::fromLatin1(version())));
        return 0;
    }

    const QString command = commandWord(arguments);
    if (command == QLatin1String("list"))
        return listingCommand(arguments, false);
    if (command == QLatin1String("search"))
        return listingCommand(arguments, true);
    if (command == QLatin1String("latest"))
        return latestCommand(arguments);
    if (command == QLatin1String("copy"))
        return copyCommand(arguments);
    if (command == QLatin1String("open"))
        return openCommand(arguments);
    if (command == QLatin1String("skill"))
        return skillCommand(arguments);
    if (command == QLatin1String("help"))
        return helpCommand(arguments);
    if (command.isEmpty())
        return fail("Name a command: list, search, copy, open, latest, skill, or help.");
    return fail("Unknown command: " + command);
}
