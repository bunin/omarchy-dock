import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel

Item {
    id: root

    // Properties injected by Omarchy Shell host
    property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null

    // Dock state & Multi-source Live Bar Position Tracking
    property bool opened: true
    property bool pluginEnabled: true
    property string shellConfigPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    property string detectedBarPosition: "top"

    // Live bar position (only used to position the dock on the opposite side of the screen)
    property string barPosition: {
        if (shell && shell.bar && shell.bar.position) return shell.bar.position
        if (shell && shell.barConfig && shell.barConfig.position) return shell.barConfig.position
        return detectedBarPosition
    }
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"

    // Direct IPC handler for lotos.dock target
    IpcHandler {
        target: "lotos.dock"
        function open() { root.open(""); return "ok" }
        function close() { root.close(); return "ok" }
        function toggle() { root.toggle(); return "ok" }
        function refresh() { return root.refresh() }
    }

    // Methods called by shell.summon / shell.hide / shell.toggle
    function open(payloadJson) {
        root.opened = true
    }

    function close() {
        root.opened = false
        root.activeMenuItem = null
    }

    function toggle() {
        root.opened = !root.opened
        root.activeMenuItem = null
    }

    // Pure standalone plugin lifecycle: enabled by default, disabled only if in disabledPlugins or removed from bar
    function updatePluginEnabled() {
        var reg = root.pluginRegistry || (shell ? shell.pluginRegistry : null)
        if (reg && typeof reg.isEnabled === "function") {
            root.pluginEnabled = reg.isEnabled("lotos.dock")
            return
        }
        try {
            var raw = shellConfigFile.text()
            if (raw && raw.length > 0) {
                var cfg = JSON.parse(raw)
                if (cfg) {
                    if (Array.isArray(cfg.disabledPlugins) && cfg.disabledPlugins.indexOf("lotos.dock") !== -1) {
                        root.pluginEnabled = false
                        return
                    }
                    if (cfg.bar && cfg.bar.layout) {
                        var inLayout = false
                        for (var s in cfg.bar.layout) {
                            var arr = cfg.bar.layout[s] || []
                            for (var k = 0; k < arr.length; k++) {
                                var entry = arr[k]
                                if (entry && (entry.id === "lotos.dock" || entry === "lotos.dock")) {
                                    inLayout = true
                                    break
                                }
                            }
                        }
                        root.pluginEnabled = inLayout
                        return
                    }
                }
            }
        } catch(e) {}
        root.pluginEnabled = true
    }

    FileView {
        id: shellConfigFile
        path: root.shellConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.updatePluginEnabled()
            try {
                var cfg = JSON.parse(text())
                if (cfg && cfg.bar && cfg.bar.position) {
                    root.detectedBarPosition = cfg.bar.position
                }
            } catch(e) {}
        }
        onFileChanged: {
            reload()
            root.updatePluginEnabled()
            try {
                var cfg = JSON.parse(text())
                if (cfg && cfg.bar && cfg.bar.position) {
                    root.detectedBarPosition = cfg.bar.position
                }
            } catch(e) {}
            root.refreshLayers()
        }
    }

    Connections {
        target: root.pluginRegistry ? root.pluginRegistry : (shell ? shell.pluginRegistry : null)
        ignoreUnknownSignals: true
        function onPluginsChanged() { root.updatePluginEnabled() }
    }

    // Safe compositor unmap-remap sequence on orientation shift
    Timer {
        id: remapTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.opened && root.pluginEnabled) dockWindow.visible = true
        }
    }

    onBarPositionChanged: {
        dockWindow.visible = false
        remapTimer.restart()
    }

    // Periodic sync timer for guaranteed real-time layer alignment
    Timer {
        id: syncPollTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.refreshLayers()
        }
    }

    // Real-time Bar Position detection via Hyprland layer shell
    Process {
        id: layersProc
        running: true
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    for (var mon in data) {
                        var levels = data[mon].levels || {}
                        for (var lvl in levels) {
                            var layers = levels[lvl] || []
                            for (var i = 0; i < layers.length; i++) {
                                var l = layers[i]
                                if (l.namespace === "omarchy-bar") {
                                    var newPos = (l.w < l.h) ? (l.x === 0 ? "left" : "right") : (l.y === 0 ? "top" : "bottom")
                                    if (root.detectedBarPosition !== newPos) {
                                        root.detectedBarPosition = newPos
                                    }
                                    return
                                }
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    function refreshLayers() {
        if (!layersProc.running) layersProc.running = true
    }

    // Dynamic system tiling border size & rounding
    property int systemBorderSize: 2
    property int systemRounding: Style.cornerRadius >= 0 ? Style.cornerRadius : 12

    // Single Active Right-Click Menu State & Precise Target Index
    property var activeMenuItem: null
    property int activeMenuItemIndex: 0
    readonly property bool isMenuOpen: activeMenuItem !== null

    // Exact geometric coordinate centering for the overlay menu
    readonly property real calculatedMenuLeft: {
        var screenW = dockWindow.screen ? dockWindow.screen.width : 1920
        var dockW = dockWindow.width
        var dockLeft = (screenW - dockW) / 2
        var iconCenterX = dockLeft + 3 + root.activeMenuItemIndex * 46 + 23
        var menuW = menuWindow.implicitWidth
        var targetLeft = iconCenterX - menuW / 2
        return Math.round(Math.max(6, Math.min(screenW - menuW - 6, targetLeft)))
    }

    readonly property real calculatedMenuTop: {
        var screenH = dockWindow.screen ? dockWindow.screen.height : 1080
        var dockH = dockWindow.height
        var dockTop = (screenH - dockH) / 2
        var iconCenterY = dockTop + 3 + root.activeMenuItemIndex * 46 + 23
        var menuH = menuWindow.implicitHeight
        var targetTop = iconCenterY - menuH / 2
        return Math.round(Math.max(6, Math.min(screenH - menuH - 6, targetTop)))
    }

    Process {
        id: borderSizeProc
        running: true
        command: ["hyprctl", "getoption", "general:border_size", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    if (parsed && parsed.int !== undefined && parsed.int > 0) {
                        root.systemBorderSize = parsed.int
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: roundingProc
        running: true
        command: ["hyprctl", "getoption", "decoration:rounding", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    if (parsed && parsed.int !== undefined && parsed.int >= 0) {
                        root.systemRounding = parsed.int
                    }
                } catch(e) {}
            }
        }
    }

    function refresh() {
        pinnedApps = DockModel.loadPinnedApps(userPinnedFile.text() || "")
        refreshClients()
        refreshLayers()
        updatePluginEnabled()
        return "ok"
    }

    // Pinned apps persistence
    property string userPinnedPath: Quickshell.env("HOME") + "/.config/omarchy/dock-pinned.json"
    property var pinnedApps: DockModel.DEFAULT_PINNED.slice()
    property var rawClients: []
    property var dockItems: []

    function updateDockItems() {
        root.dockItems = DockModel.buildDockItems(root.pinnedApps, root.rawClients)
    }

    onPinnedAppsChanged: updateDockItems()
    onRawClientsChanged: updateDockItems()

    FileView {
        id: userPinnedFile
        path: root.userPinnedPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.pinnedApps = DockModel.loadPinnedApps(text())
            root.refreshClients()
        }
        onFileChanged: reload()
    }

    function savePinned() {
        var json = DockModel.savePinnedApps(pinnedApps)
        userPinnedFile.setText(json + "\n")
    }

    // Fast asynchronous Hyprland clients query
    Process {
        id: clientsProc
        running: true
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.rawClients = JSON.parse(text)
                } catch(e) {
                    root.rawClients = []
                }
            }
        }
    }

    function refreshClients() {
        if (!clientsProc.running) {
            clientsProc.running = true
        }
    }

    // Reactive bindings to window state changes in Hyprland
    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onRawEvent(event) { root.refreshClients(); root.refreshLayers() }
        function onFocusedWorkspaceChanged() { root.refreshClients(); root.activeMenuItem = null }
        function onFocusedMonitorChanged() { root.refreshClients(); root.refreshLayers() }
    }

    readonly property var activeToplevel: ToplevelManager.activeToplevel
    onActiveToplevelChanged: refreshClients()

    Component.onCompleted: {
        pinnedApps = DockModel.loadPinnedApps(userPinnedFile.text() || "")
        refreshLayers()
        refreshClients()
        updatePluginEnabled()
    }

    readonly property int itemsCount: Math.max(1, root.dockItems.length)

    // Outside-click dismissal for the action menu
    HyprlandFocusGrab {
        active: root.isMenuOpen
        windows: [menuWindow, dockWindow]
        onCleared: root.activeMenuItem = null
    }

    // 1. The Main Solid Dock Window (Permanent, strictly 46px height/width, 100% jitter-free)
    PanelWindow {
        id: dockWindow
        visible: root.opened && root.pluginEnabled && !remapTimer.running

        WlrLayershell.namespace: "lotos-dock"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: (root.opened && root.pluginEnabled && visible) ? ExclusionMode.Auto : ExclusionMode.Ignore
        color: "transparent"

        anchors {
            top: root.barPosition === "bottom"
            bottom: root.barPosition === "top"
            left: root.barPosition === "right"
            right: root.barPosition === "left"
        }

        margins {
            bottom: (!root.isVertical && root.barPosition === "top") ? (Style.gapsOut || 5) : 0
            top: (!root.isVertical && root.barPosition === "bottom") ? (Style.gapsOut || 5) : 0
            right: (root.isVertical && root.barPosition === "left") ? (Style.gapsOut || 5) : 0
            left: (root.isVertical && root.barPosition === "right") ? (Style.gapsOut || 5) : 0
        }

        // Exact, uncompromised dock dimensions (ZERO jitter on click)
        implicitWidth: root.isVertical ? 46 : (root.itemsCount * 46 + 6)
        implicitHeight: root.isVertical ? (root.itemsCount * 46 + 6) : 46

        // Main Visual Dock Card
        Rectangle {
            id: dockSurface
            anchors.fill: parent
            visible: root.opened && root.pluginEnabled && !remapTimer.running

            color: Color.composed("bar.background", "bar.background-alpha", Color.background, 0.94)
            border.width: root.systemBorderSize
            border.color: Color.accent
            radius: root.systemRounding

            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on border.color { ColorAnimation { duration: 250 } }
            Behavior on radius { NumberAnimation { duration: 250 } }

            Item {
                id: dockContent
                anchors.centerIn: parent
                width: root.isVertical ? 42 : (root.itemsCount * 46 - 4)
                height: root.isVertical ? (root.itemsCount * 46 - 4) : 42

                Repeater {
                    model: root.dockItems

                    DockItem {
                        itemData: modelData
                        itemIndex: index
                        totalCount: root.itemsCount
                        barPosition: root.barPosition
                        shell: root.shell
                        iconBaseSize: 28
                        systemBorderSize: root.systemBorderSize
                        systemRounding: root.systemRounding
                        isSelected: root.activeMenuItem && root.activeMenuItem.appClass === modelData.appClass

                        x: root.isVertical ? 0 : (index * 46)
                        y: root.isVertical ? (index * 46) : 0

                        onItemLeftClicked: function(item) {
                            root.activeMenuItem = null
                        }

                        onItemRightClicked: function(item, targetItem) {
                            if (root.activeMenuItem && root.activeMenuItem.appClass === item.appClass) {
                                root.activeMenuItem = null
                            } else {
                                root.activeMenuItemIndex = index
                                root.activeMenuItem = item
                            }
                        }

                        onMoveRequested: function(fromIdx, toIdx) {
                            root.pinnedApps = DockModel.reorderDockItem(root.pinnedApps, root.dockItems, fromIdx, toIdx)
                            root.savePinned()
                            root.refreshClients()
                        }
                    }
                }
            }
        }
    }

    // 2. The Isolated Action Card Popup Overlay Window (Floats strictly centered over the clicked icon)
    PanelWindow {
        id: menuWindow
        visible: root.isMenuOpen && root.opened && root.pluginEnabled

        WlrLayershell.namespace: "lotos-dock-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors {
            top: root.barPosition === "bottom" ? true : (root.isVertical ? true : false)
            bottom: root.barPosition === "top" ? true : false
            left: root.barPosition === "right" ? true : (!root.isVertical ? true : false)
            right: root.barPosition === "left" ? true : false
        }

        margins {
            bottom: (!root.isVertical && root.barPosition === "top") ? ((Style.gapsOut || 5) + 52) : 0
            top: (!root.isVertical && root.barPosition === "bottom") ? ((Style.gapsOut || 5) + 52) : (root.isVertical ? root.calculatedMenuTop : 0)
            right: (root.isVertical && root.barPosition === "left") ? ((Style.gapsOut || 5) + 52) : 0
            left: (root.isVertical && root.barPosition === "right") ? ((Style.gapsOut || 5) + 52) : (!root.isVertical ? root.calculatedMenuLeft : 0)
        }

        implicitWidth: root.isVertical ? 32 : (actionRow.implicitWidth + 12)
        implicitHeight: root.isVertical ? (actionCol.implicitHeight + 12) : 32

        // Visual Action Card
        Rectangle {
            anchors.fill: parent
            color: Color.composed("popups.background", "popups.background-alpha", Color.background, 0.96)
            border.width: root.systemBorderSize
            border.color: Color.accent
            radius: Math.min(10, root.systemRounding)

            // Horizontal layout when dock is horizontal
            RowLayout {
                id: actionRow
                visible: !root.isVertical
                anchors.centerIn: parent
                spacing: 4

                // ★ / ☆ Star Pin / Unpin Button
                Rectangle {
                    width: 26
                    height: 24
                    radius: Math.min(6, root.systemRounding)
                    color: pinMouseH.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: (root.activeMenuItem && root.activeMenuItem.isPinned) ? "★" : "☆"
                        font.family: Style.font.family
                        font.pixelSize: 14
                        font.bold: true
                        color: (root.activeMenuItem && root.activeMenuItem.isPinned)
                            ? Color.accent
                            : (pinMouseH.containsMouse ? Color.accent : Color.popups.text)
                    }

                    MouseArea {
                        id: pinMouseH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.activeMenuItem) return
                            root.pinnedApps = DockModel.togglePinItem(root.pinnedApps, root.activeMenuItem)
                            root.savePinned()
                            root.refreshClients()
                            root.activeMenuItem = null
                        }
                    }
                }

                // ＋ Monochrome Plus Button
                Rectangle {
                    width: 26
                    height: 24
                    radius: Math.min(6, root.systemRounding)
                    color: newMouseH.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "＋"
                        font.family: Style.font.family
                        font.pixelSize: 13
                        font.bold: true
                        color: newMouseH.containsMouse ? Color.accent : Color.popups.text
                    }

                    MouseArea {
                        id: newMouseH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeMenuItem) {
                                var item = root.activeMenuItem
                                var target = item.appClass ? (item.appClass + ".desktop") : (item.exec + ".desktop")
                                Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(target) + " || uwsm-app -- " + item.exec)
                            }
                            root.activeMenuItem = null
                        }
                    }
                }

                // ✕ Monochrome Close Button (if running)
                Rectangle {
                    visible: root.activeMenuItem && root.activeMenuItem.isRunning
                    width: 26
                    height: 24
                    radius: Math.min(6, root.systemRounding)
                    color: closeMouseH.containsMouse ? Style.hoverFillFor(Color.urgent, Color.urgent) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.family: Style.font.family
                        font.pixelSize: 11
                        font.bold: true
                        color: closeMouseH.containsMouse ? Color.urgent : Color.muted
                    }

                    MouseArea {
                        id: closeMouseH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeMenuItem && root.activeMenuItem.addresses && root.activeMenuItem.addresses.length > 0) {
                                for (var a = 0; a < root.activeMenuItem.addresses.length; a++) {
                                    Util.execDetached("hyprctl dispatch " + Util.shellQuote("hl.dsp.window.close({ address = \"" + root.activeMenuItem.addresses[a] + "\" })"))
                                }
                            }
                            root.activeMenuItem = null
                            Qt.callLater(root.refreshClients)
                        }
                    }
                }
            }

            // Vertical layout when dock is vertical
            ColumnLayout {
                id: actionCol
                visible: root.isVertical
                anchors.centerIn: parent
                spacing: 4

                // ★ / ☆ Star Pin / Unpin Button
                Rectangle {
                    width: 24
                    height: 26
                    radius: Math.min(6, root.systemRounding)
                    color: pinMouseV.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: (root.activeMenuItem && root.activeMenuItem.isPinned) ? "★" : "☆"
                        font.family: Style.font.family
                        font.pixelSize: 14
                        font.bold: true
                        color: (root.activeMenuItem && root.activeMenuItem.isPinned)
                            ? Color.accent
                            : (pinMouseV.containsMouse ? Color.accent : Color.popups.text)
                    }

                    MouseArea {
                        id: pinMouseV
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.activeMenuItem) return
                            root.pinnedApps = DockModel.togglePinItem(root.pinnedApps, root.activeMenuItem)
                            root.savePinned()
                            root.refreshClients()
                            root.activeMenuItem = null
                        }
                    }
                }

                // ＋ Monochrome Plus Button
                Rectangle {
                    width: 24
                    height: 26
                    radius: Math.min(6, root.systemRounding)
                    color: newMouseV.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "＋"
                        font.family: Style.font.family
                        font.pixelSize: 13
                        font.bold: true
                        color: newMouseV.containsMouse ? Color.accent : Color.popups.text
                    }

                    MouseArea {
                        id: newMouseV
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeMenuItem) {
                                var item = root.activeMenuItem
                                var target = item.appClass ? (item.appClass + ".desktop") : (item.exec + ".desktop")
                                Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(target) + " || uwsm-app -- " + item.exec)
                            }
                            root.activeMenuItem = null
                        }
                    }
                }

                // ✕ Monochrome Close Button (if running)
                Rectangle {
                    visible: root.activeMenuItem && root.activeMenuItem.isRunning
                    width: 24
                    height: 26
                    radius: Math.min(6, root.systemRounding)
                    color: closeMouseV.containsMouse ? Style.hoverFillFor(Color.urgent, Color.urgent) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.family: Style.font.family
                        font.pixelSize: 11
                        font.bold: true
                        color: closeMouseV.containsMouse ? Color.urgent : Color.muted
                    }

                    MouseArea {
                        id: closeMouseV
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeMenuItem && root.activeMenuItem.addresses && root.activeMenuItem.addresses.length > 0) {
                                for (var a = 0; a < root.activeMenuItem.addresses.length; a++) {
                                    Util.execDetached("hyprctl dispatch " + Util.shellQuote("hl.dsp.window.close({ address = \"" + root.activeMenuItem.addresses[a] + "\" })"))
                                }
                            }
                            root.activeMenuItem = null
                            Qt.callLater(root.refreshClients)
                        }
                    }
                }
            }
        }
    }
}
