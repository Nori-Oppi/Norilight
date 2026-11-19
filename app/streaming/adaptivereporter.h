#pragma once

#include <QThread>

#include <QString>
#include <QVector>

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

    // networkKey: where to remember what the host sustained (autotune.h); empty to not learn.
    // requestedKbps: the bitrate this client asked for. The host reports bitrates after
    // its overhead allowance, so learning converts back to what to ask for next time.
    AdaptiveReporter(NvComputer* computer, const QString& networkKey, int requestedKbps);
    ~AdaptiveReporter() override;

    // Whether this host takes reports.
    static bool isSupported(NvComputer* computer);

    void stop();

    // Called by the decoder once per stats window (about a second), on its own thread.
    static void publishWindow(uint32_t totalFrames, uint32_t networkDroppedFrames,
                              uint32_t decodedFrames, uint64_t totalDecodeTimeUs,
                              uint32_t receivedFrames, uint64_t windowUs);

    static HostState hostState();

    // Norilight (N9): the bitrate was changed by hand during the stream, so this stream
    // doesn't teach the next one's start bitrate
    static void noteManualBitrate();

    // Appends "Host bitrate ..." to overlay text when the host has answered. Returns the
    // number of characters written.
    static int appendOverlayLine(char* output, int length);

protected:
    void run() override;

private:
    void learn();

    NvComputer* m_Computer;
    QString m_HostUuid;
    QString m_NetworkKey;
    int m_RequestedKbps;
    std::atomic<bool> m_Stop {false};

    // The host's answers over the stream, for learning
    QVector<int> m_BitrateSamples;
    int m_MaxKbps = 0;
    int m_Decreases = 0;
};
