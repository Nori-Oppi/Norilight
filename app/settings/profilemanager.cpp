#include "profilemanager.h"
#include "streamingpreferences.h"
#include "settingsreset.h"

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
            StreamingPreferences::get()->reload();
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
        p = savedProfile(id);
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

bool ProfileManager::restartIntoReset()
{
    return SettingsReset::restartIntoReset();
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
    if (trimmedName.isEmpty() || nameTaken(trimmedName)) {
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
    if (trimmedName.isEmpty() || nameTaken(trimmedName, id) || !storedIds().contains(id)) {
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

QVariantMap ProfileManager::savedProfile(const QString& id)
{
    if (!storedIds().contains(id)) {
        return {};
    }
    QSettings settings;
    settings.beginGroup(QStringLiteral(SER_PROFILES "/%1").arg(id));
    QVariantMap result;
    result["id"] = id;
    for (const char* field : {"name", "kind", "lastHostUuid", "lastHostName", "lastAppName"}) {
        result[field] = settings.value(field);
    }
    settings.beginGroup("settings");
    result["monitorKey"] = settings.value("targetmonitor");
    result["monitorLabel"] = settings.value("targetmonitorlabel");
    result["width"] = settings.value("width", 1920);
    result["height"] = settings.value("height", 1080);
    result["fps"] = settings.value("fps", 60);
    result["matchMonitorResolution"] = settings.value("matchmonitorresolution", false);
    result["matchMonitorRefreshRate"] = settings.value("matchmonitorrefreshrate", false);
    return result;
}

void ProfileManager::setTargetMonitor(const QString& id, const QString& key, const QString& label)
{
    if (!storedIds().contains(id)) {
        return;
    }
    if (id == currentId()) {
        m_Prefs->targetMonitor = key;
        m_Prefs->targetMonitorLabel = label;
        m_Prefs->save();
    }
    else {
        QSettings settings;
        settings.beginGroup(QStringLiteral(SER_PROFILES "/%1/settings").arg(id));
        settings.setValue("targetmonitor", key);
        settings.setValue("targetmonitorlabel", label);
    }
    emit profilesChanged();
}

void ProfileManager::migrateMonitorProfiles()
{
    QSettings settings;
    if (settings.value(SER_PROFILES "/monitorMigrationVersion", 0).toInt() >= 1) {
        return;
    }

    QVector<QVariantMap> legacy;
    const int count = settings.beginReadArray("displayprofiles");
    for (int i = 0; i < count; ++i) {
        settings.setArrayIndex(i);
        QVariantMap preset;
        for (const QString& key : settings.childKeys()) {
            preset[key] = settings.value(key);
        }
        if (!preset.value("id").toString().isEmpty()) {
            legacy.append(preset);
        }
    }
    settings.endArray();
    if (legacy.isEmpty()) {
        return;
    }

    auto* prefs = StreamingPreferences::get();
    QStringList ids = storedIds();
    if (ids.isEmpty()) {
        // Preserve pre-profile settings as their own profile before importing.
        const QString baseId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        settings.setValue(profileKey(baseId, "name"), tr("My settings"));
        settings.setValue(profileKey(baseId, "kind"), "custom");
        settings.beginGroup(QStringLiteral(SER_PROFILES "/%1/settings").arg(baseId));
        prefs->saveTo(settings);
        settings.endGroup();
        ids.append(baseId);
        settings.setValue(SER_PROFILE_IDS, ids);
        setCurrentId(baseId);
    }

    for (const QVariantMap& preset : legacy) {
        const QString legacyId = preset["id"].toString();
        bool imported = false;
        for (const QString& id : ids) {
            if (settings.value(profileKey(id, "legacyMonitorId")).toString() == legacyId) {
                imported = true;
                break;
            }
        }
        if (imported) {
            continue;
        }

        QString baseName = preset.value("name").toString().trimmed();
        if (baseName.isEmpty()) {
            baseName = tr("Monitor profile");
        }
        QString name = baseName;
        for (int suffix = 2;; ++suffix) {
            bool taken = false;
            for (const QString& id : ids) {
                if (settings.value(profileKey(id, "name")).toString().compare(name, Qt::CaseInsensitive) == 0) {
                    taken = true;
                    break;
                }
            }
            if (!taken) {
                break;
            }
            name = QStringLiteral("%1 %2").arg(baseName).arg(suffix);
        }

        const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        settings.beginGroup(QStringLiteral(SER_PROFILES "/%1").arg(id));
        settings.setValue("name", name);
        settings.setValue("kind", "custom");
        settings.setValue("legacyMonitorId", legacyId);
        for (const char* field : {"lastHostUuid", "lastHostName", "lastAppName"}) {
            settings.setValue(field, preset.value(field));
        }
        settings.beginGroup("settings");
        prefs->saveTo(settings);
        settings.setValue("targetmonitor", preset.value("monitorKey"));
        settings.setValue("targetmonitorlabel", preset.value("monitorLabel"));
        const bool matchResolution = preset.value("width").toInt() <= 0 || preset.value("height").toInt() <= 0;
        settings.setValue("matchmonitorresolution", matchResolution);
        if (!matchResolution) {
            settings.setValue("width", preset["width"]);
            settings.setValue("height", preset["height"]);
        }
        settings.setValue("matchmonitorrefreshrate", preset.value("fps").toInt() <= 0);
        if (preset.value("fps").toInt() > 0) {
            settings.setValue("fps", preset["fps"]);
        }
        for (const auto& fields : {qMakePair("windowMode", "windowmode"),
                                   qMakePair("vsync", "vsync"),
                                   qMakePair("framePacing", "framepacing"),
                                   qMakePair("videoScaleMode", "norilightvideoscalemode")}) {
            if (preset.contains(fields.first)) {
                settings.setValue(fields.second, preset[fields.first]);
            }
        }
        const int bitrate = preset.value("bitrateKbps").toInt();
        settings.setValue("autoadjustbitrate", bitrate <= 0);
        if (bitrate > 0) {
            settings.setValue("bitrate", bitrate);
        }
        else {
            settings.setValue("bitrate", StreamingPreferences::getDefaultBitrate(
                settings.value("width").toInt(), settings.value("height").toInt(),
                settings.value("fps").toInt(), prefs->enableYUV444));
        }
        settings.endGroup();
        settings.endGroup();
        ids.append(id);
        settings.setValue(SER_PROFILE_IDS, ids);
    }

    // Keep the old array as a backup. The marker prevents future re-imports,
    // including when an imported profile is subsequently deleted by the user.
    settings.sync();
    if (settings.status() == QSettings::NoError) {
        settings.setValue(SER_PROFILES "/monitorMigrationVersion", 1);
        settings.sync();
    }
    else {
        qWarning() << "Could not save migrated monitor profiles";
    }
}
