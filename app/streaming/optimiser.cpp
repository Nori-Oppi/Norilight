#include "optimiser.h"

#include "backend/nvcomputer.h"
#include "gui/computermodel.h"
#include "settings/profilemanager.h"
#include "settings/streamingpreferences.h"
#include "streaming/session.h"

#include <QSettings>

#include "SDL_compat.h"

#include <Limelight.h>

static_assert(OptimisePick::H264 == StreamingPreferences::VCC_FORCE_H264 &&
              OptimisePick::Hevc == StreamingPreferences::VCC_FORCE_HEVC &&
              OptimisePick::Av1 == StreamingPreferences::VCC_FORCE_AV1, "codec values");
static_assert(OptimisePick::Off == StreamingPreferences::TG_OFF &&
              OptimisePick::Performance == StreamingPreferences::TG_PERFORMANCE &&
              OptimisePick::Balanced == StreamingPreferences::TG_BALANCED &&
              OptimisePick::Quality == StreamingPreferences::TG_QUALITY, "goal values");

namespace
{
    constexpr int kTestSeconds = 10;
    constexpr int kMaxKbps = 150000;
    const char* kUndoGroup = "optimiseundo";

    QString codecName(int codec)
    {
        switch (codec) {
        case StreamingPreferences::VCC_FORCE_AV1:
            return "AV1";
        case StreamingPreferences::VCC_FORCE_HEVC:
            return "HEVC";
        case StreamingPreferences::VCC_FORCE_H264:
            return "H.264";
        default:
            return QObject::tr("Automatic");
        }
    }

    QVariantMap toMap(const Optimiser::Candidate& c)
    {
        QVariantMap m;
        m["codec"] = codecName(c.codec);
        m["width"] = c.width;
        m["height"] = c.height;
        m["fps"] = c.fps;
        m["mbps"] = c.kbps / 1000.0;
        m["measured"] = c.measured;
        m["streamed"] = !c.stats.isEmpty();
        m["keepsUp"] = OptimisePick::keepsUp(c);
        m["latencyMs"] = c.stats.isEmpty() ? QVariant() : QVariant(OptimisePick::latencyMs(c));
        m["shownFps"] = c.stats.value("renderedFps");
        return m;
    }

    QString undoGroup()
    {
        QString group = ProfileManager::settingsGroup();
        return group.isEmpty() ? QString(kUndoGroup) : group + "/" + kUndoGroup;
    }
}

Optimiser::Optimiser(QObject* parent)
    : QObject(parent)
{
}

QString Optimiser::begin(ComputerModel* model, int computerIndex)
{
    m_Candidates.clear();
    m_Done = 0;
    m_Phase = 0;
    m_Computer = model ? model->computerAt(computerIndex) : nullptr;
    if (m_Computer == nullptr) {
        return tr("Host not found");
    }

    {
        QReadLocker lock(&m_Computer->lock);
        m_TestAppId = m_Computer->norishineOptimiseAppId;
        if (m_TestAppId == 0) {
            return tr("This host can't run test streams");
        }
        if (m_Computer->currentGameId != 0) {
            return tr("Quit the running app first");
        }
    }

    StreamingPreferences* prefs = StreamingPreferences::get();
    m_Goal = prefs->tuningGoal;
    m_Profile.codec = prefs->videoCodecConfig;
    m_Profile.width = prefs->width;
    m_Profile.height = prefs->height;
    m_Profile.fps = prefs->fps;
    m_Profile.kbps = prefs->bitrateKbps;

    int codecs;
    {
        QReadLocker lock(&m_Computer->lock);
        codecs = m_Computer->serverCodecModeSupport;
    }

    // 1. Each codec at the profile's resolution, frame rate and bitrate
    QVector<int> tried = {StreamingPreferences::VCC_FORCE_H264};
    if (codecs & SCM_HEVC) {
        tried.append(StreamingPreferences::VCC_FORCE_HEVC);
    }
    if (codecs & SCM_AV1_MAIN8) {
        tried.append(StreamingPreferences::VCC_FORCE_AV1);
    }
    for (int codec : tried) {
        Candidate c = m_Profile;
        c.codec = codec;
        m_Candidates.append(c);
    }
    emit changed();
    return QString();
}

void Optimiser::planMore()
{
    int bestIndex = OptimisePick::best(m_Candidates, m_Goal);

    if (m_Phase == 0) {
        m_Phase = 1;
        if (bestIndex < 0) {
            // 2. Nothing kept up: a lower frame rate, then 1080p, with H.264 and the best codec
            Candidate c = m_Profile;
            c.codec = StreamingPreferences::VCC_FORCE_H264;
            if (c.fps > 60) {
                c.fps = 60;
                m_Candidates.append(c);
            }
            if (c.width * c.height > 1920 * 1080) {
                c.width = 1920;
                c.height = 1080;
                m_Candidates.append(c);
            }
            if (m_Candidates.size() > m_Done) {
                return;
            }
        }
    }

    if (m_Phase == 1 && bestIndex >= 0) {
        // 3. Higher bitrates with the best one, while they keep up
        const Candidate& b = m_Candidates[bestIndex];
        if (bestIndex == m_Candidates.size() - 1 || m_Candidates.last().kbps <= b.kbps) {
            Candidate c = b;
            c.measured = false;
            c.stats.clear();
            c.kbps = qMin(kMaxKbps, b.kbps * 3 / 2 / 1000 * 1000);
            int higher = 0;
            for (const Candidate& x : m_Candidates) {
                higher += x.kbps > m_Profile.kbps ? 1 : 0;
            }
            if (c.kbps > b.kbps && higher < 2) {
                m_Candidates.append(c);
            }
        }
    }
}

Session* Optimiser::nextSession()
{
    if (m_Done >= m_Candidates.size()) {
        planMore();
        emit changed();
    }
    if (m_Computer == nullptr || m_Done >= m_Candidates.size()) {
        int bestIndex = OptimisePick::best(m_Candidates, m_Goal);
        if (bestIndex >= 0) {
            const Candidate& b = m_Candidates[bestIndex];
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Optimise: finished, best %s %dx%d %d fps %d kbps",
                        qPrintable(codecName(b.codec)), b.width, b.height, b.fps, b.kbps);
        }
        else {
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Optimise: finished, nothing kept up");
        }
        return nullptr;
    }

    const Candidate& c = m_Candidates[m_Done];
    StreamingPreferences* prefs = StreamingPreferences::createCopy(this);
    prefs->videoCodecConfig = static_cast<StreamingPreferences::VideoCodecConfig>(c.codec);
    prefs->width = c.width;
    prefs->height = c.height;
    prefs->fps = c.fps;
    prefs->bitrateKbps = c.kbps;
    prefs->autoAdjustBitrate = false;
    prefs->tuningGoal = StreamingPreferences::TG_OFF;
    prefs->enableHdr = false;
    prefs->postStreamSummary = false;
    prefs->quitAppAfter = false;
    m_Prefs.append(prefs);

    NvApp app;
    app.id = m_TestAppId;
    app.name = tr("Optimise test");
    Session* session = new Session(m_Computer, app, prefs);
    session->setTestSeconds(kTestSeconds);
    return session;
}

void Optimiser::record(const QVariantMap& stats)
{
    if (m_Done < m_Candidates.size()) {
        Candidate& c = m_Candidates[m_Done];
        c.measured = true;
        c.stats = stats;
        m_Done++;
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Optimise: %s %dx%d %d fps %d kbps: %s",
                    qPrintable(codecName(c.codec)), c.width, c.height, c.fps, c.kbps,
                    stats.isEmpty() ? "didn't stream"
                                    : qPrintable(QString("%1 fps shown, %2 ms, %3 % lost, %4 % dropped, %5")
                                                 .arg(stats.value("renderedFps").toDouble(), 0, 'f', 1)
                                                 .arg(OptimisePick::latencyMs(c), 0, 'f', 2)
                                                 .arg(stats.value("networkDroppedPct").toDouble(), 0, 'f', 2)
                                                 .arg(stats.value("pacerDroppedPct").toDouble(), 0, 'f', 2)
                                                 .arg(OptimisePick::keepsUp(c) ? "keeps up" : "falls behind")));
        emit changed();
    }
}

QVariantList Optimiser::results() const
{
    QVariantList list;
    int bestIndex = OptimisePick::best(m_Candidates, m_Goal);
    for (int i = 0; i < m_Done; i++) {
        QVariantMap m = toMap(m_Candidates[i]);
        m["best"] = i == bestIndex;
        list.append(m);
    }
    return list;
}

QVariantMap Optimiser::pick() const
{
    int bestIndex = OptimisePick::best(m_Candidates, m_Goal);
    return bestIndex < 0 ? QVariantMap() : toMap(m_Candidates[bestIndex]);
}

QVariantMap Optimiser::current() const
{
    return toMap(m_Profile);
}

void Optimiser::save()
{
    int bestIndex = OptimisePick::best(m_Candidates, m_Goal);
    if (bestIndex < 0) {
        return;
    }
    const Candidate& b = m_Candidates[bestIndex];
    StreamingPreferences* prefs = StreamingPreferences::get();

    {
        QSettings settings;
        settings.beginGroup(undoGroup());
        settings.setValue("codec", static_cast<int>(prefs->videoCodecConfig));
        settings.setValue("width", prefs->width);
        settings.setValue("height", prefs->height);
        settings.setValue("fps", prefs->fps);
        settings.setValue("kbps", prefs->bitrateKbps);
        settings.setValue("autoadjust", prefs->autoAdjustBitrate);
    }

    prefs->videoCodecConfig = static_cast<StreamingPreferences::VideoCodecConfig>(b.codec);
    prefs->width = b.width;
    prefs->height = b.height;
    prefs->fps = b.fps;
    prefs->bitrateKbps = b.kbps;
    prefs->autoAdjustBitrate = false;
    prefs->save();
    emit prefs->displayModeChanged();
    emit prefs->bitrateChanged();
    emit prefs->autoAdjustBitrateChanged();
    emit prefs->videoCodecConfigChanged();
    emit changed();
}

bool Optimiser::canUndo() const
{
    QSettings settings;
    settings.beginGroup(undoGroup());
    return settings.contains("codec");
}

void Optimiser::undo()
{
    QSettings settings;
    settings.beginGroup(undoGroup());
    if (!settings.contains("codec")) {
        return;
    }
    StreamingPreferences* prefs = StreamingPreferences::get();
    prefs->videoCodecConfig = static_cast<StreamingPreferences::VideoCodecConfig>(settings.value("codec").toInt());
    prefs->width = settings.value("width").toInt();
    prefs->height = settings.value("height").toInt();
    prefs->fps = settings.value("fps").toInt();
    prefs->bitrateKbps = settings.value("kbps").toInt();
    prefs->autoAdjustBitrate = settings.value("autoadjust").toBool();
    settings.remove("");
    settings.endGroup();
    prefs->save();
    emit prefs->displayModeChanged();
    emit prefs->bitrateChanged();
    emit prefs->autoAdjustBitrateChanged();
    emit prefs->videoCodecConfigChanged();
    emit changed();
}
