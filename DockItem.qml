import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "IconResolver.js" as IconResolver

Item {
    id: root

    property var shell: null
    property var itemData: null
    property int itemIndex: 0
    property int totalCount: 1
    property string barPosition: "top"
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    property int iconBaseSize: 28
    property bool isDragging: false
    property int systemBorderSize: 2
    property int systemRounding: 12
    property bool isSelected: false

    signal moveRequested(int fromIdx, int toIdx)
    signal itemRightClicked(var item, var targetItem)
    signal itemLeftClicked(var item)

    implicitWidth: 42
    implicitHeight: 42
    width: 42
    height: 42
    z: isDragging ? 100 : (isSelected ? 60 : (mouseArea.containsMouse ? 50 : 1))

    // Position animation (smooth sliding into place when other items move or when drag is released)
    Behavior on x {
        enabled: !root.isDragging
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !root.isDragging
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // Main animated icon wrapper (strictly centered)
    Item {
        id: iconWrapper
        anchors.centerIn: parent
        width: root.iconBaseSize
        height: root.iconBaseSize

        // Smooth subtle hover and drag zoom
        scale: root.isDragging ? 1.22 : (mouseArea.containsMouse ? 1.12 : 1.0)
        opacity: root.isDragging ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        // Application Icon Image
        Image {
            id: appIconImage
            anchors.centerIn: parent
            width: root.iconBaseSize
            height: root.iconBaseSize
            sourceSize.width: root.iconBaseSize * 2
            sourceSize.height: root.iconBaseSize * 2
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true

            source: {
                if (!root.itemData) return ""
                var resolved = IconResolver.resolveIcon(root.itemData.appClass, root.itemData.icon)
                if (root.shell && root.shell.appLibrary && typeof root.shell.appLibrary.iconSource === "function") {
                    var s = root.shell.appLibrary.iconSource(resolved)
                    if (s && s.length > 0) return s
                    s = root.shell.appLibrary.iconSource(root.itemData.appClass)
                    if (s && s.length > 0) return s
                }
                var p = Quickshell.iconPath(resolved, true)
                if (p && p.length > 0) return p
                p = Quickshell.iconPath(root.itemData.appClass, true)
                if (p && p.length > 0) return p
                return Quickshell.iconPath("application-x-executable", true)
            }

            // Fallback text glyph (no border box)
            Text {
                anchors.centerIn: parent
                visible: appIconImage.status !== Image.Ready
                text: root.itemData && root.itemData.name ? root.itemData.name.charAt(0).toUpperCase() : "★"
                font.family: Style.font.family
                font.bold: true
                font.pixelSize: 14
                color: Color.accent
            }
        }

        // Apple signature launch bounce animation
        SequentialAnimation {
            id: launchBounce
            loops: 2
            NumberAnimation { target: iconWrapper; property: "scale"; to: 1.16; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: iconWrapper; property: "scale"; to: 1.0; duration: 110; easing.type: Easing.InQuad }
        }
    }

    // Running Indicator Dot (Always strictly under icon in all orientations, fades on hover)
    Rectangle {
        id: runningDot
        visible: opacity > 0
        opacity: (root.itemData && root.itemData.isRunning && !mouseArea.containsMouse && !root.isDragging) ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        width: root.itemData && root.itemData.isActive ? 4 : 3
        height: root.itemData && root.itemData.isActive ? 4 : 3
        radius: width / 2
        color: root.itemData && root.itemData.isActive ? Color.accent : Color.composed("bar.text", "bar.text-alpha", Color.bar.text, 0.75)

        // Unified positioning: ALWAYS under icon across all orientations
        anchors.top: iconWrapper.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on width { NumberAnimation { duration: 180 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        drag.target: root
        drag.axis: root.isVertical ? Drag.YAxis : Drag.XAxis
        drag.minimumX: root.isVertical ? 0 : 0
        drag.maximumX: root.isVertical ? 0 : Math.max(0, (root.totalCount - 1) * 46)
        drag.minimumY: root.isVertical ? 0 : 0
        drag.maximumY: root.isVertical ? Math.max(0, (root.totalCount - 1) * 46) : 0
        drag.threshold: 6

        property bool didDrag: false

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                didDrag = false
            }
        }

        onPositionChanged: function(mouse) {
            if (mouseArea.drag.active) {
                if (!root.isDragging) {
                    root.isDragging = true
                    didDrag = true
                }
            }
        }

        onReleased: function(mouse) {
            if (root.isDragging) {
                root.isDragging = false
                var currentCoord = root.isVertical ? root.y : root.x
                var newIdx = Math.max(0, Math.min(root.totalCount - 1, Math.round(currentCoord / 46)))
                if (newIdx !== root.itemIndex) {
                    root.moveRequested(root.itemIndex, newIdx)
                } else {
                    root.x = root.isVertical ? 0 : (root.itemIndex * 46)
                    root.y = root.isVertical ? (root.itemIndex * 46) : 0
                }
            }
        }

        onClicked: function(mouse) {
            if (didDrag) return
            if (mouse.button === Qt.LeftButton) {
                launchBounce.restart()
                root.itemLeftClicked(root.itemData)
                if (root.itemData && root.itemData.isRunning) {
                    var win = (root.itemData.windows && root.itemData.windows.length > 0)
                        ? root.itemData.windows[0]
                        : { address: (root.itemData.addresses && root.itemData.addresses[0]) || "", workspaceId: null }

                    // If already active and multiple windows exist, cycle to next window
                    if (root.itemData.isActive && root.itemData.windows && root.itemData.windows.length > 1) {
                        win = root.itemData.windows[1]
                    }

                    var cmd = ""
                    if (win.workspaceId !== null && win.workspaceId !== undefined) {
                        cmd += "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + win.workspaceId + "\" })") + " ; "
                    }
                    if (win.address) {
                        cmd += "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ window = \"address:" + win.address + "\" })")
                    }
                    if (cmd.length > 0) {
                        Util.execDetached(cmd)
                    }
                } else if (root.itemData) {
                    var execTarget = root.itemData.appClass ? (root.itemData.appClass + ".desktop") : (root.itemData.exec + ".desktop")
                    Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(execTarget) + " || uwsm-app -- " + root.itemData.exec)
                }
            } else if (mouse.button === Qt.RightButton) {
                root.itemRightClicked(root.itemData, root)
            }
        }
    }
}
