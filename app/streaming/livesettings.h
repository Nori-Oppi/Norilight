#pragma once

#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QVector>

// Norilight (N9): the stream settings menu, drawn in the status overlay while a stream to a
// Norishine host runs (Ctrl+Alt+Shift+O). It changes the running stream without reconnecting:
// bitrate, error correction and the encoder preset through the host's
// POST /api/v1/session/settings (feature "session.settings").
//
// This is the menu's state only (no SDL, no network), so it can be tested on its own.
class LiveSettingsMenu
{
public:
    enum Row {
        Bitrate,
        ErrorCorrection,
        EncoderPreset,
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

    // Values offered for each row
    static QVector<int> bitrateSteps(int currentKbps, int maxKbps);
    static QVector<int> fecSteps(int currentPercent);

private:
    struct Item {
        Row row;
        QString label;
        QVector<int> values;
        int current = 0;  // index into values
        int pending = 0;
    };

    QString valueText(const Item& item, int index) const;

    QVector<Item> m_Items;
    int m_Selected = 0;
};
