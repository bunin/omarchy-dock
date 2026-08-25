import QtQuick
import qs.Commons

Item {
    id: root

    property int count: 0
    property bool hasUrgent: false
    property bool isSuppressed: false
    property real badgeHeight: 14
    property real badgeFontSize: 8.5

    // Badge background color: identical to dock border color (Color.accent / urgent)
    readonly property color badgeColor: (root.hasUrgent && Color.urgent) ? Color.urgent : (Color.accent || "#3584E4")

    // Badge text color: identical to dock surface background color (Color.bar.background / Color.background)
    readonly property color textColor: Color.bar.background || Color.background || "#11111b"

    implicitWidth: Math.max(badgeHeight, Math.round(badgeText.paintedWidth + 6))
    implicitHeight: badgeHeight
    z: 250

    readonly property bool isBadgeActive: count > 0 && !isSuppressed
    visible: isBadgeActive || badgeRect.scale > 0.01

    // 🌟 Feature 1: Micro Bounce / Pulse animation when badge count updates while visible
    onCountChanged: {
        if (root.count > 0 && badgePulseAnim.running) {
            badgePulseAnim.stop()
        }
        if (root.count > 0 && badgeRect.scale > 0.4) {
            badgePulseAnim.restart()
        }
    }

    SequentialAnimation {
        id: badgePulseAnim
        running: false
        NumberAnimation {
            target: badgeRect
            property: "scale"
            to: 1.25
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: badgeRect
            property: "scale"
            to: 1.0
            duration: 160
            easing.type: Easing.OutBack
            easing.overshoot: 1.5
        }
    }

    Rectangle {
        id: badgeRect
        anchors.fill: parent
        radius: height / 2
        color: root.badgeColor
        border.width: 0
        border.color: "transparent"
        antialiasing: true
        smooth: true

        Behavior on color { ColorAnimation { duration: 180 } }

        scale: root.isBadgeActive ? 1.0 : 0.0
        Behavior on scale {
            enabled: !badgePulseAnim.running
            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
        }

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.count > 99 ? "99+" : String(root.count)
            color: root.textColor
            font.family: Style.font.family
            font.pixelSize: root.badgeFontSize
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            renderType: Text.CurveRendering
            font.hintingPreference: Font.PreferNoHinting

            Behavior on color { ColorAnimation { duration: 180 } }
        }
    }
}
