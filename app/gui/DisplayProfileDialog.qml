import QtQuick 2.9
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import DisplayManager 1.0
import StreamingPreferences 1.0
import "."

// Norilight: create or edit a display manager profile. Call openNew(monitorKey)
// or openEdit(profileId).
NavigableDialog {
    id: dialog

    property string profileId: ""
    property string monitorKey: ""
    property string missingMonitorLabel: ""

    title: profileId === "" ? qsTr("New monitor profile") : qsTr("Edit monitor profile")
    standardButtons: Dialog.Save | Dialog.Cancel
    width: Math.min(560, (Overlay.overlay ? Overlay.overlay.width : 600) - 32)

    readonly property var resolutions: [
        { text: qsTr("Match the monitor"), w: 0, h: 0 },
        { text: "720p (1280×720)", w: 1280, h: 720 },
        { text: "1080p (1920×1080)", w: 1920, h: 1080 },
        { text: "1440p (2560×1440)", w: 2560, h: 1440 },
        { text: "4K (3840×2160)", w: 3840, h: 2160 },
        { text: qsTr("Custom"), w: -1, h: -1 }
    ]
    // 0 matches the monitor, -1 is the custom entry
    readonly property var frameRates: [0, 30, 60, 90, 120, 144, 165, 240, -1]

    function monitorText(m) {
        return qsTr("Monitor %1: %2 (%3×%4, %5 Hz)").arg(m.number).arg(m.label)
                   .arg(m.width).arg(m.height).arg(m.refreshRate)
               + (m.primary ? " · " + qsTr("primary") : "")
    }

    function rebuildMonitorModel() {
        var list = []
        var monitors = DisplayManager.monitors
        var index = -1
        for (var i = 0; i < monitors.length; i++) {
            list.push({ key: monitors[i].key, text: monitorText(monitors[i]) })
            if (monitors[i].key === monitorKey) {
                index = i
            }
        }
        if (index < 0 && monitorKey !== "") {
            list.push({ key: monitorKey, text: qsTr("%1 (not connected)").arg(missingMonitorLabel || qsTr("Unknown monitor")) })
            index = list.length - 1
        }
        monitorBox.model = list
        monitorBox.currentIndex = Math.max(0, index)
    }

    function load(p) {
        profileId = p.id || ""
        monitorKey = p.monitorKey || ""
        missingMonitorLabel = p.monitorLabel || ""
        rebuildMonitorModel()

        nameField.text = p.name || ""

        var w = p.width || 0, h = p.height || 0
        var resIndex = resolutions.length - 1
        for (var i = 0; i < resolutions.length - 1; i++) {
            if (resolutions[i].w === w && resolutions[i].h === h) {
                resIndex = i
                break
            }
        }
        resolutionBox.currentIndex = resIndex
        customWidth.text = w > 0 ? w : ""
        customHeight.text = h > 0 ? h : ""

        var fps = p.fps || 0
        var fpsIndex = frameRates.indexOf(fps)
        fpsBox.currentIndex = fpsIndex >= 0 ? fpsIndex : frameRates.length - 1
        customFps.text = fps > 0 ? fps : ""

        windowModeBox.currentIndex = p.windowMode !== undefined ? p.windowMode : 0
        fitBox.currentIndex = p.videoScaleMode || 0
        vsyncCheck.checked = p.vsync !== undefined ? p.vsync : true
        pacingCheck.checked = p.framePacing !== undefined ? p.framePacing : false

        var kbps = p.bitrateKbps || 0
        autoBitrateCheck.checked = kbps <= 0
        bitrateField.text = kbps > 0 ? (kbps / 1000).toString() : ""
    }

    function openNew(key) {
        load({ monitorKey: key || "",
               windowMode: StreamingPreferences.windowMode,
               vsync: StreamingPreferences.enableVsync,
               framePacing: StreamingPreferences.framePacing,
               videoScaleMode: StreamingPreferences.videoScaleMode })
        open()
    }

    function openEdit(id) {
        load(DisplayManager.profile(id))
        open()
    }

    function currentMonitorLabel() {
        var monitors = DisplayManager.monitors
        var key = monitorBox.model[monitorBox.currentIndex].key
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].key === key) {
                return monitors[i].label
            }
        }
        return missingMonitorLabel
    }

    // Accept a comma as the decimal mark too, whatever the system locale is
    function parseMbps(text) {
        return parseFloat(text.replace(",", "."))
    }

    readonly property bool customResolution: resolutionBox.currentIndex === resolutions.length - 1
    readonly property bool customFrameRate: fpsBox.currentIndex === frameRates.length - 1

    // Why the profile can't be saved yet, or "" when it can
    readonly property string validationMessage: {
        if (monitorBox.count === 0) {
            return qsTr("Connect a monitor to make a profile for it.")
        }
        if (customResolution) {
            var w = parseInt(customWidth.text), h = parseInt(customHeight.text)
            if (!(w >= 256 && w <= 8192 && h >= 256 && h <= 8192)) {
                return qsTr("Enter a width and height from 256 to 8192.")
            }
        }
        if (customFrameRate) {
            var fps = parseInt(customFps.text)
            if (!(fps >= 10 && fps <= 1000)) {
                return qsTr("Enter a frame rate from 10 to 1000 FPS.")
            }
        }
        if (!autoBitrateCheck.checked) {
            var mbps = parseMbps(bitrateField.text)
            if (!(mbps >= 0.5 && mbps <= 500)) {
                return qsTr("Enter a bitrate from 0.5 to 500 Mbps.")
            }
        }
        return ""
    }

    onOpened: {
        var save = standardButton(Dialog.Save)
        if (save) {
            save.enabled = Qt.binding(function() { return dialog.validationMessage === "" })
        }
        nameField.forceActiveFocus()
    }

    onAccepted: {
        var res = resolutions[resolutionBox.currentIndex]
        var w = customResolution ? parseInt(customWidth.text) : res.w
        var h = customResolution ? parseInt(customHeight.text) : res.h
        var name = nameField.text.trim()
        if (name === "") {
            name = currentMonitorLabel()
        }

        DisplayManager.saveProfile({
            id: profileId,
            name: name,
            monitorKey: monitorBox.model[monitorBox.currentIndex].key,
            width: w,
            height: h,
            fps: customFrameRate ? parseInt(customFps.text) : frameRates[fpsBox.currentIndex],
            windowMode: windowModeBox.currentIndex,
            videoScaleMode: fitBox.currentIndex,
            vsync: vsyncCheck.checked,
            framePacing: vsyncCheck.checked && pacingCheck.checked,
            bitrateKbps: autoBitrateCheck.checked ? 0 : Math.round(parseMbps(bitrateField.text) * 1000)
        })
    }

    Connections {
        target: DisplayManager
        onMonitorsChanged: {
            if (dialog.visible) {
                dialog.monitorKey = monitorBox.model[monitorBox.currentIndex].key
                dialog.rebuildMonitorModel()
            }
        }
    }

    GridLayout {
        width: parent.width
        columns: 2
        columnSpacing: 16
        rowSpacing: 6

        Label { text: qsTr("Name") }
        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: qsTr("For example: Left monitor")
            selectByMouse: true
        }

        Label { text: qsTr("Monitor") }
        AutoResizingComboBox {
            id: monitorBox
            Layout.fillWidth: true
            textRole: "text"
        }

        Label { text: qsTr("Resolution") }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            AutoResizingComboBox {
                id: resolutionBox
                Layout.fillWidth: true
                textRole: "text"
                model: dialog.resolutions
            }
            TextField {
                id: customWidth
                visible: dialog.customResolution
                Layout.preferredWidth: 72
                placeholderText: qsTr("Width")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 8192 }
                selectByMouse: true
            }
            Label { text: "×"; visible: dialog.customResolution }
            TextField {
                id: customHeight
                visible: dialog.customResolution
                Layout.preferredWidth: 72
                placeholderText: qsTr("Height")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 8192 }
                selectByMouse: true
            }
        }

        Label { text: qsTr("Frame rate") }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            AutoResizingComboBox {
                id: fpsBox
                Layout.fillWidth: true
                model: dialog.frameRates.map(function(f) {
                    return f === 0 ? qsTr("Match the monitor's refresh rate")
                         : f < 0 ? qsTr("Custom")
                         : qsTr("%1 FPS").arg(f)
                })
            }
            TextField {
                id: customFps
                visible: dialog.customFrameRate
                Layout.preferredWidth: 72
                placeholderText: qsTr("FPS")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 1000 }
                selectByMouse: true
            }
        }

        Label { text: qsTr("Window mode") }
        AutoResizingComboBox {
            id: windowModeBox
            Layout.fillWidth: true
            model: [qsTr("Fullscreen"), qsTr("Borderless windowed"), qsTr("Windowed")]
        }

        Label { text: qsTr("Picture fit") }
        AutoResizingComboBox {
            id: fitBox
            Layout.fillWidth: true
            model: [qsTr("Fit (black bars if needed)"), qsTr("Fill (crop the edges)"), qsTr("Stretch")]
        }

        Label { text: qsTr("Frame timing") }
        RowLayout {
            Layout.fillWidth: true
            CheckBox {
                id: vsyncCheck
                text: qsTr("V-Sync")
            }
            CheckBox {
                id: pacingCheck
                text: qsTr("Frame pacing")
                enabled: vsyncCheck.checked
            }
        }

        Label { text: qsTr("Bitrate") }
        RowLayout {
            Layout.fillWidth: true
            CheckBox {
                id: autoBitrateCheck
                text: qsTr("Automatic")
            }
            TextField {
                id: bitrateField
                visible: !autoBitrateCheck.checked
                Layout.preferredWidth: 80
                placeholderText: "20"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator {
                    bottom: 0.5
                    top: 500
                    decimals: 1
                    notation: DoubleValidator.StandardNotation
                    locale: "C"
                }
                selectByMouse: true
            }
            Label {
                visible: !autoBitrateCheck.checked
                text: qsTr("Mbps")
            }
        }

        // Explains why Save is greyed out
        Label {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: dialog.validationMessage !== ""
            text: dialog.validationMessage
            color: Theme.statusError
            font.pointSize: Theme.fontDetail
            wrapMode: Text.Wrap
        }
    }
}
