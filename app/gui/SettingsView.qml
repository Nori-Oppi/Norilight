import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import QtQuick.Window 2.2

import StreamingPreferences 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0
import SystemProperties 1.0
import DisplayManager 1.0
import ProfileManager 1.0
import QtQuick.Controls.Material 2.2
import "."

Item {
    id: settingsPage
    objectName: qsTr("Settings")

    signal languageChanged()

    // Norilight: the sidebar section currently on screen, and the search filter
    property string currentSection: "video"
    property string searchText: ""

    // Search the translated name and summary, plus the English originals and
    // keywords so English terms keep working in every language
    function sectionMatches(name, summary, keywords) {
        if (searchText === "") {
            return true
        }
        var haystack = (qsTr(name) + " " + qsTr(summary) + " " + name + " " + summary + " " + keywords).toLowerCase()
        var words = searchText.toLowerCase().split(/\s+/)
        for (var i = 0; i < words.length; i++) {
            if (words[i] !== "" && haystack.indexOf(words[i]) < 0) {
                return false
            }
        }
        return true
    }

    function matchCount() {
        var count = 0
        for (var i = 0; i < sectionModel.count; i++) {
            var e = sectionModel.get(i)
            if (sectionMatches(e.name, e.summary, e.keywords)) {
                count++
            }
        }
        return count
    }

    function entryMatches(index) {
        var e = sectionModel.get(index)
        return sectionMatches(e.name, e.summary, e.keywords)
    }

    // A category heading is drawn above the first entry of its group that the
    // search leaves visible
    function firstVisibleInCategory(index) {
        if (!entryMatches(index)) {
            return false
        }
        var category = sectionModel.get(index).category
        for (var i = index - 1; i >= 0 && sectionModel.get(i).category === category; i--) {
            if (entryMatches(i)) {
                return false
            }
        }
        return true
    }

    function showSection(key) {
        currentSection = key
        settingsFlick.contentY = 0
    }

    // Up/Down in the sidebar: open the previous/next visible page and keep focus there
    function stepSection(fromIndex, delta) {
        for (var i = fromIndex + delta; i >= 0 && i < sectionModel.count; i += delta) {
            if (entryMatches(i)) {
                showSection(sectionModel.get(i).key)
                navRepeater.itemAt(i).navButton.forceActiveFocus(Qt.TabFocusReason)
                return
            }
        }
    }

    function focusCurrentSection() {
        for (var i = 0; i < sectionModel.count; i++) {
            if (sectionModel.get(i).key === currentSection) {
                navRepeater.itemAt(i).navButton.forceActiveFocus(Qt.TabFocusReason)
                return
            }
        }
    }

    // When the search hides the open section, jump to the first one that matches
    function followSearch() {
        var firstMatch = ""
        for (var i = 0; i < sectionModel.count; i++) {
            var e = sectionModel.get(i)
            if (sectionMatches(e.name, e.summary, e.keywords)) {
                if (e.key === currentSection) {
                    return
                }
                if (firstMatch === "") {
                    firstMatch = e.key
                }
            }
        }
        if (firstMatch !== "") {
            showSection(firstMatch)
        }
    }

    StackView.onActivated: {
        // This enables Tab and BackTab based navigation rather than arrow keys.
        // It is required to shift focus between controls on the settings page.
        SdlGamepadKeyNavigation.setUiNavMode(true)

        // Highlight the open page in the sidebar if a gamepad is connected.
        // The page may not be the first one (for example when opened from the
        // monitor profile picker), so don't assume which controls are visible.
        if (SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            focusCurrentSection()
        }
    }

    StackView.onDeactivating: {
        SdlGamepadKeyNavigation.setUiNavMode(false)

        // Save the prefs so the Session can observe the changes
        StreamingPreferences.save()
    }

    Component.onDestruction: {
        // Also save preferences on destruction, since we won't get a
        // deactivating callback if the user just closes the app
        StreamingPreferences.save()
    }

    // Norilight: each entry is one short page, grouped under a heading in the
    // sidebar.
    // Names are marked with QT_TR_NOOP and translated where they're shown, so
    // the sidebar follows a language change without being rebuilt.
    ListModel {
        id: sectionModel

        ListElement {
            key: "video"
            category: QT_TR_NOOP("Stream")
            name: QT_TR_NOOP("Video quality")
            summary: QT_TR_NOOP("Resolution, frame rate, bitrate, HDR")
            keywords: "fps hz resolution 720p 1080p 1440p 4k bitrate mbps sharp quality hdr very high unlock"
        }
        ListElement {
            key: "display"
            category: QT_TR_NOOP("Stream")
            name: QT_TR_NOOP("Display")
            summary: QT_TR_NOOP("Window mode, V-Sync, picture fit")
            keywords: "display screen picture fit fill stretch crop black bars letterbox aspect top align mode fullscreen borderless windowed vsync v-sync tearing frame pacing stutter"
        }
        ListElement {
            key: "profiles"
            category: QT_TR_NOOP("Stream")
            name: QT_TR_NOOP("Profiles")
            summary: QT_TR_NOOP("Streaming settings and target monitor")
            keywords: "display manager monitor monitors profile profiles screen multiple sessions streams hub second gaming work desktop create rename delete preset presets settings"
        }
        ListElement {
            key: "behaviour"
            category: QT_TR_NOOP("Stream")
            name: QT_TR_NOOP("Window behaviour")
            summary: QT_TR_NOOP("Always on top, position, watch only")
            keywords: "window on top remember position size sleep awake screensaver watch only view observe monitor input"
        }
        ListElement {
            key: "audio"
            category: QT_TR_NOOP("Stream")
            name: QT_TR_NOOP("Audio")
            summary: QT_TR_NOOP("Speakers and muting")
            keywords: "sound surround 5.1 7.1 stereo mute speakers volume"
        }
        ListElement {
            key: "advanced"
            category: QT_TR_NOOP("Stream")
            name: QT_TR_NOOP("Video decoding")
            summary: QT_TR_NOOP("Decoder, codec, colour")
            keywords: "advanced decoder decoding hardware software gpu cpu codec h.264 h264 hevc h.265 av1 renderer yuv 4:4:4 444 colour color full range"
        }
        ListElement {
            key: "input"
            category: QT_TR_NOOP("Input")
            name: QT_TR_NOOP("Mouse")
            summary: QT_TR_NOOP("Cursor, buttons, speed, scrolling")
            keywords: "mouse cursor remote desktop free drag leave capture lock swap left handed buttons sensitivity speed scroll wheel reverse natural"
        }
        ListElement {
            key: "keyboard"
            category: QT_TR_NOOP("Input")
            name: QT_TR_NOOP("Keyboard & touch")
            summary: QT_TR_NOOP("System keys, screenshots, touchscreen")
            keywords: "keyboard shortcuts alt tab windows key system keys screenshot screenshots print screen prtscn snipping powertoys quick accent accents unicode touch touchscreen"
        }
        ListElement {
            key: "gamepad"
            category: QT_TR_NOOP("Input")
            name: QT_TR_NOOP("Controllers")
            summary: QT_TR_NOOP("Gamepads and button layout")
            keywords: "gamepad controller joystick xbox playstation dualsense nintendo swap buttons layout start mouse background scroll stick deadzone drift gyro motion sensors touchpad"
        }
        ListElement {
            key: "shortcuts"
            category: QT_TR_NOOP("Input")
            name: QT_TR_NOOP("Shortcuts")
            summary: QT_TR_NOOP("Key combinations during a stream")
            keywords: "shortcut shortcuts hotkey hotkeys keys combination ctrl alt shift quit disconnect fullscreen minimize paste stats overlay mouse mode"
        }
        ListElement {
            key: "host"
            category: QT_TR_NOOP("Host")
            name: QT_TR_NOOP("Host PC")
            summary: QT_TR_NOOP("Game settings, Apollo extras")
            keywords: "host game optimize quit close sunshine geforce apollo virtual display sudovda scale factor clipboard copy paste sync history server commands run"
        }
        ListElement {
            key: "app"
            category: QT_TR_NOOP("General")
            name: QT_TR_NOOP("App")
            summary: QT_TR_NOOP("Language, warnings, Discord")
            keywords: "language translation gui main window maximized warnings notices discord presence"
        }
        ListElement {
            key: "network"
            category: QT_TR_NOOP("General")
            name: QT_TR_NOOP("Network & diagnostics")
            summary: QT_TR_NOOP("Host discovery, stats overlay")
            keywords: "advanced mdns network discover blocked firewall performance stats overlay compact lite summary latency"
        }
    }

    Rectangle {
        id: sidebar
        // Narrower in a small window, so the settings keep room
        width: settingsPage.width < 900 ? 200 : 256
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

        // Search stays pinned at the top; the grouped page list sits below it
        TextField {
            id: searchField
            x: 16
            y: 16
            width: parent.width - 33
            placeholderText: qsTr("Search settings")
            font.pointSize: Theme.fontBody
            selectByMouse: true
            // Room for the clear button
            rightPadding: text !== "" ? clearSearchButton.width + 4 : leftPadding
            onTextChanged: {
                settingsPage.searchText = text.trim()
                settingsPage.followSearch()
            }
            // Escape clears the search; on an empty field it goes back as usual
            Keys.onEscapePressed: {
                if (text !== "") {
                    text = ""
                }
                else {
                    event.accepted = false
                }
            }
            Keys.onDownPressed: settingsPage.focusCurrentSection()

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
                bottom: parent.bottom
            }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: navColumn.height

            ScrollBar.vertical: ScrollBar {
                policy: navFlick.contentHeight > navFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            // While the list moves, items slide under a still cursor; hover
            // highlights would flicker from row to row, so hold them off
            // until the list has stopped
            readonly property bool scrolling: navScrollSettle.running || moving
            onContentYChanged: navScrollSettle.restart()

            Timer {
                id: navScrollSettle
                interval: 150
            }

            Column {
                id: navColumn
                width: navFlick.width
                bottomPadding: 12
                spacing: 0

                Repeater {
                    id: navRepeater
                    model: sectionModel

                    delegate: Column {
                        property alias navButton: navItem

                        width: navColumn.width
                        visible: settingsPage.sectionMatches(model.name, model.summary, model.keywords)

                        // Same style as the headings above settings cards
                        Label {
                            x: 24
                            width: parent.width - 40
                            topPadding: index === 0 ? 4 : 12
                            bottomPadding: 4
                            visible: settingsPage.firstVisibleInCategory(index)
                            text: qsTr(model.category)
                            font.pointSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                            color: Theme.textTertiary
                            elide: Text.ElideRight
                        }

                        ItemDelegate {
                            id: navItem

                            readonly property bool selected: settingsPage.currentSection === model.key

                            width: parent.width
                            height: 32
                            padding: 0
                            hoverEnabled: true
                            focusPolicy: Qt.TabFocus

                            onClicked: settingsPage.showSection(model.key)
                            Keys.onReturnPressed: settingsPage.showSection(model.key)
                            Keys.onEnterPressed: settingsPage.showSection(model.key)
                            Keys.onUpPressed: settingsPage.stepSection(index, -1)
                            Keys.onDownPressed: settingsPage.stepSection(index, 1)

                            background: Rectangle {
                                // No colour animation: rows passing under the
                                // cursor would each leave a fading trail
                                color: navItem.selected ? Theme.navSelected
                                     : ((navItem.hovered && !navFlick.scrolling) || navItem.visualFocus ? Theme.navHover : "transparent")

                                Rectangle {
                                    x: 0
                                    width: 3
                                    radius: 1.5
                                    height: parent.height - 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Material.accent
                                    visible: navItem.selected
                                }
                            }

                            contentItem: Item {
                                Label {
                                    x: 24
                                    width: parent.width - 40
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr(model.name)
                                    font.pointSize: Theme.fontBody
                                    font.weight: navItem.selected ? Font.DemiBold : Font.Normal
                                    color: navItem.selected ? Theme.textHeading : Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Label {
                    x: 24
                    width: parent.width - 48
                    topPadding: 8
                    visible: settingsPage.searchText !== "" && settingsPage.matchCount() === 0
                    text: qsTr("No settings match \"%1\".").arg(settingsPage.searchText)
                    font.pointSize: Theme.fontDetail
                    color: Theme.textSecondary
                    wrapMode: Text.Wrap
                }
            }
        }

        WheelScroller {
            flickable: navFlick
        }
    }

    Flickable {
        id: settingsFlick
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: sidebar.right
            right: parent.right
        }
        clip: true
        boundsBehavior: Flickable.OvershootBounds

        contentWidth: width
        contentHeight: settingsColumn.height

        ScrollBar.vertical: ScrollBar {}

        function isChildOfFlickable(item) {
            while (item) {
                if (item.parent === contentItem) {
                    return true
                }

                item = item.parent
            }
            return false
        }

        NumberAnimation on contentY {
            id: autoScrollAnimation
            duration: 100
        }

        Window.onActiveFocusItemChanged: {
            var item = Window.activeFocusItem
            if (item) {
                // Ignore non-child elements like the toolbar buttons and sidebar
                if (!isChildOfFlickable(item)) {
                    return
                }

                // Map the focus item's position into our content item's coordinate space
                var pos = item.mapToItem(contentItem, 0, 0)

                // Ensure some extra space is visible around the element we're scrolling to
                var scrollMargin = height > 100 ? 50 : 0

                if (pos.y - scrollMargin < contentY) {
                    autoScrollAnimation.from = contentY
                    autoScrollAnimation.to = Math.max(pos.y - scrollMargin, 0)
                    autoScrollAnimation.start()
                }
                else if (pos.y + item.height + scrollMargin > contentY + height) {
                    autoScrollAnimation.from = contentY
                    autoScrollAnimation.to = Math.min(pos.y + item.height + scrollMargin - height, contentHeight - height)
                    autoScrollAnimation.start()
                }
            }
        }

        Column {
            id: settingsColumn
            readonly property real sideMargin: settingsFlick.width < 560 ? 20 : 44
            x: sideMargin
            width: Math.max(0, Math.min(settingsFlick.width - 2 * sideMargin, Theme.contentMaxWidth))
            topPadding: 24
            bottomPadding: 48
            spacing: 0

            // Norilight: each page is a title and a few cards of rows. A row's
            // hint stays for requirements, consequences and the current state;
            // longer explanations sit behind its (i) button.

            SettingsGroup {
                section: "video"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Video quality")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    title: qsTr("Resolution and frame rate")

                    SettingsSwitch {
                        text: qsTr("Match the target monitor's resolution")
                        checked: StreamingPreferences.matchMonitorResolution
                        onToggled: StreamingPreferences.matchMonitorResolution = checked

                        AutoResizingComboBox {
                            maximumWidth: Math.min(240, settingsColumn.width * 0.35)
                            minimumWidth: 200
                            property int lastIndexValue

                            function addDetectedResolution(friendlyNamePrefix, rect) {
                                var indexToAdd = 0
                                for (var j = 0; j < resolutionComboBox.count; j++) {
                                    var existing_width = parseInt(resolutionListModel.get(j).video_width);
                                    var existing_height = parseInt(resolutionListModel.get(j).video_height);

                                    if (rect.width === existing_width && rect.height === existing_height) {
                                        // Duplicate entry, skip
                                        indexToAdd = -1
                                        break
                                    }
                                    else if (rect.width * rect.height > existing_width * existing_height) {
                                        // Candidate entrypoint after this entry
                                        indexToAdd = j + 1
                                    }
                                }

                                // Insert this display's resolution if it's not a duplicate
                                if (indexToAdd >= 0) {
                                    resolutionListModel.insert(indexToAdd,
                                                               {
                                                                   "text": friendlyNamePrefix+" ("+rect.width+"×"+rect.height+")",
                                                                   "video_width": ""+rect.width,
                                                                   "video_height": ""+rect.height,
                                                                   "is_custom": false
                                                               })
                                }
                            }

                            // ignore setting the index at first, and actually set it when the component is loaded
                            Component.onCompleted: {
                                // Refresh display data before using it to build the list
                                SystemProperties.refreshDisplays()

                                // Add native and safe area resolutions for all attached displays
                                var done = false
                                for (var displayIndex = 0; !done; displayIndex++) {
                                    var screenRect = SystemProperties.getNativeResolution(displayIndex);
                                    var safeAreaRect = SystemProperties.getSafeAreaResolution(displayIndex);

                                    if (screenRect.width === 0) {
                                        // Exceeded max count of displays
                                        done = true
                                        break
                                    }

                                    addDetectedResolution(qsTr("Native"), screenRect)
                                    addDetectedResolution(qsTr("Native (Excluding Notch)"), safeAreaRect)
                                }

                                // Prune resolutions that are over the decoder's maximum
                                var max_pixels = SystemProperties.maximumResolution.width * SystemProperties.maximumResolution.height;
                                if (max_pixels > 0) {
                                    for (var j = 0; j < resolutionComboBox.count; j++) {
                                        var existing_width = parseInt(resolutionListModel.get(j).video_width);
                                        var existing_height = parseInt(resolutionListModel.get(j).video_height);

                                        if (existing_width * existing_height > max_pixels) {
                                            resolutionListModel.remove(j)
                                            j--
                                        }
                                    }
                                }

                                // load the saved width/height, and iterate through the ComboBox until a match is found
                                // and set it to that index.
                                var saved_width = StreamingPreferences.width
                                var saved_height = StreamingPreferences.height
                                var index_set = false
                                for (var i = 0; i < resolutionListModel.count; i++) {
                                    var el_width = parseInt(resolutionListModel.get(i).video_width);
                                    var el_height = parseInt(resolutionListModel.get(i).video_height);

                                    if (saved_width === el_width && saved_height === el_height) {
                                        currentIndex = i
                                        index_set = true
                                        break
                                    }
                                }

                                if (!index_set) {
                                    // We did not find a match. This must be a custom resolution.
                                    resolutionListModel.append({
                                                                   "text": qsTr("Custom")+" ("+StreamingPreferences.width+"×"+StreamingPreferences.height+")",
                                                                   "video_width": ""+StreamingPreferences.width,
                                                                   "video_height": ""+StreamingPreferences.height,
                                                                   "is_custom": true
                                                               })
                                    currentIndex = resolutionListModel.count - 1
                                }
                                else {
                                    resolutionListModel.append({
                                                                   "text": qsTr("Custom"),
                                                                   "video_width": "",
                                                                   "video_height": "",
                                                                   "is_custom": true
                                                               })
                                }

                                // Since we don't call activate() here, we need to trigger
                                // width calculation manually
                                recalculateWidth()

                                lastIndexValue = currentIndex
                            }

                            id: resolutionComboBox
                            enabled: !StreamingPreferences.matchMonitorResolution
                            textRole: "text"
                            model: ListModel {
                                id: resolutionListModel
                                // Other elements may be added at runtime
                                // based on attached display resolution
                                ListElement {
                                    text: qsTr("720p")
                                    video_width: "1280"
                                    video_height: "720"
                                    is_custom: false
                                }
                                ListElement {
                                    text: qsTr("1080p")
                                    video_width: "1920"
                                    video_height: "1080"
                                    is_custom: false
                                }
                                ListElement {
                                    text: qsTr("1440p")
                                    video_width: "2560"
                                    video_height: "1440"
                                    is_custom: false
                                }
                                ListElement {
                                    text: qsTr("4K")
                                    video_width: "3840"
                                    video_height: "2160"
                                    is_custom: false
                                }
                            }

                            function updateBitrateForSelection() {
                                var selectedWidth = parseInt(resolutionListModel.get(currentIndex).video_width)
                                var selectedHeight = parseInt(resolutionListModel.get(currentIndex).video_height)

                                // Only modify the bitrate if the values actually changed
                                if (StreamingPreferences.width !== selectedWidth || StreamingPreferences.height !== selectedHeight) {
                                    StreamingPreferences.width = selectedWidth
                                    StreamingPreferences.height = selectedHeight

                                    if (StreamingPreferences.autoAdjustBitrate) {
                                        StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                                  StreamingPreferences.height,
                                                                                                                  StreamingPreferences.fps,
                                                                                                                  StreamingPreferences.enableYUV444);
                                        slider.value = StreamingPreferences.bitrateKbps
                                    }
                                }

                                lastIndexValue = currentIndex
                            }

                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated : {
                                if (resolutionListModel.get(currentIndex).is_custom) {
                                    customResolutionDialog.open()
                                }
                                else {
                                    updateBitrateForSelection()
                                }
                            }

                            NavigableDialog {
                                id: customResolutionDialog
                                standardButtons: Dialog.Ok | Dialog.Cancel
                                onOpened: {
                                    // Force keyboard focus on the textbox so keyboard navigation works
                                    widthField.forceActiveFocus()

                                    // standardButton() was added in Qt 5.10, so we must check for it first
                                    if (customResolutionDialog.standardButton) {
                                        customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                    }
                                }

                                onClosed: {
                                    widthField.clear()
                                    heightField.clear()
                                }

                                onRejected: {
                                    resolutionComboBox.currentIndex = resolutionComboBox.lastIndexValue
                                }

                                function isInputValid() {
                                    // If we have text in either textbox that isn't valid,
                                    // reject the input.
                                    if ((!widthField.acceptableInput && widthField.text) ||
                                            (!heightField.acceptableInput && heightField.text)) {
                                        return false
                                    }

                                    // The textboxes need to have text or placeholder text
                                    if ((!widthField.text && !widthField.placeholderText) ||
                                            (!heightField.text && !heightField.placeholderText)) {
                                        return false
                                    }

                                    return true
                                }

                                onAccepted: {
                                    // Reject if there's invalid input
                                    if (!isInputValid()) {
                                        reject()
                                        return
                                    }

                                    var width = widthField.text ? widthField.text : widthField.placeholderText
                                    var height = heightField.text ? heightField.text : heightField.placeholderText

                                    // Find and update the custom entry
                                    for (var i = 0; i < resolutionListModel.count; i++) {
                                        if (resolutionListModel.get(i).is_custom) {
                                            resolutionListModel.setProperty(i, "video_width", width)
                                            resolutionListModel.setProperty(i, "video_height", height)
                                            resolutionListModel.setProperty(i, "text", qsTr("Custom")+" ("+width+"×"+height+")")

                                            // Now update the bitrate using the custom resolution
                                            resolutionComboBox.currentIndex = i
                                            resolutionComboBox.updateBitrateForSelection()

                                            // Update the combobox width too
                                            resolutionComboBox.recalculateWidth()
                                            break
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Label {
                                        text: qsTr("Custom resolutions are not officially supported by GeForce Experience, so it will not set your host display resolution. You will need to set it manually while in game.") + "\n\n" +
                                              qsTr("Resolutions that are not supported by your client or host PC may cause streaming errors.") + "\n"
                                        wrapMode: Label.WordWrap
                                        Layout.maximumWidth: 300
                                    }

                                    Label {
                                        text: qsTr("Enter a custom resolution:")
                                        font.bold: true
                                    }

                                    RowLayout {
                                        TextField {
                                            id: widthField
                                            maximumLength: 5
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            placeholderText: resolutionListModel.get(resolutionComboBox.currentIndex).video_width
                                            validator: IntValidator{bottom:256; top:8192}
                                            focus: true

                                            onTextChanged: {
                                                // standardButton() was added in Qt 5.10, so we must check for it first
                                                if (customResolutionDialog.standardButton) {
                                                    customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                                }
                                            }

                                            Keys.onReturnPressed: {
                                                customResolutionDialog.accept()
                                            }

                                            Keys.onEnterPressed: {
                                                customResolutionDialog.accept()
                                            }
                                        }

                                        Label {
                                            text: "x"
                                            font.bold: true
                                        }

                                        TextField {
                                            id: heightField
                                            maximumLength: 5
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            placeholderText: resolutionListModel.get(resolutionComboBox.currentIndex).video_height
                                            validator: IntValidator{bottom:256; top:8192}

                                            onTextChanged: {
                                                // standardButton() was added in Qt 5.10, so we must check for it first
                                                if (customResolutionDialog.standardButton) {
                                                    customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                                }
                                            }

                                            Keys.onReturnPressed: {
                                                customResolutionDialog.accept()
                                            }

                                            Keys.onEnterPressed: {
                                                customResolutionDialog.accept()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SettingsSwitch {
                        text: qsTr("Match the target monitor's refresh rate")
                        checked: StreamingPreferences.matchMonitorRefreshRate
                        onToggled: StreamingPreferences.matchMonitorRefreshRate = checked

                        AutoResizingComboBox {
                            maximumWidth: Math.min(240, settingsColumn.width * 0.35)
                            minimumWidth: 200
                            property int lastIndexValue

                            function updateBitrateForSelection() {
                                // Only modify the bitrate if the values actually changed
                                var selectedFps = parseInt(model.get(fpsComboBox.currentIndex).video_fps)
                                if (StreamingPreferences.fps !== selectedFps) {
                                    StreamingPreferences.fps = selectedFps

                                    if (StreamingPreferences.autoAdjustBitrate) {
                                        StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                                  StreamingPreferences.height,
                                                                                                                  StreamingPreferences.fps,
                                                                                                                  StreamingPreferences.enableYUV444);
                                        slider.value = StreamingPreferences.bitrateKbps
                                    }
                                }

                                lastIndexValue = currentIndex
                            }

                            NavigableDialog {
                                function isInputValid() {
                                    // If we have text that isn't valid, reject the input.
                                    if (!fpsField.acceptableInput && fpsField.text) {
                                        return false
                                    }

                                    // The textbox needs to have text or placeholder text
                                    if (!fpsField.text && !fpsField.placeholderText) {
                                        return false
                                    }

                                    return true
                                }

                                id: customFpsDialog
                                standardButtons: Dialog.Ok | Dialog.Cancel
                                onOpened: {
                                    // Force keyboard focus on the textbox so keyboard navigation works
                                    fpsField.forceActiveFocus()

                                    // standardButton() was added in Qt 5.10, so we must check for it first
                                    if (customFpsDialog.standardButton) {
                                        customFpsDialog.standardButton(Dialog.Ok).enabled = customFpsDialog.isInputValid()
                                    }
                                }

                                onClosed: {
                                    fpsField.clear()
                                }

                                onRejected: {
                                    fpsComboBox.currentIndex = fpsComboBox.lastIndexValue
                                }

                                onAccepted: {
                                    // Reject if there's invalid input
                                    if (!isInputValid()) {
                                        reject()
                                        return
                                    }

                                    var fps = fpsField.text ? fpsField.text : fpsField.placeholderText

                                    // Find and update the custom entry
                                    for (var i = 0; i < fpsListModel.count; i++) {
                                        if (fpsListModel.get(i).is_custom) {
                                            fpsListModel.setProperty(i, "video_fps", fps)
                                            fpsListModel.setProperty(i, "text", qsTr("Custom (%1 FPS)").arg(fps))

                                            // Now update the bitrate using the custom resolution
                                            fpsComboBox.currentIndex = i
                                            fpsComboBox.updateBitrateForSelection()

                                            // Update the combobox width too
                                            fpsComboBox.recalculateWidth()
                                            break
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Label {
                                        text: qsTr("Enter a custom frame rate:")
                                        font.bold: true
                                    }

                                    RowLayout {
                                        TextField {
                                            id: fpsField
                                            maximumLength: 4
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            placeholderText: fpsListModel.get(fpsComboBox.currentIndex).video_fps
                                            validator: IntValidator{bottom:10; top:9999}
                                            focus: true

                                            onTextChanged: {
                                                // standardButton() was added in Qt 5.10, so we must check for it first
                                                if (customFpsDialog.standardButton) {
                                                    customFpsDialog.standardButton(Dialog.Ok).enabled = customFpsDialog.isInputValid()
                                                }
                                            }

                                            Keys.onReturnPressed: {
                                                customFpsDialog.accept()
                                            }

                                            Keys.onEnterPressed: {
                                                customFpsDialog.accept()
                                            }
                                        }
                                    }
                                }
                            }

                            function addRefreshRateOrdered(fpsListModel, refreshRate, description, custom) {
                                var indexToAdd = 0
                                for (var j = 0; j < fpsListModel.count; j++) {
                                    var existing_fps = parseInt(fpsListModel.get(j).video_fps);

                                    if (refreshRate === existing_fps || (custom && fpsListModel.get(j).is_custom)) {
                                        // Duplicate entry, skip
                                        indexToAdd = -1
                                        break
                                    }
                                    else if (refreshRate > existing_fps) {
                                        // Candidate entrypoint after this entry
                                        indexToAdd = j + 1
                                    }
                                }

                                // Insert this frame rate if it's not a duplicate
                                if (indexToAdd >= 0) {
                                    // Custom values always go at the end of the list
                                    if (custom) {
                                        indexToAdd = fpsListModel.count
                                    }

                                    fpsListModel.insert(indexToAdd,
                                                        {
                                                            "text": description,
                                                            "video_fps": ""+refreshRate,
                                                            "is_custom": custom
                                                        })
                                }

                                return indexToAdd
                            }

                            function reinitialize() {
                                // Add native refresh rate for all attached displays
                                var done = false
                                for (var displayIndex = 0; !done; displayIndex++) {
                                    var refreshRate = SystemProperties.getRefreshRate(displayIndex);
                                    if (refreshRate === 0) {
                                        // Exceeded max count of displays
                                        done = true
                                        break
                                    }

                                    addRefreshRateOrdered(fpsListModel, refreshRate, qsTr("%1 FPS").arg(refreshRate), false)
                                }

                                var saved_fps = StreamingPreferences.fps
                                var found = false
                                for (var i = 0; i < model.count; i++) {
                                    var el_fps = parseInt(model.get(i).video_fps);

                                    // Look for a matching frame rate
                                    if (saved_fps === el_fps) {
                                        currentIndex = i
                                        found = true
                                        break
                                    }
                                }

                                // If we didn't find one, add a custom frame rate for the current value
                                if (!found) {
                                    currentIndex = addRefreshRateOrdered(model, saved_fps, qsTr("Custom (%1 FPS)").arg(saved_fps), true)
                                }
                                else {
                                    addRefreshRateOrdered(model, "", qsTr("Custom"), true)
                                }

                                recalculateWidth()

                                lastIndexValue = currentIndex
                            }

                            // ignore setting the index at first, and actually set it when the component is loaded
                            Component.onCompleted: {
                                reinitialize()
                                languageChanged.connect(reinitialize)
                            }

                            model: ListModel {
                                id: fpsListModel
                                // Other elements may be added at runtime
                                ListElement {
                                    text: qsTr("30 FPS")
                                    video_fps: "30"
                                    is_custom: false
                                }
                                ListElement {
                                    text: qsTr("60 FPS")
                                    video_fps: "60"
                                    is_custom: false
                                }
                            }

                            id: fpsComboBox
                            enabled: !StreamingPreferences.matchMonitorRefreshRate
                            textRole: "text"
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated : {
                                if (model.get(currentIndex).is_custom) {
                                    customFpsDialog.open()
                                }
                                else {
                                    updateBitrateForSelection()
                                }
                            }
                        }
                    }
                }

                SettingsCard {
                    title: qsTr("Picture")

                    // Norilight: launch-time tuning goal (docs/GUIDE.md, "Tuning")
                    SettingsRow {
                        text: qsTr("Tuning")
                        info: qsTr("Picks codec, HDR, V-sync, frame pacing and the start bitrate for each stream from this PC, the host and the network.")
                        focusTarget: tuningComboBox

                        AutoResizingComboBox {
                            id: tuningComboBox
                            maximumWidth: Math.min(260, settingsColumn.width * 0.4)
                            minimumWidth: 200
                            textRole: "text"
                            model: ListModel {
                                id: tuningListModel
                                ListElement {
                                    text: qsTr("Performance")
                                    val: StreamingPreferences.TG_PERFORMANCE
                                }
                                ListElement {
                                    text: qsTr("Balanced")
                                    val: StreamingPreferences.TG_BALANCED
                                }
                                ListElement {
                                    text: qsTr("Quality")
                                    val: StreamingPreferences.TG_QUALITY
                                }
                                ListElement {
                                    text: qsTr("Off")
                                    val: StreamingPreferences.TG_OFF
                                }
                            }
                            Component.onCompleted: {
                                currentIndex = 1
                                for (var i = 0; i < tuningListModel.count; i++) {
                                    if (tuningListModel.get(i).val === StreamingPreferences.tuningGoal) {
                                        currentIndex = i
                                        break
                                    }
                                }
                            }
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated: {
                                StreamingPreferences.tuningGoal = tuningListModel.get(currentIndex).val
                            }
                        }
                    }

                    SettingsRow {
                        id: bitrateRow
                        text: qsTr("Video bitrate")
                        info: qsTr("How much data the stream uses each second. Lower it on slow Wi-Fi; raise it for a sharper picture.")
                        focusTarget: slider

                        Button {
                            id: resetBitrateButton
                            text: qsTr("Reset to recommended (%1 Mbps)").arg(StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444) / 1000.0)
                            visible: StreamingPreferences.bitrateKbps !== StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444)
                            flat: true
                            onClicked: {
                                var defaultBitrate = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444)
                                StreamingPreferences.bitrateKbps = defaultBitrate
                                StreamingPreferences.autoAdjustBitrate = true
                                slider.value = defaultBitrate
                            }
                        }

                        Slider {
                            id: slider
                            Layout.preferredHeight: 32

                            value: StreamingPreferences.bitrateKbps

                            stepSize: 500
                            from : 500
                            to: StreamingPreferences.unlockBitrate ? 500000 : 150000

                            snapMode: "SnapOnRelease"
                            // Shrinks first when the window is narrow
                            Layout.preferredWidth: Math.max(100, Math.min(220, bitrateRow.width - 140
                                                                          - (resetBitrateButton.visible ? resetBitrateButton.implicitWidth + Theme.controlGap : 0)
                                                                          - bitrateField.width - bitrateUnit.implicitWidth - 2 * Theme.controlGap))

                            onValueChanged: {
                                StreamingPreferences.bitrateKbps = value
                            }

                            onMoved: {
                                StreamingPreferences.autoAdjustBitrate = false
                            }
                        }

                        // Norilight: type an exact bitrate instead of dragging
                        TextField {
                            id: bitrateField
                            Layout.preferredWidth: 72
                            horizontalAlignment: TextInput.AlignRight
                            selectByMouse: true
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            // No validator: one would reject out-of-range values
                            // like 600 without ever finishing the edit, leaving
                            // them in the field. commit() clamps instead.
                            maximumLength: 6
                            text: (slider.value / 1000.0).toString()

                            ToolTip.delay: 600
                            ToolTip.timeout: 6000
                            ToolTip.visible: hovered && !activeFocus
                            ToolTip.text: qsTr("Type an exact bitrate from 0.5 to 500 Mbps. Above 150 Mbps turns on very high bitrates.")

                            function commit() {
                                // Accept a comma as the decimal mark too
                                var mbps = parseFloat(text.replace(",", "."))
                                if (!isNaN(mbps)) {
                                    var kbps = Math.round(Math.min(Math.max(mbps, 0.5), 500) * 1000)
                                    if (kbps > 150000 && !StreamingPreferences.unlockBitrate) {
                                        StreamingPreferences.unlockBitrate = true
                                    }
                                    StreamingPreferences.autoAdjustBitrate = false
                                    StreamingPreferences.bitrateKbps = kbps
                                    slider.value = kbps
                                }
                                text = Qt.binding(function() { return (slider.value / 1000.0).toString() })
                            }

                            onEditingFinished: commit()
                        }

                        Label {
                            id: bitrateUnit
                            text: qsTr("Mbps")
                            font.pointSize: Theme.fontBody
                            color: Theme.textSecondary
                        }
                    }

                    // Norilight: next to the slider it affects. Typing a bitrate
                    // above 150 Mbps in the field turns this on as well.
                    SettingsSwitch {
                        id: unlockBitrate
                        text: qsTr("Allow very high bitrates (experimental)")
                        hint: qsTr("Raises the limit from 150 to 500 Mbps. Only for wired Ethernet with a Sunshine host.")

                        checked: StreamingPreferences.unlockBitrate
                        onCheckedChanged: {
                            StreamingPreferences.unlockBitrate = checked
                            StreamingPreferences.bitrateKbps = Math.min(StreamingPreferences.bitrateKbps, slider.to)
                            slider.value = StreamingPreferences.bitrateKbps
                        }
                    }

                    SettingsSwitch {
                        id: enableHdr
                        text: qsTr("Stream in HDR")
                        available: SystemProperties.supportsHdr
                        // Why it's unavailable stays visible; what it does is one click away
                        hint: available ? "" : qsTr("HDR streaming is not supported on this PC.")
                        info: available ? qsTr("Brighter highlights and richer colour. Needs an HDR display on this PC and a supported host. Some games also need an HDR monitor on the host.") : ""

                        checked: available && StreamingPreferences.enableHdr
                        onCheckedChanged: {
                            StreamingPreferences.enableHdr = checked
                        }
                    }
                }
            }

            SettingsGroup {
                section: "display"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Display")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    title: qsTr("Window")

                    SettingsRow {
                        text: qsTr("Window mode")
                        info: qsTr("Fullscreen gives the best performance. Borderless windowed fills the screen but switches apps instantly. Windowed lets you work beside the stream.")
                        visible: SystemProperties.hasDesktopEnvironment
                        available: !SystemProperties.rendererAlwaysFullScreen
                        focusTarget: windowModeComboBox

                        AutoResizingComboBox {
                            maximumWidth: Math.min(280, settingsColumn.width * 0.45)
                            minimumWidth: 200
                            function createModel() {
                                var model = Qt.createQmlObject('import QtQuick 2.0; ListModel {}', parent, '')

                                model.append({
                                                 text: qsTr("Fullscreen"),
                                                 val: StreamingPreferences.WM_FULLSCREEN
                                             })

                                model.append({
                                                 text: qsTr("Borderless windowed"),
                                                 val: StreamingPreferences.WM_FULLSCREEN_DESKTOP
                                             })

                                model.append({
                                                 text: qsTr("Windowed"),
                                                 val: StreamingPreferences.WM_WINDOWED
                                             })


                                // Set the recommended option based on the OS
                                for (var i = 0; i < model.count; i++) {
                                    var thisWm = model.get(i).val;
                                    if (thisWm === StreamingPreferences.recommendedFullScreenMode) {
                                        model.get(i).text += " " + qsTr("(Recommended)")
                                        model.move(i, 0, 1)
                                        break
                                    }
                                }

                                return model
                            }


                            // This is used on initialization and upon retranslation
                            function reinitialize() {
                                if (!SystemProperties.hasDesktopEnvironment) {
                                    // Do nothing if the control won't even be visible
                                    return
                                }

                                model = createModel()
                                currentIndex = 0

                                // Set the current value based on the saved preferences
                                var savedWm = StreamingPreferences.windowMode
                                for (var i = 0; i < model.count; i++) {
                                     var thisWm = model.get(i).val;
                                     if (savedWm === thisWm) {
                                         currentIndex = i
                                         break
                                     }
                                }

                                activated(currentIndex)
                            }

                            Component.onCompleted: {
                                reinitialize()
                                languageChanged.connect(reinitialize)
                            }

                            id: windowModeComboBox
                            visible: SystemProperties.hasDesktopEnvironment
                            enabled: !SystemProperties.rendererAlwaysFullScreen
                            hoverEnabled: true
                            textRole: "text"
                            onActivated: {
                                StreamingPreferences.windowMode = model.get(currentIndex).val
                            }
                        }
                    }

                    SettingsSwitch {
                        id: vsyncCheck
                        text: qsTr("V-Sync: sync frames to your display")
                        info: qsTr("Removes screen tearing. Turn it off for slightly lower input lag.")
                        checked: StreamingPreferences.enableVsync
                        onCheckedChanged: {
                            StreamingPreferences.enableVsync = checked
                        }
                    }

                    SettingsSwitch {
                        id: framePacingCheck
                        indented: true
                        text: qsTr("Frame pacing: smooth out uneven frames")
                        info: qsTr("Holds back frames that arrive early to reduce micro-stutter. Needs V-Sync.")
                        available: StreamingPreferences.enableVsync
                        checked: StreamingPreferences.enableVsync && StreamingPreferences.framePacing
                        // Save only what the user clicks: when V-Sync turns
                        // off the switch shows off, but the saved choice
                        // is kept for when V-Sync comes back on. Streams
                        // ignore frame pacing without V-Sync.
                        onToggled: {
                            StreamingPreferences.framePacing = checked
                        }
                    }
                }

                SettingsCard {
                    title: qsTr("Picture")

                    SettingsRow {
                        text: qsTr("Picture fit")
                        focusTarget: videoScaleModeComboBox

                        AutoResizingComboBox {
                            maximumWidth: Math.min(420, settingsColumn.width * 0.6)
                            minimumWidth: 200
                            id: videoScaleModeComboBox
                            textRole: "text"
                            model: ListModel {
                                id: videoScaleModeListModel
                                ListElement {
                                    text: qsTr("Fit: show the whole picture, with black bars if needed")
                                    val: 0
                                }
                                ListElement {
                                    text: qsTr("Fill: cover the window and crop the edges")
                                    val: 1
                                }
                                ListElement {
                                    text: qsTr("Stretch: cover the window and distort the picture")
                                    val: 2
                                }
                            }
                            Component.onCompleted: {
                                currentIndex = 0
                                for (var i = 0; i < videoScaleModeListModel.count; i++) {
                                    if (videoScaleModeListModel.get(i).val === StreamingPreferences.videoScaleMode) {
                                        currentIndex = i
                                        break
                                    }
                                }
                                activated(currentIndex)
                            }
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated: {
                                StreamingPreferences.videoScaleMode = videoScaleModeListModel.get(currentIndex).val
                            }
                        }
                    }

                    SettingsSwitch {
                        id: alignVideoTopCheck
                        indented: true
                        text: qsTr("Pin the picture to the top of the window")
                        info: qsTr("Black bars or cropping go at the bottom instead of being split between top and bottom. Not used with Stretch.")
                        available: StreamingPreferences.videoScaleMode !== 2
                        checked: StreamingPreferences.alignVideoTop
                        onCheckedChanged: {
                            StreamingPreferences.alignVideoTop = checked
                        }
                    }
                }
            }

            ProfileSettings {
                width: parent.width
                visible: settingsPage.currentSection === "profiles"
                onEditSettings: settingsPage.showSection("video")
            }

            SettingsGroup {
                section: "behaviour"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Window behaviour")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    SettingsSwitch {
                        id: alwaysOnTopCheck
                        text: qsTr("Keep the stream window on top of other windows")
                        info: qsTr("Handy for watching the host while you work in other apps. Has no effect in fullscreen.")
                        visible: SystemProperties.hasDesktopEnvironment
                        checked: StreamingPreferences.streamAlwaysOnTop
                        onCheckedChanged: {
                            StreamingPreferences.streamAlwaysOnTop = checked
                        }
                    }

                    SettingsSwitch {
                        id: rememberWindowCheck
                        text: qsTr("Reopen the stream window where you left it")
                        visible: SystemProperties.hasDesktopEnvironment
                        checked: StreamingPreferences.rememberWindowGeometry
                        onCheckedChanged: {
                            StreamingPreferences.rememberWindowGeometry = checked
                        }
                    }

                    SettingsSwitch {
                        id: viewOnlyCheck
                        text: qsTr("Watch only: don't send any input to the host")
                        info: qsTr("Your mouse, keyboard, touch and controllers stay on this PC, so you can keep an eye on the host without touching it. Norilight's shortcuts like Ctrl+Alt+Shift+Q still work.")
                        checked: StreamingPreferences.viewOnly
                        onCheckedChanged: {
                            StreamingPreferences.viewOnly = checked
                        }
                    }

                    SettingsSwitch {
                        id: keepAwakeCheck
                        text: qsTr("Keep this PC's screen awake while streaming")
                        checked: StreamingPreferences.keepAwake
                        onCheckedChanged: {
                            StreamingPreferences.keepAwake = checked
                        }
                    }
                }
            }

            SettingsGroup {
                section: "audio"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Audio")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    SettingsRow {
                        text: qsTr("Speaker setup")
                        focusTarget: audioComboBox

                        AutoResizingComboBox {
                            maximumWidth: Math.min(240, settingsColumn.width * 0.4)
                            minimumWidth: 200
                            // ignore setting the index at first, and actually set it when the component is loaded
                            Component.onCompleted: {
                                var saved_audio = StreamingPreferences.audioConfig
                                currentIndex = 0
                                for (var i = 0; i < audioListModel.count; i++) {
                                    var el_audio = audioListModel.get(i).val;
                                    if (saved_audio === el_audio) {
                                        currentIndex = i
                                        break
                                    }
                                }
                                activated(currentIndex)
                            }

                            id: audioComboBox
                            textRole: "text"
                            model: ListModel {
                                id: audioListModel
                                ListElement {
                                    text: qsTr("Stereo")
                                    val: StreamingPreferences.AC_STEREO
                                }
                                ListElement {
                                    text: qsTr("5.1 surround sound")
                                    val: StreamingPreferences.AC_51_SURROUND
                                }
                                ListElement {
                                    text: qsTr("7.1 surround sound")
                                    val: StreamingPreferences.AC_71_SURROUND
                                }
                            }
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated : {
                                StreamingPreferences.audioConfig = audioListModel.get(currentIndex).val
                            }
                        }
                    }

                    SettingsSwitch {
                        id: audioPcCheck
                        text: qsTr("Mute the host PC's speakers while streaming")
                        hint: qsTr("Sound only plays here, not on the host. Restart a running game for this to apply.")
                        checked: !StreamingPreferences.playAudioOnHost
                        onCheckedChanged: {
                            StreamingPreferences.playAudioOnHost = !checked
                        }
                    }

                    SettingsSwitch {
                        id: muteOnFocusLossCheck
                        text: qsTr("Mute the stream when Norilight isn't the active window")
                        visible: SystemProperties.hasDesktopEnvironment
                        checked: StreamingPreferences.muteOnFocusLoss
                        onCheckedChanged: {
                            StreamingPreferences.muteOnFocusLoss = checked
                        }
                    }
                }
            }

            SettingsGroup {
                section: "host"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Host PC")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    SettingsSwitch {
                        id: optimizeGameSettingsCheck
                        text: qsTr("Let the host adjust game settings for the stream")
                        hint: qsTr("GeForce Experience changes each game's graphics settings to suit the stream resolution.")
                        checked: StreamingPreferences.gameOptimizations
                        onCheckedChanged: {
                            StreamingPreferences.gameOptimizations = checked
                        }
                    }

                    SettingsSwitch {
                        id: quitAppAfter
                        text: qsTr("Close the game on the host when you end the stream")
                        hint: qsTr("The game or app is closed for you. Unsaved progress is lost.")
                        checked: StreamingPreferences.quitAppAfter
                        onCheckedChanged: {
                            StreamingPreferences.quitAppAfter = checked
                        }
                    }
                }

                SettingsCard {
                    title: qsTr("Apollo hosts")
                    description: qsTr("Extras for hosts running Apollo, a fork of Sunshine. Other hosts ignore these settings.")

                    SettingsSwitch {
                        id: virtualDisplayCheck
                        text: qsTr("Stream from a virtual display")
                        info: qsTr("The host creates a screen that matches this PC's resolution and frame rate for the stream, instead of using its real monitor. Needs the SudoVDA driver on the host.")
                        checked: StreamingPreferences.useVirtualDisplay
                        onCheckedChanged: {
                            StreamingPreferences.useVirtualDisplay = checked
                        }
                    }

                    SettingsRow {
                        indented: true
                        text: qsTr("Virtual display scale: %1%").arg(Math.round(virtualDisplayScaleSlider.value))
                        info: qsTr("Makes the host's virtual screen bigger or smaller than the stream. At 150%, a 1920×1080 stream is drawn on a 2880×1620 screen, so text gets smaller and sharper.")
                        available: virtualDisplayCheck.checked
                        focusTarget: virtualDisplayScaleSlider

                        Button {
                            text: qsTr("Reset to 100%")
                            flat: true
                            visible: Math.round(virtualDisplayScaleSlider.value) !== 100
                            enabled: virtualDisplayCheck.checked
                            onClicked: {
                                StreamingPreferences.virtualDisplayScale = 100
                                virtualDisplayScaleSlider.value = 100
                            }
                        }

                        Slider {
                            id: virtualDisplayScaleSlider
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: Math.min(220, settingsColumn.width * 0.3)
                            // The track ends on the same edge as the switches
                            rightPadding: -implicitHandleWidth / 2
                            enabled: virtualDisplayCheck.checked
                            from: 20
                            to: 200
                            stepSize: 5
                            snapMode: Slider.SnapOnRelease
                            value: StreamingPreferences.virtualDisplayScale
                            onMoved: StreamingPreferences.virtualDisplayScale = Math.round(value)
                        }
                    }

                    SettingsSwitch {
                        id: clipboardSyncCheck
                        text: qsTr("Sync the clipboard with the host")
                        info: qsTr("Text you copy here is sent to the host when the stream starts or you switch back to it. The host's clipboard comes back when you switch away or end the stream.")
                        checked: StreamingPreferences.clipboardSync
                        onCheckedChanged: {
                            StreamingPreferences.clipboardSync = checked
                        }
                    }

                    SettingsSwitch {
                        id: clipboardNotifyCheck
                        indented: true
                        text: qsTr("Show a notice each time it syncs")
                        available: clipboardSyncCheck.checked
                        checked: StreamingPreferences.clipboardSyncNotify
                        onCheckedChanged: {
                            StreamingPreferences.clipboardSyncNotify = checked
                        }
                    }

                    SettingsSwitch {
                        id: hideClipboardCheck
                        indented: true
                        text: qsTr("Keep text from the host out of clipboard history")
                        info: qsTr("Windows won't save it in Win+V history or sync it to your other devices.")
                        available: clipboardSyncCheck.checked
                        checked: StreamingPreferences.hideSyncedClipboard
                        onCheckedChanged: {
                            StreamingPreferences.hideSyncedClipboard = checked
                        }
                    }

                    SettingsRow {
                        text: qsTr("Host commands")
                        shortcut: "Ctrl+Alt+Shift+R"
                        info: qsTr("During a stream, press Ctrl+Alt+Shift+R to list the commands set up on your Apollo host, then press a number to run one. Esc closes the list.")
                    }
                }
            }

            SettingsGroup {
                section: "app"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("App")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    SettingsRow {
                        text: qsTr("Language")
                        focusTarget: languageComboBox

                        AutoResizingComboBox {
                            maximumWidth: Math.min(260, settingsColumn.width * 0.4)
                            minimumWidth: 200
                            // ignore setting the index at first, and actually set it when the component is loaded
                            Component.onCompleted: {
                                var saved_language = StreamingPreferences.language
                                currentIndex = 0
                                for (var i = 0; i < languageListModel.count; i++) {
                                    var el_language = languageListModel.get(i).val;
                                    if (saved_language === el_language) {
                                        currentIndex = i
                                        break
                                    }
                                }

                                activated(currentIndex)
                            }

                            id: languageComboBox
                            measureAllScripts: false
                            textRole: "text"
                            model: ListModel {
                                id: languageListModel
                                ListElement {
                                    text: qsTr("Automatic")
                                    val: StreamingPreferences.LANG_AUTO
                                }
                                ListElement {
                                    text: "Deutsch" // German
                                    val: StreamingPreferences.LANG_DE
                                }
                                ListElement {
                                    text: "English"
                                    val: StreamingPreferences.LANG_EN
                                }
                                ListElement {
                                    text: "Français" // French
                                    val: StreamingPreferences.LANG_FR
                                }
                                ListElement {
                                    text: "简体中文" // Simplified Chinese
                                    val: StreamingPreferences.LANG_ZH_CN
                                }
                                ListElement {
                                    text: "Norwegian Bokmål"
                                    val: StreamingPreferences.LANG_NB_NO
                                }
                                ListElement {
                                    text: "русский" // Russian
                                    val: StreamingPreferences.LANG_RU
                                }
                                ListElement {
                                    text: "Español" // Spanish
                                    val: StreamingPreferences.LANG_ES
                                }
                                ListElement {
                                    text: "日本語" // Japanese
                                    val: StreamingPreferences.LANG_JA
                                }
                                ListElement {
                                    text: "Tiếng Việt" // Vietnamese
                                    val: StreamingPreferences.LANG_VI
                                }
                                ListElement {
                                    text: "ภาษาไทย" // Thai
                                    val: StreamingPreferences.LANG_TH
                                }
                                ListElement {
                                    text: "한국어" // Korean
                                    val: StreamingPreferences.LANG_KO
                                }
                                ListElement {
                                    text: "Magyar" // Hungarian
                                    val: StreamingPreferences.LANG_HU
                                }
                                ListElement {
                                    text: "Nederlands" // Dutch
                                    val: StreamingPreferences.LANG_NL
                                }
                                ListElement {
                                    text: "Svenska" // Swedish
                                    val: StreamingPreferences.LANG_SV
                                }
                                ListElement {
                                    text: "Türkçe" // Turkish
                                    val: StreamingPreferences.LANG_TR
                                }
                                /* ListElement {
                                    text: "Українська" // Ukrainian
                                    val: StreamingPreferences.LANG_UK
                                } */
                                ListElement {
                                    text: "繁體中文" // Traditional Chinese
                                    val: StreamingPreferences.LANG_ZH_TW
                                }
                                ListElement {
                                    text: "Português" // Portuguese
                                    val: StreamingPreferences.LANG_PT
                                }
                                ListElement {
                                    text: "Português do Brasil" // Brazilian Portuguese
                                    val: StreamingPreferences.LANG_PT_BR
                                }
                                ListElement {
                                    text: "Ελληνικά" // Greek
                                    val: StreamingPreferences.LANG_EL
                                }
                                ListElement {
                                    text: "Italiano" // Italian
                                    val: StreamingPreferences.LANG_IT
                                }
                                /* ListElement {
                                    text: "हिन्दी, हिंदी" // Hindi
                                    val: StreamingPreferences.LANG_HI
                                } */
                                ListElement {
                                    text: "Język polski" // Polish
                                    val: StreamingPreferences.LANG_PL
                                }
                                ListElement {
                                    text: "Čeština" // Czech
                                    val: StreamingPreferences.LANG_CS
                                }
                                /* ListElement {
                                    text: "עִבְרִית" // Hebrew
                                    val: StreamingPreferences.LANG_HE
                                } */
                                /* ListElement {
                                    text: "کرمانجیی خواروو" // Central Kurdish
                                    val: StreamingPreferences.LANG_CKB
                                } */
                                /* ListElement {
                                    text: "Lietuvių kalba" // Lithuanian
                                    val: StreamingPreferences.LANG_LT
                                } */
                                /* ListElement {
                                    text: "Eesti" // Estonian
                                    val: StreamingPreferences.LANG_ET
                                } */
                                ListElement {
                                    text: "Български" // Bulgarian
                                    val: StreamingPreferences.LANG_BG
                                }
                                /* ListElement {
                                    text: "Esperanto"
                                    val: StreamingPreferences.LANG_EO
                                } */
                                ListElement {
                                    text: "தமிழ்" // Tamil
                                    val: StreamingPreferences.LANG_TA
                                }
                            }
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated : {
                                // Retranslating is expensive, so only do it if the language actually changed
                                var new_language = languageListModel.get(currentIndex).val
                                if (StreamingPreferences.language !== new_language) {
                                    StreamingPreferences.language = languageListModel.get(currentIndex).val
                                    if (!StreamingPreferences.retranslate()) {
                                        ToolTip.show(qsTr("You must restart Norilight for this change to take effect"), 5000)
                                    }
                                    else {
                                        // Force the back operation to pop any AppView pages that exist.
                                        // The AppView stops working after retranslate() for some reason.
                                        window.clearOnBack = true

                                        // Signal other controls to adjust their text
                                        languageChanged()
                                    }
                                }
                            }
                        }
                    }

                    SettingsRow {
                        text: qsTr("How Norilight's main window opens")
                        visible: SystemProperties.hasDesktopEnvironment
                        focusTarget: uiDisplayModeComboBox

                        AutoResizingComboBox {
                            maximumWidth: Math.min(240, settingsColumn.width * 0.4)
                            minimumWidth: 200
                            // ignore setting the index at first, and actually set it when the component is loaded
                            Component.onCompleted: {
                                if (!SystemProperties.hasDesktopEnvironment) {
                                    // Do nothing if the control won't even be visible
                                    return
                                }

                                var saved_uidisplaymode = StreamingPreferences.uiDisplayMode
                                currentIndex = 0
                                for (var i = 0; i < uiDisplayModeListModel.count; i++) {
                                    var el_uidisplaymode = uiDisplayModeListModel.get(i).val;
                                    if (saved_uidisplaymode === el_uidisplaymode) {
                                        currentIndex = i
                                        break
                                    }
                                }

                                activated(currentIndex)
                            }

                            id: uiDisplayModeComboBox
                            visible: SystemProperties.hasDesktopEnvironment
                            textRole: "text"
                            model: ListModel {
                                id: uiDisplayModeListModel
                                ListElement {
                                    text: qsTr("Windowed")
                                    val: StreamingPreferences.UI_WINDOWED
                                }
                                ListElement {
                                    text: qsTr("Maximized")
                                    val: StreamingPreferences.UI_MAXIMIZED
                                }   
                                ListElement {
                                    text: qsTr("Fullscreen")
                                    val: StreamingPreferences.UI_FULLSCREEN
                                }
                            }
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated : {
                                StreamingPreferences.uiDisplayMode = uiDisplayModeListModel.get(currentIndex).val
                            }
                        }
                    }

                    SettingsSwitch {
                        id: connectionWarningsCheck
                        text: qsTr("Warn me when the connection is struggling")
                        checked: StreamingPreferences.connectionWarnings
                        onCheckedChanged: {
                            StreamingPreferences.connectionWarnings = checked
                        }
                    }

                    SettingsSwitch {
                        id: configurationWarningsCheck
                        text: qsTr("Warn me about risky settings before a stream starts")
                        info: qsTr("For example, options your host or this PC may not support.")
                        checked: StreamingPreferences.configurationWarnings
                        onCheckedChanged: {
                            StreamingPreferences.configurationWarnings = checked
                        }
                    }

                    SettingsSwitch {
                        id: discordPresenceCheck
                        visible: SystemProperties.hasDiscordIntegration
                        text: qsTr("Show what I'm streaming in my Discord status")
                        checked: StreamingPreferences.richPresence
                        onCheckedChanged: {
                            StreamingPreferences.richPresence = checked
                        }
                    }

                    SettingsSwitch {
                        id: discordButtonCheck
                        visible: SystemProperties.hasDiscordIntegration
                        indented: true
                        text: qsTr("Add a \"Try Norilight!\" button to my Discord status")
                        info: qsTr("Lets friends find Norilight from your profile. A small way to support the project.")
                        available: StreamingPreferences.richPresence
                        checked: StreamingPreferences.richPresenceButton
                        onCheckedChanged: {
                            StreamingPreferences.richPresenceButton = checked
                        }
                    }
                }
            }

            SettingsGroup {
                section: "input"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Mouse")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    title: qsTr("Cursor")

                    SettingsSwitch {
                        id: absoluteMouseCheck
                        text: qsTr("Remote desktop mouse: the host cursor goes where you point")
                        shortcut: "Ctrl+Alt+Shift+M"
                        hint: StreamingPreferences.freeCursorMode ? qsTr("Already on: free cursor below includes it.") : ""
                        info: StreamingPreferences.freeCursorMode ? "" : qsTr("Best for desktop work. Most games need this off. Toggle while streaming with Ctrl+Alt+Shift+M.")
                        available: !StreamingPreferences.freeCursorMode
                        // Free cursor includes this mode, so show it as on then.
                        // Only a click saves it, so turning free cursor off
                        // goes back to the user's own choice.
                        checked: StreamingPreferences.absoluteMouseMode || StreamingPreferences.freeCursorMode
                        onToggled: {
                            StreamingPreferences.absoluteMouseMode = checked
                        }
                    }

                    SettingsSwitch {
                        id: showLocalCursorCheck
                        indented: true
                        text: qsTr("Show this PC's cursor over the stream")
                        shortcut: "Ctrl+Alt+Shift+C"
                        info: qsTr("Draws your own cursor on top of the host's so it never lags behind. Needs remote desktop mouse. Toggle while streaming with Ctrl+Alt+Shift+C.")
                        available: StreamingPreferences.absoluteMouseMode || StreamingPreferences.freeCursorMode
                        checked: StreamingPreferences.showLocalCursor
                        onCheckedChanged: {
                            StreamingPreferences.showLocalCursor = checked
                        }
                    }

                    SettingsSwitch {
                        id: freeCursorCheck
                        text: qsTr("Free cursor: let the mouse leave the stream window")
                        info: qsTr("The cursor is never locked inside the stream, even in fullscreen, so you can move or drag onto other windows and monitors. Turns on remote desktop mouse.")
                        checked: StreamingPreferences.freeCursorMode
                        onCheckedChanged: {
                            StreamingPreferences.freeCursorMode = checked
                        }
                    }
                }

                SettingsCard {
                    title: qsTr("Buttons and scrolling")

                    SettingsSwitch {
                        id: swapMouseButtonsCheck
                        text: qsTr("Swap left and right mouse buttons")
                        checked: StreamingPreferences.swapMouseButtons
                        onCheckedChanged: {
                            StreamingPreferences.swapMouseButtons = checked
                        }
                    }

                    SettingsRow {
                        text: qsTr("Mouse speed in game mode: %1%").arg(Math.round(mouseSensitivitySlider.value))
                        info: qsTr("Scales mouse movement while the cursor is captured for a game. 100% matches your mouse exactly.")
                        focusTarget: mouseSensitivitySlider

                        Button {
                            text: qsTr("Reset to 100%")
                            flat: true
                            visible: Math.round(mouseSensitivitySlider.value) !== 100
                            onClicked: {
                                StreamingPreferences.mouseSensitivity = 100
                                mouseSensitivitySlider.value = 100
                            }
                        }

                        Slider {
                            id: mouseSensitivitySlider
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: Math.min(220, settingsColumn.width * 0.3)
                            // The track ends on the same edge as the switches
                            rightPadding: -implicitHandleWidth / 2
                            from: 10
                            to: 400
                            stepSize: 5
                            snapMode: Slider.SnapOnRelease
                            value: StreamingPreferences.mouseSensitivity
                            onMoved: StreamingPreferences.mouseSensitivity = Math.round(value)
                        }
                    }

                    SettingsRow {
                        text: qsTr("Scroll speed: %1%").arg(Math.round(scrollSpeedSlider.value))
                        focusTarget: scrollSpeedSlider

                        Button {
                            text: qsTr("Reset to 100%")
                            flat: true
                            visible: Math.round(scrollSpeedSlider.value) !== 100
                            onClicked: {
                                StreamingPreferences.scrollSpeed = 100
                                scrollSpeedSlider.value = 100
                            }
                        }

                        Slider {
                            id: scrollSpeedSlider
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: Math.min(220, settingsColumn.width * 0.3)
                            // The track ends on the same edge as the switches
                            rightPadding: -implicitHandleWidth / 2
                            from: 10
                            to: 400
                            stepSize: 5
                            snapMode: Slider.SnapOnRelease
                            value: StreamingPreferences.scrollSpeed
                            onMoved: StreamingPreferences.scrollSpeed = Math.round(value)
                        }
                    }

                    SettingsSwitch {
                        id: reverseScrollButtonsCheck
                        text: qsTr("Reverse scroll direction")
                        checked: StreamingPreferences.reverseScrollDirection
                        onCheckedChanged: {
                            StreamingPreferences.reverseScrollDirection = checked
                        }
                    }
                }
            }

            SettingsGroup {
                section: "keyboard"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Keyboard & touch")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    SettingsSwitch {
                        id: captureSysKeysCheck
                        text: qsTr("Send shortcuts like Alt+Tab and the Windows key to the host")
                        hint: qsTr("When off, this PC handles them. Ctrl+Alt+Del always stays on this PC.")
                        available: SystemProperties.hasDesktopEnvironment
                        checked: StreamingPreferences.captureSysKeysMode !== StreamingPreferences.CSK_OFF || !SystemProperties.hasDesktopEnvironment

                        AutoResizingComboBox {
                            maximumWidth: Math.min(220, settingsColumn.width * 0.3)
                            minimumWidth: 200
                            // ignore setting the index at first, and actually set it when the component is loaded
                            Component.onCompleted: {
                                if (!SystemProperties.hasDesktopEnvironment) {
                                    // Do nothing if the control won't even be visible
                                    return
                                }

                                var saved_syskeysmode = StreamingPreferences.captureSysKeysMode
                                currentIndex = 0
                                for (var i = 0; i < captureSysKeysModeListModel.count; i++) {
                                    var el_syskeysmode = captureSysKeysModeListModel.get(i).val;
                                    if (saved_syskeysmode === el_syskeysmode) {
                                        currentIndex = i
                                        break
                                    }
                                }

                                activated(currentIndex)
                            }

                            enabled: captureSysKeysCheck.checked && captureSysKeysCheck.enabled
                            textRole: "text"
                            model: ListModel {
                                id: captureSysKeysModeListModel
                                ListElement {
                                    text: qsTr("Only in fullscreen")
                                    val: StreamingPreferences.CSK_FULLSCREEN
                                }
                                ListElement {
                                    text: qsTr("Always, also in a window")
                                    val: StreamingPreferences.CSK_ALWAYS
                                }
                            }

                            function updatePref() {
                                if (!enabled) {
                                    StreamingPreferences.captureSysKeysMode = StreamingPreferences.CSK_OFF
                                }
                                else {
                                    StreamingPreferences.captureSysKeysMode = captureSysKeysModeListModel.get(currentIndex).val
                                }
                            }

                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated: {
                                updatePref()
                            }

                            // This handles transition of the checkbox state
                            onEnabledChanged: {
                                updatePref()
                            }
                        }
                    }

                    SettingsSwitch {
                        id: screenshotsOnClientCheck
                        text: qsTr("Take screenshots on this PC only")
                        info: qsTr("PrtScn and Win+Shift+S take a screenshot here and aren't sent to the host, so you don't get one on both PCs.")
                        checked: StreamingPreferences.screenshotsOnClient
                        onCheckedChanged: {
                            StreamingPreferences.screenshotsOnClient = checked
                        }
                    }

                    SettingsSwitch {
                        id: forwardUnicodeInputCheck
                        visible: Qt.platform.os === "windows"
                        text: qsTr("Work with PowerToys Quick Accent")
                        info: qsTr("Sends characters that Quick Accent types on this PC to the host, including the Space it holds back while a letter is down. Without this, Space doesn't work until you stop typing, and picked accents are lost.")
                        checked: StreamingPreferences.forwardUnicodeInput
                        onCheckedChanged: {
                            StreamingPreferences.forwardUnicodeInput = checked
                        }
                    }

                    SettingsSwitch {
                        id: absoluteTouchCheck
                        text: qsTr("Touchscreen works like a trackpad")
                        info: qsTr("Drag to move the cursor and tap to click. When off, the cursor jumps to wherever you touch.")
                        checked: !StreamingPreferences.absoluteTouchMode
                        onCheckedChanged: {
                            StreamingPreferences.absoluteTouchMode = !checked
                        }
                    }
                }
            }

            SettingsGroup {
                section: "gamepad"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Controllers")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    SettingsSwitch {
                        id: swapFaceButtonsCheck
                        text: qsTr("Nintendo-style layout: swap A/B and X/Y")
                        checked: StreamingPreferences.swapFaceButtons
                        onCheckedChanged: {
                            StreamingPreferences.swapFaceButtons = checked
                        }
                    }

                    SettingsSwitch {
                        id: singleControllerCheck
                        text: qsTr("Always report one controller to the host")
                        info: qsTr("For games that only detect controllers connected before they start, even if none is plugged in here.")
                        checked: !StreamingPreferences.multiController
                        onCheckedChanged: {
                            StreamingPreferences.multiController = !checked
                        }
                    }

                    SettingsSwitch {
                        id: gamepadMouseCheck
                        text: qsTr("Hold Start to use a controller as a mouse")
                        info: qsTr("Long-press Start to switch: the stick moves the cursor, A clicks, B right-clicks. Long-press again to switch back.")
                        checked: StreamingPreferences.gamepadMouse
                        onCheckedChanged: {
                            StreamingPreferences.gamepadMouse = checked
                        }
                    }

                    SettingsRow {
                        indented: true
                        text: qsTr("While a controller is a mouse, scroll with")
                        available: gamepadMouseCheck.checked
                        focusTarget: analogScrollComboBox

                        AutoResizingComboBox {
                            maximumWidth: Math.min(320, settingsColumn.width * 0.45)
                            minimumWidth: 200
                            id: analogScrollComboBox
                            enabled: gamepadMouseCheck.checked
                            textRole: "text"
                            model: ListModel {
                                id: analogScrollListModel
                                ListElement {
                                    text: qsTr("The d-pad (either stick moves the cursor)")
                                    val: 0
                                }
                                ListElement {
                                    text: qsTr("The right stick (left stick moves the cursor)")
                                    val: 1
                                }
                                ListElement {
                                    text: qsTr("The left stick (right stick moves the cursor)")
                                    val: 2
                                }
                            }
                            Component.onCompleted: {
                                currentIndex = 0
                                for (var i = 0; i < analogScrollListModel.count; i++) {
                                    if (analogScrollListModel.get(i).val === StreamingPreferences.analogScrollStick) {
                                        currentIndex = i
                                        break
                                    }
                                }
                                activated(currentIndex)
                            }
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated: {
                                StreamingPreferences.analogScrollStick = analogScrollListModel.get(currentIndex).val
                            }
                        }
                    }

                    SettingsSwitch {
                        id: backgroundGamepadCheck
                        text: qsTr("Keep controllers working when Norilight is in the background")
                        visible: SystemProperties.hasDesktopEnvironment
                        checked: StreamingPreferences.backgroundGamepad
                        onCheckedChanged: {
                            StreamingPreferences.backgroundGamepad = checked
                        }
                    }

                    SettingsSwitch {
                        id: gamepadMotionCheck
                        text: qsTr("Let games use controller motion sensors")
                        info: qsTr("Passes gyro and accelerometer data to the host for motion aiming. Turn off if motion causes drift or stutter.")
                        checked: StreamingPreferences.gamepadMotionSensors
                        onCheckedChanged: {
                            StreamingPreferences.gamepadMotionSensors = checked
                        }
                    }

                    SettingsSwitch {
                        id: gamepadTouchpadMouseCheck
                        text: qsTr("Controller touchpad moves the mouse")
                        info: qsTr("On PlayStation-style controllers, slide on the touchpad to move the host cursor and press it to click, instead of passing the touchpad to games.")
                        checked: StreamingPreferences.gamepadTouchpadAsMouse
                        onCheckedChanged: {
                            StreamingPreferences.gamepadTouchpadAsMouse = checked
                        }
                    }

                    SettingsRow {
                        text: qsTr("Stick deadzone: %1%").arg(Math.round(deadzoneSlider.value))
                        info: qsTr("How far a stick must move before it counts. Raise it if a worn stick drifts on its own; 0% passes the stick through untouched.")
                        focusTarget: deadzoneSlider

                        Button {
                            text: qsTr("Reset to 0%")
                            flat: true
                            visible: Math.round(deadzoneSlider.value) !== 0
                            onClicked: {
                                StreamingPreferences.stickDeadzone = 0
                                deadzoneSlider.value = 0
                            }
                        }

                        Slider {
                            id: deadzoneSlider
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: Math.min(220, settingsColumn.width * 0.3)
                            // The track ends on the same edge as the switches
                            rightPadding: -implicitHandleWidth / 2
                            from: 0
                            to: 30
                            stepSize: 1
                            snapMode: Slider.SnapOnRelease
                            value: StreamingPreferences.stickDeadzone
                            onMoved: StreamingPreferences.stickDeadzone = Math.round(value)
                        }
                    }
                }
            }

            // Norilight: every shortcut in one place, instead of only in the
            // descriptions of the settings they relate to
            SettingsGroup {
                id: shortcutsGroupBox
                section: "shortcuts"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Shortcuts")
                titleReserve: editingProfileButton.width

                readonly property var keyboardShortcuts: [
                    { keys: "Ctrl+Alt+Shift+Q", action: qsTr("End the stream") },
                    { keys: "Ctrl+Alt+Shift+E", action: qsTr("End the stream and close Norilight") },
                    { keys: "Ctrl+Alt+Shift+Z", action: qsTr("Release the mouse and keyboard to this PC, or capture them again"), desktop: true },
                    { keys: "Ctrl+Alt+Shift+X", action: qsTr("Switch between fullscreen and a window"), desktop: true },
                    { keys: "Ctrl+Alt+Shift+D", action: qsTr("Minimize the stream window"), desktop: true },
                    { keys: "Ctrl+Alt+Shift+M", action: qsTr("Turn remote desktop mouse on or off") },
                    { keys: "Ctrl+Alt+Shift+C", action: qsTr("Show or hide this PC's cursor (remote desktop mouse)") },
                    { keys: "Ctrl+Alt+Shift+L", action: qsTr("Keep the cursor inside the stream window, or let it out") },
                    { keys: "Ctrl+Alt+Shift+K", action: qsTr("Send system keys like Alt+Tab to the host, or keep them here"), desktop: true },
                    { keys: "Ctrl+Alt+Shift+V", action: qsTr("Type the text on this PC's clipboard into the host") },
                    { keys: "Ctrl+Alt+Shift+S", action: qsTr("Show or hide performance stats") },
                    { keys: "Ctrl+Alt+Shift+R", action: qsTr("List the commands set up on an Apollo host") }
                ]

                readonly property var controllerShortcuts: [
                    { keys: "Start+Select+L1+R1", action: qsTr("End the stream") },
                    { keys: "Select+L1+R1+X", action: qsTr("Show or hide performance stats") },
                    { keys: qsTr("Hold Start"), action: qsTr("Use the controller as a mouse, when turned on under Controllers") }
                ]

                SettingsCard {
                    title: qsTr("Keyboard")

                    Repeater {
                        model: shortcutsGroupBox.keyboardShortcuts
                        delegate: SettingsRow {
                            // Some shortcuts only exist with a desktop environment
                            visible: !modelData.desktop || SystemProperties.hasDesktopEnvironment
                            minimumHeight: 44
                            text: modelData.action
                            shortcut: modelData.keys
                        }
                    }
                }

                SettingsCard {
                    title: qsTr("Controller")

                    Repeater {
                        model: shortcutsGroupBox.controllerShortcuts
                        delegate: SettingsRow {
                            minimumHeight: 44
                            text: modelData.action
                            shortcut: modelData.keys
                        }
                    }
                }
            }

            SettingsGroup {
                section: "advanced"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Video decoding")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    SettingsRow {
                        text: qsTr("Decode video using")
                        focusTarget: decoderComboBox

                        AutoResizingComboBox {
                            maximumWidth: Math.min(260, settingsColumn.width * 0.4)
                            minimumWidth: 200
                            // ignore setting the index at first, and actually set it when the component is loaded
                            Component.onCompleted: {
                                var saved_vds = StreamingPreferences.videoDecoderSelection
                                currentIndex = 0
                                for (var i = 0; i < decoderListModel.count; i++) {
                                    var el_vds = decoderListModel.get(i).val;
                                    if (saved_vds === el_vds) {
                                        currentIndex = i
                                        break
                                    }
                                }
                                activated(currentIndex)
                            }

                            id: decoderComboBox
                            textRole: "text"
                            model: ListModel {
                                id: decoderListModel
                                ListElement {
                                    text: qsTr("Automatic (Recommended)")
                                    val: StreamingPreferences.VDS_AUTO
                                }
                                ListElement {
                                    text: qsTr("Software only (CPU)")
                                    val: StreamingPreferences.VDS_FORCE_SOFTWARE
                                }
                                ListElement {
                                    text: qsTr("Hardware only (GPU)")
                                    val: StreamingPreferences.VDS_FORCE_HARDWARE
                                }
                            }
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated: {
                                if (enabled) {
                                    StreamingPreferences.videoDecoderSelection = decoderListModel.get(currentIndex).val
                                }
                            }
                        }
                    }

                    SettingsRow {
                        text: qsTr("Compression format (codec)")
                        focusTarget: codecComboBox

                        AutoResizingComboBox {
                            maximumWidth: Math.min(260, settingsColumn.width * 0.4)
                            minimumWidth: 200
                            // ignore setting the index at first, and actually set it when the component is loaded
                            Component.onCompleted: {
                                var saved_vcc = StreamingPreferences.videoCodecConfig

                                // Default to Automatic (relevant if HDR is enabled,
                                // where we will match none of the codecs in the list)
                                currentIndex = 0

                                for(var i = 0; i < codecListModel.count; i++) {
                                    var el_vcc = codecListModel.get(i).val;
                                    if (saved_vcc === el_vcc) {
                                        currentIndex = i
                                        break
                                    }
                                }

                                activated(currentIndex)
                            }

                            id: codecComboBox
                            textRole: "text"
                            model: ListModel {
                                id: codecListModel
                                ListElement {
                                    text: qsTr("Automatic (Recommended)")
                                    val: StreamingPreferences.VCC_AUTO
                                }
                                ListElement {
                                    text: qsTr("H.264")
                                    val: StreamingPreferences.VCC_FORCE_H264
                                }
                                ListElement {
                                    text: qsTr("HEVC (H.265)")
                                    val: StreamingPreferences.VCC_FORCE_HEVC
                                }
                                ListElement {
                                    text: qsTr("AV1")
                                    val: StreamingPreferences.VCC_FORCE_AV1
                                }
                            }
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated : {
                                if (enabled) {
                                    StreamingPreferences.videoCodecConfig = codecListModel.get(currentIndex).val
                                }
                            }
                        }
                    }

                    SettingsRow {
                        text: qsTr("Renderer")
                        visible: SystemProperties.isDarwin
                        focusTarget: rendererComboBox

                        AutoResizingComboBox {
                            maximumWidth: Math.min(300, settingsColumn.width * 0.45)
                            minimumWidth: 200
                            // ignore setting the index at first, and actually set it when the component is loaded
                            Component.onCompleted: {
                                var saved_rs = StreamingPreferences.rendererSelection

                                // Default to Automatic
                                currentIndex = 0

                                for(var i = 0; i < rendererListModel.count; i++) {
                                    var el_rs = rendererListModel.get(i).val;
                                    if (saved_rs === el_rs) {
                                        currentIndex = i
                                        break
                                    }
                                }

                                activated(currentIndex)
                            }

                            id: rendererComboBox
                            visible: SystemProperties.isDarwin
                            textRole: "text"
                            model: ListModel {
                                id: rendererListModel
                                ListElement {
                                    text: qsTr("Automatic (Recommended)")
                                    val: StreamingPreferences.RS_AUTO
                                }
                                ListElement {
                                    text: "Vulkan"
                                    val: StreamingPreferences.RS_VULKAN
                                }
                                ListElement {
                                    text: "Metal"
                                    val: StreamingPreferences.RS_METAL
                                }
                                ListElement {
                                    text: "AVSampleBufferDisplayLayer"
                                    val: StreamingPreferences.RS_AVSBDL
                                }
                            }
                            // ::onActivated must be used, as it only listens for when the index is changed by a human
                            onActivated : {
                                StreamingPreferences.rendererSelection = rendererListModel.get(currentIndex).val
                            }
                        }
                    }

                    SettingsSwitch {
                        id: enableYUV444
                        text: qsTr("Full colour detail (YUV 4:4:4)")
                        hint: qsTr("Crisper coloured text and thin lines, great for desktop work. Uses more bandwidth; not for fast games.")

                        checked: StreamingPreferences.enableYUV444
                        onCheckedChanged: {
                            // This is called on init, so only reset to default bitrate when checked state changes.
                            if (StreamingPreferences.enableYUV444 != checked) {
                                StreamingPreferences.enableYUV444 = checked
                                if (StreamingPreferences.autoAdjustBitrate) {
                                    StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                              StreamingPreferences.height,
                                                                                                              StreamingPreferences.fps,
                                                                                                              StreamingPreferences.enableYUV444);
                                    slider.value = StreamingPreferences.bitrateKbps
                                }
                            }
                        }
                    }

                    SettingsSwitch {
                        id: forceFullRangeCheck
                        text: qsTr("Full-range colour (experimental)")
                        info: qsTr("Asks the host for the full 0-255 brightness range instead of the TV range. Can crush shadows and highlights if your display or decoder doesn't expect it.")
                        checked: StreamingPreferences.forceFullRange
                        onCheckedChanged: {
                            StreamingPreferences.forceFullRange = checked
                        }
                    }
                }
            }

            SettingsGroup {
                section: "network"
                visible: settingsPage.currentSection === section
                width: parent.width
                title: qsTr("Network & diagnostics")
                titleReserve: editingProfileButton.width

                SettingsCard {
                    SettingsSwitch {
                        id: enableMdns
                        text: qsTr("Find host PCs on my network automatically")
                        info: qsTr("Discovers PCs with mDNS. Turn off if you only add PCs by IP address.")
                        checked: StreamingPreferences.enableMdns
                        onCheckedChanged: {
                            // This is called on init, so only do the work if we've
                            // actually changed the value.
                            if (StreamingPreferences.enableMdns != checked) {
                                StreamingPreferences.enableMdns = checked

                                // Restart polling so the mDNS change takes effect
                                if (window.pollingActive) {
                                    ComputerManager.stopPollingAsync()
                                    ComputerManager.startPolling()
                                }
                            }
                        }
                    }

                    SettingsSwitch {
                        id: detectNetworkBlocking
                        text: qsTr("Check for blocked connections when a stream fails")
                        checked: StreamingPreferences.detectNetworkBlocking
                        onCheckedChanged: {
                            StreamingPreferences.detectNetworkBlocking = checked
                        }
                    }

                    SettingsSwitch {
                        id: postStreamSummaryCheck
                        text: qsTr("Show a latency summary when a stream ends")
                        info: qsTr("Average network latency, decode and render times, and dropped frames for the whole session.")
                        checked: StreamingPreferences.postStreamSummary
                        onCheckedChanged: {
                            StreamingPreferences.postStreamSummary = checked
                        }
                    }

                    SettingsSwitch {
                        id: showPerformanceOverlay
                        text: qsTr("Show performance stats over the stream")
                        shortcut: "Ctrl+Alt+Shift+S"
                        info: qsTr("Frame rate, latency and decode time. Toggle while streaming with Ctrl+Alt+Shift+S, or Select+L1+R1+X on a controller. Not available on Steam Link or Raspberry Pi.")
                        checked: StreamingPreferences.showPerformanceOverlay
                        onCheckedChanged: {
                            StreamingPreferences.showPerformanceOverlay = checked
                        }
                    }

                    SettingsSwitch {
                        id: liteStatsCheck
                        indented: true
                        text: qsTr("Compact stats")
                        info: qsTr("Just resolution, frame rate, bitrate, latency, decode and render time, and packet loss on two short lines.")
                        available: showPerformanceOverlay.checked
                        checked: StreamingPreferences.liteStats
                        onCheckedChanged: {
                            StreamingPreferences.liteStats = checked
                        }
                    }
                }
            }
        }

        // Which profile these settings are saved to. Sits on the page title's
        // line; clicking it opens Profiles.
        Button {
            id: editingProfileButton
            visible: settingsPage.currentSection !== "profiles"
            // Line the icon and text up with the cards' right edge
            x: settingsColumn.x + settingsColumn.width - width + rightPadding
            y: settingsColumn.topPadding + (44 - height) / 2
            flat: true
            // Just the profile's name when the page is too narrow for the title and the full label
            text: settingsColumn.width < 480 ? ProfileManager.activeName
                                             : qsTr("Editing profile: %1").arg(ProfileManager.activeName)
            icon.source: Theme.profileIcon(ProfileManager.activeKind)
            icon.width: 18
            icon.height: 18
            icon.color: Theme.textSecondary
            font.pointSize: Theme.fontDetail + 0.5
            onClicked: {
                searchField.text = ""
                settingsPage.showSection("profiles")
            }
            ToolTip.text: qsTr("Manage profiles")
            ToolTip.visible: hovered
            ToolTip.delay: 600
        }
    }

    WheelScroller {
        flickable: settingsFlick
    }
}
