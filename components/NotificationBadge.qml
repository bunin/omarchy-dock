import QtQuick
import qs.Commons

Item {
    id: root

    property int count: 0
    property bool hasUrgent: false
    property bool isSuppressed: false
    property real badgeHeight: 18
    property real badgeFontSize: 10

    // Unified theme-aware dynamic color (Strictly Omarchy theme accent / urgent)
    readonly property color currentTargetColor: (root.hasUrgent && Color.urgent) ? Color.urgent : (Color.accent || "#3584E4")
    property color badgeColor: currentTargetColor
    
    // Perceived luminance for optimal text contrast on active badge color
    readonly property real badgeLuminance: (typeof badgeColor.r === "number")
        ? (badgeColor.r * 0.299 + badgeColor.g * 0.587 + badgeColor.b * 0.114)
        : 0.5
    property color textColor: badgeLuminance > 0.55 ? (Color.background || "#000000") : (Color.foreground || "#FFFFFF")

    implicitWidth: Math.max(badgeHeight, badgeText.contentWidth + 8)
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
            to: 1.28
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: badgeRect
            property: "scale"
            to: 1.0
            duration: 160
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
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
