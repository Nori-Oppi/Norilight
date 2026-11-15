import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import ProfileManager 1.0
import DisplayManager 1.0
import "."

Column {
    id: profileSettings
    spacing: 0
    signal editSettings()

    SettingsGroup {
        width: parent.width
        title: qsTr("Profiles")
        description: qsTr("Keep separate settings for gaming, desktop work or anything else. Changes on the other settings pages are saved to your active profile. Language is shared across profiles.")

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

    SettingsGroup {
        id: monitorProfilesGroupBox
        subheading: true
        width: (parent.width - (parent.leftPadding + parent.rightPadding))
        title: qsTr("Monitor presets")
        description: qsTr("Shared across your profiles. These presets choose a monitor and override its resolution, frame rate and window settings when you use Stream on a Monitor. Other settings come from your active profile.")

        function profileSummary(p, withMonitor) {
            var res = p.width > 0 ? p.width + "×" + p.height : qsTr("monitor resolution")
            var fps = p.fps > 0 ? qsTr("%1 FPS").arg(p.fps) : qsTr("monitor refresh rate")
            var modes = [qsTr("fullscreen"), qsTr("borderless"), qsTr("windowed")]
            var fits = [qsTr("fit"), qsTr("fill"), qsTr("stretch")]
            var parts = [res, fps, modes[p.windowMode || 0], fits[p.videoScaleMode || 0]]
            // Rows under a connected monitor's heading don't need its
            // name; rows for unplugged monitors do
            if (withMonitor) {
                parts.unshift(p.monitorLabel || qsTr("Unknown monitor"))
            }
            return parts.join(" · ")
        }

        function profilesFor(key) {
            var list = []
            var all = DisplayManager.profiles
            for (var i = 0; i < all.length; i++) {
                if (all[i].monitorKey === key) {
                    list.push(all[i])
                }
            }
            return list
        }

        function disconnectedProfiles() {
            var list = []
            var all = DisplayManager.profiles
            for (var i = 0; i < all.length; i++) {
                if (!all[i].connected) {
                    list.push(all[i])
                }
            }
            return list
        }

        Component {
            id: profileRowComponent

            Rectangle {
                property var profile: ({})
                property bool showMonitor: false

                height: 104
                radius: 6
                color: Theme.card
                border.color: Theme.border

                Column {
                    x: 14
                    y: 10
                    width: parent.width - 28
                    spacing: 2

                    Label {
                        width: parent.width
                        text: profile.name || ""
                        font.pointSize: Theme.fontBody
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: monitorProfilesGroupBox.profileSummary(profile, showMonitor)
                        font.pointSize: Theme.fontSmall
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: profileButtons
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6

                    Button {
                        flat: true
                        visible: !!profile.lastAppName
                        enabled: !!profile.connected
                        // Long app names would push the other buttons out
                        width: Math.max(60, Math.min(implicitWidth, parent.parent.width - 180, 200))
                        text: qsTr("Stream %1 again").arg(profile.lastAppName)
                        onClicked: DisplayManager.launchLast(profile.id)

                        ToolTip.text: qsTr("Stream %1 on %2 again").arg(profile.lastAppName).arg(profile.lastHostName)
                        ToolTip.delay: 600
                        ToolTip.visible: hovered
                    }
                    Button {
                        flat: true
                        text: qsTr("Edit")
                        onClicked: profileDialog.openEdit(profile.id)
                    }
                    Button {
                        flat: true
                        text: qsTr("Delete")
                        onClicked: {
                            deleteProfileDialog.profileId = profile.id
                            deleteProfileDialog.profileName = profile.name
                            deleteProfileDialog.open()
                        }
                    }
                }
            }
        }

        Column {
            anchors.fill: parent
            spacing: 6

            Repeater {
                model: DisplayManager.monitors

                delegate: Column {
                    readonly property var monitor: modelData
                    readonly property var monitorProfiles: monitorProfilesGroupBox.profilesFor(modelData.key)

                    width: parent.width
                    spacing: 6
                    topPadding: index === 0 ? 0 : 10

                    RowLayout {
                        width: parent.width

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Monitor %1: %2").arg(monitor.number).arg(monitor.label) +
                                  (monitor.primary ? "  ·  " + qsTr("primary") : "")
                            font.pointSize: Theme.fontBody
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Button {
                            flat: true
                            text: qsTr("Add preset")
                            onClicked: profileDialog.openNew(monitor.key)
                        }
                    }

                    Label {
                        text: qsTr("%1×%2, %3 Hz").arg(monitor.width).arg(monitor.height).arg(monitor.refreshRate)
                        font.pointSize: Theme.fontSmall
                        color: Theme.textSecondary
                    }

                    Label {
                        width: parent.width
                        visible: monitorProfiles.length === 0
                        text: qsTr("No presets for this monitor yet.")
                        font.pointSize: Theme.fontSmall
                        color: Theme.textSecondary
                    }

                    Repeater {
                        model: monitorProfiles
                        delegate: Loader {
                            width: parent.width
                            height: 104
                            sourceComponent: profileRowComponent
                            onLoaded: {
                                item.width = Qt.binding(function() { return width })
                                item.profile = Qt.binding(function() { return modelData })
                            }
                        }
                    }
                }
            }

            Label {
                width: parent.width
                topPadding: 14
                visible: monitorProfilesGroupBox.disconnectedProfiles().length > 0
                text: qsTr("Monitors that aren't connected")
                font.pointSize: Theme.fontBody
                font.weight: Font.DemiBold
            }

            Repeater {
                model: monitorProfilesGroupBox.disconnectedProfiles()
                delegate: Loader {
                    width: parent.width
                    height: 104
                    sourceComponent: profileRowComponent
                    onLoaded: {
                        item.width = Qt.binding(function() { return width })
                        item.profile = Qt.binding(function() { return modelData })
                        item.showMonitor = true
                    }
                }
            }
        }
    }

    DisplayProfileDialog {
        id: profileDialog
    }

    NavigableMessageDialog {
        id: deleteProfileDialog
        property string profileId: ""
        property string profileName: ""
        standardButtons: Dialog.Yes | Dialog.No
        text: qsTr("Delete the monitor preset \"%1\"?").arg(profileName)
        acceptText: qsTr("Delete")
        rejectText: qsTr("Cancel")
        onAccepted: DisplayManager.removeProfile(profileId)
    }
}
