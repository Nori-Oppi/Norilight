import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import DisplayManager 1.0

import "."

ComboBox {
    id: selector
    property string monitorKey: ""
    property string monitorLabel: ""
    signal selected(string key, string label)
    textRole: "text"

    indicator: ComboIndicator {
        control: selector
    }

    // Long choices end in "…" instead of being cut off mid-letter
    contentItem: Label {
        leftPadding: selector.Material.textFieldHorizontalPadding
        rightPadding: 4
        verticalAlignment: Text.AlignVCenter
        text: selector.displayText
        font: selector.font
        color: selector.enabled ? Theme.textPrimary : Theme.textDisabled
        elide: Text.ElideRight
    }

    // Include a missing display so opening this control never clears a saved target.
    model: {
        var options = [{ key: "", label: "", text: qsTr("Current monitor") }]
        var monitors = DisplayManager.monitors
        var found = monitorKey === ""
        for (var i = 0; i < monitors.length; ++i) {
            var m = monitors[i]
            options.push({ key: m.key, label: m.label,
                           text: qsTr("Monitor %1: %2").arg(m.number).arg(m.label) })
            found = found || m.key === monitorKey
        }
        if (!found) {
            options.push({ key: monitorKey, label: monitorLabel,
                           text: qsTr("%1 (not connected)").arg(monitorLabel || qsTr("Saved monitor")) })
        }
        return options
    }
    currentIndex: {
        for (var i = 0; i < model.length; ++i) {
            if (model[i].key === monitorKey) return i
        }
        return 0
    }
    onActivated: function(index) {
        var choice = model[index]
        selected(choice.key, choice.label)
    }
}
