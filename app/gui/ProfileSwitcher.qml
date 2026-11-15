import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

import ProfileManager 1.0
import "."

// Quick profile switching. Management lives on the Profiles settings page.
Button {
    id: switcher

    // On the coloured toolbar the button has no card behind it
    property bool onToolbar: false
    // Icon only, for narrow windows
    property bool showName: true

    implicitHeight: 36
    leftPadding: 10
    rightPadding: 6
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    activeFocusOnTab: true

    // Keyboard and gamepad users start inside the list; mouse users don't
    // get a focus highlight they didn't ask for
    property bool openedByKeyboard: false
    function openPopup(byKeyboard) {
        openedByKeyboard = byKeyboard
        profilePopup.open()
    }

    onClicked: profilePopup.visible ? profilePopup.close() : openPopup(false)
    Keys.onReturnPressed: openPopup(true)
    Keys.onEnterPressed: openPopup(true)
    Keys.onDownPressed: openPopup(true)

    ToolTip.text: qsTr("Profile: %1. Each profile has its own settings.").arg(ProfileManager.activeName)
    ToolTip.delay: 600
    ToolTip.visible: hovered && !profilePopup.visible

    background: Rectangle {
        radius: 6
        color: switcher.onToolbar ? (switcher.hovered || switcher.visualFocus || profilePopup.visible ? "#26FFFFFF" : "transparent")
                                  : (switcher.hovered || switcher.visualFocus || profilePopup.visible ? Theme.cardHover : Theme.card)
        border.width: switcher.onToolbar ? 0 : 1
        border.color: Theme.border
    }

    contentItem: Row {
        spacing: 8

        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: Theme.profileIcon(ProfileManager.activeKind)
            sourceSize.width: 18
            sourceSize.height: 18
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: switcher.showName
            // Leave long names room without letting them push the page around
            width: Math.min(implicitWidth, 170)
            text: ProfileManager.activeName
            font.pointSize: Theme.fontBody
            color: Theme.textHeading
            elide: Text.ElideRight
        }

        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: "qrc:/res/expand_more.svg"
            sourceSize.width: 18
            sourceSize.height: 18
            opacity: 0.7
            rotation: profilePopup.visible ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 120 } }
        }
    }

    function chooseProfile(id, active) {
        profilePopup.close()
        if (!active) {
            // Switching rebuilds the list, so let the click finish first
            Qt.callLater(function() {
                ProfileManager.activate(id)
            })
        }
    }

    Popup {
        id: profilePopup

        y: switcher.height + 6
        x: Math.min(0, switcher.width - width)
        width: Math.max(200, Math.min(260, window.width - 32))
        padding: 4
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        Material.elevation: 8

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 100 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 }
        }

        background: Rectangle {
            color: Theme.popup
            radius: 8
            border.width: 1
            border.color: Theme.border
        }

        onOpened: {
            if (!switcher.openedByKeyboard) {
                profilePopup.contentItem.forceActiveFocus()
                return
            }
            // Start on the active profile so Enter/Escape do the obvious thing
            for (var i = 0; i < profileRepeater.count; i++) {
                var row = profileRepeater.itemAt(i)
                if (row && row.active) {
                    row.forceActiveFocus(Qt.TabFocusReason)
                    return
                }
            }
            manageRow.forceActiveFocus(Qt.TabFocusReason)
        }
        onClosed: {
            if (switcher.openedByKeyboard) {
                switcher.forceActiveFocus(Qt.TabFocusReason)
            }
        }

        contentItem: Column {
            spacing: 0

            Repeater {
                id: profileRepeater
                model: ProfileManager.profiles

                delegate: ItemDelegate {
                    id: row

                    readonly property bool active: modelData.active === true

                    width: parent.width
                    height: 36
                    padding: 0
                    hoverEnabled: true
                    focusPolicy: Qt.TabFocus

                    onClicked: switcher.chooseProfile(modelData.id, active)
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                    Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                    Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)

                    background: Rectangle {
                        radius: 5
                        color: row.hovered || row.visualFocus ? Theme.cardHover : "transparent"
                    }

                    contentItem: Item {
                        Label {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: checkIcon.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            font.pointSize: Theme.fontBody
                            color: row.active ? Theme.textHeading : Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Image {
                            id: checkIcon
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/res/check.svg"
                            sourceSize.width: 16
                            sourceSize.height: 16
                            visible: row.active
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width - 8
                x: 4
                height: 1
                color: Theme.divider
            }

            ItemDelegate {
                id: manageRow
                width: parent.width
                height: 36
                padding: 0
                hoverEnabled: true
                focusPolicy: Qt.TabFocus

                onClicked: {
                    profilePopup.close()
                    stackView.push("qrc:/gui/SettingsView.qml", { "currentSection": "profiles" })
                }
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)

                background: Rectangle {
                    radius: 5
                    color: manageRow.hovered || manageRow.visualFocus ? Theme.cardHover : "transparent"
                }

                contentItem: Label {
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Manage profiles…")
                    font.pointSize: Theme.fontBody
                    color: Theme.textSecondary
                }
            }
        }
    }
}
