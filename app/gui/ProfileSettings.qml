import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import ProfileManager 1.0
import "."

// Norilight: one row per profile: its target monitor, a button to switch to
// it, and the rarer actions in a menu.
SettingsGroup {
    id: profileSettings

    signal editSettings()

    title: qsTr("Profiles")
    info: qsTr("Keep separate settings for gaming, desktop work or anything else. Changes on the other settings pages are saved to your active profile. Each profile also chooses where its stream opens. Language is shared across profiles.")

    SettingsCard {
        Repeater {
            model: ProfileManager.profiles

            delegate: SettingsRow {
                id: profileRow

                text: modelData.name
                iconSource: Theme.profileIcon(modelData.kind)
                badge: modelData.active ? qsTr("Active") : ""
                focusTarget: monitorSelector

                MonitorSelector {
                    id: monitorSelector
                    // The same width on every row: what's left after room for the
                    // name, the button and the menu
                    Layout.preferredWidth: Math.max(140, profileRow.width - 370)
                    monitorKey: modelData.monitorKey || ""
                    monitorLabel: modelData.monitorLabel || ""
                    onSelected: function(key, label) {
                        var profileId = modelData.id
                        Qt.callLater(function() { ProfileManager.setTargetMonitor(profileId, key, label) })
                    }

                    ToolTip.text: qsTr("Target monitor")
                    ToolTip.delay: 600
                    ToolTip.visible: hovered && !popup.visible
                }

                // Same width whether it says "Use profile" or "Edit settings",
                // so the selectors line up from row to row
                Button {
                    id: profileAction
                    // Its own width, plus whatever the longer of the two labels adds
                    Layout.preferredWidth: Math.ceil(implicitWidth
                                                     + Math.max(useWidth.advanceWidth, editWidth.advanceWidth)
                                                     - (modelData.active ? editWidth.advanceWidth : useWidth.advanceWidth))
                    text: modelData.active ? qsTr("Edit settings") : qsTr("Use profile")
                    onClicked: {
                        if (modelData.active) {
                            profileSettings.editSettings()
                        } else {
                            var profileId = modelData.id
                            Qt.callLater(function() { ProfileManager.activate(profileId) })
                        }
                    }

                    TextMetrics {
                        id: useWidth
                        font: profileAction.font
                        text: qsTr("Use profile")
                    }
                    TextMetrics {
                        id: editWidth
                        font: profileAction.font
                        text: qsTr("Edit settings")
                    }
                }

                ToolButton {
                    id: moreButton
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    padding: 0
                    topInset: 0
                    bottomInset: 0
                    leftInset: 0
                    rightInset: 0
                    display: AbstractButton.IconOnly
                    icon.source: "qrc:/res/more_vert.svg"
                    icon.width: 20
                    icon.height: 20
                    icon.color: Theme.textSecondary
                    background: Rectangle {
                        radius: width / 2
                        color: moreButton.hovered || profileMenu.visible ? Theme.cardHover : "transparent"
                        border.width: moreButton.visualFocus ? 2 : 0
                        border.color: Material.accent
                    }
                    onClicked: profileMenu.open()
                    Keys.onReturnPressed: profileMenu.open()
                    Keys.onEnterPressed: profileMenu.open()

                    Accessible.name: qsTr("More actions for %1").arg(modelData.name)
                    ToolTip.text: Accessible.name
                    ToolTip.delay: 600
                    ToolTip.visible: hovered && !profileMenu.visible

                    NavigableMenu {
                        id: profileMenu
                        initiator: moreButton
                        y: moreButton.height

                        NavigableMenuItem {
                            visible: !modelData.active
                            text: qsTr("Edit settings")
                            onTriggered: {
                                var profileId = modelData.id
                                profileSettings.editSettings()
                                ProfileManager.activate(profileId)
                            }
                        }
                        NavigableMenuItem {
                            text: qsTr("Rename")
                            onTriggered: {
                                renameProfileDialog.profileId = modelData.id
                                renameProfileDialog.profileName = modelData.name
                                renameProfileDialog.open()
                            }
                        }
                        NavigableMenuItem {
                            text: qsTr("Delete")
                            enabled: visible && ProfileManager.profiles.length > 1
                            onTriggered: {
                                removeProfileDialog.profileId = modelData.id
                                removeProfileDialog.profileName = modelData.name
                                removeProfileDialog.open()
                            }
                        }
                    }
                }
            }
        }
    }

    Button {
        text: qsTr("New profile")
        onClicked: newProfileDialog.open()
    }
}
