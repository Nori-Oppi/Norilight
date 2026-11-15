pragma Singleton
import QtQuick 2.0

// Norilight: shared colours and type sizes for the UI. Use these instead of
// hardcoded values so pages, dialogs and the hub stay consistent.
QtObject {
    // Muted rose and blush stops keep white toolbar labels readable.
    readonly property color blushStart: "#AD4F70"
    readonly property color blushMiddle: "#BC647F"
    readonly property color blushEnd: "#AE5C70"

    // Surfaces, darkest to lightest
    readonly property color sidebar: "#28282D"
    readonly property color background: "#2F2F34"
    readonly property color card: "#37373E"
    readonly property color cardHover: "#3D3D45"
    readonly property color popup: "#3C3C43"
    readonly property color navSelected: "#3A3A42"
    readonly property color navHover: "#333339"

    // Lines
    readonly property color divider: "#3B3B42"
    readonly property color border: "#47474F"

    // Text
    readonly property color textHeading: "#F4F4F6"
    readonly property color textPrimary: "#ECECEE"
    readonly property color textSecondary: "#A3A3AB"
    readonly property color textTertiary: "#9696A0"
    readonly property color textDisabled: "#76767E"
    readonly property color textDisabledSecondary: "#66666E"

    // Status
    readonly property color statusOk: "#5FCB82"
    readonly property color statusWarning: "#E0B050"
    readonly property color statusError: "#E57373"
    readonly property color statusIdle: "#76767E"

    // Type scale (points)
    readonly property real fontOverline: 8.5   // sidebar category headings
    readonly property real fontSmall: 9.5      // secondary lines on cards and rows
    readonly property real fontDetail: 10      // descriptions under settings
    readonly property real fontBody: 11.5      // card titles, list items, inline labels
    readonly property real fontLabel: 12       // setting names and field titles
    readonly property real fontSubheading: 14
    readonly property real fontHeading: 20

    // Indent for settings that depend on the one above them
    readonly property int indent: 36

    // Icon for a settings profile, by the kind it was created as
    function profileIcon(kind) {
        if (kind === "gaming") {
            return "qrc:/res/ic_videogame_asset_white_48px.svg"
        }
        if (kind === "work") {
            return "qrc:/res/desktop_windows-48px.svg"
        }
        return "qrc:/res/tune.svg"
    }
}
