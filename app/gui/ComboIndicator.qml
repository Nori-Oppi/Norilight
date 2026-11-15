import QtQuick
import QtQuick.Controls.impl
import QtQuick.Templates as T

import "."

// Norilight: the drop-down arrow for every combo box, using the same chevron
// as the profile switcher instead of Material's triangle.
ColorImage {
    // Any combo box; typed as the template so every style's ComboBox fits
    property T.Control control

    x: control.mirrored ? control.padding : control.width - width - control.padding
    y: control.topPadding + (control.availableHeight - height) / 2
    width: 20
    height: 20
    sourceSize.width: 20
    sourceSize.height: 20
    source: "qrc:/res/expand_more.svg"
    color: control.enabled ? Theme.textSecondary : Theme.textDisabled
}
