#include "livesettings.h"

#include <QCoreApplication>

#include <algorithm>

namespace {
    QString tr(const char* text)
    {
        return QCoreApplication::translate("LiveSettingsMenu", text);
    }

    int indexOf(const QVector<int>& values, int value)
    {
        int index = values.indexOf(value);
        return index < 0 ? 0 : index;
    }
}

QVector<int> LiveSettingsMenu::bitrateSteps(int currentKbps, int maxKbps)
{
    static const int steps[] = {2000, 5000, 10000, 15000, 20000, 30000, 40000, 50000, 60000,
                                80000, 100000, 120000, 150000, 200000, 300000, 500000};
    QVector<int> values;
    for (int kbps : steps) {
        if (kbps <= maxKbps) {
            values.append(kbps);
        }
    }
    if (currentKbps > 0 && !values.contains(currentKbps)) {
        values.append(currentKbps);
        std::sort(values.begin(), values.end());
    }
    return values;
}

QVector<int> LiveSettingsMenu::fecSteps(int currentPercent)
{
    QVector<int> values;
    for (int percent = 5; percent <= 50; percent += 5) {
        values.append(percent);
    }
    if (currentPercent > 0 && !values.contains(currentPercent)) {
        values.append(currentPercent);
        std::sort(values.begin(), values.end());
    }
    return values;
}

LiveSettingsMenu::LiveSettingsMenu(const Start& start)
{
    Item bitrate;
    bitrate.row = Bitrate;
    bitrate.label = tr("Bitrate");
    bitrate.values = bitrateSteps(start.bitrateKbps, std::max(start.maxBitrateKbps, start.bitrateKbps));
    bitrate.current = bitrate.pending = indexOf(bitrate.values, start.bitrateKbps);
    m_Items.append(bitrate);

    Item fec;
    fec.row = ErrorCorrection;
    fec.label = tr("Error correction");
    fec.values = fecSteps(start.fecPercent);
    fec.current = fec.pending = indexOf(fec.values, start.fecPercent);
    m_Items.append(fec);

    if (start.encoderPreset) {
        Item preset;
        preset.row = EncoderPreset;
        preset.label = tr("Encoder preset");
        preset.values = {1, 2, 3};
        preset.current = preset.pending = indexOf(preset.values, start.goal >= 1 && start.goal <= 3 ? start.goal : 2);
        m_Items.append(preset);
    }
}

bool LiveSettingsMenu::hasRow(Row row) const
{
    return std::any_of(m_Items.begin(), m_Items.end(), [row](const Item& item) { return item.row == row; });
}

LiveSettingsMenu::Result LiveSettingsMenu::key(Key key)
{
    Item& item = m_Items[m_Selected];
    switch (key) {
    case KeyUp:
        m_Selected = (m_Selected + m_Items.size() - 1) % m_Items.size();
        return Handled;
    case KeyDown:
        m_Selected = (m_Selected + 1) % m_Items.size();
        return Handled;
    case KeyLeft:
        item.pending = std::max(0, item.pending - 1);
        return Handled;
    case KeyRight:
        item.pending = std::min((int)item.values.size() - 1, item.pending + 1);
        return Handled;
    case KeyEnter:
        return changes().isEmpty() ? Close : Apply;
    case KeyEscape:
        revert();
        return Close;
    case KeyOther:
        break;
    }
    return Ignored;
}

QString LiveSettingsMenu::valueText(const Item& item, int index) const
{
    int value = item.values[index];
    switch (item.row) {
    case Bitrate:
        return value % 1000 == 0 ? tr("%1 Mbps").arg(value / 1000) : tr("%1 Mbps").arg(value / 1000.0, 0, 'f', 1);
    case ErrorCorrection:
        return tr("%1 %").arg(value);
    case EncoderPreset:
        return value == 1 ? tr("Performance") : value == 3 ? tr("Quality") : tr("Balanced");
    }
    return QString::number(value);
}

QString LiveSettingsMenu::text() const
{
    QString text = tr("Stream settings") + "\n";
    for (int i = 0; i < m_Items.size(); i++) {
        const Item& item = m_Items[i];
        QString value = valueText(item, item.pending);
        if (i == m_Selected) {
            value = QString("< %1 >").arg(value);
        }
        if (item.pending != item.current) {
            value += " *";
        }
        text += QString("%1 %2  %3\n").arg(i == m_Selected ? ">" : " ", item.label.leftJustified(18), value);
    }
    text += tr("Enter apply, Esc close");
    return text;
}

QJsonObject LiveSettingsMenu::changes() const
{
    QJsonObject body;
    for (const Item& item : m_Items) {
        if (item.pending == item.current) {
            continue;
        }
        int value = item.values[item.pending];
        switch (item.row) {
        case Bitrate:
            body["bitrate_kbps"] = value;
            break;
        case ErrorCorrection:
            body["fec_percent"] = value;
            break;
        case EncoderPreset:
            body["tuning"] = value == 1 ? "performance" : value == 3 ? "quality" : "balanced";
            break;
        }
    }
    return body;
}

void LiveSettingsMenu::applied()
{
    for (Item& item : m_Items) {
        item.current = item.pending;
    }
}

void LiveSettingsMenu::revert()
{
    for (Item& item : m_Items) {
        item.pending = item.current;
    }
}

int LiveSettingsMenu::bitrateKbps() const
{
    const Item& item = m_Items[0];
    return item.values[item.current];
}

int LiveSettingsMenu::fecPercent() const
{
    const Item& item = m_Items[1];
    return item.values[item.current];
}

int LiveSettingsMenu::goal() const
{
    for (const Item& item : m_Items) {
        if (item.row == EncoderPreset) {
            return item.values[item.current];
        }
    }
    return 0;
}
