#pragma once

// Norilight: times each step from choosing an app to the first frame on screen,
// and logs them as one line when the first frame is shown (roadmap N5).

#include <QElapsedTimer>
#include <QMutex>
#include <QString>

#include <SDL.h>

namespace StartTimeline
{

struct State
{
    QMutex lock;
    QElapsedTimer timer;
    QString line;
    qint64 previous = 0;
    bool active = false;
    unsigned once = 0;
};

// Steps recorded only the first time they happen in a stream start
enum Once : unsigned
{
    FrameBeforeDecoder = 1,
    DecoderCreated = 2,
    FirstFrameToDecoder = 4,
    FirstFrameDecoded = 8,
};

inline State& state()
{
    static State s;
    return s;
}

// A stream is being started: begins a new timeline.
inline void begin()
{
    State& s = state();
    QMutexLocker locker(&s.lock);
    s.timer.start();
    s.line.clear();
    s.previous = 0;
    s.active = true;
    s.once = 0;
}

// Records a step of the stream start under way, if any.
inline void mark(const char* step)
{
    State& s = state();
    QMutexLocker locker(&s.lock);
    if (!s.active) {
        return;
    }
    qint64 now = s.timer.elapsed();
    s.line += QString(" %1 %2 (+%3),").arg(step).arg(now).arg(now - s.previous);
    s.previous = now;
}

// Records a step only the first time it happens. Steps after the decoder exist only
// once it was created, so test decoders don't count.
inline void markOnce(Once which, const char* step)
{
    State& s = state();
    {
        QMutexLocker locker(&s.lock);
        if (!s.active || (s.once & which) ||
                ((which & (FirstFrameToDecoder | FirstFrameDecoded)) && !(s.once & DecoderCreated))) {
            return;
        }
        s.once |= which;
    }
    mark(step);
}

// The first frame is on screen: logs the timeline and ends it.
inline void finish()
{
    State& s = state();
    QMutexLocker locker(&s.lock);
    if (!s.active || !(s.once & DecoderCreated)) {
        return;
    }
    qint64 now = s.timer.elapsed();
    s.active = false;
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Stream start:%s first frame shown %lld (+%lld) ms",
                qPrintable(s.line), now, now - s.previous);
}

// The stream ended before its first frame
inline void cancel()
{
    State& s = state();
    QMutexLocker locker(&s.lock);
    s.active = false;
}

}
