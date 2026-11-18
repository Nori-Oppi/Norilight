#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class StreamingPreferences;

// Norilight: profiles. A profile is a complete, named set of settings (for
// example "Gaming" and "Work"). Exactly one is active at a time, and the
// settings page always edits the active one. The first launch runs a wizard
// that creates the first profile, so there is always at least one afterwards.
class ProfileManager : public QObject
{
    Q_OBJECT

public:
    explicit ProfileManager(StreamingPreferences* prefs, QObject* parent = nullptr);

    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(QString activeId READ activeId NOTIFY profilesChanged)
    Q_PROPERTY(QString activeName READ activeName NOTIFY profilesChanged)
    Q_PROPERTY(QString activeKind READ activeKind NOTIFY profilesChanged)
    Q_PROPERTY(bool setupNeeded READ setupNeeded NOTIFY profilesChanged)
    Q_PROPERTY(bool hasCurrentSettings READ hasCurrentSettings NOTIFY profilesChanged)
    Q_PROPERTY(bool hasMoonlightSettings READ hasMoonlightSettings CONSTANT)

    // Each entry: id, name, kind ("gaming", "work" or "custom"), active
    QVariantList profiles() const;
    QString activeId() const;
    QString activeName() const;
    QString activeKind() const;

    // True until the first profile exists
    bool setupNeeded() const;

    // Settings to copy into a new profile: the active profile's, or the ones
    // saved by a version of Norilight from before profiles existed
    bool hasCurrentSettings() const;

    // The Moonlight client has been used on this PC
    bool hasMoonlightSettings() const;

    // Creates a profile and makes it active. startFrom is one of:
    //   "gaming"    low latency defaults for games
    //   "work"      desktop defaults (free cursor, borderless window)
    //   "default"   Norilight's defaults
    //   "current"   a copy of the settings in use right now
    //   "moonlight" the settings of the Moonlight client on this PC
    // Returns the new profile's id.
    Q_INVOKABLE QString createProfile(const QString& name, const QString& startFrom);

    Q_INVOKABLE void activate(const QString& id);
    Q_INVOKABLE void rename(const QString& id, const QString& name);

    // The last profile can't be removed
    Q_INVOKABLE void remove(const QString& id);
    Q_INVOKABLE void setTargetMonitor(const QString& id, const QString& key, const QString& label);

    // Shared with the stream launcher; there is only one profile store.
    static QVariantMap savedProfile(const QString& id);
    static void migrateMonitorProfiles();

    Q_INVOKABLE bool nameTaken(const QString& name, const QString& exceptId = QString()) const;

    // A free name based on the given one ("Gaming", "Gaming 2", ...)
    Q_INVOKABLE QString suggestName(const QString& base) const;

    // The QSettings group holding the active profile's settings, or an empty
    // string while no profile exists (settings then live at the top level,
    // as they did before profiles)
    static QString settingsGroup();

    // Settings > Reset Norilight: starts a Norilight that moves the settings
    // to a backup once this one has quit (settingsreset.h). QML quits after.
    Q_INVOKABLE bool restartIntoReset();

    // "--profile <name or id>": use this profile for this run
    static void setLaunchProfile(const QString& nameOrId);

    // Makes the profile chosen with --profile the one future launches use too
    static void rememberLaunchProfile();

signals:
    void profilesChanged();

    // The active profile was switched (not sent for renames)
    void activeProfileChanged();

private:
    QString kindOf(const QString& id) const;

    StreamingPreferences* m_Prefs;
};
