#include <QtTest>
#include <QSettings>
#include <QTemporaryDir>
#include "streaming/autotune.h"

using namespace AutoTune;

class AutoTuneTest : public QObject {
    Q_OBJECT
    QTemporaryDir storage;

private slots:
    void initTestCase() {
        QVERIFY(storage.isValid());
        QCoreApplication::setOrganizationName("NorilightAutoTuneTests");
        QCoreApplication::setApplicationName("AutoTuneTest");
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, storage.path());
    }

    void firstStreamStartsByLink() {
        // 1080p60 recommends 20 Mbps.
        QCOMPARE(startBitrate(20000, false, Link::Ethernet, {}, 150000).kbps, 50000);
        QCOMPARE(startBitrate(20000, false, Link::Wifi, {}, 150000).kbps, 30000);
        QCOMPARE(startBitrate(20000, false, Link::Unknown, {}, 150000).kbps, 30000);
        QCOMPARE(startBitrate(20000, true, Link::Ethernet, {}, 150000).kbps, 62500);
    }

    void capsByLinkAndProfile() {
        // 4K120 recommends 113 Mbps.
        QCOMPARE(startBitrate(113000, false, Link::Ethernet, {}, 150000).kbps, 150000);
        QCOMPARE(startBitrate(113000, false, Link::Ethernet, {}, 500000).kbps, 282500);
        QCOMPARE(startBitrate(113000, false, Link::Wifi, {}, 500000).kbps, 150000);
        QCOMPARE(startBitrate(113000, false, Link::Unknown, {}, 500000).kbps, 100000);
    }

    void learnedLimitStartsJustAbove() {
        Learned l;
        l.kbps = 18000;
        l.limited = true;
        l.sessions = 2;
        QCOMPARE(startBitrate(20000, false, Link::Wifi, l, 150000).kbps, 21500);
        l.kbps = 500;
        QCOMPARE(startBitrate(20000, false, Link::Wifi, l, 150000).kbps, 2000);
    }

    void neverLimitedGrows() {
        Learned l;
        l.kbps = 50000;
        l.limited = false;
        l.sessions = 1;
        QCOMPARE(startBitrate(20000, false, Link::Ethernet, l, 150000).kbps, 62500);
        l.kbps = 140000;
        QCOMPARE(startBitrate(20000, false, Link::Ethernet, l, 150000).kbps, 150000);
        // Performance doesn't climb past its own start.
        QCOMPARE(startBitrate(20000, false, Link::Ethernet, l, 150000, Goal::Performance).kbps, 30000);
        l.kbps = 10000;
        QCOMPARE(startBitrate(20000, false, Link::Ethernet, l, 150000, Goal::Performance).kbps, 12500);
    }

    void learnsPerHostAndNetwork() {
        forgetAll();
        QCOMPARE(learned("host-a", "wifi 192.168.1.0/24").kbps, 0);

        learn("host-a", "wifi 192.168.1.0/24", 30000, false);
        Learned l = learned("host-a", "wifi 192.168.1.0/24");
        QCOMPARE(l.kbps, 30000);
        QCOMPARE(l.limited, false);
        QCOMPARE(l.sessions, 1);

        // Limited twice: averaged.
        learn("host-a", "wifi 192.168.1.0/24", 20000, true);
        learn("host-a", "wifi 192.168.1.0/24", 10000, true);
        l = learned("host-a", "wifi 192.168.1.0/24");
        QCOMPARE(l.kbps, 15000);
        QCOMPARE(l.limited, true);
        QCOMPARE(l.sessions, 3);

        // Other hosts and networks are separate.
        QCOMPARE(learned("host-b", "wifi 192.168.1.0/24").kbps, 0);
        QCOMPARE(learned("host-a", "ethernet 192.168.1.0/24").kbps, 0);

        forgetAll();
        QCOMPARE(learned("host-a", "wifi 192.168.1.0/24").kbps, 0);
    }

    void goalsScaleTheStartBitrate() {
        QCOMPARE(startBitrate(20000, false, Link::Ethernet, {}, 150000, Goal::Performance).kbps, 30000);
        QCOMPARE(startBitrate(20000, false, Link::Ethernet, {}, 150000, Goal::Balanced).kbps, 50000);
        QCOMPARE(startBitrate(20000, false, Link::Ethernet, {}, 150000, Goal::Quality).kbps, 70000);
        Learned l;
        l.kbps = 20000;
        l.limited = true;
        l.sessions = 1;
        QCOMPARE(startBitrate(20000, false, Link::Wifi, l, 150000, Goal::Performance).kbps, 20000);
        QCOMPARE(startBitrate(20000, false, Link::Wifi, l, 150000, Goal::Quality).kbps, 26000);
        QCOMPARE(bitrateFactor(Goal::Performance), 0.75);
        QCOMPARE(bitrateFactor(Goal::Quality), 1.25);
    }

    void performancePicksLatency() {
        Capabilities caps;
        caps.hevcHardware = caps.av1Hardware = caps.hdrDecode = caps.displayHdr = true;
        caps.hostHevc = caps.hostAv1 = caps.hostHdr = true;
        LaunchPicks p = pickFor(Goal::Performance, caps);
        QCOMPARE(p.codec, LaunchPicks::Codec::PreferHevc);
        QCOMPARE(p.hdr, 0);
        QCOMPARE(p.vsync, 0);
        QCOMPARE(p.framePacing, 0);
    }

    void qualityPicksTheBestBothCanDo() {
        Capabilities caps;
        caps.hevcHardware = caps.av1Hardware = caps.hdrDecode = caps.displayHdr = true;
        caps.hostHevc = caps.hostAv1 = caps.hostHdr = true;
        LaunchPicks p = pickFor(Goal::Quality, caps);
        QCOMPARE(p.codec, LaunchPicks::Codec::PreferAv1);
        QCOMPARE(p.hdr, 1);
        QCOMPARE(p.vsync, 1);
        QCOMPARE(p.framePacing, 1);

        // AV1 only in software here: HEVC instead. No HDR display: HDR stays as set.
        caps.av1Hardware = false;
        caps.displayHdr = false;
        p = pickFor(Goal::Quality, caps);
        QCOMPARE(p.codec, LaunchPicks::Codec::PreferHevc);
        QCOMPARE(p.hdr, -1);

        // The host can't encode HEVC or AV1: leave the codec alone.
        caps.hostHevc = caps.hostAv1 = false;
        QCOMPARE(pickFor(Goal::Quality, caps).codec, LaunchPicks::Codec::Keep);
    }

    void balancedKeepsTheProfile() {
        Capabilities caps;
        caps.hevcHardware = caps.hostHevc = true;
        LaunchPicks p = pickFor(Goal::Balanced, caps);
        QCOMPARE(p.codec, LaunchPicks::Codec::PreferHevc);
        QCOMPARE(p.hdr, -1);
        QCOMPARE(p.vsync, -1);
        QCOMPARE(p.framePacing, -1);
    }

    void loopbackIsRecognised() {
        Network n = describeNetwork("127.0.0.1");
        QCOMPARE(n.link, Link::Loopback);
        QCOMPARE(n.key, QString("loopback"));
    }
};

QTEST_GUILESS_MAIN(AutoTuneTest)
#include "AutoTuneTest.moc"
