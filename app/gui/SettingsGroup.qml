import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

import "."

// Norilight: one settings page: its title, then its SettingsCards. The page
// is named in the sidebar too, so it has no description; a page that needs
// explaining (Profiles) puts it behind an (i) button next to the title.
Column {
    id: group

    // Which sidebar section this page belongs to
    property string section: ""
    property string title: ""
    // Longer explanation behind an (i) button next to the title
    property string info: ""
    property bool expanded: false
    // Room kept free on the right of the title for the profile button
    property real titleReserve: 0

    default property alias content: body.data

    spacing: 0

    Item {
        width: parent.width
        height: 44

        Row {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - group.titleReserve
            spacing: 6

            Label {
                id: titleLabel
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - (titleInfoButton.visible ? titleInfoButton.width + parent.spacing : 0))
                text: group.title
                font.pointSize: Theme.fontHeading
                font.weight: Font.Medium
                font.letterSpacing: -0.3
                color: Theme.textHeading
                elide: Text.ElideRight
            }

            ToolButton {
                id: titleInfoButton
                anchors.verticalCenter: parent.verticalCenter
                visible: group.info !== ""
                width: 32
                height: 32
                padding: 0
                topInset: 0
                bottomInset: 0
                leftInset: 0
                rightInset: 0
                display: AbstractButton.IconOnly
                icon.source: "qrc:/res/info_outline.svg"
                icon.width: 20
                icon.height: 20
                icon.color: group.expanded ? Material.accent : Theme.textTertiary
                background: Rectangle {
                    radius: width / 2
                    color: titleInfoButton.hovered ? Theme.cardHover : "transparent"
                    border.width: titleInfoButton.visualFocus ? 2 : 0
                    border.color: Material.accent
                }
                onClicked: group.expanded = !group.expanded
                Keys.onReturnPressed: group.expanded = !group.expanded
                Keys.onEnterPressed: group.expanded = !group.expanded

                Accessible.name: group.expanded ? qsTr("Hide details") : qsTr("Show details")
                ToolTip.text: Accessible.name
                ToolTip.delay: 600
                ToolTip.visible: hovered
            }
        }
    }

    Label {
        width: Math.min(parent.width, 620)
        visible: group.expanded && group.info !== ""
        topPadding: 2
        text: group.info
        font.pointSize: Theme.fontDetail
        lineHeight: 1.15
        color: Theme.textSecondary
        wrapMode: Text.Wrap
    }


    Item {
        width: 1
        height: 12
    }

    Column {
        id: body
        width: parent.width
        spacing: Theme.cardGap
    }
}
