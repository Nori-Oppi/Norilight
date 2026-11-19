#include "optimisepick.h"

namespace OptimisePick
{
    namespace
    {
        // Higher is more efficient (more picture per bit)
        int efficiency(int codec)
        {
            return codec == Av1 ? 2 : codec == Hevc ? 1 : 0;
        }
    }

    bool keepsUp(const Candidate& c)
    {
        if (!c.measured || c.stats.isEmpty() || c.fps <= 0) {
            return false;
        }
        return c.stats.value("renderedFps").toDouble() >= 0.9 * c.fps &&
               c.stats.value("networkDroppedPct").toDouble() <= 1.0 &&
               c.stats.value("pacerDroppedPct").toDouble() <= 2.0;
    }

    double latencyMs(const Candidate& c)
    {
        return c.stats.value("hostMs").toDouble() + c.stats.value("decodeMs").toDouble() +
               c.stats.value("renderMs").toDouble();
    }

    int best(const QVector<Candidate>& candidates, int goal)
    {
        double lowest = -1;
        for (const Candidate& c : candidates) {
            if (keepsUp(c) && (lowest < 0 || latencyMs(c) < lowest)) {
                lowest = latencyMs(c);
            }
        }
        if (lowest < 0) {
            return -1;
        }

        int bestIndex = -1;
        for (int i = 0; i < candidates.size(); i++) {
            const Candidate& c = candidates[i];
            if (!keepsUp(c)) {
                continue;
            }
            if ((goal == Balanced || goal == Off) && latencyMs(c) > lowest + 1.0) {
                continue;
            }
            if (bestIndex < 0) {
                bestIndex = i;
                continue;
            }
            const Candidate& b = candidates[bestIndex];
            bool better;
            if (goal == Performance) {
                better = latencyMs(c) < latencyMs(b) - 0.5 ||
                         (latencyMs(c) <= latencyMs(b) + 0.5 && c.kbps > b.kbps);
            }
            else {
                better = efficiency(c.codec) > efficiency(b.codec) ||
                         (efficiency(c.codec) == efficiency(b.codec) && c.kbps > b.kbps);
            }
            if (better) {
                bestIndex = i;
            }
        }
        return bestIndex;
    }
}
