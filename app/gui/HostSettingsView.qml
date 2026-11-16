import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import ComputerModel 1.0

import "."

// Norilight: settings of a Norishine host, through its management API (/api/v1 on
// the HTTPS port, authenticated with this client's paired certificate). The host owns
// the list of settings (the schema), so this page renders whatever it describes.
// Reading needs "Read Host Settings" on the host, changing needs "Change Host Settings";
// both are granted per device in the host's web UI.
Item {
    id: hostPage

    property int computerIndex
    property ComputerModel computerModel

    // From the host
    property var hostStatus: null
    property var schema: null
    property var values: ({})
    property var invalid: ({})

    // Local state
    property var edits: ({})        // key: new typed value
    property var errors: ({})       // key: message from the host
    property string loadError: ""
    property bool accessDenied: false
    property string notice: ""
    property bool saving: false
    property bool restartNeeded: false
    property string searchText: ""
    property bool showAdvanced: false
    property int pendingLoads: 0

    readonly property int manageWrite: 0x20000000
    readonly property bool canWrite: hostStatus !== null && (hostStatus.device.permissions & manageWrite) !== 0
    readonly property int editCount: Object.keys(edits).length

    function request(kind, verb, path, body) {
        computerModel.hostApiRequest(computerIndex, kind, verb, path, body === undefined ? "" : JSON.stringify(body))
    }

    function reload() {
        loadError = ""
        accessDenied = false
        pendingLoads = 3
        request("status", "GET", "/api/v1/status")
        request("schema", "GET", "/api/v1/config/schema?locale=" + Qt.locale().name)
        request("values", "GET", "/api/v1/config")
    }

    function same(a, b) {
        return JSON.stringify(a) === JSON.stringify(b)
    }

    function settingByKey(key) {
        if (!schema) {
            return null
        }
        for (var i = 0; i < schema.settings.length; i++) {
            if (schema.settings[i].key === key) {
                return schema.settings[i]
            }
        }
        return null
    }

    function stored(setting) {
        return values.hasOwnProperty(setting.key) ? values[setting.key] : setting["default"]
    }

    function current(setting) {
        return edits.hasOwnProperty(setting.key) ? edits[setting.key] : stored(setting)
    }

    function setEdit(setting, value) {
        var e = Object.assign({}, edits)
        if (same(value, stored(setting))) {
            delete e[setting.key]
        }
        else {
            e[setting.key] = value
        }
        edits = e

        if (errors.hasOwnProperty(setting.key)) {
            var errs = Object.assign({}, errors)
            delete errs[setting.key]
            errors = errs
        }
        notice = ""
    }

    function isComplex(setting) {
        return ["prep_commands", "server_commands", "keybindings", "mode_remapping"].indexOf(setting.type) >= 0
    }

    function matches(setting) {
        if (!setting.available || (!showAdvanced && setting.tier !== "basic")) {
            return false
        }
        if (searchText === "") {
            return true
        }
        var haystack = (setting.title + " " + setting.help + " " + setting.key).toLowerCase()
        var words = searchText.toLowerCase().split(/\s+/)
        for (var i = 0; i < words.length; i++) {
            if (words[i] !== "" && haystack.indexOf(words[i]) < 0) {
                return false
            }
        }
        return true
    }

    function settingsIn(categoryId) {
        var result = []
        if (!schema) {
            return result
        }
        for (var i = 0; i < schema.settings.length; i++) {
            var s = schema.settings[i]
            if (s.category === categoryId && matches(s)) {
                result.push(s)
            }
        }
        return result
    }

    function rowHint(setting) {
        if (errors.hasOwnProperty(setting.key)) {
            return errors[setting.key]
        }
        if (invalid.hasOwnProperty(setting.key)) {
            return qsTr("The stored value \"%1\" isn't valid: %2").arg(invalid[setting.key].value).arg(invalid[setting.key].error)
        }
        if (isComplex(setting)) {
            return qsTr("Change this in the host's web UI.")
        }
        if (edits.hasOwnProperty(setting.key)) {
            return qsTr("Changed, not saved yet")
        }
        return ""
    }

    function save(confirmed) {
        var set = {}
        var reset = []
        var dangerous = []
        for (var key in edits) {
            var s = settingByKey(key)
            if (same(edits[key], s["default"])) {
                reset.push(key)
            }
            else {
                set[key] = edits[key]
            }
            if (s.tier === "dangerous") {
                dangerous.push(s.title)
            }
        }
        if (dangerous.length > 0 && !confirmed) {
            confirmDialog.names = dangerous.join(", ")
            confirmDialog.open()
            return
        }
        saving = true
        notice = ""
        request("save", "PATCH", "/api/v1/config", {"set": set, "reset": reset})
    }

    function describeFailure(status, data, error) {
        if (status === 0) {
            return qsTr("Couldn't reach the host: %1").arg(error)
        }
        if (data && data.error) {
            return data.error
        }
        return qsTr("The host answered with an error (%1).").arg(status)
    }

    Connections {
        target: hostPage.computerModel

        function onHostApiResponse(requestId, status, body, error) {
            var data = null
            try {
                data = JSON.parse(body)
            }
            catch (e) {
                data = null
            }

            if (requestId === "status" || requestId === "schema" || requestId === "values") {
                hostPage.pendingLoads = Math.max(0, hostPage.pendingLoads - 1)
                if (status === 403) {
                    hostPage.accessDenied = true
                    hostPage.loadError = hostPage.describeFailure(status, data, error)
                    return
                }
                if (status !== 200 || data === null) {
                    hostPage.loadError = hostPage.describeFailure(status, data, error)
                    return
                }
                if (requestId === "status") {
                    hostPage.hostStatus = data
                }
                else if (requestId === "schema") {
                    hostPage.schema = data
                }
                else {
                    hostPage.values = data.values
                    hostPage.invalid = data.invalid
                }
            }
            else if (requestId === "save") {
                hostPage.saving = false
                if (status === 200 && data !== null) {
                    hostPage.edits = ({})
                    hostPage.errors = ({})
                    hostPage.restartNeeded = hostPage.restartNeeded || data.restart_required
                    hostPage.notice = data.restart_required ? qsTr("Saved. Restart the host to apply the changes.") : qsTr("Saved.")
                    hostPage.request("values", "GET", "/api/v1/config")
                    hostPage.pendingLoads += 1
                }
                else if (status === 400 && data !== null && data.errors) {
                    hostPage.errors = data.errors
                    hostPage.notice = qsTr("Nothing was saved: fix the settings marked below.")
                }
                else {
                    hostPage.notice = hostPage.describeFailure(status, data, error)
                }
            }
            else if (requestId === "restart") {
                if (status === 200) {
                    hostPage.restartNeeded = false
                    hostPage.notice = qsTr("The host is restarting. Streams on it stop for a moment.")
                    reloadTimer.start()
                }
                else {
                    hostPage.notice = hostPage.describeFailure(status, data, error)
                }
            }
        }
    }

    Timer {
        id: reloadTimer
        interval: 6000
        onTriggered: hostPage.reload()
    }

    StackView.onActivated: {
        if (schema === null) {
            reload()
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
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

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search host settings")
                    enabled: hostPage.schema !== null
                    onTextChanged: hostPage.searchText = text.trim()
                }

                Switch {
                    id: advancedSwitch
                    text: qsTr("Advanced")
                    enabled: hostPage.schema !== null
                    onToggled: hostPage.showAdvanced = checked
                }

                Button {
                    text: qsTr("Refresh")
                    flat: true
                    enabled: hostPage.pendingLoads === 0 && !hostPage.saving
                    onClicked: hostPage.reload()
                }

                Button {
                    text: hostPage.editCount > 0 ? qsTr("Save (%1)").arg(hostPage.editCount) : qsTr("Save")
                    highlighted: true
                    visible: hostPage.canWrite
                    enabled: hostPage.editCount > 0 && !hostPage.saving
                    onClicked: hostPage.save(false)
                }
            }

            // Messages
            Rectangle {
                width: parent.width
                height: noticeColumn.height + 24
                radius: Theme.cardRadius
                color: Theme.card
                visible: hostPage.notice !== "" || hostPage.restartNeeded

                Column {
                    id: noticeColumn
                    x: Theme.cardPadding
                    y: 12
                    width: parent.width - 2 * Theme.cardPadding
                    spacing: 8

                    Label {
                        width: parent.width
                        visible: hostPage.notice !== ""
                        text: hostPage.notice
                        wrapMode: Text.Wrap
                        color: Theme.textPrimary
                        font.pointSize: Theme.fontBody
                    }

                    Button {
                        visible: hostPage.restartNeeded && hostPage.canWrite
                        text: qsTr("Restart host")
                        onClicked: {
                            hostPage.notice = qsTr("Asking the host to restart...")
                            hostPage.request("restart", "POST", "/api/v1/restart", {})
                        }
                    }
                }
            }

            // Loading and access problems
            SettingsCard {
                visible: hostPage.loadError !== "" || (hostPage.pendingLoads > 0 && hostPage.schema === null)
                title: hostPage.accessDenied ? qsTr("This device can't see the host's settings yet") : ""

                SettingsRow {
                    text: hostPage.loadError !== "" ? hostPage.loadError : qsTr("Loading host settings...")
                    hint: hostPage.accessDenied ?
                              qsTr("On the host, open the web UI, go to paired devices, and turn on \"Read Host Settings\" for this device (or \"Change Host Settings\" to also change them here).") : ""
                }
            }

            // Host status
            SettingsCard {
                visible: hostPage.hostStatus !== null
                title: qsTr("Host")

                SettingsRow {
                    text: qsTr("Version")
                    Label {
                        text: hostPage.hostStatus ? "Norishine " + hostPage.hostStatus.version + " (" + hostPage.hostStatus.platform + ")" : ""
                        color: Theme.textSecondary
                    }
                }
                SettingsRow {
                    text: qsTr("Running app")
                    Label {
                        text: hostPage.hostStatus && hostPage.hostStatus.running_app ? hostPage.hostStatus.running_app.name : qsTr("None")
                        color: Theme.textSecondary
                    }
                }
                SettingsRow {
                    text: qsTr("Active streams")
                    Label {
                        text: hostPage.hostStatus ? String(hostPage.hostStatus.active_sessions) : ""
                        color: Theme.textSecondary
                    }
                }
                SettingsRow {
                    text: qsTr("This device")
                    hint: hostPage.canWrite ? "" : qsTr("To change settings from here, turn on \"Change Host Settings\" for this device in the host's web UI.")
                    Label {
                        text: hostPage.canWrite ? qsTr("Can change settings") : qsTr("Can read settings")
                        color: Theme.textSecondary
                    }
                }
            }

            // Settings, one card per category
            Repeater {
                model: hostPage.schema ? hostPage.schema.categories : []

                delegate: SettingsCard {
                    id: categoryCard
                    readonly property var categorySettings: hostPage.settingsIn(modelData.id)
                    visible: categorySettings.length > 0
                    title: modelData.title

                    Repeater {
                        model: categoryCard.categorySettings

                        delegate: SettingsRow {
                            id: settingRow
                            readonly property var setting: modelData
                            text: setting.title
                            info: setting.help + (setting.tier === "dangerous" ? "\n\n" + qsTr("Changing this can make the host unreachable or less secure.") : "")
                            badge: setting.tier === "dangerous" ? qsTr("Careful") : ""
                            hint: hostPage.rowHint(setting)
                            hintIsError: hostPage.errors.hasOwnProperty(setting.key) || hostPage.invalid.hasOwnProperty(setting.key)
                            available: hostPage.canWrite && !hostPage.isComplex(setting)

                            Loader {
                                sourceComponent: {
                                    switch (settingRow.setting.type) {
                                    case "boolean": return booleanControl
                                    case "choice": return choiceControl
                                    case "integer":
                                    case "number": return numberControl
                                    case "string":
                                    case "path": return textControl
                                    default: return complexControl
                                    }
                                }

                                Component {
                                    id: booleanControl
                                    Switch {
                                        enabled: settingRow.available
                                        checked: hostPage.current(settingRow.setting) === true
                                        onToggled: hostPage.setEdit(settingRow.setting, checked)
                                        Accessible.name: settingRow.text
                                    }
                                }

                                Component {
                                    id: choiceControl
                                    ComboBox {
                                        enabled: settingRow.available
                                        implicitWidth: 220
                                        model: settingRow.setting.choices.map(function(c) { return c === "" ? qsTr("Automatic") : c })
                                        currentIndex: settingRow.setting.choices.indexOf(hostPage.current(settingRow.setting))
                                        onActivated: hostPage.setEdit(settingRow.setting, settingRow.setting.choices[index])
                                        Accessible.name: settingRow.text
                                    }
                                }

                                Component {
                                    id: numberControl
                                    TextField {
                                        enabled: settingRow.available
                                        implicitWidth: 140
                                        horizontalAlignment: TextInput.AlignRight
                                        text: String(hostPage.current(settingRow.setting))
                                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                                        // Count the change while typing, so Save is ready without leaving the field.
                                        onTextEdited: {
                                            var n = Number(text)
                                            if (text.trim() !== "" && !isNaN(n)) {
                                                hostPage.setEdit(settingRow.setting, n)
                                            }
                                        }
                                        onEditingFinished: {
                                            var n = Number(text)
                                            if (text.trim() !== "" && !isNaN(n)) {
                                                hostPage.setEdit(settingRow.setting, n)
                                            }
                                            else {
                                                text = String(hostPage.current(settingRow.setting))
                                            }
                                        }
                                        Accessible.name: settingRow.text
                                    }
                                }

                                Component {
                                    id: textControl
                                    TextField {
                                        enabled: settingRow.available
                                        implicitWidth: 260
                                        text: String(hostPage.current(settingRow.setting))
                                        placeholderText: text === "" ? qsTr("Default") : ""
                                        onTextEdited: hostPage.setEdit(settingRow.setting, text)
                                        Accessible.name: settingRow.text
                                    }
                                }

                                Component {
                                    id: complexControl
                                    Label {
                                        width: Math.min(260, implicitWidth)
                                        elide: Text.ElideRight
                                        color: Theme.textSecondary
                                        text: {
                                            var v = hostPage.current(settingRow.setting)
                                            if (Array.isArray(v)) {
                                                return v.length === 0 ? qsTr("None") : qsTr("%n entries", "", v.length)
                                            }
                                            return typeof v === "string" ? v : JSON.stringify(v)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: confirmDialog
        property string names: ""
        modal: true
        anchors.centerIn: parent
        title: qsTr("Change these settings?")
        standardButtons: Dialog.Ok | Dialog.Cancel

        Label {
            width: Math.min(hostPage.width - 120, 480)
            wrapMode: Text.Wrap
            text: qsTr("%1 can make the host unreachable or less secure. You may need the host's web UI to undo it.").arg(confirmDialog.names)
        }

        onAccepted: hostPage.save(true)
    }
}
