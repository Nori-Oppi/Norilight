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

    // An integer with a readable name for every value is shown as a list (as in the web UI).
    function isEnumInteger(setting) {
        if (setting.type !== "integer" || !setting.value_titles || setting.max === undefined) {
            return false
        }
        for (var n = setting.min; n <= setting.max; n++) {
            if (!setting.value_titles.hasOwnProperty(String(n))) {
                return false
            }
        }
        return true
    }

    function valueTitle(setting, value) {
        var titles = setting.value_titles || {}
        if (titles.hasOwnProperty(String(value))) {
            return titles[String(value)]
        }
        if (value === "") {
            return qsTr("Automatic")
        }
        if (typeof value === "boolean") {
            return value ? qsTr("On") : qsTr("Off")
        }
        return String(value)
    }

    // List entries: readable names, with the default marked in the list itself.
    function listValues(setting) {
        var values = []
        if (setting.type === "choice") {
            values = setting.choices.slice()
        }
        else {
            for (var n = setting.min; n <= setting.max; n++) {
                values.push(n)
            }
        }
        return values
    }

    function listTitles(setting) {
        return listValues(setting).map(function(v) {
            var title = valueTitle(setting, v)
            return same(v, setting["default"]) ? qsTr("%1 (default)").arg(title) : title
        })
    }

    // The one named special value of a wide number range (0 = "No limit", -1 = "Off").
    function specialValue(setting) {
        if (isEnumInteger(setting) || !setting.value_titles) {
            return null
        }
        var keys = Object.keys(setting.value_titles)
        return keys.length === 1 ? {"value": Number(keys[0]), "title": setting.value_titles[keys[0]]} : null
    }

    function unitScale(setting) {
        return setting.unit === "kbps" ? 1000 : 1
    }

    function unitText(setting) {
        switch (setting.unit) {
        case "kbps": return qsTr("Mbps")
        case "ms": return qsTr("ms")
        case "percent": return "%"
        case "fps": return qsTr("fps")
        case "per_second": return qsTr("/s")
        }
        return ""
    }

    // Whether the setting it depends on has one of the values it needs.
    function dependencyMet(setting) {
        if (!setting.depends_on) {
            return true
        }
        var other = settingByKey(setting.depends_on.key)
        if (!other) {
            return true
        }
        var value = current(other)
        for (var i = 0; i < setting.depends_on.values.length; i++) {
            if (same(setting.depends_on.values[i], value)) {
                return true
            }
        }
        return false
    }

    function dependencyText(setting) {
        var other = settingByKey(setting.depends_on.key)
        var names = setting.depends_on.values.map(function(v) { return "\u201C" + valueTitle(other, v) + "\u201D" })
        return qsTr("Only has an effect when \u201C%1\u201D is %2.").arg(other.title).arg(names.join(" / "))
    }

    function isComplex(setting) {
        return ["prep_commands", "server_commands", "keybindings", "mode_remapping"].indexOf(setting.type) >= 0
    }

    function matches(setting) {
        // Search covers advanced settings too, so nothing is hard to find (as in the web UI).
        if (!setting.available || (!showAdvanced && setting.tier !== "basic" && searchText === "")) {
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

    // What a row says under its name: a problem first, otherwise its explanation, plus
    // whether it has an effect right now and what the default is.
    function rowHint(setting) {
        if (errors.hasOwnProperty(setting.key)) {
            return errors[setting.key]
        }
        if (invalid.hasOwnProperty(setting.key)) {
            return qsTr("The stored value \"%1\" isn't valid: %2").arg(invalid[setting.key].value).arg(invalid[setting.key].error)
        }
        var parts = []
        if (setting.help) {
            parts.push(setting.help)
        }
        if (!dependencyMet(setting)) {
            parts.push(dependencyText(setting))
        }
        if (isComplex(setting)) {
            parts.push(qsTr("Change this in the host's web UI."))
        }
        else if (edits.hasOwnProperty(setting.key)) {
            parts.push(qsTr("Changed, not saved yet. Default: %1").arg(valueTitle(setting, setting["default"])))
        }
        else if (!same(current(setting), setting["default"])) {
            parts.push(qsTr("Default: %1").arg(valueTitle(setting, setting["default"])))
        }
        return parts.join("\n")
    }

    property bool restartAfterSave: false
    readonly property bool editsNeedRestart: {
        for (var key in edits) {
            var s = settingByKey(key)
            if (s && s.restart_required) {
                return true
            }
        }
        return false
    }

    function save(confirmed, andRestart) {
        if (andRestart !== undefined) {
            restartAfterSave = andRestart
        }
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
                    if (hostPage.restartAfterSave && data.restart_required) {
                        hostPage.notice = qsTr("Saved. Asking the host to restart...")
                        hostPage.request("restart", "POST", "/api/v1/restart", {})
                    }
                    hostPage.restartAfterSave = false
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
                    text: qsTr("Save only")
                    flat: true
                    visible: hostPage.canWrite && hostPage.editCount > 0 && hostPage.editsNeedRestart
                    enabled: !hostPage.saving
                    onClicked: hostPage.save(false, false)
                }

                Button {
                    text: hostPage.editCount === 0 ? qsTr("Save")
                          : hostPage.editsNeedRestart ? qsTr("Save and restart (%1)").arg(hostPage.editCount)
                          : qsTr("Save (%1)").arg(hostPage.editCount)
                    highlighted: true
                    visible: hostPage.canWrite
                    enabled: hostPage.editCount > 0 && !hostPage.saving
                    onClicked: hostPage.save(false, hostPage.editsNeedRestart)
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
                            info: setting.tier === "dangerous" ? qsTr("Changing this can make the host unreachable or less secure.") : ""
                            badge: setting.tier === "dangerous" ? qsTr("Careful") : ""
                            hint: hostPage.rowHint(setting)
                            hintIsError: hostPage.errors.hasOwnProperty(setting.key) || hostPage.invalid.hasOwnProperty(setting.key)
                            indented: !!setting.depends_on
                            available: hostPage.canWrite && !hostPage.isComplex(setting) && hostPage.dependencyMet(setting)

                            Loader {
                                sourceComponent: {
                                    switch (settingRow.setting.type) {
                                    case "boolean": return booleanControl
                                    case "choice": return choiceControl
                                    case "integer":
                                        return hostPage.isEnumInteger(settingRow.setting) ? choiceControl : numberControl
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
                                        readonly property var values: hostPage.listValues(settingRow.setting)
                                        enabled: settingRow.available
                                        implicitWidth: 300
                                        model: hostPage.listTitles(settingRow.setting)
                                        currentIndex: {
                                            var v = hostPage.current(settingRow.setting)
                                            for (var i = 0; i < values.length; i++) {
                                                if (hostPage.same(values[i], v)) {
                                                    return i
                                                }
                                            }
                                            return -1
                                        }
                                        displayText: currentIndex < 0 ? String(hostPage.current(settingRow.setting)) : currentText
                                        onActivated: hostPage.setEdit(settingRow.setting, values[index])
                                        Accessible.name: settingRow.text
                                    }
                                }

                                Component {
                                    id: numberControl
                                    RowLayout {
                                        id: numberRow
                                        readonly property var special: hostPage.specialValue(settingRow.setting)
                                        readonly property bool isSpecial: special !== null && Number(hostPage.current(settingRow.setting)) === special.value
                                        readonly property int unitFactor: hostPage.unitScale(settingRow.setting)
                                        spacing: 8

                                        CheckBox {
                                            visible: numberRow.special !== null
                                            enabled: settingRow.available
                                            text: numberRow.special ? numberRow.special.title : ""
                                            checked: numberRow.isSpecial
                                            onToggled: {
                                                var s = settingRow.setting
                                                if (checked) {
                                                    hostPage.setEdit(s, numberRow.special.value)
                                                }
                                                else {
                                                    var starts = {"max_bitrate": 50000, "back_button_timeout": 2000, "minimum_fps_target": 20, "dd_wa_hdr_toggle_delay": 500}
                                                    var fallback = Number(s["default"]) !== numberRow.special.value ? s["default"]
                                                                 : ((s.key in starts) ? starts[s.key] : numberRow.special.value + 1)
                                                    hostPage.setEdit(s, fallback)
                                                }
                                            }
                                        }

                                        TextField {
                                            visible: !numberRow.isSpecial
                                            enabled: settingRow.available
                                            implicitWidth: 110
                                            horizontalAlignment: TextInput.AlignRight
                                            text: String(Number(hostPage.current(settingRow.setting)) / numberRow.unitFactor)
                                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            // Count the change while typing, so Save is ready without leaving the field.
                                            function apply(final) {
                                                var n = Number(text.replace(",", "."))
                                                if (text.trim() !== "" && !isNaN(n)) {
                                                    var value = numberRow.unitFactor !== 1 ? Math.round(n * numberRow.unitFactor) : n
                                                    hostPage.setEdit(settingRow.setting, value)
                                                }
                                                else if (final) {
                                                    text = String(Number(hostPage.current(settingRow.setting)) / numberRow.unitFactor)
                                                }
                                            }
                                            onTextEdited: apply(false)
                                            onEditingFinished: apply(true)
                                            Accessible.name: settingRow.text
                                        }

                                        Label {
                                            visible: !numberRow.isSpecial && text !== ""
                                            text: hostPage.unitText(settingRow.setting)
                                            color: Theme.textSecondary
                                        }
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
                                            if (typeof v === "string" && v.charAt(0) === "[") {
                                                var items = v.length > 2 ? v.slice(1, -1).split(",").length : 0
                                                if (settingRow.setting.type === "keybindings") {
                                                    items = Math.floor(items / 2)
                                                }
                                                return items === 0 ? qsTr("None") : qsTr("%n entries", "", items)
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

        onAccepted: hostPage.save(true, hostPage.restartAfterSave)
    }
}
