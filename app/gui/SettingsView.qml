import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import QtQuick.Window 2.2

import StreamingPreferences 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0
import SystemProperties 1.0
import DisplayManager 1.0
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
    // sidebar. Pages are kept small enough to fit on screen without scrolling.
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
            name: QT_TR_NOOP("Monitor profiles")
            summary: QT_TR_NOOP("Streams on specific monitors")
            keywords: "display manager monitor monitors profile profiles screen multiple sessions streams hub second"
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
        width: 256
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

                        Label {
                            x: 24
                            width: parent.width - 40
                            topPadding: index === 0 ? 4 : 16
                            bottomPadding: 6
                            visible: settingsPage.firstVisibleInCategory(index)
                            text: qsTr(model.category).toUpperCase()
                            font.pointSize: Theme.fontOverline
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                            color: Theme.textTertiary
                            elide: Text.ElideRight
                        }

                        ItemDelegate {
                            id: navItem

                            readonly property bool selected: settingsPage.currentSection === model.key

                            width: parent.width
                            height: 38
                            padding: 0
                            hoverEnabled: true
                            focusPolicy: Qt.TabFocus

                            ToolTip.text: qsTr(model.summary)
                            ToolTip.visible: hovered
                            ToolTip.delay: 600

                            onClicked: settingsPage.showSection(model.key)
                            Keys.onReturnPressed: settingsPage.showSection(model.key)
                            Keys.onEnterPressed: settingsPage.showSection(model.key)
                            Keys.onUpPressed: settingsPage.stepSection(index, -1)
                            Keys.onDownPressed: settingsPage.stepSection(index, 1)

                            background: Rectangle {
                                color: navItem.selected ? Theme.navSelected : (navItem.hovered || navItem.visualFocus ? Theme.navHover : "transparent")

                                Behavior on color {
                                    ColorAnimation { duration: 90 }
                                }

                                Rectangle {
                                    x: 0
                                    width: 3
                                    radius: 1.5
                                    height: parent.height - 16
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
            x: 44
            width: Math.max(0, Math.min(settingsFlick.width - 88, 760))
            topPadding: 30
            bottomPadding: 48
            spacing: 0


            SettingsGroup {
                id: basicSettingsGroupBox
                section: "video"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Video quality")
                description: qsTr("How sharp and smooth the stream looks. Higher settings need a faster PC and network.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    Label {
                        width: parent.width
                        id: resFPStitle
                        text: qsTr("Resolution and frame rate")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        id: resFPSdesc
                        color: Theme.textSecondary
                        text: qsTr("Higher values look sharper and smoother, but can cause lag or stutter if your PC or network can't keep up.")
                        font.pointSize: Theme.fontDetail
                        wrapMode: Text.Wrap
                    }

                    Row {
                        spacing: 5
                        width: parent.width

                        AutoResizingComboBox {
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
                            maximumWidth: parent.width / 2
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

                        AutoResizingComboBox {
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
                            maximumWidth: parent.width / 2
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

                    Label {
                        width: parent.width
                        id: bitrateTitle
                        text: qsTr("Video bitrate")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        id: bitrateDesc
                        color: Theme.textSecondary
                        text: qsTr("How much data the stream uses each second. Lower it on slow Wi-Fi; raise it for a sharper picture.")
                        font.pointSize: Theme.fontDetail
                        wrapMode: Text.Wrap
                    }

                    Row {
                        width: parent.width
                        spacing: 5

                        Slider {
                            id: slider

                            value: StreamingPreferences.bitrateKbps

                            stepSize: 500
                            from : 500
                            to: StreamingPreferences.unlockBitrate ? 500000 : 150000

                            snapMode: "SnapOnRelease"
                            width: Math.max(120, Math.min(420, parent.width - bitrateField.width - bitrateUnit.width - 3 * parent.spacing - (resetBitrateButton.visible ? resetBitrateButton.width + parent.spacing : 0)))

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
                            width: 84
                            anchors.verticalCenter: slider.verticalCenter
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
                            anchors.verticalCenter: slider.verticalCenter
                            text: qsTr("Mbps")
                            font.pointSize: Theme.fontBody
                            color: Theme.textSecondary
                        }

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
                    }

                    // Norilight: next to the slider it affects. Typing a bitrate
                    // above 150 Mbps in the field turns this on as well.
                    SettingsCheck {
                        id: unlockBitrate
                        width: parent.width
                        text: qsTr("Allow very high bitrates (experimental)")
                        detail: qsTr("Raises the limit from 150 to 500 Mbps. Only for wired Ethernet with a Sunshine host.")

                        checked: StreamingPreferences.unlockBitrate
                        onCheckedChanged: {
                            StreamingPreferences.unlockBitrate = checked
                            StreamingPreferences.bitrateKbps = Math.min(StreamingPreferences.bitrateKbps, slider.to)
                            slider.value = StreamingPreferences.bitrateKbps
                        }
                    }

                    SettingsCheck {
                        id: enableHdr
                        width: parent.width
                        text: qsTr("Stream in HDR")
                        detail: enabled ?
                                    qsTr("Brighter highlights and richer colour. Needs an HDR display on this PC and a supported host. Some games also need an HDR monitor on the host.")
                                  :
                                    qsTr("HDR streaming is not supported on this PC.")

                        enabled: SystemProperties.supportsHdr
                        checked: enabled && StreamingPreferences.enableHdr
                        onCheckedChanged: {
                            StreamingPreferences.enableHdr = checked
                        }

                        // Updating StreamingPreferences.videoCodecConfig is handled above
                    }

                }
            }

            SettingsGroup {
                id: windowSettingsGroupBox
                section: "display"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Display")
                description: qsTr("How every stream is shown on this PC by default. Monitor profiles can override these for a specific monitor.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    Label {
                        width: parent.width
                        id: windowModeTitle
                        text: qsTr("Window mode")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                        visible: SystemProperties.hasDesktopEnvironment
                    }
                    Label {
                        width: parent.width
                        text: qsTr("Fullscreen gives the best performance. Borderless windowed fills the screen but switches apps instantly. Windowed lets you work beside the stream.")
                        font.pointSize: Theme.fontDetail
                        color: Theme.textSecondary
                        wrapMode: Text.Wrap
                        visible: SystemProperties.hasDesktopEnvironment
                    }


                    AutoResizingComboBox {
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

                    Column {
                        spacing: 5
                        width: parent.width

                        SettingsCheck {
                            id: vsyncCheck
                            width: parent.width
                            hoverEnabled: true
                            text: qsTr("V-Sync: sync frames to your display")
                            detail: qsTr("Removes screen tearing. Turn it off for slightly lower input lag.")
                            font.pointSize: Theme.fontLabel
                            checked: StreamingPreferences.enableVsync
                            onCheckedChanged: {
                                StreamingPreferences.enableVsync = checked
                            }
                        }

                        SettingsCheck {
                            id: framePacingCheck
                            width: parent.width
                            hoverEnabled: true
                            text: qsTr("Frame pacing: smooth out uneven frames")
                            detail: qsTr("Holds back frames that arrive early to reduce micro-stutter. Needs V-Sync.")
                            font.pointSize: Theme.fontLabel
                            enabled: StreamingPreferences.enableVsync
                            checked: StreamingPreferences.enableVsync && StreamingPreferences.framePacing
                            // Save only what the user clicks: when V-Sync turns
                            // off the box shows unchecked, but the saved choice
                            // is kept for when V-Sync comes back on. Streams
                            // ignore frame pacing without V-Sync.
                            onToggled: {
                                StreamingPreferences.framePacing = checked
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        topPadding: 10
                        text: qsTr("Picture fit")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("What happens when the stream's shape doesn't match the window or screen.")
                        font.pointSize: Theme.fontDetail
                        color: Theme.textSecondary
                        wrapMode: Text.Wrap
                    }

                    AutoResizingComboBox {
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

                    SettingsCheck {
                        id: alignVideoTopCheck
                        width: parent.width
                        text: qsTr("Pin the picture to the top of the window")
                        detail: qsTr("Black bars or cropping go at the bottom instead of being split between top and bottom. Not used with Stretch.")
                        font.pointSize: Theme.fontLabel
                        enabled: StreamingPreferences.videoScaleMode !== 2
                        checked: StreamingPreferences.alignVideoTop
                        onCheckedChanged: {
                            StreamingPreferences.alignVideoTop = checked
                        }
                    }

                }
            }

            SettingsGroup {
                id: monitorProfilesGroupBox
                section: "profiles"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Monitor profiles")
                description: qsTr("A profile opens a stream on one monitor with its own resolution, frame rate and window settings, even several at once. Start one with the monitor button on an app, or \"Stream on a Monitor\" in its menu. Each stream gets its own window, and Norilight's main window stays open to show and control them.")

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

                        height: 56
                        radius: 6
                        color: Theme.card
                        border.color: Theme.border

                        Column {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 28 - profileButtons.width
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
                            anchors.verticalCenter: parent.verticalCenter

                            Button {
                                flat: true
                                visible: !!profile.lastAppName
                                enabled: !!profile.connected
                                // Long app names would push the other buttons out
                                width: Math.min(implicitWidth, 200)
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
                                Label {
                                    text: qsTr("%1×%2, %3 Hz").arg(monitor.width).arg(monitor.height).arg(monitor.refreshRate)
                                    font.pointSize: Theme.fontSmall
                                    color: Theme.textSecondary
                                }
                                Button {
                                    flat: true
                                    text: qsTr("Add profile")
                                    onClicked: profileDialog.openNew(monitor.key)
                                }
                            }

                            Label {
                                width: parent.width
                                visible: monitorProfiles.length === 0
                                text: qsTr("No profiles for this monitor yet.")
                                font.pointSize: Theme.fontSmall
                                color: Theme.textSecondary
                            }

                            Repeater {
                                model: monitorProfiles
                                delegate: Loader {
                                    width: parent.width
                                    height: 56
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
                            height: 56
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

            SettingsGroup {
                id: windowBehaviourGroupBox
                section: "behaviour"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Window behaviour")
                description: qsTr("Where the stream window sits, and what it does while you stream.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    SettingsCheck {
                        id: alwaysOnTopCheck
                        width: parent.width
                        text: qsTr("Keep the stream window on top of other windows")
                        detail: qsTr("Handy for watching the host while you work in other apps. Has no effect in fullscreen.")
                        font.pointSize: Theme.fontLabel
                        visible: SystemProperties.hasDesktopEnvironment
                        checked: StreamingPreferences.streamAlwaysOnTop
                        onCheckedChanged: {
                            StreamingPreferences.streamAlwaysOnTop = checked
                        }
                    }

                    SettingsCheck {
                        id: rememberWindowCheck
                        width: parent.width
                        text: qsTr("Reopen the stream window where you left it")
                        detail: qsTr("Remembers the size and position of the windowed stream between sessions.")
                        font.pointSize: Theme.fontLabel
                        visible: SystemProperties.hasDesktopEnvironment
                        checked: StreamingPreferences.rememberWindowGeometry
                        onCheckedChanged: {
                            StreamingPreferences.rememberWindowGeometry = checked
                        }
                    }

                    SettingsCheck {
                        id: viewOnlyCheck
                        width: parent.width
                        text: qsTr("Watch only: don't send any input to the host")
                        detail: qsTr("Your mouse, keyboard, touch and controllers stay on this PC, so you can keep an eye on the host without touching it. Norilight's shortcuts like Ctrl+Alt+Shift+Q still work.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.viewOnly
                        onCheckedChanged: {
                            StreamingPreferences.viewOnly = checked
                        }
                    }

                    SettingsCheck {
                        id: keepAwakeCheck
                        width: parent.width
                        text: qsTr("Keep this PC's screen awake while streaming")
                        detail: qsTr("Blocks the screensaver and display sleep during a stream.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.keepAwake
                        onCheckedChanged: {
                            StreamingPreferences.keepAwake = checked
                        }
                    }

                }
            }

            SettingsGroup {
                id: audioSettingsGroupBox
                section: "audio"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Audio")
                description: qsTr("Where the host's sound plays and when it is muted.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    Label {
                        width: parent.width
                        id: resAudioTitle
                        text: qsTr("Speaker setup")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    AutoResizingComboBox {
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


                    SettingsCheck {
                        id: audioPcCheck
                        width: parent.width
                        text: qsTr("Mute the host PC's speakers while streaming")
                        detail: qsTr("Sound only plays here, not on the host. Restart a running game for this to apply.")
                        font.pointSize: Theme.fontLabel
                        checked: !StreamingPreferences.playAudioOnHost
                        onCheckedChanged: {
                            StreamingPreferences.playAudioOnHost = !checked
                        }
                    }

                    SettingsCheck {
                        id: muteOnFocusLossCheck
                        width: parent.width
                        text: qsTr("Mute the stream when Norilight isn't the active window")
                        detail: qsTr("Silences the stream when you Alt+Tab away or click another window.")
                        font.pointSize: Theme.fontLabel
                        visible: SystemProperties.hasDesktopEnvironment
                        checked: StreamingPreferences.muteOnFocusLoss
                        onCheckedChanged: {
                            StreamingPreferences.muteOnFocusLoss = checked
                        }
                    }
                }
            }

            SettingsGroup {
                id: hostSettingsGroupBox
                section: "host"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Host PC")
                description: qsTr("What Norilight asks the PC you stream from to do.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    SettingsCheck {
                        id: optimizeGameSettingsCheck
                        width: parent.width
                        text: qsTr("Let the host adjust game settings for the stream")
                        detail: qsTr("GeForce Experience changes each game's graphics settings to suit the stream resolution.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.gameOptimizations
                        onCheckedChanged: {
                            StreamingPreferences.gameOptimizations = checked
                        }
                    }

                    SettingsCheck {
                        id: quitAppAfter
                        width: parent.width
                        text: qsTr("Close the game on the host when you end the stream")
                        detail: qsTr("The game or app is closed for you. Unsaved progress is lost.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.quitAppAfter
                        onCheckedChanged: {
                            StreamingPreferences.quitAppAfter = checked
                        }
                    }
                }
            }

            SettingsGroup {
                id: apolloSettingsGroupBox
                section: "host"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Apollo hosts")
                description: qsTr("Extras for hosts running Apollo, a fork of Sunshine. Other hosts ignore these settings.")
                subheading: true
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    SettingsCheck {
                        id: virtualDisplayCheck
                        width: parent.width
                        text: qsTr("Stream from a virtual display")
                        detail: qsTr("The host creates a screen that matches this PC's resolution and frame rate for the stream, instead of using its real monitor. Needs the SudoVDA driver on the host.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.useVirtualDisplay
                        onCheckedChanged: {
                            StreamingPreferences.useVirtualDisplay = checked
                        }
                    }

                    Label {
                        width: parent.width - 36
                        x: 36
                        topPadding: 6
                        text: qsTr("Virtual display scale: %1%").arg(Math.round(virtualDisplayScaleSlider.value))
                        font.pointSize: Theme.fontBody
                        color: virtualDisplayCheck.checked ? Theme.textPrimary : Theme.textDisabled
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width - 36
                        x: 36
                        text: qsTr("Makes the host's virtual screen bigger or smaller than the stream. At 150%, a 1920x1080 stream is drawn on a 2880x1620 screen, so text gets smaller and sharper.")
                        font.pointSize: Theme.fontDetail
                        color: virtualDisplayCheck.checked ? Theme.textSecondary : Theme.textDisabledSecondary
                        wrapMode: Text.Wrap
                    }

                    Row {
                        x: 36
                        spacing: 8

                        Slider {
                            id: virtualDisplayScaleSlider
                            width: Math.min(360, apolloSettingsGroupBox.width - 200)
                            enabled: virtualDisplayCheck.checked
                            from: 20
                            to: 200
                            stepSize: 5
                            snapMode: Slider.SnapOnRelease
                            value: StreamingPreferences.virtualDisplayScale
                            onMoved: StreamingPreferences.virtualDisplayScale = Math.round(value)
                        }

                        Button {
                            text: qsTr("Reset to 100%")
                            flat: true
                            visible: Math.round(virtualDisplayScaleSlider.value) !== 100
                            onClicked: {
                                StreamingPreferences.virtualDisplayScale = 100
                                virtualDisplayScaleSlider.value = 100
                            }
                        }
                    }

                    SettingsCheck {
                        id: clipboardSyncCheck
                        width: parent.width
                        text: qsTr("Sync the clipboard with the host")
                        detail: qsTr("Text you copy here is sent to the host when the stream starts or you switch back to it. The host's clipboard comes back when you switch away or end the stream.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.clipboardSync
                        onCheckedChanged: {
                            StreamingPreferences.clipboardSync = checked
                        }
                    }

                    SettingsCheck {
                        id: clipboardNotifyCheck
                        width: parent.width - 36
                        x: 36
                        text: qsTr("Show a notice each time it syncs")
                        detail: qsTr("A short message on the stream says whether text was sent or received.")
                        font.pointSize: Theme.fontLabel
                        enabled: clipboardSyncCheck.checked
                        checked: StreamingPreferences.clipboardSyncNotify
                        onCheckedChanged: {
                            StreamingPreferences.clipboardSyncNotify = checked
                        }
                    }

                    SettingsCheck {
                        id: hideClipboardCheck
                        width: parent.width - 36
                        x: 36
                        text: qsTr("Keep text from the host out of clipboard history")
                        detail: qsTr("Windows won't save it in Win+V history or sync it to your other devices.")
                        font.pointSize: Theme.fontLabel
                        enabled: clipboardSyncCheck.checked
                        checked: StreamingPreferences.hideSyncedClipboard
                        onCheckedChanged: {
                            StreamingPreferences.hideSyncedClipboard = checked
                        }
                    }

                    Label {
                        width: parent.width
                        topPadding: 14
                        text: qsTr("Host commands")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("During a stream, press Ctrl+Alt+Shift+R to list the commands set up on your Apollo host, then press a number to run one. Esc closes the list.")
                        font.pointSize: Theme.fontDetail
                        color: Theme.textSecondary
                        wrapMode: Text.Wrap
                    }
                }
            }

            SettingsGroup {
                id: uiSettingsGroupBox
                section: "app"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("App")
                description: qsTr("Norilight's own window, language and notices.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    Label {
                        width: parent.width
                        id: languageTitle
                        text: qsTr("Language")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    AutoResizingComboBox {
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

                    Label {
                        width: parent.width
                        id: uiDisplayModeTitle
                        text: qsTr("How Norilight's main window opens")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                        visible: SystemProperties.hasDesktopEnvironment
                    }

                    AutoResizingComboBox {
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

                    SettingsCheck {
                        id: connectionWarningsCheck
                        width: parent.width
                        text: qsTr("Warn me when the connection is struggling")
                        detail: qsTr("Shows a notice over the stream when the network can't keep up.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.connectionWarnings
                        onCheckedChanged: {
                            StreamingPreferences.connectionWarnings = checked
                        }
                    }

                    SettingsCheck {
                        id: configurationWarningsCheck
                        width: parent.width
                        text: qsTr("Warn me about risky settings before a stream starts")
                        detail: qsTr("For example, options your host or this PC may not support.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.configurationWarnings
                        onCheckedChanged: {
                            StreamingPreferences.configurationWarnings = checked
                        }
                    }

                    SettingsCheck {
                        visible: SystemProperties.hasDiscordIntegration
                        id: discordPresenceCheck
                        width: parent.width
                        text: qsTr("Show what I'm streaming in my Discord status")
                        detail: qsTr("Your Discord profile shows the name of the game you're streaming.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.richPresence
                        onCheckedChanged: {
                            StreamingPreferences.richPresence = checked
                        }
                    }

                }
            }


            SettingsGroup {
                id: inputSettingsGroupBox
                section: "input"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Mouse")
                description: qsTr("How your mouse, cursor and scroll wheel control the host.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    SettingsCheck {
                        id: absoluteMouseCheck
                        hoverEnabled: true
                        width: parent.width
                        text: qsTr("Remote desktop mouse: the host cursor goes where you point")
                        detail: StreamingPreferences.freeCursorMode ?
                                    qsTr("Already on: free cursor below includes it.") :
                                    qsTr("Best for desktop work. Most games need this off. Toggle while streaming with Ctrl+Alt+Shift+M.")
                        enabled: !StreamingPreferences.freeCursorMode
                        font.pointSize: Theme.fontLabel
                        // Free cursor includes this mode, so show it as on then.
                        // Only a click saves it, so turning free cursor off
                        // goes back to the user's own choice.
                        checked: StreamingPreferences.absoluteMouseMode || StreamingPreferences.freeCursorMode
                        onToggled: {
                            StreamingPreferences.absoluteMouseMode = checked
                        }
                    }

                    SettingsCheck {
                        id: freeCursorCheck
                        hoverEnabled: true
                        width: parent.width
                        text: qsTr("Free cursor: let the mouse leave the stream window")
                        detail: qsTr("The cursor is never locked inside the stream, even in fullscreen, so you can move or drag onto other windows and monitors. Turns on remote desktop mouse.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.freeCursorMode
                        onCheckedChanged: {
                            StreamingPreferences.freeCursorMode = checked
                        }
                    }

                    SettingsCheck {
                        id: showLocalCursorCheck
                        width: parent.width
                        text: qsTr("Show this PC's cursor over the stream")
                        detail: qsTr("Draws your own cursor on top of the host's so it never lags behind. Needs remote desktop mouse. Toggle while streaming with Ctrl+Alt+Shift+C.")
                        font.pointSize: Theme.fontLabel
                        enabled: StreamingPreferences.absoluteMouseMode || StreamingPreferences.freeCursorMode
                        checked: StreamingPreferences.showLocalCursor
                        onCheckedChanged: {
                            StreamingPreferences.showLocalCursor = checked
                        }
                    }

                    SettingsCheck {
                        id: swapMouseButtonsCheck
                        hoverEnabled: true
                        width: parent.width
                        text: qsTr("Swap left and right mouse buttons")
                        detail: qsTr("For left-handed mouse setups.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.swapMouseButtons
                        onCheckedChanged: {
                            StreamingPreferences.swapMouseButtons = checked
                        }
                    }

                    Label {
                        width: parent.width
                        topPadding: 12
                        text: qsTr("Mouse speed in game mode: %1%").arg(Math.round(mouseSensitivitySlider.value))
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Scales mouse movement while the cursor is captured for a game. 100% matches your mouse exactly.")
                        font.pointSize: Theme.fontDetail
                        color: Theme.textSecondary
                        wrapMode: Text.Wrap
                    }

                    Row {
                        spacing: 8

                        Slider {
                            id: mouseSensitivitySlider
                            width: Math.min(360, parent.parent.width - 160)
                            from: 10
                            to: 400
                            stepSize: 5
                            snapMode: Slider.SnapOnRelease
                            value: StreamingPreferences.mouseSensitivity
                            onMoved: StreamingPreferences.mouseSensitivity = Math.round(value)
                        }

                        Button {
                            text: qsTr("Reset to 100%")
                            flat: true
                            visible: Math.round(mouseSensitivitySlider.value) !== 100
                            onClicked: {
                                StreamingPreferences.mouseSensitivity = 100
                                mouseSensitivitySlider.value = 100
                            }
                        }
                    }

                    SettingsCheck {
                        id: reverseScrollButtonsCheck
                        hoverEnabled: true
                        width: parent.width
                        text: qsTr("Reverse scroll direction")
                        detail: qsTr("Scrolling down moves the page up, like natural scrolling on a touchpad.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.reverseScrollDirection
                        onCheckedChanged: {
                            StreamingPreferences.reverseScrollDirection = checked
                        }
                    }

                    Label {
                        width: parent.width
                        topPadding: 12
                        text: qsTr("Scroll speed: %1%").arg(Math.round(scrollSpeedSlider.value))
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("How far each scroll wheel step moves on the host.")
                        font.pointSize: Theme.fontDetail
                        color: Theme.textSecondary
                        wrapMode: Text.Wrap
                    }

                    Row {
                        spacing: 8

                        Slider {
                            id: scrollSpeedSlider
                            width: Math.min(360, parent.parent.width - 160)
                            from: 10
                            to: 400
                            stepSize: 5
                            snapMode: Slider.SnapOnRelease
                            value: StreamingPreferences.scrollSpeed
                            onMoved: StreamingPreferences.scrollSpeed = Math.round(value)
                        }

                        Button {
                            text: qsTr("Reset to 100%")
                            flat: true
                            visible: Math.round(scrollSpeedSlider.value) !== 100
                            onClicked: {
                                StreamingPreferences.scrollSpeed = 100
                                scrollSpeedSlider.value = 100
                            }
                        }
                    }

                }
            }

            SettingsGroup {
                id: keyboardSettingsGroupBox
                section: "keyboard"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Keyboard & touch")
                description: qsTr("System keys, screenshots and touchscreens.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    Column {
                        spacing: 5
                        width: parent.width

                        SettingsCheck {
                            id: captureSysKeysCheck
                            width: parent.width
                            hoverEnabled: true
                            text: qsTr("Send shortcuts like Alt+Tab and the Windows key to the host")
                            detail: qsTr("When off, this PC handles them. Ctrl+Alt+Del always stays on this PC.")
                            font.pointSize: Theme.fontLabel
                            enabled: SystemProperties.hasDesktopEnvironment
                            checked: StreamingPreferences.captureSysKeysMode !== StreamingPreferences.CSK_OFF || !SystemProperties.hasDesktopEnvironment
                        }

                        AutoResizingComboBox {
                            x: 36
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

                    SettingsCheck {
                        id: screenshotsOnClientCheck
                        hoverEnabled: true
                        width: parent.width
                        text: qsTr("Take screenshots on this PC only")
                        detail: qsTr("PrtScn and Win+Shift+S take a screenshot here and aren't sent to the host, so you don't get one on both PCs.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.screenshotsOnClient
                        onCheckedChanged: {
                            StreamingPreferences.screenshotsOnClient = checked
                        }
                    }

                    SettingsCheck {
                        id: forwardUnicodeInputCheck
                        hoverEnabled: true
                        width: parent.width
                        visible: Qt.platform.os === "windows"
                        text: qsTr("Work with PowerToys Quick Accent")
                        detail: qsTr("Sends characters that Quick Accent types on this PC to the host, including the Space it holds back while a letter is down. Without this, Space doesn't work until you stop typing, and picked accents are lost.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.forwardUnicodeInput
                        onCheckedChanged: {
                            StreamingPreferences.forwardUnicodeInput = checked
                        }
                    }

                    SettingsCheck {
                        id: absoluteTouchCheck
                        hoverEnabled: true
                        width: parent.width
                        text: qsTr("Touchscreen works like a trackpad")
                        detail: qsTr("Drag to move the cursor and tap to click. When off, the cursor jumps to wherever you touch.")
                        font.pointSize: Theme.fontLabel
                        checked: !StreamingPreferences.absoluteTouchMode
                        onCheckedChanged: {
                            StreamingPreferences.absoluteTouchMode = !checked
                        }
                    }

                }
            }

            SettingsGroup {
                id: gamepadSettingsGroupBox
                section: "gamepad"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Controllers")
                description: qsTr("Gamepads connected to this PC.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    SettingsCheck {
                        id: swapFaceButtonsCheck
                        width: parent.width
                        text: qsTr("Nintendo-style layout: swap A/B and X/Y")
                        detail: qsTr("Matches the button positions on Nintendo controllers.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.swapFaceButtons
                        onCheckedChanged: {
                            StreamingPreferences.swapFaceButtons = checked
                        }
                    }

                    SettingsCheck {
                        id: singleControllerCheck
                        width: parent.width
                        text: qsTr("Always report one controller to the host")
                        detail: qsTr("For games that only detect controllers connected before they start, even if none is plugged in here.")
                        font.pointSize: Theme.fontLabel
                        checked: !StreamingPreferences.multiController
                        onCheckedChanged: {
                            StreamingPreferences.multiController = !checked
                        }
                    }

                    SettingsCheck {
                        id: gamepadMouseCheck
                        hoverEnabled: true
                        width: parent.width
                        text: qsTr("Hold Start to use a controller as a mouse")
                        detail: qsTr("Long-press Start to switch: the stick moves the cursor, A clicks, B right-clicks. Long-press again to switch back.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.gamepadMouse
                        onCheckedChanged: {
                            StreamingPreferences.gamepadMouse = checked
                        }
                    }

                    Label {
                        width: parent.width - 36
                        x: 36
                        text: qsTr("While a controller is a mouse, scroll with")
                        font.pointSize: Theme.fontBody
                        color: gamepadMouseCheck.checked ? Theme.textPrimary : Theme.textDisabled
                        wrapMode: Text.Wrap
                    }

                    AutoResizingComboBox {
                        id: analogScrollComboBox
                        x: 36
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

                    SettingsCheck {
                        id: backgroundGamepadCheck
                        width: parent.width
                        text: qsTr("Keep controllers working when Norilight is in the background")
                        detail: qsTr("Controller input still reaches the host while another window is active.")
                        font.pointSize: Theme.fontLabel
                        visible: SystemProperties.hasDesktopEnvironment
                        checked: StreamingPreferences.backgroundGamepad
                        onCheckedChanged: {
                            StreamingPreferences.backgroundGamepad = checked
                        }
                    }

                    SettingsCheck {
                        id: gamepadMotionCheck
                        width: parent.width
                        text: qsTr("Let games use controller motion sensors")
                        detail: qsTr("Passes gyro and accelerometer data to the host for motion aiming. Turn off if motion causes drift or stutter.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.gamepadMotionSensors
                        onCheckedChanged: {
                            StreamingPreferences.gamepadMotionSensors = checked
                        }
                    }

                    SettingsCheck {
                        id: gamepadTouchpadMouseCheck
                        width: parent.width
                        text: qsTr("Controller touchpad moves the mouse")
                        detail: qsTr("On PlayStation-style controllers, slide on the touchpad to move the host cursor and press it to click, instead of passing the touchpad to games.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.gamepadTouchpadAsMouse
                        onCheckedChanged: {
                            StreamingPreferences.gamepadTouchpadAsMouse = checked
                        }
                    }

                    Label {
                        width: parent.width
                        topPadding: 12
                        text: qsTr("Stick deadzone: %1%").arg(Math.round(deadzoneSlider.value))
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("How far a stick must move before it counts. Raise it if a worn stick drifts on its own; 0% passes the stick through untouched.")
                        font.pointSize: Theme.fontDetail
                        color: Theme.textSecondary
                        wrapMode: Text.Wrap
                    }

                    Row {
                        spacing: 8

                        Slider {
                            id: deadzoneSlider
                            width: Math.min(360, parent.parent.width - 160)
                            from: 0
                            to: 30
                            stepSize: 1
                            snapMode: Slider.SnapOnRelease
                            value: StreamingPreferences.stickDeadzone
                            onMoved: StreamingPreferences.stickDeadzone = Math.round(value)
                        }

                        Button {
                            text: qsTr("Reset to 0%")
                            flat: true
                            visible: Math.round(deadzoneSlider.value) !== 0
                            onClicked: {
                                StreamingPreferences.stickDeadzone = 0
                                deadzoneSlider.value = 0
                            }
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
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Shortcuts")
                description: qsTr("Key combinations you can use while a stream window is active.")

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

                Component {
                    id: shortcutRowComponent

                    RowLayout {
                        property var entry: ({})

                        spacing: 16

                        // The key combination, drawn as a key cap
                        Label {
                            Layout.preferredWidth: 190
                            Layout.alignment: Qt.AlignTop
                            text: entry.keys || ""
                            font.pointSize: Theme.fontDetail
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 3
                            bottomPadding: 3
                            elide: Text.ElideRight
                            background: Rectangle {
                                // Hug the text rather than the whole column
                                width: Math.min(parent.implicitWidth, parent.width)
                                radius: 4
                                color: Theme.card
                                border.color: Theme.border
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: entry.action || ""
                            font.pointSize: Theme.fontDetail + 0.5
                            color: Theme.textPrimary
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: 8

                    Label {
                        width: parent.width
                        text: qsTr("Keyboard")
                        font.pointSize: Theme.fontLabel
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: shortcutsGroupBox.keyboardShortcuts
                        delegate: Loader {
                            width: parent.width
                            // Some shortcuts only exist with a desktop environment
                            active: !modelData.desktop || SystemProperties.hasDesktopEnvironment
                            visible: active
                            sourceComponent: shortcutRowComponent
                            onLoaded: {
                                item.width = Qt.binding(function() { return width })
                                item.entry = modelData
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        topPadding: 14
                        text: qsTr("Controller")
                        font.pointSize: Theme.fontLabel
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: shortcutsGroupBox.controllerShortcuts
                        delegate: Loader {
                            width: parent.width
                            sourceComponent: shortcutRowComponent
                            onLoaded: {
                                item.width = Qt.binding(function() { return width })
                                item.entry = modelData
                            }
                        }
                    }
                }
            }

            SettingsGroup {
                id: advancedSettingsGroupBox
                section: "advanced"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Video decoding")
                description: qsTr("How the stream is compressed and decoded. The automatic choices suit almost everyone.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    Label {
                        width: parent.width
                        id: resVDSTitle
                        text: qsTr("Decode video using")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    AutoResizingComboBox {
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

                    Label {
                        width: parent.width
                        id: resVCCTitle
                        text: qsTr("Compression format (codec)")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                    }

                    AutoResizingComboBox {
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

                    Label {
                        width: parent.width
                        id: rendererTitle
                        text: qsTr("Renderer")
                        font.pointSize: Theme.fontLabel
                        wrapMode: Text.Wrap
                        visible: SystemProperties.isDarwin
                    }

                    AutoResizingComboBox {
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

                    SettingsCheck {
                        id: enableYUV444
                        width: parent.width
                        text: qsTr("Full colour detail (YUV 4:4:4)")
                        detail: qsTr("Crisper coloured text and thin lines, great for desktop work. Uses more bandwidth; not for fast games.")
                        font.pointSize: Theme.fontLabel

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

                    SettingsCheck {
                        id: forceFullRangeCheck
                        width: parent.width
                        text: qsTr("Full-range colour (experimental)")
                        detail: qsTr("Asks the host for the full 0-255 brightness range instead of the TV range. Can crush shadows and highlights if your display or decoder doesn't expect it.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.forceFullRange
                        onCheckedChanged: {
                            StreamingPreferences.forceFullRange = checked
                        }
                    }

                }
            }

            SettingsGroup {
                id: networkSettingsGroupBox
                section: "network"
                visible: settingsPage.currentSection === section
                width: (parent.width - (parent.leftPadding + parent.rightPadding))
                title: qsTr("Network & diagnostics")
                description: qsTr("Finding hosts, troubleshooting connections, and stream statistics.")
                font.pointSize: Theme.fontLabel

                Column {
                    anchors.fill: parent
                    spacing: 5

                    SettingsCheck {
                        id: enableMdns
                        width: parent.width
                        text: qsTr("Find host PCs on my network automatically")
                        detail: qsTr("Discovers PCs with mDNS. Turn off if you only add PCs by IP address.")
                        font.pointSize: Theme.fontLabel
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

                    SettingsCheck {
                        id: detectNetworkBlocking
                        width: parent.width
                        text: qsTr("Check for blocked connections when a stream fails")
                        detail: qsTr("Tests whether a firewall or router is blocking the stream and tells you.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.detectNetworkBlocking
                        onCheckedChanged: {
                            StreamingPreferences.detectNetworkBlocking = checked
                        }
                    }

                    SettingsCheck {
                        id: postStreamSummaryCheck
                        width: parent.width
                        text: qsTr("Show a latency summary when a stream ends")
                        detail: qsTr("Average network latency, decode and render times, and dropped frames for the whole session.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.postStreamSummary
                        onCheckedChanged: {
                            StreamingPreferences.postStreamSummary = checked
                        }
                    }

                    SettingsCheck {
                        id: showPerformanceOverlay
                        width: parent.width
                        text: qsTr("Show performance stats over the stream")
                        detail: qsTr("Frame rate, latency and decode time. Toggle while streaming with Ctrl+Alt+Shift+S, or Select+L1+R1+X on a controller. Not available on Steam Link or Raspberry Pi.")
                        font.pointSize: Theme.fontLabel
                        checked: StreamingPreferences.showPerformanceOverlay
                        onCheckedChanged: {
                            StreamingPreferences.showPerformanceOverlay = checked
                        }
                    }

                    SettingsCheck {
                        id: liteStatsCheck
                        width: parent.width - 36
                        x: 36
                        text: qsTr("Compact stats")
                        detail: qsTr("Just resolution, frame rate, bitrate, latency, decode and render time, and packet loss on two short lines.")
                        font.pointSize: Theme.fontLabel
                        enabled: showPerformanceOverlay.checked
                        checked: StreamingPreferences.liteStats
                        onCheckedChanged: {
                            StreamingPreferences.liteStats = checked
                        }
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
        text: qsTr("Delete the monitor profile \"%1\"?").arg(profileName)
        acceptText: qsTr("Delete")
        rejectText: qsTr("Cancel")
        onAccepted: DisplayManager.removeProfile(profileId)
    }
}
