import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import ProfileManager 1.0
import "."

Column {
    id: profileSettings
    spacing: 0
    signal editSettings()

    SettingsGroup {
        width: parent.width
        title: qsTr("Profiles")
        description: qsTr("Keep separate settings for gaming, desktop work or anything else. Changes on the other settings pages are saved to your active profile. Each profile also chooses where its stream opens. Language is shared across profiles.")

        Column {
            anchors.fill: parent
            spacing: 10

            Repeater {
                model: ProfileManager.profiles

                delegate: Rectangle {
                    width: parent.width
                    implicitHeight: profileContent.implicitHeight + 24
                    radius: 6
                    color: modelData.active ? Theme.navSelected : Theme.card
                    border.color: modelData.active ? Material.accent : Theme.border

                    ColumnLayout {
                        id: profileContent
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Image {
                                source: Theme.profileIcon(modelData.kind)
                                sourceSize.width: 22
                                sourceSize.height: 22
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.pointSize: Theme.fontLabel
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Label {
                                visible: modelData.active
                                text: qsTr("Active")
                                color: Material.accent
                                font.pointSize: Theme.fontSmall
                            }
                        }

                        Label {
                            text: qsTr("Target monitor")
                            font.pointSize: Theme.fontSmall
                            color: Theme.textSecondary
                        }

                        MonitorSelector {
                            Layout.fillWidth: true
                            monitorKey: modelData.monitorKey || ""
                            monitorLabel: modelData.monitorLabel || ""
                            onSelected: function(key, label) {
                                var profileId = modelData.id
                                Qt.callLater(function() { ProfileManager.setTargetMonitor(profileId, key, label) })
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Button {
                                text: modelData.active ? qsTr("Edit settings") : qsTr("Use profile")
                                onClicked: {
                                    if (modelData.active) {
                                        profileSettings.editSettings()
                                    } else {
                                        var profileId = modelData.id
                                        Qt.callLater(function() { ProfileManager.activate(profileId) })
                                    }
                                }
                            }
                            Button {
                                visible: !modelData.active
                                flat: true
                                text: qsTr("Edit settings")
                                onClicked: {
                                    var profileId = modelData.id
                                    profileSettings.editSettings()
                                    ProfileManager.activate(profileId)
                                }
                            }
                            Button {
                                flat: true
                                text: qsTr("Rename")
                                onClicked: {
                                    renameProfileDialog.profileId = modelData.id
                                    renameProfileDialog.profileName = modelData.name
                                    renameProfileDialog.open()
                                }
                            }
                            Button {
                                flat: true
                                text: qsTr("Delete")
                                enabled: ProfileManager.profiles.length > 1
                                onClicked: {
                                    removeProfileDialog.profileId = modelData.id
                                    removeProfileDialog.profileName = modelData.name
                                    removeProfileDialog.open()
                                }
                                ToolTip.text: qsTr("Keep at least one profile.")
                                ToolTip.visible: hovered && !enabled
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
    }

}
