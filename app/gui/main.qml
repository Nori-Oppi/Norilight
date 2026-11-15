import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Window 2.2
import QtQuick.Controls.Material 2.2

import ComputerManager 1.0
import AutoUpdateChecker 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0
import DisplayManager 1.0
import ProfileManager 1.0
import "."

ApplicationWindow {
    property bool pollingActive: false

    // Set by SettingsView to force the back operation to pop all
    // pages except the initial view. This is required when doing
    // a retranslate() because AppView breaks for some reason.
    property bool clearOnBack: false

    id: window
    width: 1280
    height: 680

    // Below this the settings sidebar leaves no room for the page beside it
    minimumWidth: 640
    minimumHeight: 420

    // Norilight: streams started from the display manager run in their own
    // processes and end when the hub closes, so check with the user first.
    property bool confirmedHubClose: false
    onClosing: {
        if (!confirmedHubClose && DisplayManager.runningCount > 0) {
            close.accepted = false
            hubCloseDialog.open()
        }
    }

    // This function runs prior to creation of the initial StackView item
    function doEarlyInit() {
        // Override the background color on every Qt version. This keeps the
        // contrast between GFE's placeholder box art and the app grid that
        // the Material 2 colors gave, and matches the greys used by the
        // settings page, dialogs and hub bar.
        Material.background = Theme.background

        SdlGamepadKeyNavigation.enable()
    }

    Component.onCompleted: {
        // Show the window according to the user's preferences
        if (SystemProperties.hasDesktopEnvironment) {
            if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_MAXIMIZED) {
                window.showMaximized()
            }
            else if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_FULLSCREEN) {
                window.showFullScreen()
            }
            else {
                window.show()
            }
        } else {
            window.showFullScreen()
        }

        // Display any modal dialogs for configuration warnings
        if (isGuiLaunch) {
            if (SystemProperties.isWow64) {
                wow64Dialog.open()
            }

            // Hardware acceleration and unmapped gamepads are checked asynchronously
            SystemProperties.hasHardwareAccelerationChanged.connect(hasHardwareAccelerationChanged)
            SystemProperties.unmappedGamepadsChanged.connect(hasUnmappedGamepadsChanged)
            SystemProperties.startAsyncLoad()
        }
    }

    function hasHardwareAccelerationChanged() {
        if (!SystemProperties.hasHardwareAcceleration && StreamingPreferences.videoDecoderSelection !== StreamingPreferences.VDS_FORCE_SOFTWARE) {
            if (SystemProperties.isRunningXWayland) {
                xWaylandDialog.open()
            }
            else {
                noHwDecoderDialog.open()
            }
        }
    }

    function hasUnmappedGamepadsChanged() {
        if (SystemProperties.unmappedGamepads) {
            unmappedGamepadDialog.unmappedGamepads = SystemProperties.unmappedGamepads
            unmappedGamepadDialog.open()
        }
    }

    // It would be better to use TextMetrics here, but it always lays out
    // the text slightly more compactly than real Text does in ToolTip,
    // causing unexpected line breaks to be inserted
    Text {
        id: tooltipTextLayoutHelper
        visible: false
        font: ToolTip.toolTip.font
        text: ToolTip.toolTip.text
    }

    // This configures the maximum width of the singleton attached QML ToolTip. If left unconstrained,
    // it will never insert a line break and just extend on forever.
    ToolTip.toolTip.contentWidth: Math.min(tooltipTextLayoutHelper.width, 400)

    function goBack() {
        if (clearOnBack) {
            // Pop all items except the first one
            stackView.pop(null)
            clearOnBack = false
        }
        else {
            stackView.pop()
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        focus: true

        Component.onCompleted: {
            // Perform our early initialization before constructing
            // the initial view and pushing it to the StackView
            doEarlyInit()

            // Norilight: settings live in profiles, so a normal launch starts
            // with the wizard until the first profile exists
            push(isGuiLaunch && ProfileManager.setupNeeded ? "qrc:/gui/ProfileWizard.qml" : initialView)
        }

        onCurrentItemChanged: {
            // Ensure focus travels to the next view when going back
            if (currentItem) {
                currentItem.forceActiveFocus()
            }
        }

        Keys.onEscapePressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onBackPressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onMenuPressed: {
            settingsButton.clicked()
        }

        // This is a keypress we've reserved for letting the
        // SdlGamepadKeyNavigation object tell us to show settings
        // when Menu is consumed by a focused control.
        Keys.onHangupPressed: {
            settingsButton.clicked()
        }
    }

    // This timer keeps us polling for 5 minutes of inactivity
    // to allow the user to work with Moonlight on a second display
    // while dealing with configuration issues. This will ensure
    // machines come online even if the input focus isn't on Moonlight.
    Timer {
        id: inactivityTimer
        interval: 5 * 60000
        onTriggered: {
            if (!active && pollingActive) {
                ComputerManager.stopPollingAsync()
                pollingActive = false
            }
        }
    }

    onVisibleChanged: {
        // Polling is only managed from the window for a normal GUI launch;
        // CLI commands (stream/quit/pair) manage it via the ComputerSeeker.
        if (isGuiLaunch) {
            // When we become invisible while streaming is going on,
            // stop polling immediately.
            if (!visible) {
                inactivityTimer.stop()

                if (pollingActive) {
                    ComputerManager.stopPollingAsync()
                    pollingActive = false
                }
            }
            else if (active) {
                // When we become visible and active again, start polling
                inactivityTimer.stop()

                // Restart polling if it was stopped
                if (!pollingActive) {
                    ComputerManager.startPolling()
                    pollingActive = true
                }
            }
        }

        // Poll for gamepad input only when the window is in focus
        SdlGamepadKeyNavigation.notifyWindowFocus(visible && active)
    }

    onActiveChanged: {
        // Polling is only managed from the window for a normal GUI launch;
        // CLI commands (stream/quit/pair) manage it via the ComputerSeeker.
        if (isGuiLaunch) {
            if (active) {
                // Stop the inactivity timer
                inactivityTimer.stop()

                // Restart polling if it was stopped
                if (!pollingActive) {
                    ComputerManager.startPolling()
                    pollingActive = true
                }
            }
            else {
                // Start the inactivity timer to stop polling
                // if focus does not return within a few minutes.
                inactivityTimer.restart()
            }
        }

        // Poll for gamepad input only when the window is in focus
        SdlGamepadKeyNavigation.notifyWindowFocus(visible && active)
    }

    // Norilight: the settings page reads its values when it is built, so
    // show a fresh one after switching to another profile
    function reloadSettingsPage() {
        var page = stackView.currentItem
        if (page instanceof SettingsView) {
            stackView.replace(page, "qrc:/gui/SettingsView.qml",
                              { "currentSection": page.currentSection },
                              StackView.Immediate)
        }
    }

    Connections {
        target: ProfileManager
        onActiveProfileChanged: Qt.callLater(reloadSettingsPage)
    }

    function navigateTo(url, objectType)
    {
        var existingItem = stackView.find(function(item, index) {
            return item instanceof objectType
        })

        if (existingItem !== null) {
            // Pop to the existing item
            stackView.pop(existingItem)
        }
        else {
            // Create a new item
            stackView.push(url)
        }
    }

    header: ToolBar {
        id: toolBar
        height: 60
        anchors.topMargin: 5
        anchors.bottomMargin: 5

        background: Rectangle {
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.blushStart }
                GradientStop { position: 0.5; color: Theme.blushMiddle }
                GradientStop { position: 1; color: Theme.blushEnd }
            }
        }

        Label {
            id: titleLabel
            visible: toolBar.width > 700
            anchors.fill: parent
            text: stackView.currentItem.objectName
            font.pointSize: 20
            elide: Label.ElideRight
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
        }

        RowLayout {
            spacing: 10
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.fill: parent

            NavigableToolButton {
                // Only make the button visible if the user has navigated somewhere.
                visible: stackView.depth > 1

                iconSource: "qrc:/res/arrow_left.svg"

                onClicked: goBack()

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            // Norilight: the app's mark on the home screen, where there's no
            // back button to take this spot
            Row {
                visible: stackView.depth === 1
                spacing: 10
                Layout.leftMargin: 6

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "qrc:/res/norilight.svg"
                    sourceSize.width: 32
                    sourceSize.height: 32
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: titleLabel.visible
                    text: "Norilight"
                    font.pointSize: 14
                    font.weight: Font.DemiBold
                }
            }

            // This label will appear when the window gets too small and
            // we need to ensure the toolbar controls don't collide
            Label {
                id: titleRowLabel
                font.pointSize: titleLabel.font.pointSize
                elide: Label.ElideRight
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
                Layout.fillWidth: true

                // We need this label to always be visible so it can occupy
                // the remaining space in the RowLayout. To "hide" it, we
                // just set the text to empty string.
                text: !titleLabel.visible ? stackView.currentItem.objectName : ""
            }

            Label {
                id: versionLabel
                visible: stackView.currentItem instanceof SettingsView
                text: qsTr("Version %1").arg(SystemProperties.versionString)
                font.pointSize: 12
                horizontalAlignment: Qt.AlignRight
                verticalAlignment: Qt.AlignVCenter
            }

            // Norilight: the active profile, and a quick way to switch
            ProfileSwitcher {
                visible: isGuiLaunch && !ProfileManager.setupNeeded &&
                         (stackView.currentItem instanceof PcView || stackView.currentItem instanceof AppView)
                onToolbar: true
                showName: toolBar.width > 560
                Layout.alignment: Qt.AlignVCenter

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                id: addPcButton
                visible: stackView.currentItem instanceof PcView

                iconSource:  "qrc:/res/ic_add_to_queue_white_48px.svg"

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Add PC manually") + (newPcShortcut.nativeText ? (" ("+newPcShortcut.nativeText+")") : "")

                Shortcut {
                    id: newPcShortcut
                    sequence: StandardKey.New
                    onActivated: addPcButton.clicked()
                }

                onClicked: {
                    addPcDialog.open()
                }

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                property string browserUrl: ""

                id: updateButton

                iconSource: "qrc:/res/update.svg"

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered || visible

                // Invisible until we get a callback notifying us that
                // an update is available
                visible: false

                onClicked: {
                    if (SystemProperties.hasBrowser) {
                        Qt.openUrlExternally(browserUrl);
                    }
                }

                function updateAvailable(version, url)
                {
                    ToolTip.text = qsTr("A newer Norilight nightly is available (%1). Click to download it.").arg(version)
                    updateButton.browserUrl = url
                    updateButton.visible = true
                }

                // Norilight: the checker compares this build's commit with the
                // latest nightly on GitHub and links straight to its download.
                Component.onCompleted: {
                    AutoUpdateChecker.onUpdateAvailable.connect(updateAvailable)
                    AutoUpdateChecker.start()
                }

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                id: helpButton
                visible: SystemProperties.hasBrowser

                iconSource: "qrc:/res/question_mark.svg"

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Help") + (helpShortcut.nativeText ? (" ("+helpShortcut.nativeText+")") : "")

                Shortcut {
                    id: helpShortcut
                    sequence: StandardKey.HelpContents
                    onActivated: helpButton.clicked()
                }

                // TODO need to make sure browser is brought to foreground.
                onClicked: Qt.openUrlExternally("https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide");

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                // TODO: Implement gamepad mapping then unhide this button
                visible: false

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Gamepad Mapper")

                iconSource: "qrc:/res/ic_videogame_asset_white_48px.svg"

                onClicked: navigateTo("qrc:/gui/GamepadMapper.qml", GamepadMapper)

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                id: settingsButton

                // Settings need a profile to belong to
                visible: !(stackView.currentItem instanceof ProfileWizard)

                iconSource:  "qrc:/res/settings.svg"

                onClicked: {
                    // Also reached from the Menu key, so check again here
                    if (!(stackView.currentItem instanceof ProfileWizard)) {
                        navigateTo("qrc:/gui/SettingsView.qml", SettingsView)
                    }
                }

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }

                Shortcut {
                    id: settingsShortcut
                    sequence: StandardKey.Preferences
                    onActivated: settingsButton.clicked()
                }

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Settings") + (settingsShortcut.nativeText ? (" ("+settingsShortcut.nativeText+")") : "")
            }
        }
    }

    // Norilight: the hub. Streams started with profiles run in their own
    // windows; this bar lists them and lets you stop or restart each one.
    footer: Pane {
        id: hubBar

        readonly property int endedCount: DisplayManager.sessions.length - DisplayManager.runningCount

        visible: DisplayManager.sessions.length > 0
        padding: 0
        topPadding: 8
        bottomPadding: 8
        leftPadding: 16
        rightPadding: 16

        background: Rectangle {
            color: Theme.sidebar
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.divider
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 14

            Column {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Label {
                    text: qsTr("Streams")
                    font.pointSize: Theme.fontLabel
                    font.weight: Font.DemiBold
                }
                Label {
                    text: qsTr("%1 running").arg(DisplayManager.runningCount)
                    font.pointSize: Theme.fontSmall
                    color: Theme.textSecondary
                }
            }

            ListView {
                id: hubList

                readonly property bool scrollable: contentWidth > width
                readonly property int cardHeight: 58

                Layout.fillWidth: true
                // Leave a strip under the cards for the scroll bar
                Layout.preferredHeight: cardHeight + (scrollable ? 12 : 0)
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: DisplayManager.sessions

                ScrollBar.horizontal: ScrollBar {
                    policy: hubList.scrollable ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: Rectangle {
                    id: hubCard

                    readonly property string status: modelData.stopping ? qsTr("Stopping…")
                                                   : modelData.running ? qsTr("Streaming")
                                                   : modelData.failed ? qsTr("Ended with an error")
                                                   : qsTr("Ended")
                    readonly property string titleText: modelData.hostName ? qsTr("%1 on %2").arg(modelData.appName).arg(modelData.hostName)
                                                                           : modelData.appName
                    readonly property string detailText: modelData.profileName + " · " + modelData.monitorLabel + " · " + status

                    width: 330
                    height: hubList.cardHeight
                    radius: 6
                    color: cardHover.containsMouse ? Theme.cardHover : Theme.card
                    border.color: Theme.border

                    // Shows the full text when either line is cut off
                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    ToolTip.text: titleText + "\n" + detailText
                    ToolTip.delay: 600
                    ToolTip.visible: cardHover.containsMouse && (cardTitle.truncated || cardDetail.truncated)

                    Rectangle {
                        id: statusDot
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9
                        height: 9
                        radius: 4.5
                        color: modelData.stopping ? Theme.statusWarning
                             : modelData.running ? Theme.statusOk
                             : modelData.failed ? Theme.statusError : Theme.statusIdle
                    }

                    Column {
                        anchors.left: statusDot.right
                        anchors.leftMargin: 10
                        anchors.right: hubActions.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Label {
                            id: cardTitle
                            width: parent.width
                            text: hubCard.titleText
                            font.pointSize: Theme.fontBody - 1
                            elide: Text.ElideRight
                        }
                        Label {
                            id: cardDetail
                            width: parent.width
                            text: hubCard.detailText
                            font.pointSize: Theme.fontSmall - 0.5
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        id: hubActions
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Button {
                            visible: modelData.running
                            enabled: !modelData.stopping
                            flat: true
                            text: qsTr("Stop")
                            onClicked: DisplayManager.stopSession(modelData.id)
                        }
                        Button {
                            visible: !modelData.running
                            flat: true
                            text: qsTr("Restart")
                            onClicked: DisplayManager.relaunch(modelData.id)
                        }
                        ToolButton {
                            visible: !modelData.running
                            anchors.verticalCenter: parent.verticalCenter
                            icon.source: "qrc:/res/close.svg"
                            icon.width: 18
                            icon.height: 18
                            onClicked: DisplayManager.dismissSession(modelData.id)

                            ToolTip.text: qsTr("Remove from the list")
                            ToolTip.delay: 600
                            ToolTip.visible: hovered
                        }
                    }
                }
            }

            Button {
                visible: hubBar.endedCount > 0
                text: qsTr("Clear ended")
                flat: true
                onClicked: {
                    // Copy the ids first: each dismissal rebuilds the list
                    var ids = []
                    var sessions = DisplayManager.sessions
                    for (var i = 0; i < sessions.length; i++) {
                        if (!sessions[i].running) {
                            ids.push(sessions[i].id)
                        }
                    }
                    for (var j = 0; j < ids.length; j++) {
                        DisplayManager.dismissSession(ids[j])
                    }
                }
            }

            Button {
                visible: DisplayManager.runningCount > 1
                text: qsTr("Stop all")
                flat: true
                onClicked: DisplayManager.stopAll()
            }
        }
    }

    Connections {
        target: DisplayManager
        onLaunchFailed: {
            hubErrorDialog.text = message
            hubErrorDialog.open()
        }
    }

    ErrorMessageDialog {
        id: hubErrorDialog
    }

    NavigableMessageDialog {
        id: hubCloseDialog
        standardButtons: Dialog.Yes | Dialog.No
        text: qsTr("Closing Norilight will end the %n stream(s) you started on your monitors. Close anyway?", "", DisplayManager.runningCount)
        acceptText: qsTr("Close and end streams")
        rejectText: qsTr("Keep open")
        onAccepted: {
            window.confirmedHubClose = true
            window.close()
        }
    }

    ErrorMessageDialog {
        id: noHwDecoderDialog
        text: qsTr("No functioning hardware accelerated video decoder was detected by Norilight. " +
                   "Your streaming performance may be severely degraded in this configuration.")
        helpText: qsTr("Click the Help button for more information on solving this problem.")
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Fixing-Hardware-Decoding-Problems"
    }

    ErrorMessageDialog {
        id: xWaylandDialog
        text: qsTr("Hardware acceleration doesn't work on XWayland. Continuing on XWayland may result in poor streaming performance. " +
                   "Try running with QT_QPA_PLATFORM=wayland or switch to X11.")
        helpText: qsTr("Click the Help button for more information.")
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Fixing-Hardware-Decoding-Problems"
    }

    NavigableMessageDialog {
        id: wow64Dialog
        standardButtons: Dialog.Ok | Dialog.Cancel
        text: qsTr("This version of Norilight isn't optimized for your PC. Please download the '%1' version of Norilight for the best streaming performance.").arg(SystemProperties.friendlyNativeArchName)
        onAccepted: {
            Qt.openUrlExternally("https://github.com/azijnwater/Norilight/releases");
        }
    }

    ErrorMessageDialog {
        id: unmappedGamepadDialog
        property string unmappedGamepads : ""
        text: qsTr("Norilight detected gamepads without a mapping:") + "\n" + unmappedGamepads
        helpTextSeparator: "\n\n"
        helpText: qsTr("Click the Help button for information on how to map your gamepads.")
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Gamepad-Mapping"
    }

    // This dialog appears when quitting via keyboard or gamepad button
    NavigableMessageDialog {
        id: quitConfirmationDialog
        standardButtons: Dialog.Yes | Dialog.No
        text: qsTr("Are you sure you want to quit?")
        acceptText: qsTr("Quit")
        rejectText: qsTr("Cancel")
        // For keyboard/gamepad navigation
        onAccepted: Qt.quit()
    }

    // HACK: This belongs in StreamSegue but keeping a dialog around after the parent
    // dies can trigger bugs in Qt 5.12 that cause the app to crash. For now, we will
    // host this dialog in a QML component that is never destroyed.
    //
    // To repro: Start a stream, cut the network connection to trigger the "Connection
    // terminated" dialog, wait until the app grid times out back to the PC grid, then
    // try to dismiss the dialog.
    // Norilight: end-of-stream latency summary (hosted here for the same reason
    // as the error dialog below)
    NavigableMessageDialog {
        id: streamSummaryDialog
        title: qsTr("Stream summary")
        standardButtons: Dialog.Ok
        imageSrc: "qrc:/res/baseline-check_circle_outline-24px.svg"
        onClosed: text = ""
    }

    ErrorMessageDialog {
        id: streamSegueErrorDialog

        property bool quitAfter: false

        onClosed: {
            if (quitAfter) {
                Qt.quit()
            }

            // StreamSegue assumes its dialog will be re-created each time we
            // start streaming, so fake it by wiping out the text each time.
            text = ""
        }
    }

    // Norilight: profile dialogs, opened from the profile button. They live
    // here because the settings page is rebuilt when the profile changes.
    NavigableDialog {
        id: newProfileDialog

        title: qsTr("New profile")
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: Math.min(window.width - 40, 540)

        onAboutToShow: {
            newProfileEditor.reset()

            // standardButton() was added in Qt 5.10
            if (newProfileDialog.standardButton) {
                var ok = newProfileDialog.standardButton(Dialog.Ok)
                if (ok) {
                    ok.text = qsTr("Create profile")
                    ok.enabled = Qt.binding(function() { return newProfileEditor.valid })
                }
            }
        }

        onOpened: newProfileEditor.focusName()

        onAccepted: {
            if (newProfileEditor.valid) {
                var profileId = ProfileManager.createProfile(newProfileEditor.name, newProfileEditor.startFrom)
                if (profileId) {
                    ProfileManager.setTargetMonitor(profileId, newProfileEditor.monitorKey, newProfileEditor.monitorLabel)
                }
            }
        }

        Flickable {
            id: newProfileFlick
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: Math.min(newProfileEditor.height, Math.max(120, window.height - 230))
            height: implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: newProfileEditor.height

            ScrollBar.vertical: ScrollBar {
                policy: newProfileFlick.contentHeight > newProfileFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            ProfileEditor {
                id: newProfileEditor
                width: newProfileFlick.width - 12
                onAccepted: {
                    if (valid) {
                        newProfileDialog.accept()
                    }
                }
            }
        }
    }

    NavigableDialog {
        id: renameProfileDialog
        property string profileId: ""
        property string profileName: ""

        readonly property bool nameInUse: renameField.text.trim() !== "" &&
                                          ProfileManager.nameTaken(renameField.text, profileId)
        readonly property bool valid: renameField.text.trim() !== "" && !nameInUse

        title: qsTr("Rename profile")
        standardButtons: Dialog.Ok | Dialog.Cancel

        onAboutToShow: {
            renameField.text = profileName

            if (renameProfileDialog.standardButton) {
                var ok = renameProfileDialog.standardButton(Dialog.Ok)
                if (ok) {
                    ok.text = qsTr("Rename")
                    ok.enabled = Qt.binding(function() { return renameProfileDialog.valid })
                }
            }
        }

        onOpened: {
            renameField.forceActiveFocus()
            renameField.selectAll()
        }

        onAccepted: {
            if (valid) {
                ProfileManager.rename(profileId, renameField.text)
            }
        }

        ColumnLayout {
            Label {
                text: qsTr("Profile name")
            }

            TextField {
                id: renameField
                Layout.fillWidth: true
                Layout.minimumWidth: 300
                maximumLength: 40
                selectByMouse: true

                Keys.onReturnPressed: {
                    if (renameProfileDialog.valid) {
                        renameProfileDialog.accept()
                    }
                }

                Keys.onEnterPressed: {
                    if (renameProfileDialog.valid) {
                        renameProfileDialog.accept()
                    }
                }
            }

            Label {
                visible: renameProfileDialog.nameInUse
                text: qsTr("You already have a profile with this name.")
                font.pointSize: Theme.fontDetail
                color: Theme.statusError
            }
        }
    }

    NavigableMessageDialog {
        id: removeProfileDialog
        property string profileId: ""
        property string profileName: ""
        standardButtons: Dialog.Yes | Dialog.No
        text: qsTr("Delete the profile \"%1\"? Its settings can't be brought back.").arg(profileName)
        acceptText: qsTr("Delete")
        rejectText: qsTr("Cancel")
        onAccepted: ProfileManager.remove(profileId)
    }

    NavigableDialog {
        id: addPcDialog
        property string label: qsTr("Enter the IP address of your host PC:")

        title: qsTr("Add PC manually")
        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                ComputerManager.addNewHostManually(editText.text.trim())
            }
        }

        ColumnLayout {
            Label {
                text: addPcDialog.label
            }

            TextField {
                id: editText
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    addPcDialog.accept()
                }

                Keys.onEnterPressed: {
                    addPcDialog.accept()
                }
            }
        }
    }
}
