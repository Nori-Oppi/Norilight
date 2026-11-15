#include "profilemanager.h"
#include "streamingpreferences.h"

#include <QGuiApplication>
#include <QScreen>
#include <QSettings>
#include <QUuid>
#include <QtDebug>

#define SER_PROFILES "norilightprofiles"
#define SER_PROFILE_IDS SER_PROFILES "/ids"
#define SER_PROFILE_ACTIVE SER_PROFILES "/active"

// Written by every save of the settings, so it tells us settings exist
#define SER_SETTINGS_MARKER "defaultver"

namespace {
    // The active profile of this process. It is read from the settings once
    // and then kept here, so another Norilight process switching profiles
    // can't redirect where this one saves its settings.
    bool s_ActiveLoaded = false;
    QString s_ActiveId;

    QStringList storedIds()
    {
        return QSettings().value(SER_PROFILE_IDS).toStringList();
    }

    QString profileKey(const QString& id, const char* field)
    {
        return QStringLiteral(SER_PROFILES "/%1/%2").arg(id, QString::fromLatin1(field));
    }

    QString storedName(const QString& id)
    {
        return QSettings().value(profileKey(id, "name")).toString();
    }

    const QString& currentId()
    {
        if (!s_ActiveLoaded) {
            QStringList ids = storedIds();
            s_ActiveId = QSettings().value(SER_PROFILE_ACTIVE).toString();
            if (!ids.contains(s_ActiveId)) {
                s_ActiveId = ids.isEmpty() ? QString() : ids.first();
            }
            s_ActiveLoaded = true;
        }
        return s_ActiveId;
    }

    void setCurrentId(const QString& id)
    {
        s_ActiveId = id;
        s_ActiveLoaded = true;
        QSettings().setValue(SER_PROFILE_ACTIVE, id);
    }

    QSettings* openMoonlightSettings()
    {
#ifdef Q_OS_DARWIN
        // macOS names the preferences file after the organization's domain
        return new QSettings("moonlight-stream.com", "Moonlight");
#else
        return new QSettings("Moonlight Game Streaming Project", "Moonlight");
#endif
    }

    void applyPreset(StreamingPreferences* prefs, const QString& kind)
    {
        if (kind == "gaming") {
            // Lowest latency: exclusive fullscreen at the display's full
            // refresh rate, nothing waiting on V-Sync, mouse locked to the game
            int refreshRate = 60;
            if (QScreen* screen = QGuiApplication::primaryScreen()) {
                refreshRate = qBound(60, qRound(screen->refreshRate()), 240);
            }
            prefs->fps = refreshRate;
            prefs->windowMode = prefs->recommendedFullScreenMode;
            prefs->enableVsync = false;
            prefs->framePacing = false;
            prefs->gameOptimizations = true;
            prefs->absoluteMouseMode = false;
            prefs->freeCursorMode = false;
            prefs->captureSysKeysMode = StreamingPreferences::CSK_FULLSCREEN;
        }
        else if (kind == "work") {
            // Desktop use: a borderless window the cursor can leave freely,
            // a steady 60 FPS, and the host's own desktop settings left alone
            prefs->fps = 60;
            prefs->windowMode = StreamingPreferences::WM_FULLSCREEN_DESKTOP;
            prefs->enableVsync = true;
            prefs->framePacing = false;
            prefs->gameOptimizations = false;
            prefs->absoluteMouseMode = true;
            prefs->freeCursorMode = true;
            prefs->captureSysKeysMode = StreamingPreferences::CSK_FULLSCREEN;
        }
        else {
            return;
        }

        prefs->bitrateKbps = StreamingPreferences::getDefaultBitrate(prefs->width, prefs->height,
                                                                     prefs->fps, prefs->enableYUV444);
    }
}

ProfileManager::ProfileManager(StreamingPreferences* prefs, QObject* parent)
    : QObject(parent),
      m_Prefs(prefs)
{
}

QString ProfileManager::settingsGroup()
{
    const QString& id = currentId();
    return id.isEmpty() ? QString() : QStringLiteral(SER_PROFILES "/%1/settings").arg(id);
}

void ProfileManager::setLaunchProfile(const QString& nameOrId)
{
    const QStringList ids = storedIds();
    for (const QString& id : ids) {
        if (id == nameOrId || storedName(id).compare(nameOrId, Qt::CaseInsensitive) == 0) {
            s_ActiveId = id;
            s_ActiveLoaded = true;
            return;
        }
    }

    qWarning() << "No profile named" << nameOrId << "- using the active profile";
}

void ProfileManager::rememberLaunchProfile()
{
    if (!currentId().isEmpty()) {
        QSettings().setValue(SER_PROFILE_ACTIVE, currentId());
    }
}

QVariantList ProfileManager::profiles() const
{
    QVariantList list;
    const QStringList ids = storedIds();
    for (const QString& id : ids) {
        QVariantMap p;
        p["id"] = id;
        p["name"] = storedName(id);
        p["kind"] = kindOf(id);
        p["active"] = id == currentId();
        list.append(p);
    }
    return list;
}

QString ProfileManager::activeId() const
{
    return currentId();
}

QString ProfileManager::activeName() const
{
    return currentId().isEmpty() ? QString() : storedName(currentId());
}

QString ProfileManager::activeKind() const
{
    return kindOf(currentId());
}

QString ProfileManager::kindOf(const QString& id) const
{
    QString kind = id.isEmpty() ? QString() : QSettings().value(profileKey(id, "kind")).toString();
    return kind.isEmpty() ? QStringLiteral("custom") : kind;
}

bool ProfileManager::setupNeeded() const
{
    return currentId().isEmpty();
}

bool ProfileManager::hasCurrentSettings() const
{
    return !currentId().isEmpty() || QSettings().contains(SER_SETTINGS_MARKER);
}

bool ProfileManager::hasMoonlightSettings() const
{
    QScopedPointer<QSettings> moonlight(openMoonlightSettings());
    return moonlight->contains(SER_SETTINGS_MARKER);
}

bool ProfileManager::nameTaken(const QString& name, const QString& exceptId) const
{
    const QStringList ids = storedIds();
    for (const QString& id : ids) {
        if (id != exceptId && storedName(id).compare(name.trimmed(), Qt::CaseInsensitive) == 0) {
            return true;
        }
    }
    return false;
}

QString ProfileManager::suggestName(const QString& base) const
{
    QString name = base;
    for (int i = 2; nameTaken(name); i++) {
        name = QStringLiteral("%1 %2").arg(base).arg(i);
    }
    return name;
}

QString ProfileManager::createProfile(const QString& name, const QString& startFrom)
{
    QString trimmedName = name.trimmed();
    if (trimmedName.isEmpty()) {
        return QString();
    }

    // Keep what the user changed in the profile we're about to leave
    m_Prefs->save();

    QString id = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    QString kind = (startFrom == "gaming" || startFrom == "work") ? startFrom : QStringLiteral("custom");

    if (startFrom == "moonlight") {
        QScopedPointer<QSettings> moonlight(openMoonlightSettings());
        m_Prefs->loadFrom(*moonlight);
    }
    else if (startFrom != "current") {
        // The new profile's group is still empty, so this loads the defaults
        QSettings settings;
        settings.beginGroup(QStringLiteral(SER_PROFILES "/%1/settings").arg(id));
        m_Prefs->loadFrom(settings);
        applyPreset(m_Prefs, kind);
    }

    {
        QSettings settings;
        QStringList ids = storedIds();
        ids.append(id);
        settings.setValue(SER_PROFILE_IDS, ids);
        settings.setValue(profileKey(id, "name"), trimmedName);
        settings.setValue(profileKey(id, "kind"), kind);
    }

    setCurrentId(id);

    // Write the settings now in memory into the new profile
    m_Prefs->save();
    emit m_Prefs->enableMdnsChanged();

    emit profilesChanged();
    emit activeProfileChanged();
    return id;
}

void ProfileManager::activate(const QString& id)
{
    if (id == currentId() || !storedIds().contains(id)) {
        return;
    }

    m_Prefs->save();
    setCurrentId(id);
    m_Prefs->reload();
    emit m_Prefs->enableMdnsChanged();

    emit profilesChanged();
    emit activeProfileChanged();
}

void ProfileManager::rename(const QString& id, const QString& name)
{
    QString trimmedName = name.trimmed();
    if (trimmedName.isEmpty() || !storedIds().contains(id)) {
        return;
    }

    QSettings().setValue(profileKey(id, "name"), trimmedName);
    emit profilesChanged();
}

void ProfileManager::remove(const QString& id)
{
    QStringList ids = storedIds();
    if (!ids.contains(id) || ids.size() < 2) {
        return;
    }

    bool wasActive = id == currentId();
    ids.removeAll(id);

    if (wasActive) {
        // Nothing to keep from the profile being deleted
        setCurrentId(ids.first());
        m_Prefs->reload();
        emit m_Prefs->enableMdnsChanged();
    }

    {
        QSettings settings;
        settings.setValue(SER_PROFILE_IDS, ids);
        settings.remove(QStringLiteral(SER_PROFILES "/%1").arg(id));
    }

    emit profilesChanged();
    if (wasActive) {
        emit activeProfileChanged();
    }
}
