import QtQuick 2.9
import QtQuick.Controls 2.2

import "."

// Norilight: a group of SettingsRows on one card, with an optional small
// heading (and a line of context under it) above the card.
Column {
    id: card

    property string title: ""
    property string description: ""

    default property alias rows: rowColumn.data

    width: parent ? parent.width : 0
    spacing: 8

    Column {
        width: parent.width
        spacing: 2
        visible: card.title !== ""

        Label {
            width: parent.width
            text: card.title
            font.pointSize: Theme.fontSmall
            font.weight: Font.DemiBold
            color: Theme.textTertiary
            wrapMode: Text.Wrap
        }

        Label {
            width: Math.min(parent.width, 620)
            visible: text !== ""
            text: card.description
            font.pointSize: Theme.fontDetail
            color: Theme.textSecondary
            wrapMode: Text.Wrap
        }
    }

    Rectangle {
        width: parent.width
        height: rowColumn.height
        radius: Theme.cardRadius
        color: Theme.card

        Column {
            id: rowColumn
            x: Theme.cardPadding
            width: parent.width - 2 * Theme.cardPadding
        }
    }
}
