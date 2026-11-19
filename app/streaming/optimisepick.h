#pragma once

#include <QVariantMap>
#include <QVector>

// Norilight (roadmap N6): how Optimise scores its test streams. Separate from Optimiser so
// the unit test needs no streaming code (tests/optimise).
namespace OptimisePick
{
    // Same values as StreamingPreferences::VideoCodecConfig and ::TuningGoal
    enum Codec { H264 = 1, Hevc = 2, Av1 = 4 };
    enum Goal { Off = 0, Performance = 1, Balanced = 2, Quality = 3 };

    // A candidate setting and what its test stream measured
    struct Candidate {
        int codec = H264;
        int width = 0;
        int height = 0;
        int fps = 0;
        int kbps = 0;
        bool measured = false;
        QVariantMap stats;  // FFmpegVideoDecoder::getSessionStats; empty: it didn't stream
    };

    // Showed at least 90 % of the frames, lost at most 1 % and dropped at most 2 %
    bool keepsUp(const Candidate& c);

    // Host processing, decoding and rendering per frame, in ms
    double latencyMs(const Candidate& c);

    // Index of the best candidate for the goal, or -1 when none keeps up. Among those that
    // keep up: Performance takes the lowest latency (a higher bitrate within 0.5 ms of it),
    // Quality the most efficient codec, Balanced and Off the most efficient within 1 ms of
    // the lowest latency; then the higher bitrate.
    int best(const QVector<Candidate>& candidates, int goal);
}
