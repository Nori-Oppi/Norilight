#include "settingsreset.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QProcessEnvironment>
#include <QSettings>
#include <QStandardPaths>
#include <QThread>

#ifdef Q_OS_WIN32
#include <Windows.h>
#else
#include <signal.h>
#include <sys/types.h>
#endif

// The Norilight that asked for the reset; the new one waits for it to exit,
// so nothing it saves while quitting lands in the fresh settings
#define RESET_WAIT_PID_ENV "NORILIGHT_RESET_WAIT_PID"

namespace {
    QString backupSuffix()
    {
        return QStringLiteral("-backup-") + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss"));
    }

    void setError(QString* error, const QString& message)
    {
        if (error != nullptr) {
            *error = message;
        }
    }

    // Settings in a file of their own folder (portable mode's
    // <folder>\Norilight\Norilight.ini, Linux's ~/.config/Norilight/Norilight.conf):
    // the folder is renamed to "Norilight-backup-<time>" next to it
    QString moveFolder(const QString& settingsFile, QString* error)
    {
        QFileInfo file(settingsFile);
        if (!file.exists()) {
            setError(error, QStringLiteral("No settings at %1").arg(QDir::toNativeSeparators(settingsFile)));
            return {};
        }

        QString folder = file.absolutePath();
        QString target = folder + backupSuffix();
        if (!QDir().rename(folder, target)) {
            setError(error, QStringLiteral("Couldn't move %1 to %2").arg(QDir::toNativeSeparators(folder),
                                                                          QDir::toNativeSeparators(target)));
            return {};
        }
        return QDir::toNativeSeparators(target);
    }

#ifdef Q_OS_WIN32
    // Registry (installed Norilight): HKCU\Software\Norilight\Norilight is
    // copied to the sibling key "Norilight-backup-<time>", then removed
    QString moveRegistryKey(QString* error)
    {
        const QString parentPath = QStringLiteral("Software\\") + QCoreApplication::organizationName();
        const QString app = QCoreApplication::applicationName();
        const QString backupName = app + backupSuffix();
        auto w = [](const QString& s) { return reinterpret_cast<LPCWSTR>(s.utf16()); };

        HKEY parent;
        if (RegOpenKeyExW(HKEY_CURRENT_USER, w(parentPath), 0, KEY_ALL_ACCESS, &parent) != ERROR_SUCCESS) {
            setError(error, QStringLiteral("No settings in HKCU\\%1").arg(parentPath));
            return {};
        }

        QString result;
        HKEY source;
        if (RegOpenKeyExW(parent, w(app), 0, KEY_READ, &source) != ERROR_SUCCESS) {
            setError(error, QStringLiteral("No settings in HKCU\\%1\\%2").arg(parentPath, app));
        }
        else {
            HKEY backup;
            if (RegCreateKeyExW(parent, w(backupName), 0, nullptr, 0, KEY_ALL_ACCESS, nullptr,
                                &backup, nullptr) != ERROR_SUCCESS) {
                setError(error, QStringLiteral("Couldn't create HKCU\\%1\\%2").arg(parentPath, backupName));
            }
            else {
                LSTATUS copied = RegCopyTreeW(source, nullptr, backup);
                RegCloseKey(backup);
                if (copied == ERROR_SUCCESS) {
                    result = QStringLiteral("HKCU\\%1\\%2").arg(parentPath, backupName);
                }
                else {
                    // Leave the settings as they were
                    RegDeleteTreeW(parent, w(backupName));
                    RegDeleteKeyW(parent, w(backupName));
                    setError(error, QStringLiteral("Couldn't copy the settings (error %1)").arg(copied));
                }
            }
            RegCloseKey(source);

            if (!result.isEmpty()) {
                RegDeleteTreeW(parent, w(app));
                RegDeleteKeyW(parent, w(app));
            }
        }
        RegCloseKey(parent);
        return result;
    }
#endif

#ifdef Q_OS_DARWIN
    // macOS's preferences: every value is copied to
    // ~/Library/Preferences/Norilight-backup-<time>/Norilight.ini, then cleared
    QString copyAndClear(QSettings& settings, QString* error)
    {
        const QStringList keys = settings.allKeys();
        if (keys.isEmpty()) {
            setError(error, QStringLiteral("No settings to reset"));
            return {};
        }

        QString base = QFileInfo(settings.fileName()).absolutePath();
        if (base.isEmpty() || !QFileInfo(base).isDir()) {
            base = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
        }
        QString folder = QDir(base).filePath(QCoreApplication::applicationName() + backupSuffix());
        if (!QDir().mkpath(folder)) {
            setError(error, QStringLiteral("Couldn't create %1").arg(folder));
            return {};
        }

        {
            QSettings backup(QDir(folder).filePath(QCoreApplication::applicationName() + QStringLiteral(".ini")),
                             QSettings::IniFormat);
            for (const QString& key : keys) {
                backup.setValue(key, settings.value(key));
            }
            backup.sync();
            if (backup.status() != QSettings::NoError) {
                setError(error, QStringLiteral("Couldn't write the backup in %1").arg(folder));
                return {};
            }
        }

        settings.clear();
        settings.sync();
        return folder;
    }
#endif

    void waitForProcess(qint64 pid)
    {
        if (pid <= 0) {
            return;
        }
#ifdef Q_OS_WIN32
        HANDLE process = OpenProcess(SYNCHRONIZE, FALSE, static_cast<DWORD>(pid));
        if (process != nullptr) {
            WaitForSingleObject(process, 30000);
            CloseHandle(process);
        }
#else
        for (int i = 0; i < 300 && kill(static_cast<pid_t>(pid), 0) == 0; i++) {
            QThread::msleep(100);
        }
#endif
    }
}

QString SettingsReset::moveToBackup(QString* error)
{
    QSettings settings;
    settings.sync();

    if (settings.format() == QSettings::IniFormat) {
        return moveFolder(settings.fileName(), error);
    }
#if defined(Q_OS_WIN32)
    return moveRegistryKey(error);
#elif defined(Q_OS_DARWIN)
    return copyAndClear(settings, error);
#else
    return moveFolder(settings.fileName(), error);
#endif
}

bool SettingsReset::handleCommandLine(int argc, char* argv[], QString* message)
{
    bool requested = false;
    for (int i = 1; i < argc; i++) {
        QString arg = QString::fromLocal8Bit(argv[i]);
        if (arg == QStringLiteral("--reset") || arg == QStringLiteral("-reset")) {
            requested = true;
        }
    }
    if (!requested) {
        return false;
    }

    waitForProcess(qEnvironmentVariableIntValue(RESET_WAIT_PID_ENV));
    qunsetenv(RESET_WAIT_PID_ENV);

    QString backup = moveToBackup(message);
    if (!backup.isEmpty()) {
        setError(message, QStringLiteral("Settings moved to %1").arg(backup));
    }
    return true;
}

bool SettingsReset::restartIntoReset()
{
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral(RESET_WAIT_PID_ENV), QString::number(QCoreApplication::applicationPid()));

    QProcess process;
    process.setProgram(QCoreApplication::applicationFilePath());
    process.setArguments({QStringLiteral("--reset")});
    // Portable mode is found by portable.dat in the working folder
    process.setWorkingDirectory(QDir::currentPath());
    process.setProcessEnvironment(env);
    return process.startDetached();
}
