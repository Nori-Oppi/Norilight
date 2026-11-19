#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#include "optimisepick.h"

class ComputerModel;
class NvComputer;
class Session;
class StreamingPreferences;

// Norilight (roadmap N6): the profile's Optimise button. Short test streams of the host's
// test picture, one per candidate setting, measured with the stream's own figures
// (FFmpegVideoDecoder::getSessionStats):
//
//   1. each codec both PCs handle, at the profile's resolution, frame rate and bitrate
//   2. if none keeps up: a lower frame rate, then 1080p
//   3. higher bitrates with the best codec, while they keep up
//
// The picks are saved to the active profile, and the values they replaced are kept for
// Undo. The host's own encoder test (POST /api/v1/optimise) is run from QML. How it
// decides: the Norilight-Guide wiki page, "Optimise".
class Optimiser : public QObject
{
    Q_OBJECT

public:
    explicit Optimiser(QObject* parent = nullptr);

    Q_PROPERTY(QVariantList results READ results NOTIFY changed)
    Q_PROPERTY(int done READ doneCount NOTIFY changed)
    Q_PROPERTY(int planned READ plannedCount NOTIFY changed)
    Q_PROPERTY(QVariantMap pick READ pick NOTIFY changed)
    Q_PROPERTY(QVariantMap current READ current NOTIFY changed)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY changed)

    // Plans the test streams for this host. Returns an error to show, or "" when ready.
    Q_INVOKABLE QString begin(ComputerModel* model, int computerIndex);

    // The next test stream (ends by itself), or null when finished. Its stats go to record().
    Q_INVOKABLE Session* nextSession();

    // A test stream's figures (Session::streamStatsReady; empty when it didn't stream)
    Q_INVOKABLE void record(const QVariantMap& stats);

    // Saves the pick to the active profile, keeping what it replaces for undo()
    Q_INVOKABLE void save();
    Q_INVOKABLE void undo();

    QVariantList results() const;
    int doneCount() const { return m_Done; }
    int plannedCount() const { return m_Candidates.size(); }
    QVariantMap pick() const;
    QVariantMap current() const;
    bool canUndo() const;

    using Candidate = OptimisePick::Candidate;

signals:
    void changed();

private:
    void planMore();

    NvComputer* m_Computer = nullptr;
    int m_TestAppId = 0;
    QVector<Candidate> m_Candidates;
    int m_Done = 0;
    int m_Phase = 0;
    int m_Goal = 0;
    Candidate m_Profile;
    QVector<StreamingPreferences*> m_Prefs;
};
