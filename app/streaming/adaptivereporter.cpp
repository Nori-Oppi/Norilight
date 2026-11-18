#include "adaptivereporter.h"

#include "backend/nvcomputer.h"
#include "backend/nvhttp.h"
#include "autotune.h"

#include <Limelight.h>
#include "SDL_compat.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QMutex>
#include <QMutexLocker>

#include <algorithm>
#include <cstdio>
#include <cstring>

namespace {
    // The latest stats window from the decoder, and the host's latest answer.
    struct Window {
        uint64_t sequence = 0;
        uint32_t totalFrames = 0;
        uint32_t networkDroppedFrames = 0;
        uint32_t decodedFrames = 0;
        uint64_t totalDecodeTimeUs = 0;
        uint32_t receivedFrames = 0;
        uint64_t windowUs = 0;
        uint32_t rttMs = 0;
        uint32_t rttVarianceMs = 0;
    };

    QMutex s_Lock;
    Window s_Window;
    AdaptiveReporter::HostState s_HostState;

    // Give up after this many failed reports in a row (other than "no stream yet").
    constexpr int k_MaxFailures = 10;

    // Learn only from streams with this many answers (about a second each), and skip the
    // first ones while the stream settles.
    constexpr int k_MinSamples = 30;
    constexpr int k_SettleSamples = 5;
}

AdaptiveReporter::AdaptiveReporter(NvComputer* computer, const QString& networkKey, int requestedKbps)
    : m_Computer(computer),
      m_NetworkKey(networkKey),
      m_RequestedKbps(requestedKbps)
{
    {
        QReadLocker locker(&computer->lock);
        m_HostUuid = computer->uuid;
    }

    QMutexLocker locker(&s_Lock);
    s_Window = Window();
    s_HostState = HostState();
}

AdaptiveReporter::~AdaptiveReporter()
{
    stop();
    wait();

    QMutexLocker locker(&s_Lock);
    s_HostState = HostState();
}

bool AdaptiveReporter::isSupported(NvComputer* computer)
{
    QReadLocker locker(&computer->lock);
    return computer->norishineFeatures.contains("adaptive");
}

void AdaptiveReporter::stop()
{
    m_Stop = true;
}

void AdaptiveReporter::publishWindow(uint32_t totalFrames, uint32_t networkDroppedFrames,
                                     uint32_t decodedFrames, uint64_t totalDecodeTimeUs,
                                     uint32_t receivedFrames, uint64_t windowUs)
{
    Window w;
    w.totalFrames = totalFrames;
    w.networkDroppedFrames = networkDroppedFrames;
    w.decodedFrames = decodedFrames;
    w.totalDecodeTimeUs = totalDecodeTimeUs;
    w.receivedFrames = receivedFrames;
    w.windowUs = windowUs;
    if (!LiGetEstimatedRttInfo(&w.rttMs, &w.rttVarianceMs)) {
        w.rttMs = 0;
        w.rttVarianceMs = 0;
    }

    QMutexLocker locker(&s_Lock);
    w.sequence = s_Window.sequence + 1;
    s_Window = w;
}

AdaptiveReporter::HostState AdaptiveReporter::hostState()
{
    QMutexLocker locker(&s_Lock);
    return s_HostState;
}

int AdaptiveReporter::appendOverlayLine(char* output, int length)
{
    HostState s = hostState();
    if (!s.valid || length <= 1) {
        return 0;
    }

    int ret = snprintf(output, length,
                       "Host bitrate %.1f / %.1f Mbps  FEC %d%%%s%s\n",
                       s.bitrateKbps / 1000.0,
                       s.maxKbps / 1000.0,
                       s.fecPercent,
                       s.hostLimited ? "  Host busy" : "",
                       s.clientLimited ? "  Decoder busy" : "");
    if (ret < 0 || ret >= length) {
        output[0] = 0;
        return 0;
    }
    return ret;
}

void AdaptiveReporter::run()
{
    // Created on this thread, so its network requests run on this thread's event loop.
    NvHTTP http(m_Computer);

    uint64_t lastSequence = 0;
    int failures = 0;

    while (!m_Stop) {
        // Wait for a new stats window (they come about once a second).
        Window w;
        for (int i = 0; i < 10 && !m_Stop; i++) {
            QThread::msleep(100);
            QMutexLocker locker(&s_Lock);
            if (s_Window.sequence != lastSequence) {
                w = s_Window;
                break;
            }
        }
        if (m_Stop || w.sequence == lastSequence) {
            continue;
        }
        lastSequence = w.sequence;

        QJsonObject report;
        if (w.totalFrames > 0) {
            report["loss_percent"] = qMin(100.0, 100.0 * w.networkDroppedFrames / w.totalFrames);
        }
        if (w.rttMs > 0) {
            report["rtt_ms"] = (double)w.rttMs;
            report["rtt_variance_ms"] = (double)w.rttVarianceMs;
        }
        if (w.decodedFrames > 0) {
            report["decode_ms"] = w.totalDecodeTimeUs / 1000.0 / w.decodedFrames;
        }
        if (w.windowUs > 0) {
            report["fps"] = qMin(1000.0, w.receivedFrames * 1000000.0 / w.windowUs);
        }

        NvHTTP::ApiResponse response = http.apiRequest("POST", "/api/v1/session/report",
                                                       QJsonDocument(report).toJson(QJsonDocument::Compact), 900);
        if (response.status == 404) {
            // The host hasn't registered the stream yet, or it just ended.
            continue;
        }
        if (response.status != 200) {
            if (++failures >= k_MaxFailures) {
                SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                            "Stopped reporting to the host: %d %s",
                            response.status,
                            response.error.isEmpty() ? response.body.constData() : qPrintable(response.error));
                break;
            }
            continue;
        }
        failures = 0;

        QJsonObject adaptive = QJsonDocument::fromJson(response.body).object()
                                   .value("stream").toObject()
                                   .value("adaptive").toObject();
        HostState state;
        if (!adaptive.isEmpty()) {
            state.valid = true;
            state.bitrateKbps = adaptive.value("bitrate_kbps").toInt();
            state.maxKbps = adaptive.value("max_kbps").toInt();
            state.fecPercent = adaptive.value("fec_percent").toInt();
            QByteArray reason = adaptive.value("last_reason").toString().toLatin1();
            strncpy(state.reason, reason.constData(), sizeof(state.reason) - 1);
            state.hostLimited = adaptive.value("host_limited").toBool();
            state.clientLimited = adaptive.value("client_limited").toBool();

            if (adaptive.value("live_bitrate").toBool()) {
                m_BitrateSamples.append(state.bitrateKbps);
                m_MaxKbps = state.maxKbps;
                m_Decreases = adaptive.value("decreases").toInt();
            }
        }

        QMutexLocker locker(&s_Lock);
        s_HostState = state;
    }

    learn();
}

void AdaptiveReporter::learn()
{
    if (m_NetworkKey.isEmpty() || m_BitrateSamples.size() < k_MinSamples || m_MaxKbps <= 0) {
        return;
    }

    // In the units this client asks in: the host's maximum is what was asked for.
    double scale = m_RequestedKbps > 0 ? (double)m_RequestedKbps / m_MaxKbps : 1.0;
    bool limited = m_Decreases > 0;
    int sustained = m_RequestedKbps > 0 ? m_RequestedKbps : m_MaxKbps;
    if (limited) {
        // The median of what the host held once the stream had settled
        QVector<int> settled = m_BitrateSamples.mid(k_SettleSamples);
        std::sort(settled.begin(), settled.end());
        sustained = (int)(settled[settled.size() / 2] * scale);
    }

    AutoTune::learn(m_HostUuid, m_NetworkKey, sustained, limited);
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Learned for this host and network (%s): %d kbps, %s",
                qPrintable(m_NetworkKey), sustained, limited ? "limited" : "never limited");
}
