import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import DisplayManager 1.0

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
        var res = p.width > 0 ? p.width + "x" + p.height : qsTr("monitor resolution")
        var fps = p.fps > 0 ? qsTr("%1 FPS").arg(p.fps) : qsTr("monitor refresh rate")
        var modes = [qsTr("fullscreen"), qsTr("borderless"), qsTr("windowed")]
        return (p.monitorLabel || qsTr("Unknown monitor")) + " · " + res + " · " + fps + " · " + modes[p.windowMode || 0]
    }

    ColumnLayout {
        width: parent.width
        spacing: 4

        Label {
            Layout.fillWidth: true
            visible: DisplayManager.profiles.length === 0
            text: qsTr("You don't have any monitor profiles yet. Create one in Settings under Display manager, then come back here.")
            wrapMode: Text.Wrap
            color: "#B4B4BC"
        }

        Button {
            visible: DisplayManager.profiles.length === 0
            text: qsTr("Open Display manager")
            onClicked: {
                picker.close()
                stackView.push("qrc:/gui/SettingsView.qml", { "currentSection": "window" })
            }
        }

        Repeater {
            model: DisplayManager.profiles

            delegate: ItemDelegate {
                Layout.fillWidth: true
                enabled: modelData.connected
                padding: 10

                onClicked: {
                    DisplayManager.launch(modelData.id, picker.hostUuid, picker.hostName, picker.appName)
                    picker.close()
                }

                contentItem: Column {
                    spacing: 2
                    Label {
                        width: parent.width
                        text: modelData.name
                        font.pointSize: 12
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: modelData.connected ? picker.profileSummary(modelData)
                                                  : qsTr("%1 isn't connected").arg(modelData.monitorLabel || qsTr("This monitor"))
                        font.pointSize: 9.5
                        color: "#9D9DA6"
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
