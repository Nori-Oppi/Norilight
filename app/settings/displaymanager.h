#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class QProcess;
class QScreen;
class QWindow;

// Launches complete settings profiles in separate stream processes and tracks
// their sessions. All profile data belongs to ProfileManager.
class DisplayManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList monitors READ monitors NOTIFY monitorsChanged)
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY sessionsChanged)
    Q_PROPERTY(int runningCount READ runningCount NOTIFY sessionsChanged)

public:
    explicit DisplayManager(QObject* parent = nullptr);
    ~DisplayManager() override;

    // A key that identifies a physical monitor across runs and processes.
    // Uses the EDID manufacturer/model/serial when the monitor reports a
    // serial, otherwise the OS name for the output it is plugged into.
    static QString monitorKey(QScreen* screen);
    static QScreen* findScreen(const QString& key);

    QVariantList monitors() const;
    QVariantList sessions() const;
    int runningCount() const;

    Q_INVOKABLE bool isMonitorConnected(const QString& key) const;
    Q_INVOKABLE QString monitorName(const QString& key) const;
    Q_INVOKABLE void setCurrentWindow(QWindow* window);

    // Starts a stream of appName on hostUuid using the given profile.
    // hostName is only used for display in the hub. Returns the session id,
    // or an empty string if the profile is unknown or its monitor is missing.
    Q_INVOKABLE QString launch(const QString& profileId, const QString& hostUuid,
                               const QString& hostName, const QString& appName);
    // Starts the profile's last app again
    Q_INVOKABLE QString launchLast(const QString& profileId);
    Q_INVOKABLE void relaunch(const QString& sessionId);
    Q_INVOKABLE void stopSession(const QString& sessionId);
    Q_INVOKABLE void dismissSession(const QString& sessionId);
    Q_INVOKABLE void stopAll();

signals:
    void monitorsChanged();
    void sessionsChanged();
    void launchFailed(QString message);

private:
    struct HubSession {
        QString id;
        QString profileId;
        QString profileName;
        QString monitorLabel;
        QString hostUuid;
        QString hostName;
        QString appName;
        QProcess* process = nullptr;
        bool running = false;
        bool stopRequested = false;
        int exitCode = 0;
        bool crashed = false;
        qint64 startedAt = 0;
    };

    int indexOfSession(const QString& id) const;
    QStringList buildArguments(const QVariantMap& profile, QScreen* screen,
                               const QString& hostUuid, const QString& appName) const;
    static QString monitorLabel(QScreen* screen);
    void watchScreen(QScreen* screen);

    QString m_CurrentMonitor;
    friend class ProfilesTest;
    QVector<HubSession> m_Sessions;
};
