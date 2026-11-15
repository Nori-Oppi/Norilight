#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QCryptographicHash>
#include <QFile>
#include <QPointer>

class QNetworkReply;

// Norilight: checks the rolling "nightly" GitHub pre-release and reports when
// it was built from a different commit than the running build. It can also
// download that build and install it in place:
//
//  - Windows, installed: runs the new Setup.exe silently. The installer
//    replaces the files once Norilight has closed and starts it again.
//  - Windows, portable (ZIP): a helper script waits for Norilight to close,
//    copies the new files over the old ones (keeping settings) and restarts it.
//  - macOS: a helper script waits for Norilight to close, copies the new app
//    bundle from the DMG over the old one and opens it.
//
// Every download is checked against the SHA-256 digest GitHub publishes for it.
class AutoUpdateChecker : public QObject
{
    Q_OBJECT

    // True when the update can be installed from inside the app; otherwise
    // the download link opens in the browser
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY updateInfoChanged)
    // The Windows installer asks for administrator permission
    Q_PROPERTY(bool needsPermission READ needsPermission NOTIFY updateInfoChanged)
    Q_PROPERTY(QString downloadUrl READ downloadUrl NOTIFY updateInfoChanged)
    Q_PROPERTY(QString releaseUrl READ releaseUrl CONSTANT)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit AutoUpdateChecker(QObject *parent = nullptr);

    Q_INVOKABLE void start();

    // Downloads the update found by start() and hands it to the installer.
    // Emits downloadProgress, then either installerStarted (quit now) or
    // installFailed.
    Q_INVOKABLE void installUpdate();
    Q_INVOKABLE void cancelInstall();

    bool canInstall() const;
    bool needsPermission() const { return canInstall() && m_Kind == InstallKind::WindowsInstaller; }
    QString downloadUrl() const { return m_AssetUrl.isEmpty() ? releaseUrl() : m_AssetUrl; }
    QString releaseUrl() const;
    bool busy() const { return m_Download != nullptr; }

signals:
    void onUpdateAvailable(QString newVersion, QString url);
    void updateInfoChanged();
    void busyChanged();
    void downloadProgress(qint64 received, qint64 total);
    // The installer or helper has started and is waiting for Norilight to quit
    void installerStarted();
    void installFailed(QString message);

private slots:
    void handleUpdateCheckRequestFinished(QNetworkReply* reply);
    void handleDownloadReadyRead();
    void handleDownloadFinished();

private:
    enum class InstallKind {
        None,
        WindowsInstaller,
        WindowsPortable,
        MacDmg,
    };

    static InstallKind detectInstallKind();
    bool launchInstaller(QString& error);
    void failInstall(const QString& message);
    void finishDownload();

    QString m_BuildSha;
    QNetworkAccessManager* m_Nam;
    InstallKind m_Kind;

    // The asset that matches this installation
    QString m_AssetUrl;
    QString m_AssetName;
    qint64 m_AssetSize;
    QByteArray m_AssetSha256;

    QPointer<QNetworkReply> m_Download;
    QFile m_DownloadFile;
    QCryptographicHash m_DownloadHash;
};
