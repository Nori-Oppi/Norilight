import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import ComputerModel 1.0

import "."

// Norilight: apps, paired devices, streams and displays of a Norishine host, through
// its management API (/api/v1 on the HTTPS port, with this client's paired
// certificate). Seeing them needs "View" host management for this device on the host,
// changing them needs "Manage"; both are granted per device in the host's web UI.
Item {
    id: managePage

    property int computerIndex
    property ComputerModel computerModel

    // From the host
    property var hostStatus: null
    property var apps: []
    property string runningApp: ""
    property var devices: []
    property var displays: []
    property string outputName: ""
    property var virtualDisplay: null  // headless_mode; null while unknown (or on other platforms)
    property bool appsLoaded: false
    property bool devicesLoaded: false
    property bool displaysLoaded: false

    // Local state
    property string loadError: ""
    property bool accessDenied: false
    property string notice: ""
    property int pending: 0
    property int busy: 0

    readonly property int manageRead: 0x10000000
    readonly property int manageWrite: 0x20000000
    readonly property bool canWrite: hostStatus !== null && (hostStatus.device.permissions & manageWrite) !== 0
    readonly property string runningName: {
        for (var i = 0; i < apps.length; i++) {
            if (apps[i].uuid === runningApp) {
                return apps[i].name
            }
        }
        return ""
    }

    // Device permission bits (crypto::PERM on the host), grouped as in the host's web UI
    readonly property var accessLevels: [
        {"bits": 0, "title": qsTr("Nothing"), "help": qsTr("Can't see or start apps.")},
        {"bits": 0x01000000, "title": qsTr("See apps"), "help": qsTr("Lists apps, can't stream.")},
        {"bits": 0x03000000, "title": qsTr("Watch"), "help": qsTr("Joins streams others started.")},
        {"bits": 0x07000000, "title": qsTr("Start apps"), "help": qsTr("Starts and stops apps.")}
    ]
    readonly property int accessMask: 0x07000000
    readonly property var inputs: [
        {"bit": 0x00000100, "title": qsTr("Controller")},
        {"bit": 0x00001000, "title": qsTr("Keyboard")},
        {"bit": 0x00000800, "title": qsTr("Mouse")},
        {"bit": 0x00000200, "title": qsTr("Touch")},
        {"bit": 0x00000400, "title": qsTr("Pen")}
    ]
    readonly property var extras: [
        {"bit": 0x00010000, "title": qsTr("Send clipboard"), "help": qsTr("Paste from the device into the host.")},
        {"bit": 0x00020000, "title": qsTr("Read clipboard"), "help": qsTr("Copy from the host to the device.")},
        {"bit": 0x00100000, "title": qsTr("Run server commands"), "help": qsTr("Run the commands set up on the host.")}
    ]
    readonly property var manageLevels: [
        {"bits": 0, "title": qsTr("None"), "help": qsTr("No access to settings, apps or devices.")},
        {"bits": 0x10000000, "title": qsTr("View"), "help": qsTr("Sees status, settings, apps, paired devices and displays.")},
        {"bits": 0x30000000, "title": qsTr("Manage"), "help": qsTr("Changes settings, apps and paired devices. App and device commands run on the host, so only for devices you trust.")}
    ]
    readonly property int manageMask: 0x30000000

    function request(kind, verb, path, body) {
        computerModel.hostApiRequest(computerIndex, "manage:" + kind, verb, path, body === undefined ? "" : JSON.stringify(body))
    }

    function load(what) {
        pending += 1
        switch (what) {
        case "status": request("status", "GET", "/api/v1/status"); break
        case "apps": request("apps", "GET", "/api/v1/apps"); break
        case "devices": request("devices", "GET", "/api/v1/devices"); break
        case "displays": request("displays", "GET", "/api/v1/displays"); break
        case "config": request("config", "GET", "/api/v1/config"); break
        }
    }

    function reload() {
        loadError = ""
        accessDenied = false
        load("status")
        load("apps")
        load("devices")
        load("displays")
        load("config")
    }

    // A change: "what" is reloaded afterwards, "done" is shown on success
    function change(kind, verb, path, body, done) {
        busy += 1
        notice = ""
        pendingChanges[kind] = done
        request("change:" + kind, verb, path, body)
    }
    property var pendingChanges: ({})

    function describeFailure(status, data, error) {
        if (status === 0) {
            return qsTr("Couldn't reach the host: %1").arg(error)
        }
        if (data && data.error) {
            return data.error
        }
        if (data && data.errors) {
            var parts = []
            for (var key in data.errors) {
                parts.push(key + ": " + data.errors[key])
            }
            return parts.join("\n")
        }
        return qsTr("The host answered with an error (%1).").arg(status)
    }

    function appSummary(app) {
        if (app.cmd) {
            return app.cmd
        }
        if (app.detached && app.detached.length > 0) {
            return app.detached[0]
        }
        return qsTr("Desktop (no command)")
    }

    function sessionOf(uuid) {
        if (!hostStatus || !hostStatus.sessions) {
            return null
        }
        for (var i = 0; i < hostStatus.sessions.length; i++) {
            if (hostStatus.sessions[i].uuid === uuid) {
                return hostStatus.sessions[i]
            }
        }
        return null
    }

    // The highest level whose bits are all set (levels are cumulative)
    function levelIndex(levels, perm) {
        for (var i = levels.length - 1; i > 0; i--) {
            if ((perm & levels[i].bits) === levels[i].bits) {
                return i
            }
        }
        return 0
    }

    function levelTitle(levels, perm) {
        return levels[levelIndex(levels, perm)].title
    }

    function deviceHint(device) {
        var session = sessionOf(device.uuid)
        if (session) {
            return qsTr("Streaming %1 × %2 at %3 fps, %4%5").arg(session.width).arg(session.height).arg(session.fps)
                .arg(session.codec).arg(session.hdr ? ", HDR" : "")
        }
        var parts = [levelTitle(accessLevels, device.perm)]
        var inputCount = 0
        for (var i = 0; i < inputs.length; i++) {
            if (device.perm & inputs[i].bit) {
                inputCount++
            }
        }
        parts.push(inputCount === inputs.length ? qsTr("all input") : inputCount === 0 ? qsTr("no input") : qsTr("some input"))
        if (device.perm & manageMask) {
            parts.push(qsTr("host management: %1").arg(levelTitle(manageLevels, device.perm)))
        }
        return parts.join(" · ")
    }

    function displayHint(display) {
        if (!display.active) {
            return qsTr("Not active")
        }
        var text = qsTr("%1 × %2 at %3 Hz").arg(display.width).arg(display.height).arg(Math.round(display.refresh_rate * 100) / 100)
        if (display.hdr === true) {
            text += ", HDR"
        }
        if (display.primary) {
            text += " · " + qsTr("main display")
        }
        return text
    }

    function displayBadge(display) {
        if (virtualDisplay === true) {
            return ""
        }
        if (display.selected || (outputName === "" && display.primary && display.active)) {
            return qsTr("Streamed")
        }
        return ""
    }

    function moveApp(index, delta) {
        var order = apps.map(function(a) { return a.uuid })
        var target = index + delta
        if (target < 0 || target >= order.length) {
            return
        }
        var moved = order.splice(index, 1)[0]
        order.splice(target, 0, moved)
        change("apps", "POST", "/api/v1/apps/order", {"order": order}, "")
    }

    Connections {
        target: managePage.computerModel

        function onHostApiResponse(requestId, status, body, error) {
            if (requestId.indexOf("manage:") !== 0) {
                return
            }
            var kind = requestId.substring(7)
            var data = null
            try {
                data = JSON.parse(body)
            }
            catch (e) {
                data = null
            }

            if (kind.indexOf("change:") === 0) {
                var what = kind.substring(7)
                var done = managePage.pendingChanges[what]
                managePage.busy = Math.max(0, managePage.busy - 1)
                var editorSaving = appEditor.saving || deviceEditor.saving
                appEditor.saving = false
                deviceEditor.saving = false
                if (status === 200 && data !== null) {
                    var text = typeof done === "function" ? done(data) : done
                    if (data.closed_running_app) {
                        text = (text ? text + " " : "") + qsTr("The app that was running was closed.")
                    }
                    managePage.notice = text || ""
                    if (what === "apps" || what === "launch") {
                        managePage.load("apps")
                        managePage.load("status")
                    }
                    else if (what === "devices" || what === "disconnect") {
                        managePage.load("devices")
                        managePage.load("status")
                    }
                    else if (what === "displays") {
                        managePage.load("displays")
                        managePage.load("config")
                    }
                    else if (what === "unpair-self") {
                        managePage.devices = []
                        managePage.apps = []
                        managePage.displays = []
                        managePage.hostStatus = null
                    }
                }
                else if (status === 400 && data !== null && data.errors && editorSaving && what === "apps") {
                    // Back to the editor, with the host's message next to each field
                    appEditor.errors = data.errors
                    appEditor.open()
                }
                else if (status === 400 && data !== null && data.errors && editorSaving && what === "devices") {
                    deviceEditor.errors = data.errors
                    deviceEditor.open()
                }
                else {
                    managePage.notice = managePage.describeFailure(status, data, error)
                }
                return
            }

            managePage.pending = Math.max(0, managePage.pending - 1)
            if (status === 403) {
                managePage.accessDenied = true
                managePage.loadError = managePage.describeFailure(status, data, error)
                return
            }
            if (status !== 200 || data === null) {
                managePage.loadError = managePage.describeFailure(status, data, error)
                return
            }
            if (kind === "status") {
                managePage.hostStatus = data
            }
            else if (kind === "apps") {
                managePage.apps = data.apps
                managePage.runningApp = data.running_app
                managePage.appsLoaded = true
            }
            else if (kind === "devices") {
                managePage.devices = data.devices
                managePage.devicesLoaded = true
            }
            else if (kind === "config") {
                managePage.virtualDisplay = data.values && data.values.hasOwnProperty("headless_mode") ? data.values.headless_mode === true : false
            }
            else if (kind === "displays") {
                managePage.displays = data.displays
                managePage.outputName = data.output_name
                managePage.displaysLoaded = true
            }
        }
    }

    // Streams start and stop on their own; keep the device list current while open.
    Timer {
        interval: 10000
        repeat: true
        running: managePage.StackView.status === StackView.Active && managePage.hostStatus !== null && managePage.busy === 0
        onTriggered: {
            managePage.load("status")
            managePage.load("devices")
        }
    }

    StackView.onActivated: {
        if (hostStatus === null) {
            reload()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: tabs
            Layout.fillWidth: true
            Layout.maximumWidth: Theme.contentMaxWidth
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12

            TabButton { text: qsTr("Apps") }
            TabButton { text: qsTr("Devices") }
            TabButton { text: qsTr("Displays") }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.OvershootBounds
            contentWidth: width
            contentHeight: pageColumn.height + 40
            ScrollBar.vertical: ScrollBar {}

            Column {
                id: pageColumn
                width: Math.min(Theme.contentMaxWidth, flick.width - 40)
                x: (flick.width - width) / 2
                y: 20
                spacing: Theme.cardGap

                // Toolbar
                RowLayout {
                    width: parent.width
                    spacing: Theme.controlGap

                    Label {
                        Layout.fillWidth: true
                        text: managePage.hostStatus === null || managePage.canWrite ? "" :
                              qsTr("This device can only look. To change things from here, choose \"Manage\" under host management for this device in the host's web UI.")
                        wrapMode: Text.Wrap
                        color: Theme.textSecondary
                        font.pointSize: Theme.fontDetail
                    }

                    Button {
                        text: qsTr("Add app")
                        highlighted: true
                        visible: tabs.currentIndex === 0 && managePage.canWrite
                        enabled: managePage.busy === 0
                        onClicked: appEditor.edit(null)
                    }

                    Button {
                        text: qsTr("Refresh")
                        flat: true
                        enabled: managePage.pending === 0 && managePage.busy === 0
                        onClicked: managePage.reload()
                    }
                }

                // Messages
                Rectangle {
                    width: parent.width
                    height: noticeLabel.height + 24
                    radius: Theme.cardRadius
                    color: Theme.card
                    visible: managePage.notice !== ""

                    Label {
                        id: noticeLabel
                        x: Theme.cardPadding
                        y: 12
                        width: parent.width - 2 * Theme.cardPadding
                        text: managePage.notice
                        wrapMode: Text.Wrap
                        color: Theme.textPrimary
                        font.pointSize: Theme.fontBody
                    }
                }

                // Loading and access problems
                SettingsCard {
                    visible: managePage.loadError !== "" || (managePage.pending > 0 && managePage.hostStatus === null)
                    title: managePage.accessDenied ? qsTr("This device can't see the host's apps and devices yet") : ""

                    SettingsRow {
                        text: managePage.loadError !== "" ? managePage.loadError : qsTr("Loading...")
                        hint: managePage.accessDenied ?
                                  qsTr("On the host, open the web UI, go to paired devices, and choose \"View\" under host management for this device (or \"Manage\" to also change things here).") : ""
                    }
                }

                // Apps
                SettingsCard {
                    visible: tabs.currentIndex === 0 && managePage.appsLoaded
                    title: qsTr("Apps")
                    description: managePage.runningApp !== "" && managePage.canWrite ?
                                     qsTr("Saving, adding, moving or removing an app closes the app that is running now.") : ""

                    SettingsRow {
                        visible: managePage.apps.length === 0
                        text: qsTr("No apps yet")
                    }

                    Repeater {
                        model: managePage.apps

                        delegate: SettingsRow {
                            id: appRow
                            readonly property var app: modelData
                            text: app.name
                            badge: app.running ? qsTr("Running") : ""
                            hint: managePage.appSummary(app)
                            available: managePage.canWrite

                            Button {
                                visible: managePage.canWrite
                                enabled: managePage.busy === 0
                                text: appRow.app.running ? qsTr("Close") : qsTr("Start")
                                flat: true
                                onClicked: {
                                    if (appRow.app.running) {
                                        managePage.change("launch", "POST", "/api/v1/apps/close", {}, qsTr("%1 closed.").arg(appRow.app.name))
                                    }
                                    else {
                                        launchDialog.app = appRow.app
                                        launchDialog.open()
                                    }
                                }
                            }

                            Button {
                                visible: managePage.canWrite
                                enabled: managePage.busy === 0
                                text: qsTr("Edit")
                                flat: true
                                onClicked: appEditor.edit(appRow.app)
                            }

                            ToolButton {
                                visible: managePage.canWrite
                                enabled: managePage.busy === 0
                                text: "⋯"
                                Accessible.name: qsTr("More for %1").arg(appRow.app.name)
                                onClicked: appMenu.open()

                                Menu {
                                    id: appMenu
                                    MenuItem {
                                        text: qsTr("Move up")
                                        enabled: index > 0
                                        onTriggered: managePage.moveApp(index, -1)
                                    }
                                    MenuItem {
                                        text: qsTr("Move down")
                                        enabled: index < managePage.apps.length - 1
                                        onTriggered: managePage.moveApp(index, 1)
                                    }
                                    MenuItem {
                                        text: qsTr("Remove...")
                                        onTriggered: {
                                            confirmDialog.ask(qsTr("Remove %1?").arg(appRow.app.name),
                                                              qsTr("It disappears from every device's app list. Its files on the host are not touched."),
                                                              function() {
                                                                  managePage.change("apps", "DELETE", "/api/v1/apps/" + appRow.app.uuid, undefined, qsTr("%1 removed.").arg(appRow.app.name))
                                                              })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Devices and their streams
                SettingsCard {
                    visible: tabs.currentIndex === 1 && managePage.devicesLoaded
                    title: qsTr("Paired devices")

                    SettingsRow {
                        visible: managePage.devices.length === 0
                        text: qsTr("No paired devices")
                    }

                    Repeater {
                        model: managePage.devices

                        delegate: SettingsRow {
                            id: deviceRow
                            readonly property var device: modelData
                            text: device.name
                            badge: device.this_device ? qsTr("This device") : (managePage.sessionOf(device.uuid) ? qsTr("Streaming") : "")
                            hint: managePage.deviceHint(device)
                            available: managePage.canWrite

                            Button {
                                visible: managePage.canWrite && managePage.sessionOf(deviceRow.device.uuid) !== null
                                enabled: managePage.busy === 0
                                text: qsTr("End stream")
                                flat: true
                                onClicked: confirmDialog.ask(qsTr("End the stream on %1?").arg(deviceRow.device.name),
                                                             qsTr("The app keeps running on the host."),
                                                             function() {
                                                                 managePage.change("disconnect", "POST", "/api/v1/devices/" + deviceRow.device.uuid + "/disconnect", {},
                                                                                   qsTr("Stream on %1 ended.").arg(deviceRow.device.name))
                                                             })
                            }

                            Button {
                                visible: managePage.canWrite
                                enabled: managePage.busy === 0
                                text: qsTr("Edit")
                                flat: true
                                onClicked: deviceEditor.edit(deviceRow.device)
                            }

                            ToolButton {
                                visible: managePage.canWrite
                                enabled: managePage.busy === 0
                                text: "⋯"
                                Accessible.name: qsTr("More for %1").arg(deviceRow.device.name)
                                onClicked: deviceMenu.open()

                                Menu {
                                    id: deviceMenu
                                    MenuItem {
                                        text: qsTr("Unpair...")
                                        onTriggered: {
                                            var self = deviceRow.device.this_device
                                            confirmDialog.ask(qsTr("Unpair %1?").arg(deviceRow.device.name),
                                                              self ? qsTr("This is the device you are using. It can't stream from or manage the host until you pair it again.")
                                                                   : qsTr("It can't stream from the host until it is paired again. A stream it has now ends."),
                                                              function() {
                                                                  managePage.change(self ? "unpair-self" : "devices", "DELETE", "/api/v1/devices/" + deviceRow.device.uuid, undefined,
                                                                                    qsTr("%1 unpaired.").arg(deviceRow.device.name))
                                                              })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Displays
                SettingsCard {
                    visible: tabs.currentIndex === 2 && managePage.displaysLoaded
                    title: qsTr("Displays")
                    description: managePage.virtualDisplay === true
                                 ? qsTr("Each stream gets its own virtual display that matches the device. Turn this off to stream one of these monitors.")
                                 : managePage.outputName === "" ? qsTr("Streams use the main display, unless a device or app asks for a virtual display.")
                                                                : qsTr("Streams use the monitor marked below, unless a device or app asks for a virtual display.")

                    SettingsRow {
                        visible: managePage.virtualDisplay !== null
                        text: qsTr("Stream to a virtual display")
                        hint: qsTr("Your monitors are left alone, and the stream matches the device's resolution and refresh rate.")
                        available: managePage.canWrite
                        Switch {
                            enabled: managePage.canWrite && managePage.busy === 0
                            checked: managePage.virtualDisplay === true
                            onToggled: managePage.change("displays", "PATCH", "/api/v1/config", {"set": {"headless_mode": checked}}, function(data) {
                                return data.restart_required ? qsTr("Saved. Restart the host (Host Settings) to apply it.") : ""
                            })
                            Accessible.name: qsTr("Stream to a virtual display")
                        }
                    }

                    SettingsRow {
                        visible: managePage.displays.length === 0
                        text: qsTr("The host didn't report any displays")
                    }

                    Repeater {
                        model: managePage.displays

                        delegate: SettingsRow {
                            id: displayRow
                            readonly property var display: modelData
                            text: display.friendly_name !== "" ? display.friendly_name : display.name
                            badge: managePage.displayBadge(display)
                            hint: managePage.displayHint(display)
                            info: display.name
                            available: managePage.canWrite

                            Button {
                                visible: managePage.canWrite && managePage.virtualDisplay !== true && managePage.displayBadge(displayRow.display) === ""
                                enabled: managePage.busy === 0
                                text: qsTr("Stream this one")
                                flat: true
                                onClicked: managePage.change("displays", "PATCH", "/api/v1/config", {"set": {"output_name": displayRow.display.id}}, function(data) {
                                    return data.restart_required ? qsTr("Saved. Restart the host (Host Settings) to apply it.") : qsTr("Streams now use %1.").arg(displayRow.text)
                                })
                            }
                        }
                    }

                    SettingsRow {
                        visible: managePage.outputName !== "" && managePage.canWrite
                        text: qsTr("Use the main display again")
                        hint: qsTr("Forget the chosen display.")
                        Button {
                            text: qsTr("Use main display")
                            flat: true
                            enabled: managePage.busy === 0
                            onClicked: managePage.change("displays", "PATCH", "/api/v1/config", {"reset": ["output_name"]}, function(data) {
                                return data.restart_required ? qsTr("Saved. Restart the host (Host Settings) to apply it.") : qsTr("Streams use the main display again.")
                            })
                        }
                    }
                }

                SettingsCard {
                    visible: tabs.currentIndex === 2 && managePage.displaysLoaded && managePage.canWrite
                    title: qsTr("Display changes")

                    SettingsRow {
                        text: qsTr("Forget saved display changes")
                        hint: qsTr("Use this if the host keeps putting back a resolution or display layout after streams.")
                        info: qsTr("While streaming, the host can change the display's resolution, refresh rate or HDR, and undoes that afterwards. If the host stopped unexpectedly, it remembers what to undo. This forgets that, so nothing more is changed back.")
                        Button {
                            text: qsTr("Forget")
                            flat: true
                            enabled: managePage.busy === 0
                            onClicked: confirmDialog.ask(qsTr("Forget saved display changes?"),
                                                         qsTr("The host won't undo display changes from earlier streams. Displays stay as they are now."),
                                                         function() {
                                                             managePage.change("displays", "POST", "/api/v1/displays/reset", {}, qsTr("Saved display changes forgotten."))
                                                         })
                        }
                    }
                }
            }
        }
    }

    // Yes/no for actions that can't be undone from here
    Dialog {
        id: confirmDialog
        property string message: ""
        property var action: null
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel

        function ask(question, detail, onYes) {
            title = question
            message = detail
            action = onYes
            open()
        }

        Label {
            width: Math.min(managePage.width - 120, 480)
            wrapMode: Text.Wrap
            text: confirmDialog.message
        }

        onAccepted: {
            if (action) {
                action()
            }
        }
    }

    Dialog {
        id: launchDialog
        property var app: null
        modal: true
        anchors.centerIn: parent
        title: app ? qsTr("Start %1 on the host?").arg(app.name) : ""
        standardButtons: Dialog.Ok | Dialog.Cancel

        Label {
            width: Math.min(managePage.width - 120, 480)
            wrapMode: Text.Wrap
            text: qsTr("It starts without a stream, as if a device had started it.") +
                  (managePage.runningName !== "" ? "\n\n" + qsTr("%1, which is running now, is closed first.").arg(managePage.runningName) : "")
        }

        onAccepted: managePage.change("launch", "POST", "/api/v1/apps/" + app.uuid + "/launch", {}, qsTr("%1 started.").arg(app.name))
    }

    // Add or change an app. Fields this page doesn't show (commands to run before and
    // after, cover image, ...) are sent back unchanged.
    Dialog {
        id: appEditor
        property var original: null
        property var errors: ({})
        property bool saving: false
        modal: true
        anchors.centerIn: parent
        title: original ? qsTr("Edit %1").arg(original.name) : qsTr("Add app")
        standardButtons: Dialog.Save | Dialog.Cancel
        width: Math.min(managePage.width - 40, 560)
        height: Math.min(managePage.height - 40, editorColumn.height + 150)

        function edit(app) {
            original = app
            errors = ({})
            nameField.text = app ? app.name : ""
            cmdField.text = app && app.cmd ? app.cmd : ""
            detachedField.text = app && app.detached ? app.detached.join("\n") : ""
            dirField.text = app && app["working-dir"] ? app["working-dir"] : ""
            elevatedSwitch.checked = app ? app.elevated === true : false
            virtualSwitch.checked = app ? app["virtual-display"] === true : false
            autoDetachSwitch.checked = app ? app["auto-detach"] !== false : true
            waitAllSwitch.checked = app ? app["wait-all"] !== false : true
            timeoutField.text = String(app && app["exit-timeout"] !== undefined ? app["exit-timeout"] : 5)
            open()
            nameField.forceActiveFocus()
        }

        function errorFor(key) {
            return errors.hasOwnProperty(key) ? errors[key] : ""
        }

        // Set a field, but don't add one the app didn't have just to store its default
        function setField(app, key, value, defaultValue) {
            if (JSON.stringify(value) === JSON.stringify(defaultValue) && !(original && original.hasOwnProperty(key))) {
                delete app[key]
            }
            else {
                app[key] = value
            }
        }

        onAccepted: {
            var app = original ? Object.assign({}, original) : {}
            delete app.running
            app.name = nameField.text.trim()
            setField(app, "cmd", cmdField.text.trim(), "")
            setField(app, "detached", detachedField.text.split("\n").map(function(l) { return l.trim() }).filter(function(l) { return l !== "" }), [])
            setField(app, "working-dir", dirField.text.trim(), "")
            setField(app, "elevated", elevatedSwitch.checked, false)
            setField(app, "virtual-display", virtualSwitch.checked, false)
            setField(app, "auto-detach", autoDetachSwitch.checked, true)
            setField(app, "wait-all", waitAllSwitch.checked, true)
            var timeout = Number(timeoutField.text)
            // Not a number: sent as typed, so the host says what's wrong with it
            setField(app, "exit-timeout", timeoutField.text.trim() === "" || isNaN(timeout) ? timeoutField.text : timeout, 5)
            if (original) {
                managePage.change("apps", "PUT", "/api/v1/apps/" + original.uuid, app, qsTr("%1 saved.").arg(app.name))
            }
            else {
                managePage.change("apps", "POST", "/api/v1/apps", app, qsTr("%1 added.").arg(app.name))
            }
            saving = true
        }

        Flickable {
            id: appFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: editorColumn.height
            clip: true
            ScrollBar.vertical: ScrollBar {}

            Column {
                id: editorColumn
                width: appFlick.width - 12
                spacing: 6

                Label { text: qsTr("Name"); font.pointSize: Theme.fontLabel }
                TextField { id: nameField; width: parent.width; Accessible.name: qsTr("Name") }
                Label { visible: text !== ""; text: appEditor.errorFor("name"); color: Theme.statusError; wrapMode: Text.Wrap; width: parent.width }

                Label { text: qsTr("Command"); font.pointSize: Theme.fontLabel }
                TextField { id: cmdField; width: parent.width; placeholderText: qsTr("Empty for the desktop"); Accessible.name: qsTr("Command") }
                Label { visible: text !== ""; text: appEditor.errorFor("cmd"); color: Theme.statusError; wrapMode: Text.Wrap; width: parent.width }

                Label { text: qsTr("Commands that keep running on their own (one per line)"); font.pointSize: Theme.fontLabel; wrapMode: Text.Wrap; width: parent.width }
                TextArea { id: detachedField; width: parent.width; wrapMode: TextEdit.NoWrap; placeholderText: qsTr("For example steam://open/bigpicture"); Accessible.name: qsTr("Detached commands") }
                Label { visible: text !== ""; text: appEditor.errorFor("detached"); color: Theme.statusError; wrapMode: Text.Wrap; width: parent.width }

                Label { text: qsTr("Working folder"); font.pointSize: Theme.fontLabel }
                TextField { id: dirField; width: parent.width; placeholderText: qsTr("The command's own folder"); Accessible.name: qsTr("Working folder") }

                Switch { id: elevatedSwitch; text: qsTr("Run as administrator") }
                Switch { id: virtualSwitch; text: qsTr("Always stream on a virtual display") }
                Switch { id: autoDetachSwitch; text: qsTr("Keep streaming when the command exits quickly (launchers)") }
                Switch { id: waitAllSwitch; text: qsTr("Wait for all of the app's processes to end") }

                Label { text: qsTr("Seconds to wait for the app to close when the stream ends"); font.pointSize: Theme.fontLabel; wrapMode: Text.Wrap; width: parent.width }
                TextField { id: timeoutField; width: 120; inputMethodHints: Qt.ImhDigitsOnly; Accessible.name: qsTr("Exit timeout") }
                Label { visible: text !== ""; text: appEditor.errorFor("exit-timeout"); color: Theme.statusError; wrapMode: Text.Wrap; width: parent.width }

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Theme.textSecondary
                    font.pointSize: Theme.fontDetail
                    text: qsTr("Commands to run before and after, the cover image and other options are kept as they are. Change them in the host's web UI.")
                }

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Theme.statusError
                    visible: text !== ""
                    text: {
                        var shown = ["name", "cmd", "detached", "exit-timeout"]
                        var rest = []
                        for (var key in appEditor.errors) {
                            if (shown.indexOf(key) < 0) {
                                rest.push(key + ": " + appEditor.errors[key])
                            }
                        }
                        return rest.join("\n")
                    }
                }
            }
        }
    }

    // Change a paired device: name, display mode and permissions
    Dialog {
        id: deviceEditor
        property var original: null
        property int perm: 0
        property var errors: ({})
        property bool saving: false
        readonly property bool self: original !== null && original.this_device === true
        modal: true
        anchors.centerIn: parent
        title: original ? qsTr("Edit %1").arg(original.name) : ""
        standardButtons: Dialog.Save | Dialog.Cancel
        width: Math.min(managePage.width - 40, 560)
        height: Math.min(managePage.height - 40, deviceColumn.height + 150)

        function edit(device) {
            original = device
            perm = device.perm
            errors = ({})
            deviceName.text = device.name
            displayMode.text = device.display_mode || ""
            alwaysVirtual.checked = device.always_use_virtual_display === true
            open()
        }

        function setBits(mask, bits) {
            perm = ((perm & ~mask) | bits) >>> 0
        }

        onAccepted: {
            var body = {"name": deviceName.text.trim(), "display_mode": displayMode.text.trim(), "always_use_virtual_display": alwaysVirtual.checked}
            if (!self) {
                body.perm = perm
            }
            managePage.change("devices", "PATCH", "/api/v1/devices/" + original.uuid, body, qsTr("%1 saved.").arg(body.name))
            saving = true
        }

        Flickable {
            id: deviceFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: deviceColumn.height
            clip: true
            ScrollBar.vertical: ScrollBar {}

            Column {
                id: deviceColumn
                width: deviceFlick.width - 12
                spacing: 6

                Label { text: qsTr("Name"); font.pointSize: Theme.fontLabel }
                TextField { id: deviceName; width: parent.width; Accessible.name: qsTr("Name") }
                Label { visible: text !== ""; text: deviceEditor.errors.name || ""; color: Theme.statusError; wrapMode: Text.Wrap; width: parent.width }


                Label {
                    width: parent.width
                    visible: deviceEditor.self
                    wrapMode: Text.Wrap
                    color: Theme.textSecondary
                    font.pointSize: Theme.fontDetail
                    text: qsTr("A device can't change its own permissions. Use the host's web UI or another device.")
                }

                Label { text: qsTr("Can stream"); font.pointSize: Theme.fontLabel }
                ComboBox {
                    width: parent.width
                    enabled: !deviceEditor.self
                    model: managePage.accessLevels.map(function(l) { return l.title })
                    currentIndex: managePage.levelIndex(managePage.accessLevels, deviceEditor.perm)
                    onActivated: deviceEditor.setBits(managePage.accessMask, managePage.accessLevels[index].bits)
                    Accessible.name: qsTr("Can stream")
                }
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Theme.textSecondary
                    font.pointSize: Theme.fontDetail
                    text: managePage.accessLevels[managePage.levelIndex(managePage.accessLevels, deviceEditor.perm)].help
                }

                Label { text: qsTr("Host management"); font.pointSize: Theme.fontLabel }
                ComboBox {
                    width: parent.width
                    enabled: !deviceEditor.self
                    model: managePage.manageLevels.map(function(l) { return l.title })
                    currentIndex: managePage.levelIndex(managePage.manageLevels, deviceEditor.perm)
                    onActivated: deviceEditor.setBits(managePage.manageMask, managePage.manageLevels[index].bits)
                    Accessible.name: qsTr("Host management")
                }
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Theme.textSecondary
                    font.pointSize: Theme.fontDetail
                    text: managePage.manageLevels[managePage.levelIndex(managePage.manageLevels, deviceEditor.perm)].help
                }

                Label { text: qsTr("Input it may send"); font.pointSize: Theme.fontLabel }
                Flow {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: managePage.inputs
                        CheckBox {
                            text: modelData.title
                            enabled: !deviceEditor.self
                            checked: (deviceEditor.perm & modelData.bit) !== 0
                            onToggled: deviceEditor.setBits(modelData.bit, checked ? modelData.bit : 0)
                        }
                    }
                }

                Label { text: qsTr("Extras"); font.pointSize: Theme.fontLabel }
                Repeater {
                    model: managePage.extras
                    CheckBox {
                        text: modelData.title + " — " + modelData.help
                        enabled: !deviceEditor.self
                        checked: (deviceEditor.perm & modelData.bit) !== 0
                        onToggled: deviceEditor.setBits(modelData.bit, checked ? modelData.bit : 0)
                    }
                }

                Switch {
                    id: alwaysVirtual
                    text: qsTr("Always use a virtual display for this device")
                }
                Label { text: qsTr("Display mode for this device"); font.pointSize: Theme.fontLabel }
                TextField { id: displayMode; width: parent.width; placeholderText: qsTr("Empty: what the device asks for, e.g. 1920x1080x60"); Accessible.name: qsTr("Display mode") }
                Label { visible: text !== ""; text: deviceEditor.errors.display_mode || ""; color: Theme.statusError; wrapMode: Text.Wrap; width: parent.width }
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Theme.textSecondary
                    font.pointSize: Theme.fontDetail
                    text: qsTr("Commands to run when this device connects are kept as they are. Change them in the host's web UI.")
                }

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Theme.statusError
                    visible: text !== ""
                    text: deviceEditor.errors.perm || ""
                }
            }
        }
    }
}
