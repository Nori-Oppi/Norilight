import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2
import QtQuick.Templates 2.2 as T

import "."

// Norilight: one setting on a SettingsCard. The name and an optional short
// hint sit on the left, the controls on the right. A longer explanation sits
// behind an (i) button that opens it in place, so it can be read with a
// mouse, keyboard, controller or touchscreen alike.
Item {
    id: row

    property string text: ""
    // Optional icon before the name, and a short accent label after it
    property url iconSource: ""
    property string badge: ""
    // Short, always visible: a requirement, a consequence or the current state
    property string hint: ""
    // Show the hint as an error (a value the host rejected)
    property bool hintIsError: false
    // Longer explanation, shown when the (i) button is opened
    property string info: ""
    // Explanation shown on hover over the name instead (Host Settings, like the web UI)
    property string tooltip: ""
    // Changed but not saved: a bar at the card's edge (red with hintIsError)
    property bool modified: false
    // Key combination that changes this setting during a stream
    property string shortcut: ""
    // Depends on the setting above it
    property bool indented: false
    property bool expanded: false
    // The control whose keyboard focus outlines the whole row
    property T.Control focusTarget: null
    property real minimumHeight: Theme.rowMinHeight
    // Whether the setting can be changed right now. Rows don't use "enabled"
    // for this, so the (i) button keeps working on unavailable settings.
    property bool available: true

    // Controls, laid out left to right after the shortcut key label
    default property alias controls: controlRow.data
    readonly property alias controlArea: controlRow

    // A click on the row outside its controls
    signal rowClicked()

    readonly property bool isSettingsRow: true
    readonly property real leftEdge: indented ? Theme.indent : 0
    readonly property real verticalPadding: 10
    // In a narrow window the controls move under the name instead of
    // squeezing it to nothing
    readonly property bool stacked: width - leftEdge - controlRow.implicitWidth - Theme.rowGap < 160
    // The name/hint block and the controls: side by side (the taller one
    // sets the height) or stacked
    readonly property real topBlockHeight: stacked ? textColumn.height + 8 + controlRow.height
                                                   : Math.max(textColumn.height, controlRow.height)

    // The first visible row on a card draws no divider above it
    readonly property bool firstOnCard: {
        if (!parent) {
            return true
        }
        var siblings = parent.children
        for (var i = 0; i < siblings.length; i++) {
            if (siblings[i] === row) {
                return true
            }
            if (siblings[i].isSettingsRow && siblings[i].visible) {
                return false
            }
        }
        return true
    }

    width: parent ? parent.width : 0
    height: Math.max(minimumHeight,
                     verticalPadding * 2 + topBlockHeight + (infoLabel.visible ? infoLabel.height + 6 : 0))

    Rectangle {
        x: row.leftEdge
        width: row.width - x
        height: 1
        color: Theme.rowDivider
        visible: !row.firstOnCard
    }

    MouseArea {
        anchors.fill: parent
        enabled: row.available
        onClicked: row.rowClicked()
    }

    Rectangle {
        x: -Theme.cardPadding
        y: 10
        width: 3
        height: row.height - 20
        radius: 1.5
        color: row.hintIsError ? Theme.statusError : Material.accent
        visible: row.modified || row.hintIsError
    }

    // Keyboard and controller focus on the row's control outlines the row
    Rectangle {
        x: row.leftEdge - 8
        y: 3
        width: row.width - x + 8
        height: row.height - 6
        radius: 6
        color: "transparent"
        border.width: 2
        border.color: Material.accent
        visible: row.focusTarget !== null && row.focusTarget.visualFocus
    }

    Column {
        id: textColumn
        x: row.leftEdge
        y: row.stacked ? row.verticalPadding : row.verticalPadding + (row.topBlockHeight - height) / 2
        width: Math.max(0, row.stacked ? row.width - x : row.width - controlRow.implicitWidth - x - Theme.rowGap)
        spacing: 2

        // Icon, name, badge and (i). The badge and (i) follow the end of the
        // text, even when a long name wraps onto several lines.
        Item {
            width: parent.width
            height: Math.max(nameLabel.height, infoButton.visible ? infoButton.height : 0)
            visible: row.text !== ""

            Image {
                id: rowIcon
                anchors.verticalCenter: parent.verticalCenter
                visible: row.iconSource.toString() !== ""
                source: row.iconSource
                sourceSize.width: 20
                sourceSize.height: 20
                opacity: row.available ? 1 : 0.5
            }

            Label {
                id: nameLabel
                x: rowIcon.visible ? rowIcon.width + 8 : 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(implicitWidth, parent.width - x
                                            - (badgeLabel.visible ? badgeLabel.implicitWidth + 4 : 0)
                                            - (infoButton.visible ? infoButton.width + 4 : 0)))
                text: row.text
                font.pointSize: Theme.fontBody
                color: row.available ? Theme.textPrimary : Theme.textDisabled
                wrapMode: Text.Wrap
            }

            Label {
                id: badgeLabel
                x: nameLabel.x + nameLabel.contentWidth + 4
                anchors.verticalCenter: parent.verticalCenter
                visible: row.badge !== ""
                leftPadding: 4
                text: row.badge
                font.pointSize: Theme.fontSmall
                font.weight: Font.DemiBold
                color: Material.accent
            }

            ToolButton {
                id: infoButton
                x: (badgeLabel.visible ? badgeLabel.x + badgeLabel.width : nameLabel.x + nameLabel.contentWidth) + 4
                anchors.verticalCenter: parent.verticalCenter
                visible: row.info !== ""
                width: 28
                height: 28
                padding: 0
                topInset: 0
                bottomInset: 0
                leftInset: 0
                rightInset: 0
                display: AbstractButton.IconOnly
                icon.source: "qrc:/res/info_outline.svg"
                icon.width: 18
                icon.height: 18
                icon.color: row.expanded ? Material.accent
                                         : (row.available ? Theme.textTertiary : Theme.textDisabled)
                // A clear ring for keyboard and controller focus, like the row outline
                background: Rectangle {
                    radius: width / 2
                    color: infoButton.hovered ? Theme.cardHover : "transparent"
                    border.width: infoButton.visualFocus ? 2 : 0
                    border.color: Material.accent
                }
                onClicked: row.expanded = !row.expanded
                Keys.onReturnPressed: row.expanded = !row.expanded
                Keys.onEnterPressed: row.expanded = !row.expanded

                Accessible.name: row.expanded ? qsTr("Hide details") : qsTr("Show details")
                ToolTip.text: Accessible.name
                ToolTip.delay: 600
                ToolTip.visible: hovered
            }
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: row.hint
            font.pointSize: Theme.fontDetail
            lineHeight: 1.1
            color: row.hintIsError ? Theme.statusError : row.available ? Theme.textSecondary : Theme.textDisabledSecondary
            wrapMode: Text.Wrap
        }
    }

    // Hovering the name shows the explanation
    MouseArea {
        id: tooltipArea
        x: textColumn.x
        y: textColumn.y
        width: textColumn.width
        height: textColumn.height
        visible: row.tooltip !== ""
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        ToolTip {
            id: rowTip
            visible: tooltipArea.containsMouse
            delay: 500
            text: row.tooltip
            width: Math.min(implicitWidth, 440)
            contentItem: Label {
                text: rowTip.text
                wrapMode: Text.Wrap
                font.pointSize: Theme.fontDetail
                color: Theme.textPrimary
            }
        }
    }

    RowLayout {
        id: controlRow
        // Right-aligned either way, so switches stay in one column
        x: row.width - width
        y: row.stacked ? row.verticalPadding + textColumn.height + 8
                       : row.verticalPadding + (row.topBlockHeight - height) / 2
        spacing: Theme.controlGap

        Label {
            id: keyLabel
            visible: row.shortcut !== ""
            // As wide as the widest Ctrl+Alt+Shift+letter, so they line up
            Layout.minimumWidth: keyMetrics.width + leftPadding + rightPadding
            horizontalAlignment: Text.AlignHCenter
            text: row.shortcut
            font.pointSize: Theme.fontSmall
            font.weight: Font.DemiBold
            color: row.available ? Theme.textSecondary : Theme.textDisabled
            leftPadding: 7
            rightPadding: 7
            topPadding: 3
            bottomPadding: 3
            TextMetrics {
                id: keyMetrics
                font: keyLabel.font
                text: "Ctrl+Alt+Shift+W"
            }

            background: Rectangle {
                radius: 4
                color: Theme.background
                border.color: row.available ? Theme.border : Theme.rowDivider
            }
        }
    }

    // Opened with the (i) button; spans the row under the name and controls
    Label {
        id: infoLabel
        x: row.leftEdge
        y: row.verticalPadding + row.topBlockHeight + 6
        width: row.width - x
        visible: row.expanded && row.info !== ""
        text: row.info
        font.pointSize: Theme.fontDetail
        lineHeight: 1.15
        color: Theme.textSecondary
        wrapMode: Text.Wrap
    }
}
