import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import ComputerModel 1.0

import "."

// Norilight: settings of a Norishine host, through its management API (/api/v1 on
// the HTTPS port, authenticated with this client's paired certificate). The host owns
// the list of settings (the schema), so this page renders whatever it describes, laid
// out like the host's own web UI: a sidebar of categories (everyday ones, then a
// collapsible Expert group), sub-headings inside a category, search across everything,
// and a save bar. Explanations are on hover and in the docs, not on the page.
Item {
    id: hostPage

    property int computerIndex
    property ComputerModel computerModel
    // The host's Norishine features (serverinfo)
    property var hostFeatures: []

    // From the host
    property var hostStatus: null
    property var schema: null
    property var values: ({})
    property var invalid: ({})
    property var unknown: ({})
    property var displays: null

    // Local state
    property var edits: ({})        // key: new typed value
    property var errors: ({})       // key: message from the host
    property string requestError: ""
    property string loadError: ""
    property bool accessDenied: false
    property string notice: ""
    property string noticeKind: ""  // "ok", "restart", "restarting" or "error"
    property bool saving: false
    property bool restartNeeded: false
    property bool restartAfterSave: false
    property string searchText: ""
    property bool showAdvanced: false
    property bool expertOpen: false
    property bool showOtherEncoders: false
    property string category: "general"
    property int pendingLoads: 0

    // Recommended encoder settings (GET /api/v1/recommendations), on hosts with the feature
    readonly property bool recommendationsSupported: hostFeatures.indexOf("recommendations") >= 0
    property var recommendations: null
    property bool recommendBusy: false
    readonly property string recommendDocsUrl: "https://github.com/Nori-Oppi/Norishine/blob/master/docs/AUTOTUNE.md#host-settings-norishine"
    readonly property var recommendReasons: ({
        "encoder_limited": qsTr("Encoder was the bottleneck"),
        "headroom": qsTr("Encoder has room to spare"),
        "loss": qsTr("Frequent frame loss")
    })

    readonly property int manageWrite: 0x20000000
    readonly property bool canWrite: hostStatus !== null && (hostStatus.device.permissions & manageWrite) !== 0
    readonly property int editCount: Object.keys(edits).length
    readonly property string docsUrl: "https://github.com/Nori-Oppi/Norishine/blob/master/docs/SETTINGS.md"
    // The encoder the host picked, so the Expert group lists only its tuning page
    readonly property var encoderCategories: ({"nvenc": "nv", "quicksync": "qsv", "amdvce": "amd",
                                               "vaapi": "vaapi", "videotoolbox": "vt", "software": "sw"})

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
        request("displays", "GET", "/api/v1/displays")
        loadRecommendations()
    }

    function loadRecommendations() {
        if (recommendationsSupported) {
            request("recommendations", "GET", "/api/v1/recommendations")
        }
    }

    function settingTitle(key) {
        var setting = settingByKey(key)
        return setting ? setting.title : key
    }

    function settingValue(key, value) {
        var setting = settingByKey(key)
        return setting ? plainTitle(valueTitle(setting, value)) : String(value)
    }

    function changeRecommendations(path, body) {
        recommendBusy = true
        notice = ""
        request("recommendChange", "POST", path, body)
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

    function categoryById(id) {
        if (!schema) {
            return null
        }
        for (var i = 0; i < schema.categories.length; i++) {
            if (schema.categories[i].id === id) {
                return schema.categories[i]
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
        if (same(value, stored(setting)) && !invalid.hasOwnProperty(setting.key)) {
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
        if (noticeKind !== "restarting") {
            notice = ""
            noticeKind = ""
        }
    }

    function discard() {
        edits = ({})
        errors = ({})
        requestError = ""
    }

    function canReset(setting) {
        return !same(current(setting), setting["default"]) || (invalid.hasOwnProperty(setting.key) && !edits.hasOwnProperty(setting.key))
    }

    // ---- Categories and the sidebar ----

    function isExpertCategory(id) {
        var c = categoryById(id)
        return c !== null && c.expert === true
    }

    // Expert categories sit in their own sidebar group, so they show all their settings.
    function visibleTier(setting) {
        return showAdvanced || setting.tier === "basic" || isExpertCategory(setting.category)
    }

    readonly property var categories: {
        var list = []
        if (!schema) {
            return list
        }
        for (var i = 0; i < schema.categories.length; i++) {
            var c = schema.categories[i]
            var all = []
            var shown = []
            for (var j = 0; j < schema.settings.length; j++) {
                var s = schema.settings[j]
                if (s.category === c.id && s.available) {
                    all.push(s)
                    if (visibleTier(s)) {
                        shown.push(s)
                    }
                }
            }
            if (all.length === 0) {
                continue
            }
            // A category with only advanced settings still shows them, rather than vanishing.
            list.push({"id": c.id, "title": c.title, "expert": c.expert === true, "group": c.group || "",
                       "group_title": c.group_title || "", "tag": "", "settings": shown.length > 0 ? shown : all})
        }
        if (showAdvanced && Object.keys(unknown).length > 0) {
            list.push({"id": "unknown", "title": qsTr("Other entries in the config file"), "expert": false,
                       "group": "", "group_title": "", "tag": "", "settings": []})
        }
        return list
    }

    readonly property string detectedEncoderCategory: {
        var id = hostStatus && hostStatus.encoder ? (encoderCategories[hostStatus.encoder] || "") : ""
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].id === id) {
                return id
            }
        }
        return ""
    }

    readonly property var navItems: categories.filter(function(c) { return !c.expert })

    readonly property var expertItems: categories
        .filter(function(c) {
            return c.expert && (!c.group || detectedEncoderCategory === "" || showOtherEncoders || c.id === detectedEncoderCategory)
        })
        .map(function(c) {
            if (c.group && c.id === detectedEncoderCategory && !showOtherEncoders) {
                return Object.assign({}, c, {"title": c.group_title, "tag": c.title})
            }
            return c
        })

    readonly property int otherEncoderCount: detectedEncoderCategory === "" ? 0
        : categories.filter(function(c) { return c.group && c.id !== detectedEncoderCategory }).length

    readonly property var currentCategory: {
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].id === category) {
                return categories[i]
            }
        }
        return categories.length > 0 ? categories[0] : null
    }

    readonly property string pageTitle: {
        if (searching) {
            return qsTr("Search results")
        }
        var c = currentCategory
        if (!c) {
            return qsTr("Host settings")
        }
        return c.group && c.id === detectedEncoderCategory ? c.group_title + ": " + c.title : c.title
    }

    function showCategory(id) {
        category = id
        if (isExpertCategory(id)) {
            expertOpen = true
        }
        searchField.text = ""
        flick.contentY = 0
    }

    // The current category's settings under their sub-headings; settings without one come first.
    readonly property var currentSections: {
        var c = currentCategory
        if (!c || c.id === "unknown") {
            return []
        }
        var defs = (schema && schema.sections ? schema.sections : []).filter(function(d) { return d.category === c.id })
        var known = defs.map(function(d) { return d.id })
        var out = [{"id": "", "title": "", "note": "", "inactive": false,
                    "settings": c.settings.filter(function(s) { return !s.section || known.indexOf(s.section) < 0 })}]
        for (var i = 0; i < defs.length; i++) {
            var d = defs[i]
            out.push({"id": d.id, "title": d.title, "note": d.note || "", "inactive": !dependencyMet(d),
                      "settings": c.settings.filter(function(s) { return s.section === d.id })})
        }
        return out.filter(function(sec) { return sec.settings.length > 0 })
    }

    // ---- Search ----

    readonly property var searchWords: searchText.toLowerCase().split(/\s+/).filter(function(w) { return w !== "" })
    readonly property bool searching: searchWords.length > 0

    function matches(setting, categoryTitle) {
        var titles = setting.value_titles || {}
        var parts = [setting.title, setting.help || "", setting.key, categoryTitle]
        for (var k in titles) {
            parts.push(titles[k])
        }
        var haystack = parts.join(" ").toLowerCase()
        for (var i = 0; i < searchWords.length; i++) {
            if (haystack.indexOf(searchWords[i]) < 0) {
                return false
            }
        }
        return true
    }

    // Search covers every setting, advanced ones too, so nothing is hard to find.
    readonly property var results: {
        var out = []
        if (!searching || !schema) {
            return out
        }
        for (var i = 0; i < schema.categories.length; i++) {
            var c = schema.categories[i]
            var found = []
            for (var j = 0; j < schema.settings.length; j++) {
                var s = schema.settings[j]
                if (s.category === c.id && s.available && matches(s, c.title)) {
                    found.push(s)
                }
            }
            if (found.length > 0) {
                out.push({"id": c.id, "title": (c.group_title ? c.group_title + ": " : "") + c.title, "settings": found})
            }
        }
        return out
    }

    readonly property int resultCount: {
        var n = 0
        for (var i = 0; i < results.length; i++) {
            n += results[i].settings.length
        }
        return n
    }

    // ---- Values ----

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

    // "Balanced (default)" -> "Balanced", where the marker would repeat itself.
    function plainTitle(text) {
        return text.replace(/,\s*default\)$/i, ")").replace(/\s*\(default(?:;[^()]*)?\)$/i, "")
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

    // The monitor picker for output_name, from the host's display list.
    function displayValues() {
        var list = [""]
        for (var i = 0; i < displays.length; i++) {
            list.push(displays[i].id)
        }
        return list
    }

    function displayTitles(currentValue) {
        var list = [qsTr("Automatic (main display)")]
        for (var i = 0; i < displays.length; i++) {
            var d = displays[i]
            var name = d.friendly_name || d.name
            list.push(d.active ? "%1 (%2×%3, %4 Hz)".arg(name).arg(d.width).arg(d.height).arg(Math.round(d.refresh_rate))
                               : qsTr("%1 (off)").arg(name))
        }
        return list
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

    function numberText(setting) {
        var n = Number(current(setting))
        return isNaN(n) ? String(current(setting)) : String(n / unitScale(setting))
    }

    // Whether the setting (or section) it depends on has one of the values it needs.
    function dependencyMet(item) {
        if (!item.depends_on) {
            return true
        }
        var other = settingByKey(item.depends_on.key)
        if (!other) {
            return true
        }
        var value = current(other)
        for (var i = 0; i < item.depends_on.values.length; i++) {
            if (same(item.depends_on.values[i], value)) {
                return true
            }
        }
        return false
    }

    function dependencyText(setting) {
        var other = settingByKey(setting.depends_on.key)
        var names = setting.depends_on.values.map(function(v) { return "“" + plainTitle(valueTitle(other, v)) + "”" })
        return qsTr("Only has an effect when “%1” is set to %2.").arg(other.title).arg(names.join(" / "))
    }

    function isComplex(setting) {
        return ["prep_commands", "server_commands", "keybindings", "mode_remapping"].indexOf(setting.type) >= 0
    }

    // On hover: the explanation, why it has no effect now, and its name in the config file.
    function rowTooltip(setting) {
        var parts = []
        if (setting.help) {
            parts.push(setting.help)
        }
        if (!dependencyMet(setting)) {
            parts.push(dependencyText(setting))
        }
        if (isComplex(setting)) {
            parts.push(qsTr("Edit this in the host's web UI."))
        }
        if (showAdvanced) {
            parts.push("sunshine.conf: " + setting.key)
        }
        return parts.join("\n\n")
    }

    // Under the name: only problems.
    function rowHint(setting) {
        if (errors.hasOwnProperty(setting.key)) {
            return errors[setting.key]
        }
        if (invalid.hasOwnProperty(setting.key) && !edits.hasOwnProperty(setting.key)) {
            return qsTr("The config file has \"%1\" here, which isn't valid (%2). Norishine uses the default until you save a new value.")
                       .arg(invalid[setting.key].value).arg(invalid[setting.key].error)
        }
        return ""
    }

    // ---- Saving ----

    readonly property bool editsNeedRestart: {
        for (var key in edits) {
            var s = settingByKey(key)
            if (s && s.restart_required) {
                return true
            }
        }
        return false
    }

    readonly property var errorEntries: {
        var list = []
        for (var key in errors) {
            if (key === "") {
                continue
            }
            var s = settingByKey(key)
            list.push({"key": key, "title": s ? s.title : key, "message": errors[key], "category": s ? s.category : ""})
        }
        return list
    }

    function categoryHasErrors(id) {
        for (var i = 0; i < errorEntries.length; i++) {
            if (errorEntries[i].category === id) {
                return true
            }
        }
        return false
    }

    function categoryHasChanges(id) {
        for (var key in edits) {
            var s = settingByKey(key)
            if (s && s.category === id) {
                return true
            }
        }
        return false
    }

    readonly property bool expertHasNews: {
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].expert && (categoryHasErrors(categories[i].id) || categoryHasChanges(categories[i].id))) {
                return true
            }
        }
        return false
    }

    function save(confirmed, andRestart) {
        if (editCount === 0 || saving) {
            return
        }
        restartAfterSave = andRestart
        if (!confirmed) {
            var dangerous = []
            for (var key in edits) {
                var s = settingByKey(key)
                if (s && s.tier === "dangerous") {
                    dangerous.push(s.title)
                }
            }
            if (dangerous.length > 0) {
                confirmDialog.names = dangerous
                confirmDialog.open()
                return
            }
        }
        if (andRestart) {
            // Restarting ends every stream: ask first if one is running.
            saving = true
            request("restartCheck", "GET", "/api/v1/status")
            return
        }
        doSave()
    }

    function doSave() {
        var set = {}
        var reset = []
        for (var key in edits) {
            var s = settingByKey(key)
            if (same(edits[key], s["default"])) {
                reset.push(key)
            }
            else {
                set[key] = edits[key]
            }
        }
        saving = true
        notice = ""
        noticeKind = ""
        requestError = ""
        request("save", "PATCH", "/api/v1/config", {"set": set, "reset": reset})
    }

    function restartHost() {
        notice = qsTr("Restarting Norishine. Streams on this host stop for a moment.")
        noticeKind = "restarting"
        request("restart", "POST", "/api/v1/restart", {})
    }

    // Open a setting: its category (showing advanced settings if needed), scrolled into view.
    function reveal(key) {
        var s = settingByKey(key)
        if (!s) {
            return
        }
        if (!visibleTier(s)) {
            showAdvanced = true
        }
        if (isExpertCategory(s.category)) {
            expertOpen = true
            if (s.category !== detectedEncoderCategory && categoryById(s.category).group) {
                showOtherEncoders = true
            }
        }
        searchField.text = ""
        category = s.category
        revealTimer.key = key
        revealTimer.restart()
    }

    function findRow(item, name) {
        if (item.objectName === name) {
            return item
        }
        for (var i = 0; i < item.children.length; i++) {
            var found = findRow(item.children[i], name)
            if (found) {
                return found
            }
        }
        return null
    }

    Timer {
        id: revealTimer
        property string key: ""
        interval: 50
        onTriggered: {
            var rowItem = hostPage.findRow(pageColumn, "setting-" + key)
            if (rowItem) {
                var pos = rowItem.mapToItem(flick.contentItem, 0, 0)
                flick.contentY = Math.max(0, Math.min(pos.y - flick.height / 3, flick.contentHeight - flick.height))
            }
        }
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

            if (requestId === "recommendations") {
                hostPage.recommendations = status === 200 && data ? data : null
                return
            }
            if (requestId === "recommendChange") {
                hostPage.recommendBusy = false
                if (status === 200 && data !== null) {
                    hostPage.restartNeeded = hostPage.restartNeeded || data.restart_required
                    var skipped = data.skipped || []
                    if (skipped.length > 0) {
                        hostPage.notice = qsTr("Changed since, so kept: %1").arg(skipped.map(hostPage.settingTitle).join(", "))
                    }
                    else {
                        hostPage.notice = hostPage.restartNeeded ? qsTr("Saved. Restart Norishine to apply the changes.") : qsTr("Saved.")
                    }
                    hostPage.noticeKind = hostPage.restartNeeded ? "restart" : "ok"
                    hostPage.request("values", "GET", "/api/v1/config")
                    hostPage.pendingLoads += 1
                }
                else {
                    hostPage.notice = hostPage.describeFailure(status, data, error)
                    hostPage.noticeKind = "error"
                }
                hostPage.loadRecommendations()
                return
            }

            if (requestId === "displays") {
                hostPage.displays = status === 200 && data && data.displays ? data.displays : null
            }
            else if (requestId === "status" || requestId === "schema" || requestId === "values") {
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
                    hostPage.values = data.values || {}
                    hostPage.invalid = data.invalid || {}
                    hostPage.unknown = data.unknown || {}
                }
            }
            else if (requestId === "restartCheck") {
                hostPage.saving = false
                if (status === 200 && data !== null && data.active_sessions > 0) {
                    streamDialog.count = data.active_sessions
                    streamDialog.open()
                }
                else {
                    hostPage.doSave()
                }
            }
            else if (requestId === "save") {
                hostPage.saving = false
                if (status === 200 && data !== null) {
                    hostPage.edits = ({})
                    hostPage.errors = ({})
                    hostPage.restartNeeded = hostPage.restartNeeded || data.restart_required
                    if (hostPage.restartAfterSave && hostPage.restartNeeded) {
                        hostPage.restartHost()
                    }
                    else if (hostPage.restartNeeded) {
                        hostPage.notice = qsTr("Saved. Restart Norishine to apply the changes.")
                        hostPage.noticeKind = "restart"
                    }
                    else {
                        hostPage.notice = qsTr("Saved.")
                        hostPage.noticeKind = "ok"
                    }
                    hostPage.restartAfterSave = false
                    hostPage.request("values", "GET", "/api/v1/config")
                    hostPage.pendingLoads += 1
                }
                else if (status === 400 && data !== null && data.errors) {
                    var errs = Object.assign({}, data.errors)
                    if (errs.hasOwnProperty("")) {
                        hostPage.requestError = errs[""]
                        delete errs[""]
                    }
                    hostPage.errors = errs
                    var first = Object.keys(errs)[0]
                    if (first && !hostPage.searching) {
                        hostPage.reveal(first)
                    }
                }
                else {
                    hostPage.requestError = qsTr("Couldn't save: %1").arg(hostPage.describeFailure(status, data, error))
                }
            }
            else if (requestId === "restart") {
                if (status === 200) {
                    hostPage.restartNeeded = false
                    reloadTimer.start()
                }
                else {
                    hostPage.notice = hostPage.describeFailure(status, data, error)
                    hostPage.noticeKind = "error"
                }
            }
        }
    }

    Timer {
        id: reloadTimer
        interval: 6000
        onTriggered: {
            hostPage.notice = qsTr("Norishine has restarted with the new settings.")
            hostPage.noticeKind = "ok"
            hostPage.reload()
        }
    }

    StackView.onActivated: {
        if (schema === null) {
            reload()
        }
    }

    readonly property bool pageActive: StackView.status === StackView.Active

    Shortcut {
        sequences: [StandardKey.Save]
        enabled: hostPage.pageActive && hostPage.canWrite
        onActivated: hostPage.save(false, false)
    }

    Shortcut {
        sequence: "/"
        enabled: hostPage.pageActive && hostPage.schema !== null
        onActivated: searchField.forceActiveFocus()
    }

    Shortcut {
        sequences: [StandardKey.Refresh]
        enabled: hostPage.pageActive && hostPage.pendingLoads === 0 && !hostPage.saving
        onActivated: hostPage.reload()
    }

    // ---- Sidebar ----

    Rectangle {
        id: sidebar
        width: hostPage.width < 900 ? 200 : 256
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        color: Theme.sidebar

        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            width: 1
            color: Theme.divider
        }

        TextField {
            id: searchField
            x: 16
            y: 16
            width: parent.width - 33
            placeholderText: qsTr("Search settings")
            font.pointSize: Theme.fontBody
            selectByMouse: true
            enabled: hostPage.schema !== null
            rightPadding: text !== "" ? clearSearchButton.width + 4 : leftPadding
            onTextChanged: {
                hostPage.searchText = text.trim()
                flick.contentY = 0
            }
            Keys.onEscapePressed: {
                if (text !== "") {
                    text = ""
                }
                else {
                    event.accepted = false
                }
            }

            ToolButton {
                id: clearSearchButton
                visible: searchField.text !== ""
                focusPolicy: Qt.NoFocus
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                icon.source: "qrc:/res/close.svg"
                icon.width: 16
                icon.height: 16
                onClicked: searchField.text = ""

                ToolTip.text: qsTr("Clear search")
                ToolTip.delay: 600
                ToolTip.visible: hovered
            }
        }

        Flickable {
            id: navFlick
            anchors {
                top: searchField.bottom
                topMargin: 10
                left: parent.left
                right: parent.right
                rightMargin: 1
                bottom: advancedRow.top
            }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: navColumn.height

            ScrollBar.vertical: ScrollBar {
                policy: navFlick.contentHeight > navFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            Column {
                id: navColumn
                width: navFlick.width
                bottomPadding: 12

                Label {
                    x: 24
                    width: parent.width - 40
                    topPadding: 4
                    bottomPadding: 4
                    visible: hostPage.navItems.length > 0
                    text: qsTr("Streaming")
                    font.pointSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                }

                Repeater {
                    model: hostPage.navItems
                    delegate: navDelegate
                }

                // Expert: categories few people need, collapsed by default
                ItemDelegate {
                    id: expertToggle
                    width: parent.width
                    height: 36
                    visible: hostPage.expertItems.length > 0
                    padding: 0
                    hoverEnabled: true
                    focusPolicy: Qt.TabFocus
                    onClicked: hostPage.expertOpen = !hostPage.expertOpen
                    Accessible.name: qsTr("Expert")

                    background: Rectangle {
                        color: expertToggle.hovered || expertToggle.visualFocus ? Theme.navHover : "transparent"
                    }

                    contentItem: Item {
                        Label {
                            x: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Expert")
                            font.pointSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                            color: expertToggle.hovered ? Theme.textPrimary : Theme.textTertiary
                        }
                        Rectangle {
                            x: parent.width - 52
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            color: Material.accent
                            visible: !hostPage.expertOpen && hostPage.expertHasNews
                        }
                        Image {
                            x: parent.width - 38
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/res/expand_more.svg"
                            sourceSize.width: 18
                            sourceSize.height: 18
                            rotation: hostPage.expertOpen ? 0 : -90
                            opacity: 0.7
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: hostPage.expertOpen

                    Repeater {
                        model: hostPage.expertItems
                        delegate: navDelegate
                    }

                    Label {
                        x: 24
                        width: parent.width - 40
                        topPadding: 6
                        bottomPadding: 4
                        visible: hostPage.otherEncoderCount > 0
                        text: hostPage.showOtherEncoders ? qsTr("Hide the other encoders")
                                                         : qsTr("Show the other encoders (%1)").arg(hostPage.otherEncoderCount)
                        font.pointSize: Theme.fontDetail
                        font.underline: otherEncodersArea.containsMouse
                        color: Material.accent

                        MouseArea {
                            id: otherEncodersArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hostPage.showOtherEncoders = !hostPage.showOtherEncoders
                        }
                    }
                }
            }
        }

        WheelScroller {
            flickable: navFlick
        }

        // "Show advanced settings", pinned under the list
        Item {
            id: advancedRow
            anchors {
                left: parent.left
                right: parent.right
                rightMargin: 1
                bottom: parent.bottom
            }
            height: 56

            Rectangle {
                x: 16
                width: parent.width - 32
                height: 1
                color: Theme.divider
            }

            Label {
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - advancedSwitch.width - 36
                text: qsTr("Show advanced settings")
                font.pointSize: Theme.fontDetail
                color: Theme.textSecondary
                elide: Text.ElideRight
            }

            Switch {
                id: advancedSwitch
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                enabled: hostPage.schema !== null
                checked: hostPage.showAdvanced
                onToggled: hostPage.showAdvanced = checked
                Accessible.name: qsTr("Show advanced settings")
            }
        }
    }

    Component {
        id: navDelegate

        ItemDelegate {
            id: navItem
            readonly property bool selected: !hostPage.searching && hostPage.currentCategory !== null && hostPage.currentCategory.id === modelData.id

            width: navColumn.width
            height: 32
            padding: 0
            hoverEnabled: true
            focusPolicy: Qt.TabFocus
            onClicked: hostPage.showCategory(modelData.id)
            Keys.onReturnPressed: hostPage.showCategory(modelData.id)
            Keys.onEnterPressed: hostPage.showCategory(modelData.id)
            Accessible.name: modelData.title

            background: Rectangle {
                color: navItem.selected ? Theme.navSelected
                     : (navItem.hovered || navItem.visualFocus ? Theme.navHover : "transparent")

                Rectangle {
                    width: 3
                    radius: 1.5
                    height: parent.height - 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Material.accent
                    visible: navItem.selected
                }
            }

            contentItem: Item {
                RowLayout {
                    x: 24
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        text: modelData.title
                        font.pointSize: Theme.fontBody
                        font.weight: navItem.selected ? Font.DemiBold : Font.Normal
                        color: navItem.selected ? Theme.textHeading
                             : modelData.expert ? Theme.textSecondary : Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    Label {
                        visible: modelData.tag !== ""
                        text: modelData.tag
                        font.pointSize: Theme.fontSmall
                        color: Theme.textSecondary
                        leftPadding: 7
                        rightPadding: 7
                        topPadding: 1
                        bottomPadding: 1
                        background: Rectangle {
                            radius: height / 2
                            color: navItem.selected ? Theme.background : Theme.navSelected
                        }
                    }

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        visible: hostPage.categoryHasErrors(modelData.id) || hostPage.categoryHasChanges(modelData.id)
                        color: hostPage.categoryHasErrors(modelData.id) ? Theme.statusError : Material.accent
                    }
                }
            }
        }
    }

    // ---- Content ----

    Flickable {
        id: flick
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: sidebar.right
            right: parent.right
        }
        clip: true
        boundsBehavior: Flickable.OvershootBounds
        contentWidth: width
        contentHeight: pageColumn.height
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: pageColumn
            readonly property real sideMargin: flick.width < 560 ? 20 : 44
            x: sideMargin
            width: Math.max(0, Math.min(flick.width - 2 * sideMargin, Theme.contentMaxWidth))
            topPadding: 24
            // Room for the save bar
            bottomPadding: 110
            spacing: Theme.cardGap

            // Title, help and whether this device can change anything
            Item {
                width: parent.width
                height: 44

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 6

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - 120)
                        text: hostPage.pageTitle
                        font.pointSize: Theme.fontHeading
                        font.weight: Font.Medium
                        font.letterSpacing: -0.3
                        color: Theme.textHeading
                        elide: Text.ElideRight
                    }

                    ToolButton {
                        id: helpButton
                        anchors.verticalCenter: parent.verticalCenter
                        visible: hostPage.schema !== null
                        width: 32
                        height: 32
                        padding: 0
                        topInset: 0
                        bottomInset: 0
                        leftInset: 0
                        rightInset: 0
                        display: AbstractButton.IconOnly
                        icon.source: "qrc:/res/baseline-help_outline-24px.svg"
                        icon.width: 20
                        icon.height: 20
                        icon.color: Theme.textTertiary
                        background: Rectangle {
                            radius: width / 2
                            color: helpButton.hovered ? Theme.cardHover : "transparent"
                            border.width: helpButton.visualFocus ? 2 : 0
                            border.color: Material.accent
                        }
                        onClicked: Qt.openUrlExternally(hostPage.docsUrl +
                                                        (!hostPage.searching && hostPage.currentCategory ? "#" + hostPage.currentCategory.id : ""))
                        Accessible.name: qsTr("What these settings do")
                        ToolTip.text: Accessible.name
                        ToolTip.delay: 600
                        ToolTip.visible: hovered
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: hostPage.hostStatus !== null && !hostPage.canWrite
                        text: qsTr("Read only")
                        font.pointSize: Theme.fontSmall
                        color: Theme.textSecondary
                        leftPadding: 8
                        rightPadding: 8
                        topPadding: 2
                        bottomPadding: 2
                        background: Rectangle {
                            radius: height / 2
                            color: Theme.navSelected
                        }
                    }
                }
            }

            // Saved / restart notice
            Rectangle {
                width: parent.width
                height: noticeRow.implicitHeight + 24
                radius: Theme.cardRadius
                color: Theme.card
                visible: hostPage.notice !== "" || hostPage.restartNeeded

                RowLayout {
                    id: noticeRow
                    x: Theme.cardPadding
                    width: parent.width - 2 * Theme.cardPadding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.controlGap

                    BusyIndicator {
                        visible: hostPage.noticeKind === "restarting"
                        running: visible
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                    }

                    Image {
                        visible: hostPage.noticeKind === "ok"
                        source: "qrc:/res/baseline-check_circle_outline-24px.svg"
                        sourceSize.width: 20
                        sourceSize.height: 20
                    }

                    Label {
                        Layout.fillWidth: true
                        text: hostPage.notice !== "" ? hostPage.notice : qsTr("Saved. Restart Norishine to apply the changes.")
                        wrapMode: Text.Wrap
                        color: hostPage.noticeKind === "error" ? Theme.statusError : Theme.textPrimary
                        font.pointSize: Theme.fontBody
                    }

                    Button {
                        visible: hostPage.restartNeeded && hostPage.canWrite && hostPage.noticeKind !== "restarting"
                        text: qsTr("Restart now")
                        highlighted: true
                        onClicked: hostPage.restartHost()
                    }
                }
            }

            // What the host rejected
            Rectangle {
                width: parent.width
                height: errorColumn.height + 24
                radius: Theme.cardRadius
                color: Theme.card
                border.color: Theme.statusError
                border.width: 1
                visible: hostPage.requestError !== "" || hostPage.errorEntries.length > 0

                Column {
                    id: errorColumn
                    x: Theme.cardPadding
                    y: 12
                    width: parent.width - 2 * Theme.cardPadding
                    spacing: 6

                    Label {
                        width: parent.width
                        text: hostPage.requestError !== "" ? hostPage.requestError : qsTr("Nothing was saved. Fix these settings and try again:")
                        wrapMode: Text.Wrap
                        font.pointSize: Theme.fontBody
                        font.weight: Font.DemiBold
                        color: Theme.statusError
                    }

                    Repeater {
                        model: hostPage.errorEntries

                        Label {
                            width: errorColumn.width
                            text: "<a href=\"#\">" + modelData.title + "</a>: " + modelData.message
                            textFormat: Text.StyledText
                            linkColor: Theme.textPrimary
                            wrapMode: Text.Wrap
                            font.pointSize: Theme.fontDetail
                            color: Theme.textPrimary
                            onLinkActivated: hostPage.reveal(modelData.key)
                        }
                    }
                }
            }

            // Recommended encoder settings, with Apply and Undo
            SettingsCard {
                id: recommendCard
                readonly property var items: hostPage.recommendations ? hostPage.recommendations.recommendations : []
                readonly property var applied: hostPage.recommendations ? hostPage.recommendations.applied : null
                visible: hostPage.schema !== null && !hostPage.searching && (items.length > 0 || applied !== null)
                title: qsTr("Recommended")

                Repeater {
                    model: recommendCard.items

                    SettingsRow {
                        text: hostPage.settingTitle(modelData.key)
                        hint: hostPage.recommendReasons[modelData.reason] || ""

                        Label {
                            text: hostPage.settingValue(modelData.key, modelData.current) + "  →  " +
                                  hostPage.settingValue(modelData.key, modelData.recommended)
                            color: Theme.textPrimary
                            font.pointSize: Theme.fontBody
                        }

                        Button {
                            visible: hostPage.canWrite
                            enabled: !hostPage.recommendBusy
                            text: qsTr("Apply")
                            flat: true
                            onClicked: hostPage.changeRecommendations("/api/v1/recommendations/apply", {"keys": [modelData.key]})
                        }
                    }
                }


                SettingsRow {
                    visible: recommendCard.applied !== null
                    text: qsTr("Applied recommendations")
                    hint: {
                        var a = recommendCard.applied
                        if (!a) {
                            return ""
                        }
                        return a.settings.map(function(s) {
                            return hostPage.settingTitle(s.key) + ": " + hostPage.settingValue(s.key, s.previous) +
                                   " → " + hostPage.settingValue(s.key, s.value)
                        }).join("\n")
                    }

                    Button {
                        visible: hostPage.canWrite
                        enabled: !hostPage.recommendBusy
                        text: qsTr("Undo")
                        flat: true
                        onClicked: hostPage.changeRecommendations("/api/v1/recommendations/rollback", {})
                    }
                }

                SettingsRow {
                    Button {
                        visible: hostPage.canWrite && recommendCard.items.length > 1
                        enabled: !hostPage.recommendBusy
                        text: qsTr("Apply all")
                        highlighted: true
                        onClicked: hostPage.changeRecommendations("/api/v1/recommendations/apply", {})
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        icon.source: "qrc:/res/baseline-help_outline-24px.svg"
                        icon.width: 20
                        icon.height: 20
                        icon.color: Theme.textTertiary
                        onClicked: Qt.openUrlExternally(hostPage.recommendDocsUrl)
                        Accessible.name: qsTr("How recommendations work")
                        ToolTip.text: Accessible.name
                        ToolTip.delay: 600
                        ToolTip.visible: hovered
                    }
                }
            }

            // Loading and access problems
            SettingsCard {
                visible: hostPage.loadError !== "" || (hostPage.pendingLoads > 0 && hostPage.schema === null)
                title: hostPage.accessDenied ? qsTr("No access to this host's settings") : ""

                SettingsRow {
                    text: hostPage.loadError !== "" ? hostPage.loadError : qsTr("Loading host settings...")
                    hint: hostPage.accessDenied ? qsTr("Allow \"Read Host Settings\" for this device in the host's web UI.") : ""

                    Button {
                        visible: hostPage.loadError !== ""
                        text: qsTr("Try again")
                        flat: true
                        onClicked: hostPage.reload()
                    }
                }
            }

            // Search results, across all categories
            Label {
                visible: hostPage.searching && hostPage.schema !== null
                text: hostPage.resultCount === 0 ? qsTr("No settings match \"%1\".").arg(hostPage.searchText)
                                                 : hostPage.resultCount === 1 ? qsTr("1 setting found")
                                                 : qsTr("%1 settings found").arg(hostPage.resultCount)
                font.pointSize: Theme.fontDetail
                color: Theme.textSecondary
            }

            Repeater {
                model: hostPage.searching ? hostPage.results : []

                delegate: SettingsCard {
                    id: resultCard
                    readonly property var cardSettings: modelData.settings
                    title: modelData.title

                    Repeater {
                        model: resultCard.cardSettings
                        delegate: settingDelegate
                    }
                }
            }

            // Config file entries the host doesn't know
            SettingsCard {
                visible: !hostPage.searching && hostPage.currentCategory !== null && hostPage.currentCategory.id === "unknown"

                Repeater {
                    model: Object.keys(hostPage.unknown)

                    SettingsRow {
                        text: modelData
                        Label {
                            text: String(hostPage.unknown[modelData])
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.maximumWidth: 300
                        }
                    }
                }
            }

            // The current category, under its sub-headings
            Repeater {
                model: hostPage.searching ? [] : hostPage.currentSections

                delegate: Column {
                    id: sectionBlock
                    readonly property var section: modelData
                    width: pageColumn.width
                    spacing: 8

                    Row {
                        visible: sectionBlock.section.title !== ""
                        spacing: 10

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: sectionBlock.section.title
                            font.pointSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                            color: Theme.textTertiary
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: sectionBlock.section.inactive && sectionBlock.section.note !== ""
                            text: qsTr("Not used now")
                            font.pointSize: Theme.fontSmall
                            color: Theme.textSecondary
                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 1
                            bottomPadding: 1
                            background: Rectangle {
                                radius: height / 2
                                color: Theme.navSelected
                            }

                            MouseArea {
                                id: noteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                ToolTip.text: sectionBlock.section.note
                                ToolTip.delay: 400
                                ToolTip.visible: containsMouse
                            }
                        }
                    }

                    SettingsCard {
                        opacity: sectionBlock.section.inactive ? 0.62 : 1

                        Repeater {
                            model: sectionBlock.section.settings
                            delegate: settingDelegate
                        }
                    }
                }
            }
        }
    }

    WheelScroller {
        flickable: flick
    }

    // One setting. "inSearch" rows mark advanced settings and aren't indented.
    Component {
        id: settingDelegate

        SettingsRow {
            id: settingRow
            readonly property var setting: modelData
            readonly property bool inSearch: hostPage.searching
            readonly property bool editable: hostPage.canWrite && !hostPage.isComplex(setting)
            objectName: "setting-" + setting.key
            text: setting.title
            badge: setting.tier === "dangerous" ? qsTr("Careful")
                 : (inSearch && setting.tier === "advanced") ? qsTr("Advanced") : ""
            tooltip: hostPage.rowTooltip(setting)
            hint: hostPage.rowHint(setting)
            hintIsError: hostPage.errors.hasOwnProperty(setting.key)
            modified: hostPage.edits.hasOwnProperty(setting.key)
            indented: !inSearch && !!setting.depends_on
            available: hostPage.dependencyMet(setting)

            ToolButton {
                id: resetButton
                visible: settingRow.editable && hostPage.canReset(settingRow.setting)
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                padding: 0
                topInset: 0
                bottomInset: 0
                leftInset: 0
                rightInset: 0
                display: AbstractButton.IconOnly
                icon.source: "qrc:/res/undo.svg"
                icon.width: 18
                icon.height: 18
                icon.color: Theme.textTertiary
                background: Rectangle {
                    radius: width / 2
                    color: resetButton.hovered ? Theme.cardHover : "transparent"
                    border.width: resetButton.visualFocus ? 2 : 0
                    border.color: Material.accent
                }
                onClicked: hostPage.setEdit(settingRow.setting, settingRow.setting["default"])
                Accessible.name: qsTr("Reset")
                ToolTip.text: qsTr("Reset (default: %1)").arg(hostPage.plainTitle(hostPage.valueTitle(settingRow.setting, settingRow.setting["default"])))
                ToolTip.delay: 400
                ToolTip.visible: hovered
            }

            Loader {
                sourceComponent: {
                    switch (settingRow.setting.type) {
                    case "boolean": return booleanControl
                    case "choice": return choiceControl
                    case "integer":
                        return hostPage.isEnumInteger(settingRow.setting) ? choiceControl : numberControl
                    case "number": return numberControl
                    case "string":
                        return settingRow.setting.key === "output_name" && hostPage.displays && hostPage.displays.length > 0
                               ? displayControl : textControl
                    case "path": return textControl
                    default: return complexControl
                    }
                }

                Component {
                    id: booleanControl
                    Switch {
                        enabled: settingRow.editable
                        checked: hostPage.current(settingRow.setting) === true
                        onToggled: hostPage.setEdit(settingRow.setting, checked)
                        Accessible.name: settingRow.text
                    }
                }

                Component {
                    id: choiceControl
                    ComboBox {
                        readonly property var values: hostPage.listValues(settingRow.setting)
                        enabled: settingRow.editable
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
                    id: displayControl
                    ComboBox {
                        readonly property var values: {
                            var list = hostPage.displayValues()
                            var v = String(hostPage.current(settingRow.setting))
                            if (list.indexOf(v) < 0) {
                                list.push(v)
                            }
                            return list
                        }
                        enabled: settingRow.editable
                        implicitWidth: 300
                        model: {
                            var titles = hostPage.displayTitles()
                            if (values.length > titles.length) {
                                titles.push(qsTr("%1 (not connected)").arg(values[values.length - 1]))
                            }
                            return titles
                        }
                        currentIndex: values.indexOf(String(hostPage.current(settingRow.setting)))
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
                            enabled: settingRow.editable
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
                            id: numberField
                            readonly property string shown: hostPage.numberText(settingRow.setting)
                            visible: !numberRow.isSpecial
                            enabled: settingRow.editable
                            implicitWidth: 110
                            horizontalAlignment: TextInput.AlignRight
                            text: shown
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            // Follow resets and reloads while not being typed in
                            onShownChanged: {
                                if (!activeFocus) {
                                    text = shown
                                }
                            }
                            // Count the change while typing, so Save is ready without leaving the field.
                            function apply(final) {
                                var n = Number(text.replace(",", "."))
                                if (text.trim() !== "" && !isNaN(n)) {
                                    var value = numberRow.unitFactor !== 1 ? Math.round(n * numberRow.unitFactor) : n
                                    hostPage.setEdit(settingRow.setting, value)
                                }
                                else if (final) {
                                    text = shown
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
                        readonly property string shown: String(hostPage.current(settingRow.setting))
                        enabled: settingRow.editable
                        implicitWidth: 260
                        text: shown
                        placeholderText: qsTr("Automatic")
                        selectByMouse: true
                        onShownChanged: {
                            if (!activeFocus) {
                                text = shown
                            }
                        }
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

    // ---- Save bar: floats over the content while there are changes ----

    Rectangle {
        id: saveBar
        visible: hostPage.canWrite && (hostPage.editCount > 0 || hostPage.saving)
        anchors {
            left: sidebar.right
            right: parent.right
            bottom: parent.bottom
            leftMargin: 24
            rightMargin: 24
            bottomMargin: 16
        }
        height: saveRow.implicitHeight + 24
        radius: 12
        color: Theme.popup
        border.color: Theme.border

        RowLayout {
            id: saveRow
            x: 16
            width: parent.width - 32
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.controlGap

            Label {
                Layout.fillWidth: true
                text: hostPage.editCount === 1 ? qsTr("1 unsaved change") : qsTr("%1 unsaved changes").arg(hostPage.editCount)
                font.pointSize: Theme.fontBody
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Button {
                text: qsTr("Discard")
                flat: true
                enabled: !hostPage.saving
                onClicked: hostPage.discard()
            }

            Button {
                text: qsTr("Save only")
                visible: hostPage.editsNeedRestart
                enabled: !hostPage.saving
                onClicked: hostPage.save(false, false)
            }

            Button {
                text: hostPage.saving ? qsTr("Saving...")
                    : hostPage.editsNeedRestart ? qsTr("Save and restart") : qsTr("Save")
                highlighted: true
                enabled: !hostPage.saving
                onClicked: hostPage.save(false, hostPage.editsNeedRestart)
            }
        }
    }

    // ---- Dialogs ----

    Dialog {
        id: confirmDialog
        property var names: []
        modal: true
        anchors.centerIn: parent
        title: qsTr("Save risky changes?")
        width: Math.min(hostPage.width - 80, 520)

        Column {
            width: parent.width
            spacing: 8

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("These settings can make the host unreachable or less secure:")
            }

            Repeater {
                model: confirmDialog.names
                Label {
                    text: "• " + modelData
                    font.weight: Font.DemiBold
                }
            }
        }

        footer: DialogButtonBox {
            Button {
                id: confirmCancel
                text: qsTr("Cancel")
                flat: true
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
            Button {
                text: qsTr("Save anyway")
                flat: true
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
        }

        // The risky choice is never the default
        onOpened: confirmCancel.forceActiveFocus()
        onAccepted: hostPage.save(true, hostPage.restartAfterSave)
    }

    Dialog {
        id: streamDialog
        property int count: 0
        modal: true
        anchors.centerIn: parent
        title: qsTr("Restart while streaming?")
        width: Math.min(hostPage.width - 80, 560)

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            text: streamDialog.count === 1
                  ? qsTr("Restarting ends the stream that is running now. You can also save now and restart later.")
                  : qsTr("Restarting ends the %1 streams that are running now. You can also save now and restart later.").arg(streamDialog.count)
        }

        footer: DialogButtonBox {
            Button {
                id: streamCancel
                text: qsTr("Cancel")
                flat: true
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
            Button {
                text: qsTr("Save only")
                flat: true
                DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
                onClicked: {
                    streamDialog.close()
                    hostPage.restartAfterSave = false
                    hostPage.doSave()
                }
            }
            Button {
                text: qsTr("Save and restart")
                flat: true
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
        }

        onOpened: streamCancel.forceActiveFocus()
        onAccepted: hostPage.doSave()
    }
}
