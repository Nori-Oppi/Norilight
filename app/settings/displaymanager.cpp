#include "displaymanager.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QGuiApplication>
#include <QProcess>
#include <QScreen>
#include <QSettings>
#include <QTimer>
#include <QUuid>
#include <QtMath>

#define SER_DISPLAYPROFILES "displayprofiles"

// Profile fields as stored in QSettings and handed to QML
static const char* const kProfileKeys[] = {
    "id", "name", "monitorKey", "monitorLabel",
    "width", "height", "fps", "windowMode", "vsync", "framePacing",
    "videoScaleMode", "bitrateKbps",
    "lastHostUuid", "lastHostName", "lastAppName",
};

DisplayManager::DisplayManager(QObject* parent)
    : QObject(parent)
{
    loadProfiles();

    // A profile's "connected" flag follows its monitor
    connect(this, &DisplayManager::monitorsChanged, this, &DisplayManager::profilesChanged);

    if (auto* app = qobject_cast<QGuiApplication*>(QCoreApplication::instance())) {
        connect(app, &QGuiApplication::screenAdded, this, [this](QScreen* screen) {
            watchScreen(screen);
            emit monitorsChanged();
        });
        connect(app, &QGuiApplication::screenRemoved, this, &DisplayManager::monitorsChanged);
        connect(app, &QGuiApplication::primaryScreenChanged, this, &DisplayManager::monitorsChanged);

        for (QScreen* screen : QGuiApplication::screens()) {
            watchScreen(screen);
        }
    }
}

DisplayManager::~DisplayManager()
{
    // Closing the hub ends the streams it started. Ask each one to close
    // normally first so the host sees a clean disconnect.
    for (HubSession& s : m_Sessions) {
        if (s.process != nullptr && s.running) {
            s.process->disconnect(this);
            s.process->terminate();
        }
    }
    for (HubSession& s : m_Sessions) {
        if (s.process != nullptr && s.running) {
            if (!s.process->waitForFinished(3000)) {
                s.process->kill();
                s.process->waitForFinished(1000);
            }
        }
    }
}

void DisplayManager::watchScreen(QScreen* screen)
{
    connect(screen, &QScreen::geometryChanged, this, &DisplayManager::monitorsChanged);
    connect(screen, &QScreen::refreshRateChanged, this, &DisplayManager::monitorsChanged);
}

QString DisplayManager::monitorKey(QScreen* screen)
{
    if (screen == nullptr) {
        return QString();
    }

    if (!screen->serialNumber().isEmpty()) {
        return QStringLiteral("edid:%1|%2|%3").arg(screen->manufacturer(),
                                                   screen->model(),
                                                   screen->serialNumber());
    }

    return QStringLiteral("name:") + screen->name();
}

QScreen* DisplayManager::findScreen(const QString& key)
{
    if (key.isEmpty()) {
        return nullptr;
    }

    for (QScreen* screen : QGuiApplication::screens()) {
        if (monitorKey(screen) == key) {
            return screen;
        }
    }

    return nullptr;
}

QString DisplayManager::monitorLabel(QScreen* screen)
{
    QString model = screen->model().trimmed();
    QString manufacturer = screen->manufacturer().trimmed();

    QString label;
    if (!model.isEmpty()) {
        label = model.startsWith(manufacturer, Qt::CaseInsensitive) || manufacturer.isEmpty() ?
                    model : manufacturer + " " + model;
    }
    else {
        label = screen->name();
    }

    return label;
}

QVariantList DisplayManager::monitors() const
{
    QVariantList list;
    const QList<QScreen*> screens = QGuiApplication::screens();

    for (int i = 0; i < screens.size(); i++) {
        QScreen* screen = screens[i];
        qreal dpr = screen->devicePixelRatio();
        QRect geometry = screen->geometry();

        QVariantMap m;
        m["key"] = monitorKey(screen);
        m["number"] = i + 1;
        m["label"] = monitorLabel(screen);
        m["primary"] = screen == QGuiApplication::primaryScreen();
        m["width"] = qRound(geometry.width() * dpr);
        m["height"] = qRound(geometry.height() * dpr);
        m["refreshRate"] = qRound(screen->refreshRate());
        m["x"] = geometry.x();
        m["y"] = geometry.y();
        list.append(m);
    }

    return list;
}

void DisplayManager::loadProfiles()
{
    QSettings settings;
    int count = settings.beginReadArray(SER_DISPLAYPROFILES);
    for (int i = 0; i < count; i++) {
        settings.setArrayIndex(i);
        QVariantMap p;
        for (const char* key : kProfileKeys) {
            p[key] = settings.value(key);
        }
        if (!p["id"].toString().isEmpty()) {
            m_Profiles.append(p);
        }
    }
    settings.endArray();
}

void DisplayManager::storeProfiles()
{
    QSettings settings;
    settings.remove(SER_DISPLAYPROFILES);
    settings.beginWriteArray(SER_DISPLAYPROFILES, m_Profiles.size());
    for (int i = 0; i < m_Profiles.size(); i++) {
        settings.setArrayIndex(i);
        for (const char* key : kProfileKeys) {
            settings.setValue(key, m_Profiles[i].value(key));
        }
    }
    settings.endArray();
}

QVariantList DisplayManager::profiles() const
{
    QVariantList list;
    for (const QVariantMap& p : m_Profiles) {
        QVariantMap copy = p;
        copy["connected"] = findScreen(p["monitorKey"].toString()) != nullptr;
        list.append(copy);
    }
    return list;
}

int DisplayManager::indexOfProfile(const QString& id) const
{
    for (int i = 0; i < m_Profiles.size(); i++) {
        if (m_Profiles[i]["id"].toString() == id) {
            return i;
        }
    }
    return -1;
}

QString DisplayManager::saveProfile(const QVariantMap& profile)
{
    QVariantMap p;
    for (const char* key : kProfileKeys) {
        if (profile.contains(key)) {
            p[key] = profile.value(key);
        }
    }

    // Cache the monitor's name so the profile still reads well while unplugged
    if (QScreen* screen = findScreen(p["monitorKey"].toString())) {
        p["monitorLabel"] = monitorLabel(screen);
    }

    QString id = p["id"].toString();
    int index = id.isEmpty() ? -1 : indexOfProfile(id);
    if (index < 0) {
        if (id.isEmpty()) {
            id = QUuid::createUuid().toString(QUuid::WithoutBraces);
            p["id"] = id;
        }
        m_Profiles.append(p);
    }
    else {
        // Keep fields the caller didn't send (like the last launched app)
        QVariantMap merged = m_Profiles[index];
        for (auto it = p.constBegin(); it != p.constEnd(); ++it) {
            merged[it.key()] = it.value();
        }
        m_Profiles[index] = merged;
    }

    storeProfiles();
    emit profilesChanged();
    return id;
}

void DisplayManager::removeProfile(const QString& id)
{
    int index = indexOfProfile(id);
    if (index >= 0) {
        m_Profiles.removeAt(index);
        storeProfiles();
        emit profilesChanged();
    }
}

QVariantMap DisplayManager::profile(const QString& id) const
{
    int index = indexOfProfile(id);
    return index >= 0 ? m_Profiles[index] : QVariantMap();
}

bool DisplayManager::isMonitorConnected(const QString& key) const
{
    return findScreen(key) != nullptr;
}

QStringList DisplayManager::buildArguments(const QVariantMap& profile, QScreen* screen,
                                           const QString& hostUuid, const QString& appName) const
{
    QStringList args;
    args << "stream" << hostUuid << appName;
    args << "--monitor" << monitorKey(screen);

    // 0 means "match the monitor"
    int width = profile["width"].toInt();
    int height = profile["height"].toInt();
    if (width <= 0 || height <= 0) {
        qreal dpr = screen->devicePixelRatio();
        width = qRound(screen->geometry().width() * dpr) & ~1;
        height = qRound(screen->geometry().height() * dpr) & ~1;
    }
    args << "--resolution" << QStringLiteral("%1x%2").arg(width).arg(height);

    int fps = profile["fps"].toInt();
    if (fps <= 0) {
        fps = qRound(screen->refreshRate());
    }
    args << "--fps" << QString::number(qBound(10, fps, 480));

    static const char* const windowModes[] = { "fullscreen", "borderless", "windowed" };
    int windowMode = qBound(0, profile["windowMode"].toInt(), 2);
    args << "--display-mode" << windowModes[windowMode];

    args << (profile["vsync"].toBool() ? "--vsync" : "--no-vsync");
    args << (profile["framePacing"].toBool() ? "--frame-pacing" : "--no-frame-pacing");

    static const char* const scaleModes[] = { "fit", "fill", "stretch" };
    args << "--picture-fit" << scaleModes[qBound(0, profile["videoScaleMode"].toInt(), 2)];

    // Without --bitrate the stream command picks the recommended bitrate for
    // the resolution and frame rate above
    int bitrate = profile["bitrateKbps"].toInt();
    if (bitrate > 0) {
        args << "--bitrate" << QString::number(qBound(500, bitrate, 500000));
    }

    return args;
}

QString DisplayManager::launch(const QString& profileId, const QString& hostUuid,
                               const QString& hostName, const QString& appName)
{
    int profileIndex = indexOfProfile(profileId);
    if (profileIndex < 0 || hostUuid.isEmpty() || appName.isEmpty()) {
        return QString();
    }

    QVariantMap& profile = m_Profiles[profileIndex];
    QScreen* screen = findScreen(profile["monitorKey"].toString());
    if (screen == nullptr) {
        emit launchFailed(tr("The monitor for \"%1\" isn't connected.").arg(profile["name"].toString()));
        return QString();
    }

    // Remember what this profile streamed last, for one-click relaunch
    profile["lastHostUuid"] = hostUuid;
    profile["lastHostName"] = hostName;
    profile["lastAppName"] = appName;
    profile["monitorLabel"] = monitorLabel(screen);
    storeProfiles();
    emit profilesChanged();

    HubSession s;
    s.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    s.profileId = profileId;
    s.profileName = profile["name"].toString();
    s.monitorLabel = monitorLabel(screen);
    s.hostUuid = hostUuid;
    s.hostName = hostName;
    s.appName = appName;
    s.startedAt = QDateTime::currentMSecsSinceEpoch();
    s.running = true;

    auto* process = new QProcess(this);
    s.process = process;

    // Nobody reads the child's output; don't let a full pipe stall it
    process->setStandardOutputFile(QProcess::nullDevice());
    process->setStandardErrorFile(QProcess::nullDevice());

    QString sessionId = s.id;
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this, sessionId](int exitCode, QProcess::ExitStatus status) {
        int i = indexOfSession(sessionId);
        if (i < 0) {
            return;
        }
        HubSession& s = m_Sessions[i];
        s.running = false;
        s.exitCode = exitCode;
        s.crashed = status == QProcess::CrashExit && !s.stopRequested;
        s.process->deleteLater();
        s.process = nullptr;
        emit sessionsChanged();
    });
    connect(process, &QProcess::errorOccurred, this, [this, sessionId](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart) {
            return;
        }
        int i = indexOfSession(sessionId);
        if (i < 0) {
            return;
        }
        HubSession& s = m_Sessions[i];
        s.running = false;
        s.crashed = true;
        s.process->deleteLater();
        s.process = nullptr;
        emit sessionsChanged();
        emit launchFailed(tr("Norilight couldn't start a new stream window."));
    });

    m_Sessions.append(s);
    emit sessionsChanged();

    process->start(QCoreApplication::applicationFilePath(),
                   buildArguments(profile, screen, hostUuid, appName));

    return sessionId;
}

QString DisplayManager::launchLast(const QString& profileId)
{
    QVariantMap p = profile(profileId);
    return launch(profileId, p["lastHostUuid"].toString(),
                  p["lastHostName"].toString(), p["lastAppName"].toString());
}

int DisplayManager::indexOfSession(const QString& id) const
{
    for (int i = 0; i < m_Sessions.size(); i++) {
        if (m_Sessions[i].id == id) {
            return i;
        }
    }
    return -1;
}

QVariantList DisplayManager::sessions() const
{
    QVariantList list;
    for (const HubSession& s : m_Sessions) {
        QVariantMap m;
        m["id"] = s.id;
        m["profileId"] = s.profileId;
        m["profileName"] = s.profileName;
        m["monitorLabel"] = s.monitorLabel;
        m["hostName"] = s.hostName;
        m["appName"] = s.appName;
        m["running"] = s.running;
        m["stopping"] = s.running && s.stopRequested;
        m["failed"] = !s.running && (s.crashed || (s.exitCode != 0 && !s.stopRequested));
        m["startedAt"] = s.startedAt;
        list.append(m);
    }
    return list;
}

int DisplayManager::runningCount() const
{
    int count = 0;
    for (const HubSession& s : m_Sessions) {
        if (s.running) {
            count++;
        }
    }
    return count;
}

void DisplayManager::relaunch(const QString& sessionId)
{
    int i = indexOfSession(sessionId);
    if (i < 0 || m_Sessions[i].running) {
        return;
    }

    HubSession old = m_Sessions[i];
    m_Sessions.removeAt(i);
    emit sessionsChanged();

    launch(old.profileId, old.hostUuid, old.hostName, old.appName);
}

void DisplayManager::stopSession(const QString& sessionId)
{
    int i = indexOfSession(sessionId);
    if (i < 0 || !m_Sessions[i].running || m_Sessions[i].process == nullptr) {
        return;
    }

    HubSession& s = m_Sessions[i];
    s.stopRequested = true;
    emit sessionsChanged();

    // Closing the stream window ends the stream and the process with it.
    // If it hasn't gone away after a few seconds, end it forcefully.
    QProcess* process = s.process;
    process->terminate();
    QTimer::singleShot(5000, process, [process]() {
        if (process->state() != QProcess::NotRunning) {
            process->kill();
        }
    });
}

void DisplayManager::dismissSession(const QString& sessionId)
{
    int i = indexOfSession(sessionId);
    if (i >= 0 && !m_Sessions[i].running) {
        m_Sessions.removeAt(i);
        emit sessionsChanged();
    }
}

void DisplayManager::stopAll()
{
    QStringList ids;
    for (const HubSession& s : m_Sessions) {
        if (s.running) {
            ids.append(s.id);
        }
    }
    for (const QString& id : ids) {
        stopSession(id);
    }
}
