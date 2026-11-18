#include "backend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStringList>
#include <QVariantMap>

Backend::Backend(const QString &historyPath, QObject *parent)
    : QObject(parent),
      m_historyPath(historyPath.isEmpty()
                        ? QDir::homePath() + "/.local/state/omarchy/clipboard-history.json"
                        : historyPath) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(120);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_debounce, &QTimer::timeout, this, &Backend::reload);
    reload();
}

// Collapses any run of whitespace to one space so a row can show a single line.
QString Backend::preview(const QString &text) {
    static const QRegularExpression whitespace("\\s+");
    QString collapsed = text;
    collapsed.replace(whitespace, " ");
    collapsed = collapsed.trimmed();
    if (collapsed.size() > 500)
        collapsed = collapsed.left(500) + QChar(0x2026);
    return collapsed;
}

// Reads the shell's history, newest first, and keeps each entry's position in
// the file as its index so omarchy-clipboard-open can address the same entry.
QVariantList Backend::parse(const QByteArray &json, QString *error) {
    QVariantList entries;
    QJsonParseError parseError{};
    const QJsonDocument document = QJsonDocument::fromJson(json, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        if (error)
            *error = parseError.errorString();
        return entries;
    }
    if (!document.isArray()) {
        if (error)
            *error = QStringLiteral("the clipboard history is not a list");
        return entries;
    }

    const QJsonArray array = document.array();
    for (int i = 0; i < array.size(); ++i) {
        if (!array.at(i).isObject())
            continue;
        const QJsonObject object = array.at(i).toObject();
        const QString type = object.value("type").toString();

        QVariantMap entry;
        if (type == QLatin1String("text")) {
            const QString text = object.value("text").toString();
            if (text.trimmed().isEmpty())
                continue;
            entry.insert("type", "text");
            entry.insert("text", text);
            entry.insert("preview", preview(text));
            entry.insert("search", text.toLower());
            entry.insert("bytes", text.toUtf8().size());
        } else if (type == QLatin1String("image")) {
            const QString path = object.value("path").toString();
            if (path.isEmpty())
                continue;
            QString mime = object.value("mime").toString();
            if (mime.isEmpty())
                mime = QStringLiteral("image/png");
            const QString capturedAt = object.value("capturedAt").toString();
            entry.insert("type", "image");
            entry.insert("path", path);
            entry.insert("mime", mime);
            entry.insert("capturedAt", capturedAt);
            entry.insert("preview", QString());
            entry.insert("search", QStringLiteral("image ") + mime + " " + capturedAt);
            entry.insert("bytes", QFileInfo(path).size());
        } else {
            continue;
        }
        // The index is the entry's position in the file, assigned after any
        // skip, so it always addresses the entry omarchy-clipboard-open reads.
        entry.insert("index", i);
        entries.append(entry);
    }
    return entries;
}

void Backend::reload() {
    // Re-arm the watcher: Omarchy replaces the file when it rewrites the
    // history, which drops the path from the watch, and the first copy creates
    // it, so watch the directory too.
    const QStringList watched = m_watcher.files() + m_watcher.directories();
    if (!watched.isEmpty())
        m_watcher.removePaths(watched);
    const QString directory = QFileInfo(m_historyPath).absolutePath();
    if (QFileInfo::exists(directory))
        m_watcher.addPath(directory);
    if (QFileInfo::exists(m_historyPath))
        m_watcher.addPath(m_historyPath);

    QFile file(m_historyPath);
    if (!file.open(QIODevice::ReadOnly)) {
        m_available = false;
        m_entries.clear();
        emit entriesChanged();
        return;
    }

    QString error;
    const QVariantList parsed = parse(file.readAll(), &error);
    m_available = true;
    m_entries = parsed;
    emit entriesChanged();
    if (!error.isEmpty())
        emit failed(tr("Could not read the clipboard history"));
}

bool Backend::copyEntry(int index) {
    if (index < 0 || index >= m_entries.size()) {
        emit failed(tr("No such clipboard entry"));
        return false;
    }

    const QVariantMap entry = m_entries.at(index).toMap();
    const QString type = entry.value("type").toString();

    QStringList arguments;
    QByteArray payload;
    if (type == QLatin1String("text")) {
        payload = entry.value("text").toString().toUtf8();
    } else if (type == QLatin1String("image")) {
        const QString path = entry.value("path").toString();
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            emit failed(tr("Could not read %1").arg(path));
            return false;
        }
        payload = file.readAll();
        arguments << "--type" << entry.value("mime").toString();
    } else {
        emit failed(tr("Unsupported entry"));
        return false;
    }

    const QString wlCopy = QStandardPaths::findExecutable("wl-copy");
    if (wlCopy.isEmpty()) {
        emit failed(tr("wl-copy is not installed"));
        return false;
    }

    QProcess process;
    process.start(wlCopy, arguments);
    if (!process.waitForStarted(2000)) {
        emit failed(tr("Could not start wl-copy"));
        return false;
    }
    process.write(payload);
    process.closeWriteChannel();
    if (!process.waitForFinished(5000) || process.exitStatus() != QProcess::NormalExit
        || process.exitCode() != 0) {
        emit failed(tr("wl-copy failed"));
        return false;
    }

    emit copied(index);
    return true;
}

// Hands the entry to Omarchy's own opener, so a URL opens in the browser, text
// opens in the editor, and an image opens in the snapshot viewer.
bool Backend::openEntry(int index) {
    if (index < 0 || index >= m_entries.size()) {
        emit failed(tr("No such clipboard entry"));
        return false;
    }

    const QString opener = QStandardPaths::findExecutable("omarchy-clipboard-open");
    if (opener.isEmpty()) {
        emit failed(tr("omarchy-clipboard-open is not available"));
        return false;
    }

    if (!QProcess::startDetached(opener, {"--history-index", QString::number(index)})) {
        emit failed(tr("Could not open the entry"));
        return false;
    }

    emit opened(index);
    return true;
}
