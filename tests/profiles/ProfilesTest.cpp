#include <QtTest>
#include <QGuiApplication>
#include <QScreen>
#include <QSettings>
#include <QTemporaryDir>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include "settings/profilemanager.h"
#include "settings/displaymanager.h"
#include "settings/streamingpreferences.h"

class ProfilesTest : public QObject {
    Q_OBJECT
    QTemporaryDir storage;

    void seed() {
        QSettings s;
        s.setValue("norilightprofiles/ids", QStringList{"base", "other"});
        s.setValue("norilightprofiles/active", "base");
        s.setValue("norilightprofiles/base/name", "Desktop");
        s.setValue("norilightprofiles/other/name", "Gaming");
        s.setValue("norilightprofiles/base/settings/defaultver", 2);
        s.setValue("norilightprofiles/base/settings/fps", 60);
        s.setValue("norilightprofiles/base/settings/norilightfreecursor", true);
        s.setValue("norilightprofiles/other/settings/defaultver", 2);
        s.setValue("norilightprofiles/other/settings/fps", 144);
        s.setValue("norilightprofiles/other/settings/norilightfreecursor", false);
        s.sync();
    }

    void legacy(bool automatic) {
        QSettings s;
        s.beginWriteArray("displayprofiles", 1);
        s.setArrayIndex(0);
        s.setValue("id", "legacy-left");
        s.setValue("name", "Desktop"); // A name collision must be resolved.
        s.setValue("monitorKey", "missing:display");
        s.setValue("monitorLabel", "Left display");
        s.setValue("width", automatic ? 0 : 2560);
        s.setValue("height", automatic ? 0 : 1440);
        s.setValue("fps", automatic ? 0 : 120);
        s.setValue("bitrateKbps", automatic ? 0 : 42000);
        s.setValue("windowMode", 2);
        s.setValue("vsync", false);
        s.setValue("framePacing", true);
        s.setValue("videoScaleMode", 1);
        s.setValue("lastAppName", "Desktop");
        s.endArray();
        s.sync();
    }

private slots:
    void initTestCase() {
        QVERIFY(storage.isValid());
        QCoreApplication::setOrganizationName("NorilightProfileTests");
        QCoreApplication::setApplicationName("ProfilesTest");
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, storage.path());
        QSettings::setPath(QSettings::IniFormat, QSettings::SystemScope, storage.path());
    }

    void migrationPreservesSettings() {
        seed(); legacy(false);
        ProfileManager::migrateMonitorProfiles();
        QSettings s;
        const auto ids = s.value("norilightprofiles/ids").toStringList();
        QCOMPARE(ids.size(), 3);
        QCOMPARE(s.value("norilightprofiles/active").toString(), QString("base"));
        const auto p = ProfileManager::savedProfile(ids.last());
        QCOMPARE(p["name"].toString(), QString("Desktop 2"));
        QCOMPARE(p["monitorLabel"].toString(), QString("Left display"));
        QCOMPARE(p["lastAppName"].toString(), QString("Desktop"));
        s.beginGroup("norilightprofiles/" + ids.last() + "/settings");
        QCOMPARE(s.value("width").toInt(), 2560);
        QCOMPARE(s.value("height").toInt(), 1440);
        QCOMPARE(s.value("fps").toInt(), 120);
        QCOMPARE(s.value("bitrate").toInt(), 42000);
        QCOMPARE(s.value("windowmode").toInt(), 2);
        QCOMPARE(s.value("norilightvideoscalemode").toInt(), 1);
        QVERIFY(!s.value("vsync").toBool());
        QVERIFY(s.value("framepacing").toBool());
        QVERIFY(s.value("norilightfreecursor").toBool()); // inherited input
        QVERIFY(!s.value("autoadjustbitrate").toBool());
        s.endGroup();
        QVERIFY(s.contains("displayprofiles/1/id")); // Original retained.
        ProfileManager::migrateMonitorProfiles();
        QCOMPARE(QSettings().value("norilightprofiles/ids").toStringList(), ids);
        // Retry after an interrupted migration must not duplicate completed entries.
        s.remove("norilightprofiles/monitorMigrationVersion"); s.sync();
        ProfileManager::migrateMonitorProfiles();
        QCOMPARE(QSettings().value("norilightprofiles/ids").toStringList(), ids);
        ProfileManager manager(StreamingPreferences::get());
        manager.remove(ids.last());
        ProfileManager::migrateMonitorProfiles();
        QCOMPARE(QSettings().value("norilightprofiles/ids").toStringList().size(), 2);
    }

    void automaticMigrationAndLegacyBase() {
        QSettings s;
        s.setValue("defaultver", 2);
        s.setValue("norilightfreecursor", true);
        s.setValue("fps", 75); s.sync();
        legacy(true);
        ProfileManager::migrateMonitorProfiles();
        const auto ids = QSettings().value("norilightprofiles/ids").toStringList();
        QCOMPARE(ids.size(), 2);
        QCOMPARE(ProfileManager::savedProfile(ids.first())["name"].toString(), QString("My settings"));
        const auto p = ProfileManager::savedProfile(ids.last());
        QVERIFY(p["matchMonitorResolution"].toBool());
        QVERIFY(p["matchMonitorRefreshRate"].toBool());
        s.beginGroup("norilightprofiles/" + ids.last() + "/settings");
        QVERIFY(s.value("autoadjustbitrate").toBool());
        QVERIFY(s.value("norilightfreecursor").toBool());
        QCOMPARE(s.value("fps").toInt(), 75);
    }

    void profileIsolationAndLaunchSelection() {
        seed();
        ProfileManager::setLaunchProfile("base");
        auto* prefs = StreamingPreferences::get();
        ProfileManager manager(prefs);
        manager.setTargetMonitor("base", "monitor-a", "A");
        manager.setTargetMonitor("other", "monitor-b", "B");
        prefs->fps = 90;
        manager.activate("other");
        QCOMPARE(prefs->fps, 144);
        QCOMPARE(prefs->targetMonitor, QString("monitor-b"));
        QVERIFY(!prefs->freeCursorMode);
        manager.activate("base");
        QCOMPARE(prefs->fps, 90);
        QCOMPARE(prefs->targetMonitor, QString("monitor-a"));
        QVERIFY(prefs->freeCursorMode);
        // A child selecting another profile must reload its entire settings.
        ProfileManager::setLaunchProfile("Gaming");
        QCOMPARE(prefs->fps, 144);
        QCOMPARE(prefs->targetMonitor, QString("monitor-b"));
        QCOMPARE(QSettings().value("norilightprofiles/active").toString(), QString("base"));
    }

    void launchArgumentsHaveOneSettingsSource() {
        seed();
        ProfileManager::setLaunchProfile("base");
        DisplayManager launcher;
        auto* screen = QGuiApplication::primaryScreen();
        QVERIFY(screen);
        const auto args = launcher.buildArguments(ProfileManager::savedProfile("other"), screen, "host", "Desktop");
        QCOMPARE(args, QStringList({"stream", "host", "Desktop", "--profile", "other", "--monitor", DisplayManager::monitorKey(screen)}));
        QSignalSpy errors(&launcher, &DisplayManager::launchFailed);
        ProfileManager manager(StreamingPreferences::get());
        manager.setTargetMonitor("other", "missing:display", "Missing");
        QVERIFY(launcher.launch("other", "host", "Host", "Desktop").isEmpty());
        QCOMPARE(errors.count(), 1);
        QCOMPARE(launcher.runningCount(), 0);
        QCOMPARE(ProfileManager::settingsGroup(), QString("norilightprofiles/base/settings"));
    }

    void pickerLoadsUnifiedProfiles() {
        seed(); legacy(false);
        ProfileManager::migrateMonitorProfiles();
        // A long list must remain inside the window with scrolling.
        ProfileManager manager(StreamingPreferences::get());
        for (int i = 0; i < 12; ++i) {
            QVERIFY(!manager.createProfile(QString("Extra %1").arg(i), "current").isEmpty());
        }
        qmlRegisterSingletonType<ProfileManager>("ProfileManager", 1, 0, "ProfileManager",
            [](QQmlEngine*, QJSEngine*) -> QObject* { return new ProfileManager(StreamingPreferences::get()); });
        qmlRegisterSingletonType<DisplayManager>("DisplayManager", 1, 0, "DisplayManager",
            [](QQmlEngine*, QJSEngine*) -> QObject* { return new DisplayManager(); });
        QQmlApplicationEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        const QString guiPath = QUrl::fromLocalFile(QFINDTESTDATA("../../app/gui")).toString();
        const auto source = QString(R"(
            import QtQuick 2.9
            import QtQuick.Controls 2.5
            import "%1" as Gui
            ApplicationWindow {
                id: window
                width: 800; height: 600; visible: true
                StackView { id: stackView }
                Gui.DisplayProfilePicker {
                    id: picker; objectName: "profilePicker"
                    appName: "Desktop"; hostUuid: "host"
                    Component.onCompleted: open()
                }
            }
        )").arg(guiPath).toUtf8();
        engine.loadData(source);
        QVERIFY(!engine.rootObjects().isEmpty());
        auto* picker = engine.rootObjects().first()->findChild<QObject*>("profilePicker");
        QVERIFY(picker);
        QTRY_VERIFY(picker->property("visible").toBool());
        QVERIFY(picker->property("height").toReal() <= 600);
        QVERIFY(picker->property("width").toReal() <= 800);
        QCOMPARE(warnings.count(), 0);
    }

    void matchingUsesChosenMonitor() {
        seed(); ProfileManager::setLaunchProfile("base");
        auto* prefs = StreamingPreferences::get();
        auto* screen = QGuiApplication::primaryScreen();
        QVERIFY(screen);
        prefs->targetMonitor = DisplayManager::monitorKey(screen);
        prefs->matchMonitorResolution = true;
        prefs->matchMonitorRefreshRate = true;
        prefs->autoAdjustBitrate = true;
        prefs->resolveDisplaySettings(screen);
        QCOMPARE(prefs->width, qMax(2, qRound(screen->geometry().width() * screen->devicePixelRatio()) & ~1));
        QCOMPARE(prefs->height, qMax(2, qRound(screen->geometry().height() * screen->devicePixelRatio()) & ~1));
        QCOMPARE(prefs->fps, qBound(10, qRound(screen->refreshRate()), 480));
        QCOMPARE(prefs->bitrateKbps, StreamingPreferences::getDefaultBitrate(prefs->width, prefs->height, prefs->fps, prefs->enableYUV444));
        prefs->autoAdjustBitrate = false; prefs->bitrateKbps = 42000;
        prefs->resolveDisplaySettings(screen);
        QCOMPARE(prefs->bitrateKbps, 42000);
    }
};
QTEST_MAIN(ProfilesTest)
#include "ProfilesTest.moc"
