#pragma once

#include <QThread>

#include <atomic>
#include <cstdint>

class NvComputer;

// Norilight: reports what the client measures to a Norishine host during a stream, once a
// second, so the host can adapt the stream's bitrate and error correction (Norishine's
// POST /api/v1/session/report, feature "adaptive"). Keeps the host's answer for the
// performance overlay. See docs/AUTOTUNE.md.
class AdaptiveReporter : public QThread
{
    Q_OBJECT

public:
    // What the host's controller does now.
    struct HostState {
        bool valid = false;
        int bitrateKbps = 0;
        int maxKbps = 0;
        int fecPercent = 0;
        char reason[16] = {};
        bool hostLimited = false;
        bool clientLimited = false;
    };

    explicit AdaptiveReporter(NvComputer* computer);
    ~AdaptiveReporter() override;

    // Whether this host takes reports.
    static bool isSupported(NvComputer* computer);

    void stop();

    // Called by the decoder once per stats window (about a second), on its own thread.
    static void publishWindow(uint32_t totalFrames, uint32_t networkDroppedFrames,
                              uint32_t decodedFrames, uint64_t totalDecodeTimeUs,
                              uint32_t receivedFrames, uint64_t windowUs);

    static HostState hostState();

    // Appends "Host bitrate ..." to overlay text when the host has answered. Returns the
    // number of characters written.
    static int appendOverlayLine(char* output, int length);

protected:
    void run() override;

private:
    NvComputer* m_Computer;
    std::atomic<bool> m_Stop {false};
};
