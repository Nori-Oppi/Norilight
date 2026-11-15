import QtQuick 2.9
import QtQuick.Controls 2.2

import SdlGamepadKeyNavigation 1.0
import "."

// https://stackoverflow.com/questions/45029968/how-do-i-set-the-combobox-width-to-fit-the-largest-item
ComboBox {
    property int textWidth
    property int desiredWidth : leftPadding + textWidth + indicator.width + rightPadding
    property int maximumWidth : parent.width
    // Measuring text in scripts the UI font lacks (CJK, Thai, Hindi, ...) makes
    // the system load fallback fonts, which can take half a second the first
    // time. Lists that name languages in their own script can skip those
    // entries; they are never wider than the longest Latin one.
    property bool measureAllScripts: true

    implicitWidth: desiredWidth < maximumWidth ? desiredWidth : maximumWidth

    TextMetrics {
        id: popupMetrics
    }

    TextMetrics {
        id: textMetrics
    }

    // Latin, Greek and Cyrillic (including Vietnamese letters), which the
    // UI font draws itself
    function usesUiFontScripts(text) {
        for (var i = 0; i < text.length; i++) {
            var code = text.charCodeAt(i)
            if (code > 0x052F && (code < 0x1E00 || code > 0x1EFF)) {
                return false
            }
        }
        return true
    }

    function recalculateWidth() {
        textMetrics.font = font
        popupMetrics.font = popup.font
        textWidth = 0
        for (var i = 0; i < count; i++){
            var itemText = textAt(i)
            if (!measureAllScripts && !usesUiFontScripts(itemText)) {
                continue
            }
            textMetrics.text = itemText
            popupMetrics.text = itemText
            textWidth = Math.max(textMetrics.width, textWidth)
            textWidth = Math.max(popupMetrics.width, textWidth)
        }
    }

    // We call this every time the options change (and init)
    // so we can adjust the combo box width here too
    onActivated: recalculateWidth()

    // The gamepad navigation mode in effect before the popup opened. Combo
    // boxes also appear in dialogs over the app grid, which doesn't use UI
    // navigation mode, so restore what was there instead of assuming it.
    property bool previousUiNavMode: true

    popup.onAboutToShow: {
        // Switch to normal navigation for combo boxes
        previousUiNavMode = SdlGamepadKeyNavigation.getUiNavMode()
        SdlGamepadKeyNavigation.setUiNavMode(false)

        // Override the popup color to improve contrast with the overridden
        // background color set in main.qml.
        if (popup.background && popup.background.color !== undefined) {
            popup.background.color = Theme.popup
        }
    }

    popup.onAboutToHide: {
        SdlGamepadKeyNavigation.setUiNavMode(previousUiNavMode)
    }

    Keys.onLeftPressed: {
        decrementCurrentIndex()
    }

    Keys.onRightPressed: {
        incrementCurrentIndex()
    }
}
