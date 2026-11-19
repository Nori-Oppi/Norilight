// Norilight (N6): which test stream Optimise picks (app/streaming/optimisepick.*)
#include <QtTest>

#include "streaming/optimisepick.h"

using namespace OptimisePick;

namespace
{
    Candidate stream(int codec, int kbps, double shownFps, double latency, double lostPct = 0, double droppedPct = 0)
    {
        Candidate c;
        c.codec = codec;
        c.width = 1920;
        c.height = 1080;
        c.fps = 60;
        c.kbps = kbps;
        c.measured = true;
        c.stats["renderedFps"] = shownFps;
        c.stats["networkDroppedPct"] = lostPct;
        c.stats["pacerDroppedPct"] = droppedPct;
        c.stats["hostMs"] = latency;
        return c;
    }
}

class OptimisePickTest : public QObject
{
    Q_OBJECT

private slots:
    void keepsUpNeedsFramesAndNoLoss()
    {
        QVERIFY(keepsUp(stream(H264, 20000, 59.9, 3)));
        QVERIFY(!keepsUp(stream(H264, 20000, 50, 3)));        // too few frames shown
        QVERIFY(!keepsUp(stream(H264, 20000, 59.9, 3, 2.5)));  // lost on the network
        QVERIFY(!keepsUp(stream(H264, 20000, 59.9, 3, 0, 5)));  // dropped by the client
        Candidate none;
        none.fps = 60;
        none.measured = true;  // measured, but it didn't stream
        QVERIFY(!keepsUp(none));
    }

    void nothingWhenNothingKeepsUp()
    {
        QVector<Candidate> c = {stream(H264, 20000, 40, 3), stream(Hevc, 20000, 45, 3)};
        QCOMPARE(best(c, Balanced), -1);
    }

    void performanceTakesTheLowestLatency()
    {
        QVector<Candidate> c = {stream(H264, 20000, 59.9, 6.5), stream(Hevc, 20000, 59.9, 4.4), stream(Av1, 20000, 59.9, 5.5)};
        QCOMPARE(best(c, Performance), 1);
    }

    void performanceTakesAHigherBitrateAtAboutTheSameLatency()
    {
        QVector<Candidate> c = {stream(Hevc, 20000, 59.9, 4.4), stream(Hevc, 30000, 59.9, 4.5), stream(Hevc, 45000, 59.9, 4.7)};
        QCOMPARE(best(c, Performance), 2);
        c[2].stats["hostMs"] = 6.0;  // much slower: not worth it
        QCOMPARE(best(c, Performance), 1);
    }

    void qualityTakesTheMostEfficientCodecThatKeepsUp()
    {
        QVector<Candidate> c = {stream(H264, 20000, 59.9, 3), stream(Hevc, 20000, 59.9, 6), stream(Av1, 20000, 40, 5)};
        QCOMPARE(best(c, Quality), 1);  // AV1 falls behind
    }

    void balancedStaysWithinAMillisecond()
    {
        QVector<Candidate> c = {stream(H264, 20000, 59.9, 3.0), stream(Hevc, 20000, 59.9, 3.8), stream(Av1, 20000, 59.9, 5.0)};
        QCOMPARE(best(c, Balanced), 1);  // AV1 is 2 ms slower
        QCOMPARE(best(c, Off), 1);
    }

    void aHigherBitrateThatFallsBehindIsNotPicked()
    {
        QVector<Candidate> c = {stream(Hevc, 20000, 59.9, 4), stream(Hevc, 30000, 59.9, 4, 3.0)};
        QCOMPARE(best(c, Quality), 0);
    }
};

QTEST_GUILESS_MAIN(OptimisePickTest)
#include "OptimisePickTest.moc"
