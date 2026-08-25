import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel
import "components"

Item {
    id: root

    property var itemData: null
    property int itemIndex: 0
    property int totalCount: 1
    property string barPosition: "bottom"
    property var shell: null
    property real slotSize: 42
    property real iconBaseSize: 24
    property int systemBorderSize: Style.normalBorderWidth > 0 ? Style.normalBorderWidth : 2
    property int systemRounding: Style.cornerRadius > 0 ? Style.cornerRadius : 12
    property bool isSelected: false
    property bool isMergeTarget: false
    property bool isEditMode: false
    property int dockDragActiveIndex: -1
    readonly property bool isAnyDragging: dockDragActiveIndex >= 0 || isDragging
    property bool showBadges: true

    signal itemLeftClicked(var itemData)
    signal itemRightClicked(var itemData, var itemItem)
    signal moveRequested(int fromIndex, int toIndex)
    signal mergeRequested(int fromIndex, int targetIndex)
    signal dragHoverChanged(int fromIndex, int targetIndex, bool isMergeIntent)
    signal editModeRequested()
    signal editModeExitRequested()
    signal togglePinRequested(string appId)
    signal dissolveRequested(string stackId)
    signal originalAppLaunched(string appId)
    signal dragStarted(int fromIndex)

    readonly property int badgeCount: (root.itemData && typeof root.itemData.badgeCount === "number") ? root.itemData.badgeCount : 0
    property int lastBadgeCount: 0

    onBadgeCountChanged: {
        if (badgeCount > lastBadgeCount && badgeCount > 0) {
            clickEffectAnim.restart()
        }
        lastBadgeCount = badgeCount
    }

    readonly property bool isVertical: barPosition === "left" || barPosition === "right"

    width: slotSize
    height: slotSize
    z: isDragging ? 100 : (isSelected ? 60 : (mouseArea.containsMouse ? 50 : 1))

    property bool isDragging: false
    property bool isMergeActive: false
    property int iconRevision: 0
    property bool iconsReady: true

    // Dynamic Real-time Theme-aware Icon Resolution
    function resolveIcon(itemObj) {
        if (!itemObj) return Quickshell.iconPath("application-x-executable", true)
        var raw = (typeof itemObj === "string") ? itemObj : (itemObj.rawIcon || itemObj.icon || itemObj.appId || itemObj.id || "")
        if (!raw) return Quickshell.iconPath("application-x-executable", true)
        if (raw.indexOf("://") >= 0) return raw
        if (raw.indexOf("/") === 0) return "file://" + raw

        var cands = (typeof itemObj === "string")
            ? DockModel.getCandidates(itemObj, itemObj, itemObj)
            : DockModel.getCandidates(itemObj.rawIcon, itemObj.icon, itemObj.appId || itemObj.id)

        for (var i = 0; i < cands.length; i++) {
            var c = cands[i]
            if (shell && shell.appLibrary && typeof shell.appLibrary.iconSource === "function") {
                var src = shell.appLibrary.iconSource(c)
                if (src && src.length > 0 && src.indexOf("application-x-executable") === -1) {
                    return src
                }
            }
            var qs = Quickshell.iconPath(c, false)
            if (qs && qs.length > 0 && qs.indexOf("application-x-executable") === -1) {
                return qs
            }
        }

        return Quickshell.iconPath("application-x-executable", true)
    }

    // Clear, steady Merge Target Halo (stays perfectly still while hovered)
    Rectangle {
        id: mergeTargetHalo
        anchors.centerIn: parent
        width: root.slotSize - 6
        height: root.slotSize - 6
        radius: root.systemRounding
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        border.width: root.systemBorderSize
        border.color: Color.accent
        visible: opacity > 0
        opacity: root.isMergeTarget ? 1.0 : 0.0
        scale: root.isMergeTarget ? 1.04 : 0.92
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        z: 0
    }

    property real clickScaleFactor: 1.0
    property real clickLiftY: 0

    // Bouncy macOS-style physical press response
    ParallelAnimation {
        id: clickEffectAnim
        running: false
        NumberAnimation {
            target: root
            property: "clickScaleFactor"
            from: 0.88
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
        }
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "clickLiftY"
                to: (root.isVertical ? 0 : (root.barPosition === "bottom" ? -4 : 4))
                duration: 90
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "clickLiftY"
                to: 0
                duration: 130
                easing.type: Easing.OutBounce
            }
        }
    }

    // Independent drag offset so root.x and root.y bindings are NEVER broken
    Item {
        id: dragOffset
        x: 0
        y: 0
    }

    // Clamped drag offset for visual rendering (strictly confined within dock surface boundaries)
    readonly property real clampedDragOffsetX: root.isVertical ? 0 : Math.max(-root.itemIndex * root.slotSize, Math.min((root.totalCount - 1 - root.itemIndex) * root.slotSize, dragOffset.x))
    readonly property real clampedDragOffsetY: root.isVertical ? Math.max(-root.itemIndex * root.slotSize, Math.min((root.totalCount - 1 - root.itemIndex) * root.slotSize, dragOffset.y)) : 0

    // Main animated icon wrapper (smooth, buttery rail motion)
    Item {
        id: iconWrapper
        x: (parent.width - width) / 2 + root.clampedDragOffsetX
        y: Math.round((parent.height - height) / 2) - 1 + root.clampedDragOffsetY + root.clickLiftY
        width: root.iconBaseSize
        height: root.iconBaseSize
        z: 1

        scale: (root.isDragging ? 1.15 : (root.isEditMode ? 0.82 : (root.isMergeTarget ? 0.94 : (mouseArea.pressed ? 0.92 : (mouseArea.containsMouse ? 1.10 : 1.0))))) * root.clickScaleFactor
        opacity: root.iconsReady ? (root.isDragging ? 0.92 : 1.0) : 0.0

        Behavior on scale {
            enabled: !clickEffectAnim.running
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Normal Single App Icon (Instantly react to rawIcon theme swaps, crisp HiDPI rasterization)
        Image {
            id: appIcon
            visible: root.itemData && !root.itemData.isStack
            anchors.centerIn: parent
            width: root.iconBaseSize
            height: root.iconBaseSize
            fillMode: Image.PreserveAspectFit
            cache: false
            source: (root.iconRevision, root.resolveIcon(root.itemData))
            sourceSize: Qt.size(Math.max(128, width * 4 * Screen.devicePixelRatio), Math.max(128, height * 4 * Screen.devicePixelRatio))
            asynchronous: false
            mipmap: true
            smooth: true
            antialiasing: true
        }

        // Folder Custom Symbol Icon (Optically centered vector glyph with smooth anti-aliased rotation)
        DockGlyph {
            id: stackSymbolText
            visible: root.itemData && root.itemData.isStack === true && root.itemData.icon && root.itemData.icon !== "grid" && root.itemData.icon !== "folder" && root.itemData.icon !== "󰕰"
            anchors.centerIn: parent
            width: root.iconBaseSize
            height: root.iconBaseSize
            text: (root.itemData && root.itemData.icon) ? root.itemData.icon : ""
            fontFamily: Style.font.family
            fontSize: 20
            color: Color.accent
        }

        // Folder Mini-Grid (Shown when icon is "grid", "folder", "󰕰" or not set)
        Grid {
            id: stackGrid
            visible: root.itemData && root.itemData.isStack === true && (!root.itemData.icon || root.itemData.icon === "grid" || root.itemData.icon === "folder" || root.itemData.icon === "󰕰")
            anchors.centerIn: parent
            readonly property int totalSubs: (root.itemData && root.itemData.subApps) ? root.itemData.subApps.length : 0
            readonly property bool is3x3: totalSubs > 4
            columns: is3x3 ? 3 : 2
            spacing: is3x3 ? 1.5 : 2

            readonly property int cellWidth: is3x3
                ? Math.max(6, Math.floor((root.iconBaseSize - 4) / 3))
                : Math.max(9, Math.floor((root.iconBaseSize - 3) / 2))

            Repeater {
                model: (root.itemData && root.itemData.subApps) ? root.itemData.subApps.slice(0, stackGrid.is3x3 ? 9 : 4) : []
                Image {
                    width: stackGrid.cellWidth
                    height: stackGrid.cellWidth
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    source: (root.iconRevision, root.resolveIcon(modelData))
                    sourceSize: Qt.size(Math.max(64, width * 4 * Screen.devicePixelRatio), Math.max(64, height * 4 * Screen.devicePixelRatio))
                    mipmap: true
                    smooth: true
                    antialiasing: true
                }
            }
        }

        // Silky smooth, organic wiggle animation
        SequentialAnimation {
            id: jiggleAnim
            running: root.isDragging || root.isEditMode
            loops: Animation.Infinite

            NumberAnimation {
                target: iconWrapper
                property: "rotation"
                to: -3.8
                duration: 105
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: iconWrapper
                property: "rotation"
                to: 3.8
                duration: 105
                easing.type: Easing.InOutSine
            }
        }

        NumberAnimation {
            id: resetRotation
            target: iconWrapper
            property: "rotation"
            to: 0.0
            duration: 150
            easing.type: Easing.OutCubic
            running: !root.isDragging && !root.isEditMode && iconWrapper.rotation !== 0.0
        }
    }

    // Long press timer for Edit Mode activation (450ms)
    Timer {
        id: longPressTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (!root.isDragging) {
                mouseArea.didLongPress = true
                root.editModeRequested()
            }
        }
    }

    property int previewTopIndex: -1
    property bool isWheelScrolling: false

    Timer {
        id: wheelCursorTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.isWheelScrolling = false
        }
    }

    readonly property int realActiveTopIndex: (root.itemData && typeof root.itemData.activeTopIndex === "number") ? root.itemData.activeTopIndex : 0

    readonly property int effectiveTopIndex: {
        var total = (root.itemData && root.itemData.toplevels) ? root.itemData.toplevels.length : 0
        if (total === 0) return 0
        if (root.previewTopIndex >= 0 && root.previewTopIndex < total) return root.previewTopIndex
        return root.realActiveTopIndex
    }

    Timer {
        id: previewResetTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (!mouseArea.containsMouse) {
                root.previewTopIndex = -1
            }
        }
    }

    // 0. iOS / macOS-Style Theme Notification Badge with Count (Anchored to top-right of iconWrapper)
    NotificationBadge {
        anchors.top: iconWrapper.top
        anchors.topMargin: -2
        anchors.right: iconWrapper.right
        anchors.rightMargin: -2
        count: root.badgeCount
        hasUrgent: (root.itemData && !!root.itemData.hasUrgent)
        isSuppressed: root.isEditMode || root.isAnyDragging || !root.showBadges
    }

    // 1. Pin / Unpin Glyph (Centered directly above scaled iconWrapper, hidden while dragging)
    Item {
        id: pinBadge
        visible: root.isEditMode && !root.isAnyDragging && root.itemData && !root.itemData.isStack
        anchors.horizontalCenter: iconWrapper.horizontalCenter
        anchors.bottom: iconWrapper.top
        anchors.bottomMargin: -5
        width: 16
        height: 14
        z: 200

        DockGlyph {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            text: "•"
            fontFamily: Style.font.family
            fontSize: 11
            color: (root.itemData && root.itemData.isPinned)
                ? Color.accent
                : (pinBadgeMouse.containsMouse ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.45))

            scale: pinBadgeMouse.containsMouse ? 1.35 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: pinBadgeMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: (root.isAnyDragging || root.isDragging || mouseArea.drag.active) ? Qt.BlankCursor : Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.editModeExitRequested()
                    return
                }
                if (root.itemData && !root.itemData.isStack) {
                    root.togglePinRequested(root.itemData.appId)
                }
            }
        }
    }

    // 2. Dissolve Folder Glyph (Centered directly above scaled iconWrapper, hidden while dragging)
    Item {
        id: dissolveBadge
        visible: root.isEditMode && !root.isAnyDragging && root.itemData && root.itemData.isStack
        anchors.horizontalCenter: iconWrapper.horizontalCenter
        anchors.bottom: iconWrapper.top
        anchors.bottomMargin: -5
        width: 16
        height: 14
        z: 200

        DockGlyph {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            text: "-"
            fontFamily: Style.font.family
            fontSize: 16
            color: dissolveBadgeMouse.containsMouse ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.85)

            scale: dissolveBadgeMouse.containsMouse ? 1.25 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: dissolveBadgeMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: (root.isAnyDragging || root.isDragging || mouseArea.drag.active) ? Qt.BlankCursor : Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.editModeExitRequested()
                    return
                }
                if (root.itemData && root.itemData.isStack) {
                    root.dissolveRequested(root.itemData.id)
                }
            }
        }
    }

    // 3. Multi-instance Duplicate Status Capsule (Sliding window viewport)
    Rectangle {
        id: duplicateCapsule
        visible: root.iconsReady && !root.isEditMode && root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        readonly property int totalWindows: (root.itemData && root.itemData.toplevels) ? root.itemData.toplevels.length : 0
        readonly property int winCount: Math.min(totalWindows, 3)

        function getSlotWindowIndex(slotIdx) {
            if (totalWindows <= 3) {
                return slotIdx
            }
            var cur = root.effectiveTopIndex
            if (cur === 0 || cur === 1) {
                return slotIdx
            }
            if (cur === totalWindows - 1) {
                if (slotIdx === 0) return totalWindows - 2
                if (slotIdx === 1) return totalWindows - 1
                return 0
            }
            if (slotIdx === 0) return cur - 1
            if (slotIdx === 1) return cur
            return cur + 1
        }

        x: Math.round((parent.width - width) / 2 + root.clampedDragOffsetX)
        y: parent.height - height - 2 + root.clampedDragOffsetY
        z: root.isDragging ? 101 : 1

        height: 6
        width: Math.max(18, 12 + winCount * 5)
        radius: height / 2

        color: Color.composed("popups.background", "popups.background-alpha", Color.background, 0.92)
        antialiasing: true
        smooth: true

        Row {
            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: duplicateCapsule.winCount
                Rectangle {
                    readonly property int targetWinIdx: duplicateCapsule.getSlotWindowIndex(index)
                    readonly property bool isAppActive: (root.itemData && root.itemData.isActive === true)
                    readonly property bool isPreviewing: (root.previewTopIndex >= 0)
                    readonly property bool isSlotHighlighted: (isAppActive || isPreviewing) && (targetWinIdx === root.effectiveTopIndex)
                    readonly property bool isOriginalApp: (targetWinIdx === 0)

                    width: isOriginalApp ? 9.0 : (isSlotHighlighted ? 3.5 : 2.5)
                    height: 2.5
                    radius: 1.25
                    color: isSlotHighlighted ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, isOriginalApp ? 0.45 : 0.28)
                    antialiasing: true
                    smooth: true

                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
        }
    }

    // 4. Running / Active Application Indicator (Single instance)
    Rectangle {
        id: runningDot
        visible: root.iconsReady && !root.isEditMode && root.itemData && root.itemData.isRunning && (!root.itemData.toplevels || root.itemData.toplevels.length <= 1)
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        x: Math.round((parent.width - width) / 2 + root.clampedDragOffsetX)
        y: parent.height - height - 3 + root.clampedDragOffsetY
        z: root.isDragging ? 101 : 1

        height: 2
        width: root.itemData.isActive ? 10 : 4
        radius: 1
        color: root.itemData.isActive ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.6)
        antialiasing: true
        smooth: true

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    function cycleDuplicate(forward) {
        if (!root.itemData || root.itemData.isStack || !root.itemData.isRunning || !root.itemData.toplevels) return
        var len = root.itemData.toplevels.length
        if (len <= 1) return

        root.isWheelScrolling = true
        wheelCursorTimer.restart()
        previewResetTimer.stop()
        var curIdx = root.effectiveTopIndex
        var nextIdx = forward ? ((curIdx + 1) % len) : ((curIdx - 1 + len) % len)
        root.previewTopIndex = nextIdx
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: (root.isDragging || mouseArea.drag.active || root.dockDragActiveIndex >= 0 || root.isAnyDragging || root.isWheelScrolling) ? Qt.BlankCursor : (root.isEditMode ? Qt.PointingHandCursor : Qt.ArrowCursor)

        drag.target: dragOffset
        drag.axis: root.isVertical ? Drag.YAxis : Drag.XAxis
        // Allow free mouse movement across the full screen while dragging along the rail
        drag.minimumX: -99999
        drag.maximumX: 99999
        drag.minimumY: -99999
        drag.maximumY: 99999
        drag.threshold: 6

        property bool didDrag: false
        property bool didLongPress: false

        focus: containsMouse

        onEntered: {
            mouseArea.forceActiveFocus()
        }

        Keys.onRightPressed: function(event) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2) {
                root.cycleDuplicate(true)
                event.accepted = true
            }
        }

        Keys.onLeftPressed: function(event) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2) {
                root.cycleDuplicate(false)
                event.accepted = true
            }
        }

        Keys.onTabPressed: function(event) {
            if (root.itemData) {
                clickEffectAnim.restart()
                DockModel.launchApp(root.shell, root.itemData, Util)
                event.accepted = true
            }
        }

        Keys.onReturnPressed: function(event) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2 && root.previewTopIndex >= 0) {
                var top = root.itemData.toplevels[root.previewTopIndex]
                if (top && typeof top.activate === "function") {
                    top.activate()
                    root.previewTopIndex = -1
                    event.accepted = true
                }
            }
        }

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                didDrag = false
                didLongPress = false
                longPressTimer.restart()
            }
        }

        onPositionChanged: function(mouse) {
            if (root.isWheelScrolling) {
                root.isWheelScrolling = false
            }
            if (mouseArea.drag.active) {
                longPressTimer.stop()
                if (!root.isDragging) {
                    root.isDragging = true
                    root.dragStarted(root.itemIndex)
                }
                // Enforce strict 1D rail axis lock (zero orthogonal wobble)
                if (root.isVertical) {
                    dragOffset.x = 0
                } else {
                    dragOffset.y = 0
                }

                var rawOffset = root.isVertical ? dragOffset.y : dragOffset.x
                var currentOffset = Math.max(-root.itemIndex * root.slotSize, Math.min((root.totalCount - 1 - root.itemIndex) * root.slotSize, rawOffset))
                var absolutePos = root.itemIndex * root.slotSize + currentOffset

                var targetIdx = Math.max(0, Math.min(root.totalCount - 1, Math.round(absolutePos / root.slotSize)))
                var slotCenter = targetIdx * root.slotSize
                var distFromSlotCenter = absolutePos - slotCenter

                var canMerge = root.itemData && !root.itemData.isStack
                var isMerge = false

                if (canMerge && targetIdx !== root.itemIndex) {
                    if (targetIdx > root.itemIndex) {
                        isMerge = (distFromSlotCenter >= -22 && distFromSlotCenter <= 0)
                    } else {
                        isMerge = (distFromSlotCenter <= 22 && distFromSlotCenter >= 0)
                    }
                }

                // Outer edge insert: dragging all the way to the far outer edges opens the rail slot
                if ((targetIdx === 0 && absolutePos <= 8) || (targetIdx === root.totalCount - 1 && absolutePos >= (root.totalCount - 1) * root.slotSize - 8)) {
                    isMerge = false
                }

                root.isMergeActive = isMerge
                root.dragHoverChanged(root.itemIndex, targetIdx, isMerge)
            }
        }

        onReleased: function(mouse) {
            longPressTimer.stop()
            if (root.isDragging) {
                root.isDragging = false
                var rawOffset = root.isVertical ? dragOffset.y : dragOffset.x
                var currentOffset = Math.max(-root.itemIndex * root.slotSize, Math.min((root.totalCount - 1 - root.itemIndex) * root.slotSize, rawOffset))
                var absolutePos = root.itemIndex * root.slotSize + currentOffset
                var targetIdx = Math.max(0, Math.min(root.totalCount - 1, Math.round(absolutePos / root.slotSize)))
                var slotCenter = targetIdx * root.slotSize
                var distFromSlotCenter = absolutePos - slotCenter

                var canMerge = root.itemData && !root.itemData.isStack
                var isMerge = false

                if (canMerge && targetIdx !== root.itemIndex) {
                    if (targetIdx > root.itemIndex) {
                        isMerge = (distFromSlotCenter >= -22 && distFromSlotCenter <= 0)
                    } else {
                        isMerge = (distFromSlotCenter <= 22 && distFromSlotCenter >= 0)
                    }
                }

                if ((targetIdx === 0 && absolutePos <= 8) || (targetIdx === root.totalCount - 1 && absolutePos >= (root.totalCount - 1) * root.slotSize - 8)) {
                    isMerge = false
                }

                if (targetIdx !== root.itemIndex) {
                    if (isMerge) {
                        root.mergeRequested(root.itemIndex, targetIdx)
                    } else {
                        root.moveRequested(root.itemIndex, targetIdx)
                    }
                }

                root.isMergeActive = false
                dragOffset.x = 0
                dragOffset.y = 0
                root.dragHoverChanged(root.itemIndex, -1, false)
            }
        }

        onExited: {
            longPressTimer.stop()
            root.isWheelScrolling = false
            previewResetTimer.restart()
        }

        onCanceled: {
            longPressTimer.stop()
            didLongPress = false
            if (root.isDragging) {
                root.isDragging = false
                root.isMergeActive = false
                dragOffset.x = 0
                dragOffset.y = 0
                root.dragHoverChanged(root.itemIndex, -1, false)
            }
        }

        onWheel: function(wheel) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2) {
                if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) {
                    root.cycleDuplicate(true)
                    wheel.accepted = true
                } else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0) {
                    root.cycleDuplicate(false)
                    wheel.accepted = true
                }
            }
        }

        onClicked: function(mouse) {
            longPressTimer.stop()
            if (didDrag || didLongPress) {
                didLongPress = false
                return
            }

            // Middle Click (Wheel Button click) -> Immediately launch a duplicate
            if (mouse.button === Qt.MiddleButton) {
                clickEffectAnim.restart()
                if (root.itemData) {
                    DockModel.launchApp(root.shell, root.itemData, Util)
                }
                return
            }

            if (mouse.button === Qt.LeftButton) {
                clickEffectAnim.restart()
                if (root.isEditMode) {
                    if (root.itemData && root.itemData.isStack) {
                        root.itemLeftClicked(root.itemData)
                    }
                    return
                }
                if (root.itemData && root.itemData.isStack) {
                    root.itemLeftClicked(root.itemData)
                    return
                }
                if (root.itemData) {
                    // 1. If not running, launch it
                    if (!root.itemData.isRunning || !root.itemData.toplevels || root.itemData.toplevels.length === 0) {
                        var launchId = root.itemData.desktopId || root.itemData.appId || ""
                        root.originalAppLaunched(launchId)
                        DockModel.launchApp(root.shell, root.itemData, Util)
                        return
                    }

                    // 2. If running: activate chosen window (LMB focuses/switches, Middle Click creates duplicates)
                    var tops = root.itemData.toplevels
                    var targetWindowIdx = root.effectiveTopIndex
                    if (targetWindowIdx < 0 || targetWindowIdx >= tops.length) targetWindowIdx = 0

                    var chosenWindow = tops[targetWindowIdx]
                    if (chosenWindow && typeof chosenWindow.activate === "function") {
                        chosenWindow.activate()
                    }
                    root.previewTopIndex = -1
                }
            } else if (mouse.button === Qt.RightButton) {
                clickEffectAnim.restart()
                if (root.isEditMode) {
                    root.editModeExitRequested()
                    return
                }
                // Right click only opens menu for Folders (Stacks) to customize folder icon
                if (root.itemData && root.itemData.isStack) {
                    root.itemRightClicked(root.itemData, root)
                }
            }
        }
    }
}
