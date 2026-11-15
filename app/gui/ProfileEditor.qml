import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

import ProfileManager 1.0
import "."

// Norilight: the form for a new profile - a name and what to start it from.
// Used by the first-run wizard and by "New profile" in the profile menu.
Column {
    id: editor

    property alias name: nameField.text
    property string startFrom: "gaming"
    property string monitorKey: ""
    property string monitorLabel: ""

    // Once the user types a name, picking another starting point keeps it
    property bool nameEdited: false

    readonly property bool nameInUse: name.trim() !== "" && ProfileManager.nameTaken(name)
    readonly property bool valid: name.trim() !== "" && !nameInUse

    // Enter was pressed in the name field
    signal accepted()

    readonly property var options: {
        var list = [
            {
                key: "gaming",
                kind: "gaming",
                title: qsTr("Gaming"),
                detail: qsTr("Lowest latency: fullscreen at your display's refresh rate, V-Sync off, and the mouse locked to the game.")
            },
            {
                key: "work",
                kind: "work",
                title: qsTr("Work and desktop"),
                detail: qsTr("A borderless window at 60 FPS. The cursor moves freely between the stream and your other windows and monitors.")
            },
            {
                key: "default",
                kind: "custom",
                title: qsTr("Standard"),
                detail: qsTr("Norilight's default settings. A balanced starting point to adjust yourself.")
            }
        ]

        if (ProfileManager.hasCurrentSettings) {
            list.push(ProfileManager.setupNeeded ? {
                key: "current",
                kind: "custom",
                title: qsTr("My current settings"),
                detail: qsTr("Keep the settings you already use in Norilight.")
            } : {
                key: "current",
                kind: "custom",
                title: qsTr("Copy of \"%1\"").arg(ProfileManager.activeName),
                detail: qsTr("Start with the settings of the profile you're using now.")
            })
        }

        if (ProfileManager.hasMoonlightSettings) {
            list.push({
                key: "moonlight",
                kind: "custom",
                title: qsTr("My Moonlight settings"),
                detail: qsTr("Bring over the settings from the Moonlight client on this PC.")
            })
        }

        return list
    }

    function suggestedName(key) {
        if (key === "gaming") {
            return qsTr("Gaming")
        }
        if (key === "work") {
            return qsTr("Work")
        }
        if (key === "current") {
            return ProfileManager.setupNeeded ? qsTr("My settings")
                                              : qsTr("%1 copy").arg(ProfileManager.activeName)
        }
        if (key === "moonlight") {
            return qsTr("Moonlight")
        }
        return qsTr("Standard")
    }

    function choose(key) {
        startFrom = key
        monitorKey = ""
        monitorLabel = ""
        if (key === "current") {
            var profiles = ProfileManager.profiles
            for (var i = 0; i < profiles.length; ++i) {
                if (profiles[i].active) {
                    monitorKey = profiles[i].monitorKey || ""
                    monitorLabel = profiles[i].monitorLabel || ""
                }
            }
        }
        if (!nameEdited) {
            nameField.text = ProfileManager.suggestName(suggestedName(key))
        }
    }

    // Start over with the starting point that suits this user best
    function reset() {
        nameEdited = false
        if (ProfileManager.setupNeeded && ProfileManager.hasCurrentSettings) {
            choose("current")
        }
        else if (ProfileManager.setupNeeded && ProfileManager.hasMoonlightSettings) {
            choose("moonlight")
        }
        else {
            choose("gaming")
        }
    }

    function focusName() {
        nameField.forceActiveFocus(Qt.TabFocusReason)
        nameField.selectAll()
    }

    spacing: 6

    Label {
        text: qsTr("Profile name")
        font.pointSize: Theme.fontLabel
    }

    TextField {
        id: nameField
        width: Math.min(parent.width, 320)
        font.pointSize: Theme.fontBody
        maximumLength: 40
        selectByMouse: true
        onTextEdited: editor.nameEdited = true
        Keys.onReturnPressed: editor.accepted()
        Keys.onEnterPressed: editor.accepted()
    }

    Label {
        visible: editor.nameInUse
        text: qsTr("You already have a profile with this name.")
        font.pointSize: Theme.fontDetail
        color: Theme.statusError
    }

    Label {
        topPadding: 12
        text: qsTr("Target monitor")
        font.pointSize: Theme.fontLabel
    }

    MonitorSelector {
        width: parent.width
        monitorKey: editor.monitorKey
        monitorLabel: editor.monitorLabel
        onSelected: function(key, label) {
            editor.monitorKey = key
            editor.monitorLabel = label
        }
    }

    Label {
        topPadding: 12
        text: qsTr("Start with")
        font.pointSize: Theme.fontLabel
    }

    Label {
        width: parent.width
        bottomPadding: 4
        text: qsTr("This only sets the starting values. You can change every setting of the profile afterwards.")
        font.pointSize: Theme.fontDetail
        color: Theme.textSecondary
        wrapMode: Text.Wrap
    }

    Repeater {
        model: editor.options

        delegate: ItemDelegate {
            id: option

            readonly property bool selected: editor.startFrom === modelData.key

            width: editor.width
            topPadding: 10
            bottomPadding: 10
            leftPadding: 14
            rightPadding: 14
            hoverEnabled: true
            focusPolicy: Qt.TabFocus

            onClicked: editor.choose(modelData.key)
            Keys.onReturnPressed: editor.choose(modelData.key)
            Keys.onEnterPressed: editor.choose(modelData.key)

            background: Rectangle {
                radius: 6
                color: option.selected ? Theme.navSelected
                                       : (option.hovered || option.visualFocus ? Theme.cardHover : Theme.card)
                border.width: option.selected ? 2 : 1
                border.color: option.selected ? Material.accent : Theme.border
            }

            contentItem: Row {
                spacing: 14

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Theme.profileIcon(modelData.kind)
                    sourceSize.width: 22
                    sourceSize.height: 22
                    opacity: option.selected ? 1.0 : 0.7
                }

                Column {
                    width: parent.width - 36
                    spacing: 2

                    Label {
                        width: parent.width
                        text: modelData.title
                        font.pointSize: Theme.fontBody
                        font.weight: option.selected ? Font.DemiBold : Font.Normal
                        color: Theme.textHeading
                        elide: Text.ElideRight
                    }

                    Label {
                        width: parent.width
                        text: modelData.detail
                        font.pointSize: Theme.fontSmall
                        color: Theme.textSecondary
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
