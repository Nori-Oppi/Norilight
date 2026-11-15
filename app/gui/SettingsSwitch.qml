import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import "."

// Norilight: a SettingsRow with an on/off switch. Clicking anywhere on the
// row flips it, and Enter works as well as Space (and a controller's A).
SettingsRow {
    id: switchRow

    property alias checked: toggle.checked
    signal toggled()

    function flip() {
        if (available) {
            toggle.toggle()
            toggled()
        }
    }

    focusTarget: toggle
    onRowClicked: flip()

    // Controls added by a page (say, a combo box) go before the switch, so the
    // switch is always last and lines up with the switches on other rows
    Component.onCompleted: {
        toggle.parent = null
        toggle.parent = controlArea
    }

    Switch {
        id: toggle
        enabled: switchRow.available
        padding: 0
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0
        // The Material indicator sizes itself with width/height, not implicit sizes
        Layout.preferredWidth: indicator ? indicator.width : 52
        Layout.preferredHeight: indicator ? indicator.height : 32
        Accessible.name: switchRow.text

        onToggled: switchRow.toggled()
        Keys.onReturnPressed: switchRow.flip()
        Keys.onEnterPressed: switchRow.flip()
    }
}
