import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

// Norilight: one block of settings with a real heading and a plain-language
// description, instead of a framed GroupBox with a coloured title.
GroupBox {
    id: group

    // Which sidebar section this block belongs to
    property string section: ""
    // One sentence telling the user what lives here
    property string description: ""
    // Second-level block inside a section (smaller heading, extra space above)
    property bool subheading: false

    padding: 0
    topPadding: header.height + (subheading ? 14 : 18)
    bottomPadding: 8

    label: Column {
        id: header
        x: 0
        width: group.width
        spacing: 6
        topPadding: group.subheading ? 22 : 0

        Label {
            width: parent.width
            text: group.title
            font.family: "Segoe UI Variable Display"
            font.pointSize: group.subheading ? 14 : 21
            font.weight: group.subheading ? Font.DemiBold : Font.Medium
            font.letterSpacing: group.subheading ? 0 : -0.3
            color: "#F1F1F3"
            wrapMode: Text.Wrap
        }

        Label {
            width: Math.min(parent.width, 620)
            visible: text !== ""
            text: group.description
            font.pointSize: 10.5
            lineHeight: 1.15
            color: "#A3A3AB"
            wrapMode: Text.Wrap
        }

        Item { width: 1; height: 6 }

        Rectangle {
            width: parent.width
            height: 1
            color: group.subheading ? "#3A3A40" : "#45454D"
        }
    }

    background: Item {}
}
