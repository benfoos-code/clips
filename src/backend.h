#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantList>

// Reads Omarchy's clipboard history
// (~/.local/state/omarchy/clipboard-history.json, newest first) and copies an
// entry back to the clipboard. Read-only: the Omarchy shell owns the file, so
// the app never writes to it.
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY entriesChanged)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(QString historyPath READ historyPath CONSTANT)
    Q_PROPERTY(bool available READ available NOTIFY entriesChanged)

public:
    explicit Backend(const QString &historyPath = {}, QObject *parent = nullptr);

    int count() const { return m_entries.size(); }
    QVariantList entries() const { return m_entries; }
    QString historyPath() const { return m_historyPath; }
    bool available() const { return m_available; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE bool copyEntry(int index);
    Q_INVOKABLE bool openEntry(int index);

    static QVariantList parse(const QByteArray &json, QString *error = nullptr);
    static QString preview(const QString &text);

signals:
    void entriesChanged();
    void copied(int index);
    void opened(int index);
    void failed(const QString &message);

private:
    QString m_historyPath;
    QVariantList m_entries;
    bool m_available = false;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
