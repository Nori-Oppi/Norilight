import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQml 2.2

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

    onClicked: profileMenu.open()
    Keys.onReturnPressed: profileMenu.open()
    Keys.onEnterPressed: profileMenu.open()

    ToolTip.text: qsTr("Profile: %1. Each profile has its own settings.").arg(ProfileManager.activeName)
    ToolTip.delay: 600
    ToolTip.visible: hovered && !profileMenu.visible

    background: Rectangle {
        radius: 6
        color: switcher.onToolbar ? (switcher.hovered || switcher.visualFocus || profileMenu.visible ? "#26FFFFFF" : "transparent")
                                  : (switcher.hovered || switcher.visualFocus || profileMenu.visible ? Theme.cardHover : Theme.card)
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
        }
    }

    NavigableMenu {
        id: profileMenu
        initiator: switcher
        y: switcher.height + 4
        x: switcher.width - width

        // One entry per profile, kept in step with the list
        Instantiator {
            model: ProfileManager.profiles

            delegate: NavigableMenuItem {
                text: modelData.name
                checkable: true
                checked: modelData.active
                font.weight: modelData.active ? Font.DemiBold : Font.Normal

                onTriggered: {
                    // Clicking flips the tick; it follows the active profile instead
                    checked = modelData.active

                    if (!modelData.active) {
                        // Switching rebuilds this menu, so let the click finish first
                        var id = modelData.id
                        Qt.callLater(function() {
                            ProfileManager.activate(id)
                        })
                    }
                }
            }

            onObjectAdded: function(index, object) {
                profileMenu.insertItem(index, object)
            }
            onObjectRemoved: function(index, object) {
                profileMenu.removeItem(object)
            }
        }

        MenuSeparator {}

        NavigableMenuItem {
            text: qsTr("Manage profiles")
            onTriggered: stackView.push("qrc:/gui/SettingsView.qml", { "currentSection": "profiles" })
        }
    }
}
