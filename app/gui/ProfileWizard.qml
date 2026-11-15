import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

import ProfileManager 1.0
import SdlGamepadKeyNavigation 1.0
import "."

// Norilight: the first-run wizard. Every settings change belongs to a profile,
// so the app opens here until the first profile exists. It creates one or
// more profiles and then hands over to the PC list.
Item {
    id: wizard
    objectName: qsTr("Welcome to Norilight")

    // true: the form for a new profile. false: the list of profiles made so far.
    property bool adding: true

    function showForm() {
        adding = true
        editor.reset()
        editor.focusName()
    }

    function createProfile() {
        if (!editor.valid) {
            return
        }
        ProfileManager.createProfile(editor.name, editor.startFrom)
        adding = false
        finishButton.forceActiveFocus(Qt.TabFocusReason)
    }

    function finish() {
        // Replace the wizard so Back can't return to it
        stackView.replace(null, "qrc:/gui/PcView.qml")
    }

    StackView.onActivated: {
        // Tab moves between the controls, as on the settings page
        SdlGamepadKeyNavigation.setUiNavMode(true)

        if (ProfileManager.setupNeeded) {
            showForm()
        }
        else {
            adding = false
        }
    }

    StackView.onDeactivating: {
        SdlGamepadKeyNavigation.setUiNavMode(false)
    }

    Flickable {
        id: wizardFlick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: wizardColumn.height

        ScrollBar.vertical: ScrollBar {}

        Column {
            id: wizardColumn
            width: Math.max(0, Math.min(wizardFlick.width - 48, 600))
            x: (wizardFlick.width - width) / 2
            topPadding: 32
            bottomPadding: 40
            spacing: 0

            Image {
                source: "qrc:/res/norilight.svg"
                sourceSize.width: 52
                sourceSize.height: 52
            }

            Label {
                width: parent.width
                topPadding: 16
                text: !wizard.adding ? qsTr("Your profiles")
                    : ProfileManager.setupNeeded ? qsTr("Create your first profile")
                    : qsTr("Add another profile")
                font.pointSize: Theme.fontHeading
                font.weight: Font.Medium
                font.letterSpacing: -0.3
                color: Theme.textHeading
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                topPadding: 8
                text: !wizard.adding ? qsTr("Norilight opens with the selected profile. You can switch profiles, add more and change every setting later from the profile button in the toolbar and in Settings.")
                    : ProfileManager.setupNeeded ? qsTr("A profile is a complete set of Norilight settings. Make one for each way you stream, for example one for gaming and one for work, and switch between them whenever you like.")
                    : qsTr("Each profile keeps its own settings, so changing one never affects the others.")
                font.pointSize: Theme.fontDetail + 0.5
                lineHeight: 1.15
                color: Theme.textSecondary
                wrapMode: Text.Wrap
            }

            // Shown to people coming from the Moonlight client
            Item {
                visible: wizard.adding && ProfileManager.setupNeeded && ProfileManager.hasMoonlightSettings
                width: parent.width
                height: moonlightBox.height + 14

                Rectangle {
                    id: moonlightBox
                    y: 14
                    width: parent.width
                    height: moonlightNotice.height
                    radius: 6
                    color: Theme.card
                    border.color: Theme.border

                    Label {
                        id: moonlightNotice
                        width: parent.width
                        padding: 12
                        text: qsTr("Norilight found the settings of your Moonlight client. Choose \"My Moonlight settings\" below to bring them over.")
                        font.pointSize: Theme.fontDetail
                        color: Theme.textPrimary
                        wrapMode: Text.Wrap
                    }
                }
            }

            Item {
                width: 1
                height: 24
            }

            // Step 1: a new profile
            ProfileEditor {
                id: editor
                visible: wizard.adding
                width: parent.width
                onAccepted: wizard.createProfile()
            }

            Row {
                visible: wizard.adding
                topPadding: 20
                spacing: 10

                Button {
                    text: qsTr("Create profile")
                    highlighted: true
                    enabled: editor.valid
                    font.pointSize: Theme.fontBody
                    onClicked: wizard.createProfile()
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                }

                Button {
                    visible: !ProfileManager.setupNeeded
                    text: qsTr("Back")
                    flat: true
                    font.pointSize: Theme.fontBody
                    onClicked: wizard.adding = false
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                }
            }

            // Step 2: the profiles made so far
            Column {
                visible: !wizard.adding
                width: parent.width
                spacing: 6

                Repeater {
                    model: ProfileManager.profiles

                    delegate: ItemDelegate {
                        id: profileRow

                        width: parent.width
                        height: 52
                        leftPadding: 14
                        rightPadding: 14
                        hoverEnabled: true
                        focusPolicy: Qt.TabFocus

                        function select() {
                            var id = modelData.id
                            Qt.callLater(function() {
                                ProfileManager.activate(id)
                            })
                        }

                        onClicked: select()
                        Keys.onReturnPressed: select()
                        Keys.onEnterPressed: select()

                        background: Rectangle {
                            radius: 6
                            color: modelData.active ? Theme.navSelected
                                                    : (profileRow.hovered || profileRow.visualFocus ? Theme.cardHover : Theme.card)
                            border.width: modelData.active ? 2 : 1
                            border.color: modelData.active ? Material.accent : Theme.border
                        }

                        contentItem: Item {
                            Image {
                                id: rowIcon
                                anchors.verticalCenter: parent.verticalCenter
                                source: Theme.profileIcon(modelData.kind)
                                sourceSize.width: 22
                                sourceSize.height: 22
                                opacity: modelData.active ? 1.0 : 0.7
                            }

                            Label {
                                anchors.left: rowIcon.right
                                anchors.leftMargin: 14
                                anchors.right: rowTag.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.pointSize: Theme.fontBody
                                font.weight: modelData.active ? Font.DemiBold : Font.Normal
                                color: Theme.textHeading
                                elide: Text.ElideRight
                            }

                            Label {
                                id: rowTag
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.active ? qsTr("Selected") : ""
                                font.pointSize: Theme.fontSmall
                                color: Theme.textSecondary
                            }
                        }
                    }
                }
            }

            Row {
                visible: !wizard.adding
                topPadding: 20
                spacing: 10

                Button {
                    id: finishButton
                    text: qsTr("Finish")
                    highlighted: true
                    font.pointSize: Theme.fontBody
                    onClicked: wizard.finish()
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                }

                Button {
                    text: qsTr("Add another profile")
                    flat: true
                    font.pointSize: Theme.fontBody
                    onClicked: wizard.showForm()
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                }
            }
        }
    }
}
