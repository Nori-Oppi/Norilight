import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import ComputerModel 1.0
import Optimiser 1.0
import ProfileManager 1.0

import "."

// Norilight (roadmap N6): Optimise. The host's encoder test (POST /api/v1/optimise on
// Norishine hosts), then short test streams of the host's test picture, one per candidate
// setting (Optimiser). The best is saved to the active profile and the host, each with
// Undo. Labels only; how it decides is in the Norilight-Guide wiki page, "Optimise".
Item {
    id: page

    property int computerIndex
    property ComputerModel computerModel
    property var hostFeatures: []

    // "idle", "host", "streams", "done" or "failed"
    property string phase: "idle"
    property string error: ""
    property var hostTest: null       // GET /api/v1/optimise
    property string hostNote: ""
    property bool hostApplied: false
    property bool profileSaved: false
    property bool waitingForStats: false

    readonly property string docsUrl: "https://github.com/Nori-Oppi/norilight-docs/wiki/Norilight-Guide#optimise"

    function request(kind, verb, path, body) {
        computerModel.hostApiRequest(computerIndex, kind, verb, path, body === undefined ? "" : JSON.stringify(body))
    }

    function start() {
        error = ""
        hostNote = ""
        hostTest = null
        hostApplied = false
        profileSaved = false
        var problem = optimiser.begin(computerModel, computerIndex)
        if (problem !== "") {
            error = problem
            phase = "failed"
            return
        }
        if (hostFeatures.indexOf("optimise") >= 0) {
            phase = "host"
            request("optimiseStart", "POST", "/api/v1/optimise", {})
        }
        else {
            startStreams()
        }
    }

    function startStreams() {
        phase = "streams"
        nextStream()
    }

    function nextStream() {
        var session = optimiser.nextSession()
        if (session === null) {
            phase = "done"
            return
        }
        waitingForStats = true
        session.streamStatsReady.connect(function(stats) {
            waitingForStats = false
            optimiser.record(stats)
        })
        var component = Qt.createComponent("StreamSegue.qml")
        stackView.push(component.createObject(stackView, {"appName": qsTr("Optimise test"), "session": session}))
    }

    // Back from a test stream
    StackView.onActivated: {
        if (phase !== "streams") {
            return
        }
        if (waitingForStats) {
            // It didn't stream; its error is shown by the stream page
            waitingForStats = false
            optimiser.record({})
            error = qsTr("A test stream failed")
            phase = "failed"
            return
        }
        nextStreamTimer.start()
    }

    Timer {
        id: nextStreamTimer
        interval: 1500
        onTriggered: page.nextStream()
    }

    Timer {
        id: hostPollTimer
        interval: 1000
        onTriggered: page.request("optimiseState", "GET", "/api/v1/optimise")
    }

    Optimiser {
        id: optimiser
    }

    Connections {
        target: computerModel

        function onHostApiResponse(requestId, status, body, error) {
            var data = null
            try {
                data = JSON.parse(body)
            }
            catch (e) {
                data = null
            }

            if (requestId === "optimiseStart" || requestId === "optimiseState") {
                if (page.phase !== "host") {
                    return
                }
                if (status === 202 || status === 200) {
                    page.hostTest = data
                    if (data && data.state === "running") {
                        hostPollTimer.start()
                        return
                    }
                    if (data && data.state === "failed") {
                        page.hostNote = qsTr("Encoder test failed: %1").arg(data.error || "")
                    }
                }
                else {
                    page.hostNote = status === 403 ? qsTr("No permission to change host settings")
                                                   : qsTr("Encoder test failed: %1").arg((data && data.error) || error || status)
                }
                page.startStreams()
            }
            else if (requestId === "optimiseApply" || requestId === "optimiseUndo") {
                if (status === 200) {
                    page.hostApplied = requestId === "optimiseApply"
                    page.hostNote = requestId === "optimiseApply" ? qsTr("Applied. Takes effect after the host restarts.") : qsTr("Undone.")
                }
                else {
                    page.hostNote = qsTr("Couldn't change it: %1").arg((data && data.error) || error || status)
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: pageColumn.height + 40
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: pageColumn
            width: Math.min(Theme.contentMaxWidth, flick.width - 40)
            x: (flick.width - width) / 2
            y: 20
            spacing: Theme.cardGap

            RowLayout {
                width: parent.width
                spacing: Theme.controlGap

                Label {
                    Layout.fillWidth: true
                    text: qsTr("Profile: %1").arg(ProfileManager.activeName)
                    font.pointSize: Theme.fontDetail
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }

                Button {
                    text: qsTr("How it works")
                    flat: true
                    onClicked: Qt.openUrlExternally(page.docsUrl)
                }

                Button {
                    text: page.phase === "idle" || page.phase === "failed" ? qsTr("Start") : qsTr("Start again")
                    highlighted: true
                    enabled: page.phase !== "host" && page.phase !== "streams"
                    onClicked: page.start()
                }
            }

            // Progress
            SettingsCard {
                visible: page.phase === "host" || page.phase === "streams"

                SettingsRow {
                    text: page.phase === "host" ? qsTr("Testing the host's encoder")
                                                : qsTr("Test stream %1 of %2").arg(Math.min(optimiser.done + 1, optimiser.planned)).arg(optimiser.planned)

                    BusyIndicator {
                        running: parent.visible
                        implicitWidth: 32
                        implicitHeight: 32
                    }
                }
            }

            Label {
                width: parent.width
                visible: page.error !== ""
                text: page.error
                color: Theme.statusError
                wrapMode: Text.Wrap
            }

            // Test streams
            SettingsCard {
                title: qsTr("Test streams")
                visible: optimiser.results.length > 0

                Repeater {
                    model: optimiser.results

                    SettingsRow {
                        text: modelData.codec + " · " + modelData.width + "×" + modelData.height + " · " + modelData.fps + " fps · " + modelData.mbps + " Mbps"
                        badge: modelData.best ? qsTr("Best") : ""
                        hint: !modelData.streamed ? qsTr("Didn't stream")
                            : qsTr("%1 fps shown · %2 ms").arg(Number(modelData.shownFps).toFixed(1)).arg(Number(modelData.latencyMs).toFixed(1))
                        hintIsError: !modelData.keepsUp

                        Label {
                            text: modelData.keepsUp ? qsTr("Keeps up") : qsTr("Falls behind")
                            color: modelData.keepsUp ? Theme.textPrimary : Theme.statusError
                        }
                    }
                }
            }

            // Result: profile
            SettingsCard {
                title: qsTr("Profile")
                visible: page.phase === "done" || optimiser.canUndo

                SettingsRow {
                    visible: page.phase === "done"
                    text: optimiser.pick.codec === undefined ? qsTr("Nothing kept up")
                        : optimiser.pick.codec + " · " + optimiser.pick.width + "×" + optimiser.pick.height + " · " +
                          optimiser.pick.fps + " fps · " + optimiser.pick.mbps + " Mbps"
                    hint: qsTr("Now: %1 · %2×%3 · %4 fps · %5 Mbps").arg(optimiser.current.codec).arg(optimiser.current.width)
                          .arg(optimiser.current.height).arg(optimiser.current.fps).arg(optimiser.current.mbps)

                    Button {
                        text: page.profileSaved ? qsTr("Saved") : qsTr("Save")
                        highlighted: true
                        enabled: optimiser.pick.codec !== undefined && !page.profileSaved
                        onClicked: {
                            optimiser.save()
                            page.profileSaved = true
                        }
                    }
                }

                SettingsRow {
                    visible: optimiser.canUndo
                    text: qsTr("Undo Optimise")

                    Button {
                        text: qsTr("Undo")
                        onClicked: {
                            optimiser.undo()
                            page.profileSaved = false
                        }
                    }
                }
            }

            // Result: host
            SettingsCard {
                title: qsTr("Host")
                visible: page.hostTest !== null || page.hostNote !== ""

                SettingsRow {
                    visible: page.hostTest !== null && page.hostTest.state === "done"
                    text: page.hostTest && page.hostTest.pick !== undefined ? String(page.hostTest.pick) : ""
                    hint: page.hostTest ? qsTr("Encoder preset · now: %1").arg(String(page.hostTest.current)) : ""

                    Button {
                        text: qsTr("Apply")
                        highlighted: true
                        visible: page.hostTest !== null && JSON.stringify(page.hostTest.pick) !== JSON.stringify(page.hostTest.current)
                        enabled: !page.hostApplied
                        onClicked: page.request("optimiseApply", "POST", "/api/v1/optimise/apply", {})
                    }

                    Button {
                        text: qsTr("Undo")
                        visible: page.hostApplied
                        onClicked: page.request("optimiseUndo", "POST", "/api/v1/recommendations/rollback", {})
                    }
                }

                SettingsRow {
                    visible: page.hostNote !== ""
                    text: page.hostNote
                }
            }
        }
    }
}
