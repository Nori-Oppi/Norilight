import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import ProfileManager 1.0
import DisplayManager 1.0
import "."

// Launch a complete profile in a separate window, leaving the hub open.
NavigableDialog {
    id: picker

    property string appName: ""
    property string hostUuid: ""
    property string hostName: ""

    title: qsTr("Stream %1 with a profile").arg(appName)
    standardButtons: Dialog.Cancel
    width: Math.min(520, (parent ? parent.width : 560) - 32)

    function profileSummary(p) {
        var res = p.matchMonitorResolution ? qsTr("monitor resolution") : p.width + "\u00d7" + p.height
        var fps = p.matchMonitorRefreshRate ? qsTr("monitor refresh rate") : qsTr("%1 FPS").arg(p.fps)
        var monitor = p.monitorKey ? (DisplayManager.monitorName(p.monitorKey) || p.monitorLabel || qsTr("Saved monitor")) : qsTr("Current monitor")
        return monitor + " \u00b7 " + res + " \u00b7 " + fps
    }

    function connected(p) {
        // Reading the monitor list makes this update when a display is unplugged.
        var monitors = DisplayManager.monitors
        return !p.monitorKey || DisplayManager.isMonitorConnected(p.monitorKey)
    }

    // Give keyboard and gamepad users somewhere to start
    function focusFirst() {
        for (var i = 0; i < profileRepeater.count; i++) {
            var row = profileRepeater.itemAt(i)
            if (row && row.enabled) {
                row.forceActiveFocus(Qt.TabFocusReason)
                return
            }
        }
        manageProfilesButton.forceActiveFocus(Qt.TabFocusReason)
    }

    onAboutToShow: DisplayManager.setCurrentWindow(window)
    onOpened: focusFirst()

    ColumnLayout {
        width: parent.width
        spacing: 4

        Label {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            visible: ProfileManager.profiles.length === 0
            text: qsTr("Create a profile in Settings to choose its streaming settings and target monitor.")
            wrapMode: Text.Wrap
            color: Theme.textSecondary
        }

        Flickable {
            id: profileFlick
            Layout.fillWidth: true
            implicitHeight: Math.min(profileRows.implicitHeight, Math.max(100, window.height - 240))
            contentWidth: width
            contentHeight: profileRows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            Column {
                id: profileRows
                width: parent.width
                Repeater {
                    id: profileRepeater
                    model: ProfileManager.profiles

                    delegate: ItemDelegate {
                        id: row
                        width: parent.width
                        enabled: picker.connected(modelData)
                        highlighted: activeFocus
                        focusPolicy: Qt.StrongFocus
                        padding: 10
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                profileFlick.contentY = Math.max(0, Math.min(y, profileFlick.contentHeight - profileFlick.height))
                            }
                        }

                        function launch() {
                            DisplayManager.launch(modelData.id, picker.hostUuid, picker.hostName, picker.appName)
                            picker.close()
                        }

                        onClicked: launch()
                        Keys.onReturnPressed: launch()
                        Keys.onEnterPressed: launch()
                        Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                        Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)

                        contentItem: Column {
                            spacing: 2
                            Label {
                                width: parent.width
                                text: modelData.name
                                font.pointSize: Theme.fontLabel
                                color: row.enabled ? Theme.textPrimary : Theme.textDisabled
                                elide: Text.ElideRight
                            }
                            Label {
                                width: parent.width
                                text: picker.connected(modelData) ? picker.profileSummary(modelData)
                                                          : qsTr("%1 isn't connected").arg(modelData.monitorLabel || qsTr("This monitor"))
                                font.pointSize: Theme.fontSmall
                                color: row.enabled ? Theme.textSecondary : Theme.textDisabledSecondary
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 4

            Button {
                id: manageProfilesButton
                flat: true
                text: qsTr("Manage profiles")
                onClicked: {
                    picker.close()
                    stackView.push("qrc:/gui/SettingsView.qml", { "currentSection": "profiles" })
                }
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
            }

            Item { Layout.fillWidth: true }
        }
    }

}
