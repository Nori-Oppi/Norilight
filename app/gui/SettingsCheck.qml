import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

// Norilight: a checkbox whose name is followed by a short, always-visible line
// explaining what the setting actually does (no need to hover for a tooltip).
CheckBox {
    id: control

    property string detail: ""

    hoverEnabled: true
    topPadding: 7
    bottomPadding: 7

    contentItem: Column {
        leftPadding: control.indicator && !control.mirrored ? control.indicator.width + control.spacing : 0
        rightPadding: control.indicator && control.mirrored ? control.indicator.width + control.spacing : 0
        spacing: 2

        Label {
            id: nameLabel
            width: parent.width - parent.leftPadding - parent.rightPadding
            text: control.text
            font: control.font
            color: control.enabled ? "#ECECEE" : "#76767E"
            wrapMode: Text.Wrap
        }

        Label {
            width: nameLabel.width
            visible: control.detail !== ""
            text: control.detail
            font.pointSize: 10
            lineHeight: 1.12
            color: control.enabled ? "#9D9DA6" : "#62626A"
            wrapMode: Text.Wrap
        }
    }

    // Keep the box level with the first line of the name, not centred on the
    // whole two-line block.
    Component.onCompleted: {
        if (indicator) {
            indicator.y = Qt.binding(function() {
                return control.topPadding + Math.max(0, (nameLabel.height - indicator.height) / 2)
            })
        }
    }
}
