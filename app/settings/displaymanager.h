#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class QProcess;
class QScreen;

// Norilight: the display manager.
//
// Holds per-monitor stream profiles (resolution, frame rate, window mode and
// picture options tied to one physical monitor) and launches each profile as
// its own Norilight stream process ("Norilight stream <host> <app> --monitor
// ..."). The main window stays open and acts as a hub that lists the running
// sessions and can stop or relaunch them, so several streams can run at once.
class DisplayManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList monitors READ monitors NOTIFY monitorsChanged)
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY profilesChanged)
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
    QVariantList profiles() const;
    QVariantList sessions() const;
    int runningCount() const;

    // Inserts the profile, or updates the one with the same "id". Returns its id.
    Q_INVOKABLE QString saveProfile(const QVariantMap& profile);
    Q_INVOKABLE void removeProfile(const QString& id);
    Q_INVOKABLE QVariantMap profile(const QString& id) const;
    Q_INVOKABLE bool isMonitorConnected(const QString& key) const;

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
    void profilesChanged();
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

    void loadProfiles();
    void storeProfiles();
    int indexOfProfile(const QString& id) const;
    int indexOfSession(const QString& id) const;
    QStringList buildArguments(const QVariantMap& profile, QScreen* screen,
                               const QString& hostUuid, const QString& appName) const;
    static QString monitorLabel(QScreen* screen);
    void watchScreen(QScreen* screen);

    QVector<QVariantMap> m_Profiles;
    QVector<HubSession> m_Sessions;
};
