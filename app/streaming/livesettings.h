#pragma once

#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QVector>

// Norilight (N9): the stream settings menu, drawn in the status overlay while a stream to a
// Norishine host runs (Ctrl+Alt+Shift+O). It changes the running stream without reconnecting:
// bitrate, error correction and the encoder preset through the host's
// POST /api/v1/session/settings (feature "session.settings"); resolution, frame rate and
// codec too on hosts with feature "session.video" (the decoder is rebuilt when the host's
// new format arrives).
//
// This is the menu's state only (no SDL, no network), so it can be tested on its own.
class LiveSettingsMenu
{
public:
    enum Row {
        Bitrate,
        ErrorCorrection,
        EncoderPreset,
        Resolution,
        FrameRate,
        Codec,
    };

    enum Key {
        KeyUp,
        KeyDown,
        KeyLeft,
        KeyRight,
        KeyEnter,
        KeyEscape,
        KeyOther,
    };

    enum Result {
        Ignored,   // not the menu's key: pass it on to the host
        Handled,   // the menu changed; redraw it
        Apply,     // send changes() to the host
        Close,     // close the menu
    };

    struct Start {
        int bitrateKbps = 20000;   // what this client asked for (before the host's allowances)
        int maxBitrateKbps = 150000;
        int fecPercent = 20;
        int goal = 2;              // 1 Performance, 2 Balanced, 3 Quality (AutoTune::Goal + 1)
        bool encoderPreset = true; // the host takes tuning goals (feature "tuning")

        bool videoFormat = false;  // the host changes size, frame rate and codec (feature "session.video")
        int width = 1920;
        int height = 1080;
        int fps = 60;
        int codec = 1;             // 0 H.264, 1 HEVC, 2 AV1
        QVector<int> codecs = {0}; // codecs both sides can stream now
    };

    explicit LiveSettingsMenu(const Start& start);

    Result key(Key key);

    // The menu as overlay text
    QString text() const;

    // The changed settings, as the host's request body; empty when nothing changed
    QJsonObject changes() const;

    // The host took the changes: they're the current values now
    void applied();

    // Puts the changes back
    void revert();

    bool hasRow(Row row) const;
    int selectedRow() const { return m_Selected; }

    // Values now (after applied()), for tests and the caller
    int bitrateKbps() const;
    int fecPercent() const;
    int goal() const;
    int width() const;
    int height() const;
    int fps() const;
    int codec() const;

    // Values offered for each row
    static QVector<int> bitrateSteps(int currentKbps, int maxKbps);
    static QVector<int> fecSteps(int currentPercent);
    static QVector<int> resolutionSteps(int width, int height);  // (width << 16) | height
    static QVector<int> fpsSteps(int currentFps);

private:
    struct Item {
        Row row;
        QString label;
        QVector<int> values;
        int current = 0;  // index into values
        int pending = 0;
    };

    QString valueText(const Item& item, int index) const;
    int value(Row row, int fallback) const;

    QVector<Item> m_Items;
    int m_Selected = 0;
};
