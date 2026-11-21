#pragma once

#include <QJsonObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// The headless half of Clips. These helpers are used before QGuiApplication is
// created, so no window, icon theme, or platform plugin is involved. The GUI's
// QML is untouched; both interfaces only ever read the history file.
namespace Cli {

constexpr const char *version() { return "0.2.0"; }

// True when the arguments name a command or a command-line-only option. A bare
// `clips --history <path>` still opens the window, as it always has.
bool isCommand(const QStringList &arguments);
bool isCliCommand(const QString &word);

// Accepts both `--history <path>` and `--history=<path>`, in any position.
QString historyPath(const QStringList &arguments);

// Reads and filters the history without writing to it.
QVariantList load(const QString &path, QString *error = nullptr);
QVariantList filter(const QVariantList &entries, const QString &query, int limit, QString *error = nullptr);

// Every listing command uses the same fields in the same order.
QString preview(const QVariantMap &entry);
QString time(const QVariantMap &entry);
QJsonObject listing(const QVariantList &entries);
QString human(const QVariantList &entries);

QString cliSummary();
int run(const QStringList &arguments);

} // namespace Cli
