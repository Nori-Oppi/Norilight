// Norilight (N9): the stream settings menu (app/streaming/livesettings.*)
#include <QtTest>

#include "streaming/livesettings.h"

class LiveSettingsTest : public QObject
{
    Q_OBJECT

private slots:
    void stepsIncludeTheCurrentValue()
    {
        QVector<int> steps = LiveSettingsMenu::bitrateSteps(23500, 150000);
        QVERIFY(steps.contains(23500));
        QVERIFY(std::is_sorted(steps.begin(), steps.end()));
        QCOMPARE(steps.last(), 150000);
        QVERIFY(!LiveSettingsMenu::bitrateSteps(20000, 100000).contains(150000));
        QVERIFY(LiveSettingsMenu::fecSteps(23).contains(23));
        QCOMPARE(LiveSettingsMenu::fecSteps(20).size(), 10);
    }

    void nothingChangedCloses()
    {
        LiveSettingsMenu menu(LiveSettingsMenu::Start {});
        QVERIFY(menu.changes().isEmpty());
        QCOMPARE(menu.key(LiveSettingsMenu::KeyEnter), LiveSettingsMenu::Close);
        QCOMPARE(menu.key(LiveSettingsMenu::KeyOther), LiveSettingsMenu::Ignored);
    }

    void changesBecomeTheRequestBody()
    {
        LiveSettingsMenu::Start start;
        start.bitrateKbps = 20000;
        start.fecPercent = 20;
        start.goal = 2;
        LiveSettingsMenu menu(start);

        // Bitrate one step up, error correction one step down, encoder to Quality
        QCOMPARE(menu.key(LiveSettingsMenu::KeyRight), LiveSettingsMenu::Handled);
        menu.key(LiveSettingsMenu::KeyDown);
        menu.key(LiveSettingsMenu::KeyLeft);
        menu.key(LiveSettingsMenu::KeyDown);
        menu.key(LiveSettingsMenu::KeyRight);
        QJsonObject body = menu.changes();
        QCOMPARE(body.value("bitrate_kbps").toInt(), 30000);
        QCOMPARE(body.value("fec_percent").toInt(), 15);
        QCOMPARE(body.value("tuning").toString(), QString("quality"));
        QCOMPARE(menu.key(LiveSettingsMenu::KeyEnter), LiveSettingsMenu::Apply);
        QVERIFY(menu.text().contains("*"));

        menu.applied();
        QVERIFY(menu.changes().isEmpty());
        QCOMPARE(menu.bitrateKbps(), 30000);
        QCOMPARE(menu.fecPercent(), 15);
        QCOMPARE(menu.goal(), 3);
        QVERIFY(!menu.text().contains("*"));
    }

    void escapePutsChangesBack()
    {
        LiveSettingsMenu menu(LiveSettingsMenu::Start {});
        menu.key(LiveSettingsMenu::KeyRight);
        QVERIFY(!menu.changes().isEmpty());
        QCOMPARE(menu.key(LiveSettingsMenu::KeyEscape), LiveSettingsMenu::Close);
        QVERIFY(menu.changes().isEmpty());
    }

    void rowsWrapAndValuesStopAtTheEnds()
    {
        LiveSettingsMenu::Start start;
        start.encoderPreset = false;  // a host without tuning goals
        LiveSettingsMenu menu(start);
        QVERIFY(!menu.hasRow(LiveSettingsMenu::EncoderPreset));
        menu.key(LiveSettingsMenu::KeyUp);
        QCOMPARE(menu.selectedRow(), 1);
        menu.key(LiveSettingsMenu::KeyDown);
        QCOMPARE(menu.selectedRow(), 0);
        for (int i = 0; i < 40; i++) {
            menu.key(LiveSettingsMenu::KeyLeft);
        }
        QCOMPARE(menu.changes().value("bitrate_kbps").toInt(), 2000);
    }
};

QTEST_GUILESS_MAIN(LiveSettingsTest)
#include "LiveSettingsTest.moc"
