import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import DisplayManager 1.0
import "."

// Norilight: choose a display manager profile to stream an app with. The
// stream opens in its own window on the profile's monitor, and the main
// window stays open as the hub.
NavigableDialog {
    id: picker

    property string appName: ""
    property string hostUuid: ""
    property string hostName: ""

    title: qsTr("Stream %1 on…").arg(appName)
    standardButtons: Dialog.Cancel
    width: Math.min(520, (parent ? parent.width : 560) - 32)

    function profileSummary(p) {
        var res = p.width > 0 ? p.width + "×" + p.height : qsTr("monitor resolution")
        var fps = p.fps > 0 ? qsTr("%1 FPS").arg(p.fps) : qsTr("monitor refresh rate")
        var modes = [qsTr("fullscreen"), qsTr("borderless"), qsTr("windowed")]
        return (p.monitorLabel || qsTr("Unknown monitor")) + " · " + res + " · " + fps + " · " + modes[p.windowMode || 0]
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
        newProfileButton.forceActiveFocus(Qt.TabFocusReason)
    }

    onOpened: focusFirst()

    ColumnLayout {
        width: parent.width
        spacing: 4

        Label {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            visible: DisplayManager.profiles.length === 0
            text: qsTr("You don't have any monitor presets yet. A preset picks the monitor the stream opens on, and its resolution and window settings.")
            wrapMode: Text.Wrap
            color: Theme.textSecondary
        }

        Repeater {
            id: profileRepeater
            model: DisplayManager.profiles

            delegate: ItemDelegate {
                id: row
                Layout.fillWidth: true
                enabled: modelData.connected
                highlighted: activeFocus
                focusPolicy: Qt.StrongFocus
                padding: 10

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
                        text: modelData.connected ? picker.profileSummary(modelData)
                                                  : qsTr("%1 isn't connected").arg(modelData.monitorLabel || qsTr("This monitor"))
                        font.pointSize: Theme.fontSmall
                        color: row.enabled ? Theme.textSecondary : Theme.textDisabledSecondary
                        elide: Text.ElideRight
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 4

            Button {
                id: newProfileButton
                flat: DisplayManager.profiles.length > 0
                highlighted: DisplayManager.profiles.length === 0
                text: qsTr("New preset…")
                onClicked: newProfileDialog.openNew("")
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)
                Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
            }

            Button {
                flat: true
                visible: DisplayManager.profiles.length > 0
                text: qsTr("Manage profiles")
                onClicked: {
                    picker.close()
                    stackView.push("qrc:/gui/SettingsView.qml", { "currentSection": "profiles" })
                }
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)
            }

            Item { Layout.fillWidth: true }
        }
    }

    DisplayProfileDialog {
        id: newProfileDialog

        // NavigableDialog hands focus back to the page when it closes; keep it
        // in the picker instead, which is still open underneath.
        onClosed: {
            if (picker.visible) {
                picker.focusFirst()
            }
        }
    }
}
