#include "displaymanager.h"
#include "profilemanager.h"
#include "streamingpreferences.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QGuiApplication>
#include <QProcess>
#include <QScreen>
#include <QWindow>
#include <QSettings>
#include <QTimer>
#include <QUuid>
#include <QtMath>

DisplayManager::DisplayManager(QObject* parent)
    : QObject(parent)
{
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

bool DisplayManager::isMonitorConnected(const QString& key) const
{
    return findScreen(key) != nullptr;
}

QString DisplayManager::monitorName(const QString& key) const
{
    QScreen* screen = findScreen(key);
    return screen ? monitorLabel(screen) : QString();
}

void DisplayManager::setCurrentWindow(QWindow* window)
{
    m_CurrentMonitor = window ? monitorKey(window->screen()) : QString();
}

QStringList DisplayManager::buildArguments(const QVariantMap& profile, QScreen* screen,
                                           const QString& hostUuid, const QString& appName) const
{
    QStringList args;
    args << "stream" << hostUuid << appName;
    args << "--profile" << profile["id"].toString();
    // Pin a Current monitor launch to the hub's current display. The child's
    // --monitor override stays process-local and never rewrites the profile.
    args << "--monitor" << monitorKey(screen);

    return args;
}

QString DisplayManager::launch(const QString& profileId, const QString& hostUuid,
                               const QString& hostName, const QString& appName)
{
    StreamingPreferences::get()->save();
    const QVariantMap profile = ProfileManager::savedProfile(profileId);
    if (profile.isEmpty() || hostUuid.isEmpty() || appName.isEmpty()) {
        return QString();
    }

    const QString target = profile["monitorKey"].toString();
    QScreen* screen = findScreen(target.isEmpty() ? m_CurrentMonitor : target);
    if (target.isEmpty() && screen == nullptr) {
        screen = QGuiApplication::primaryScreen();
    }
    if (screen == nullptr) {
        emit launchFailed(tr("The monitor for \"%1\" isn't connected.").arg(profile["name"].toString()));
        return QString();
    }

    QSettings settings;
    settings.beginGroup(QStringLiteral("norilightprofiles/%1").arg(profileId));
    settings.setValue("lastHostUuid", hostUuid);
    settings.setValue("lastHostName", hostName);
    settings.setValue("lastAppName", appName);
    settings.sync();

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

    StreamingPreferences::get()->save();
    process->start(QCoreApplication::applicationFilePath(),
                   buildArguments(profile, screen, hostUuid, appName));

    return sessionId;
}

QString DisplayManager::launchLast(const QString& profileId)
{
    QVariantMap p = ProfileManager::savedProfile(profileId);
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
