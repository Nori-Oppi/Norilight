import QtQuick 2.9
import QtQuick.Controls 2.2

// Norilight: scrolls a Flickable by exactly what the mouse wheel or touchpad
// asks for. Flickable's own wheel handling turns each notch into a flick with
// momentum, which stutters, overshoots and keeps moving after a touchpad
// gesture ends. Place this after the Flickable as its sibling so it sits on
// top; clicks and hover still go to the items underneath.
MouseArea {
    id: scroller

    property Flickable flickable
    // Pixels moved per standard wheel notch
    property real notchStep: 72

    // Where a run of wheel notches is heading, so quick notches add up
    // instead of each starting from wherever the animation has got to
    property real targetY: 0

    anchors.fill: flickable
    acceptedButtons: Qt.NoButton

    function maxContentY() {
        return Math.max(0, flickable.contentHeight + flickable.topMargin + flickable.bottomMargin - flickable.height) - flickable.topMargin
    }

    function clamp(y) {
        return Math.max(-flickable.topMargin, Math.min(y, maxContentY()))
    }

    NumberAnimation {
        id: wheelAnimation
        target: scroller.flickable
        property: "contentY"
        duration: 120
        easing.type: Easing.OutCubic
    }

    onWheel: function(wheel) {
        if (!flickable || flickable.contentHeight <= flickable.height) {
            wheel.accepted = false
            return
        }

        flickable.cancelFlick()

        if (wheel.pixelDelta.y !== 0) {
            // Touchpads and smooth-scrolling mice report exact pixels; follow
            // them directly so the content stays under the fingers
            wheelAnimation.stop()
            flickable.contentY = clamp(flickable.contentY - wheel.pixelDelta.y)
        }
        else if (wheel.angleDelta.y !== 0) {
            var start = wheelAnimation.running ? targetY : flickable.contentY
            targetY = clamp(start - wheel.angleDelta.y / 120 * notchStep)
            wheelAnimation.stop()
            wheelAnimation.from = flickable.contentY
            wheelAnimation.to = targetY
            wheelAnimation.start()
        }
        else {
            wheel.accepted = false
            return
        }

        // Let the scroll bar show while the wheel moves the content
        if (flickable.ScrollBar.vertical) {
            flickable.ScrollBar.vertical.active = true
            hideScrollBarTimer.restart()
        }
    }

    Timer {
        id: hideScrollBarTimer
        interval: 600
        onTriggered: {
            var bar = scroller.flickable ? scroller.flickable.ScrollBar.vertical : null
            if (bar && !bar.hovered && !bar.pressed) {
                bar.active = false
            }
        }
    }
}
