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
    property bool detectedBarTransparent: false

    // Live bar position (only used to position the dock on the opposite side of the screen)
    property string barPosition: {
        if (shell && shell.bar && shell.bar.position) return shell.bar.position
        if (shell && shell.barConfig && shell.barConfig.position) return shell.barConfig.position
        return detectedBarPosition
    }
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"

    // Live Bar & Tray Transparency Tracking (Auto-syncs dock with bar & tray glassmorphism)
    readonly property bool isBarTransparent: {
        if (shell && shell.bar && shell.bar.transparent !== undefined) return (shell.bar.transparent === true)
        if (shell && shell.barConfig && shell.barConfig.transparent !== undefined) return (shell.barConfig.transparent === true)
        return detectedBarTransparent
    }

    // Static Standard Dock Geometry (Strictly stable, no jumping/twitching on window state)
    readonly property real slotSize: 42
    readonly property real iconBaseSize: 24

    // Live 1D Rail Displacement for Main Dock Bar
    property int dockDragActiveIndex: -1
    property int dockDragTargetIndex: -1
    property int currentMergeTargetIndex: -1

    function getDockVisualSlot(itemIdx, dragIdx, targetIdx) {
        if (dragIdx < 0 || targetIdx < 0 || dragIdx === targetIdx) return itemIdx;
        if (itemIdx === dragIdx) return dragIdx;
        if (dragIdx < targetIdx) {
            if (itemIdx > dragIdx && itemIdx <= targetIdx) return itemIdx - 1;
        } else {
            if (itemIdx >= targetIdx && itemIdx < dragIdx) return itemIdx + 1;
        }
        return itemIdx;
    }

    // Live 2D Rail Displacement inside Folder Grid
    property int folderDragActiveIndex: -1
    property int folderDragTargetIndex: -1

    function getFolderVisualSlot(itemIdx, dragIdx, targetIdx) {
        if (dragIdx < 0 || targetIdx < 0 || dragIdx === targetIdx) return itemIdx;
        if (itemIdx === dragIdx) return dragIdx;
        if (dragIdx < targetIdx) {
            if (itemIdx > dragIdx && itemIdx <= targetIdx) return itemIdx - 1;
        } else {
            if (itemIdx >= targetIdx && itemIdx < dragIdx) return itemIdx + 1;
        }
        return itemIdx;
    }

    // Direct IPC handler for rosakodu.dock target
    IpcHandler {
        target: "rosakodu.dock"
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
        root.activeStackItem = null
        root.dockDragActiveIndex = -1
        root.dockDragTargetIndex = -1
        root.currentMergeTargetIndex = -1
        root.folderDragActiveIndex = -1
        root.folderDragTargetIndex = -1
    }

    function toggle() {
        root.opened = !root.opened
        root.activeMenuItem = null
        root.activeStackItem = null
        root.dockDragActiveIndex = -1
        root.dockDragTargetIndex = -1
        root.currentMergeTargetIndex = -1
        root.folderDragActiveIndex = -1
        root.folderDragTargetIndex = -1
    }

    function toggleStack(item, index) {
        root.activeMenuItem = null
        if (!item) {
            root.activeStackItem = null
            return
        }
        var itemId = item.id || item.appId || ""
        if (root.activeStackItem && (root.activeStackItem.id === itemId || root.activeStackItem.appId === itemId || root.activeStackItemIndex === index)) {
            root.activeStackItem = null
        } else {
            root.activeStackItemIndex = index
            if (item.isStack) {
                root.activeStackItem = item
            }
        }
    }

    // Persistent stable chronological window registry (never reordered on focus or workspace switch)
    property var knownWindows: []
    property string pendingFocusAppId: ""
    property double pendingFocusTimestamp: 0

    function requestFocusOnLaunch(appId) {
        var clean = DockModel.stripDesktop(appId || "").toLowerCase()
        if (!clean) return
        root.pendingFocusAppId = clean
        root.pendingFocusTimestamp = Date.now()
    }

    function syncKnownWindows() {
        var live = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []
        var nextKnown = []
        // 1. Preserve existing known windows in their original creation order if still alive
        for (var i = 0; i < root.knownWindows.length; i++) {
            var k = root.knownWindows[i]
            for (var j = 0; j < live.length; j++) {
                if (live[j] === k) {
                    nextKnown.push(k)
                    break
                }
            }
        }
        // 2. Append newly opened windows to the end
        for (var l = 0; l < live.length; l++) {
            var cand = live[l]
            if (cand && nextKnown.indexOf(cand) === -1) {
                nextKnown.push(cand)
            }
        }
        root.knownWindows = nextKnown
        return root.knownWindows
    }

    function activateAppWindow(appId, winIndex) {
        root.syncKnownWindows()
        var tops = root.knownWindows
        var matched = []
        for (var i = 0; i < tops.length; i++) {
            var t = tops[i]
            if (t && DockModel.matchToplevel(t, appId, null)) {
                matched.push(t)
            }
        }
        if (winIndex >= 0 && winIndex < matched.length && matched[winIndex] && matched[winIndex].activate) {
            matched[winIndex].activate()
        }
    }

    // Deterministic Right-Click Menu Toggle (Only for Folders / Stacks icon selection)
    function toggleMenu(item, index, fromFolder) {
        if (!item || !item.isStack) {
            root.activeMenuItem = null
            return
        }
        var appId = item.appId || item.id || ""
        if (root.activeMenuItem && root.activeMenuItem.appId === appId) {
            root.activeMenuItem = null
        } else {
            root.activeStackItem = null
            root.isMenuFromFolder = false
            root.activeMenuItemIndex = index
            root.activeMenuItem = item
        }
    }

    // Standalone plugin lifecycle: enabled by default, disabled ONLY if in disabledPlugins
    function updatePluginEnabled() {
        var reg = root.pluginRegistry || (shell ? shell.pluginRegistry : null)
        if (reg && typeof reg.isEnabled === "function") {
            root.pluginEnabled = reg.isEnabled("rosakodu.dock")
            return
        }
        try {
            var raw = shellConfigFile.text()
            if (raw && raw.length > 0) {
                var cfg = JSON.parse(raw)
                if (cfg) {
                    if (Array.isArray(cfg.disabledPlugins) && cfg.disabledPlugins.indexOf("rosakodu.dock") !== -1) {
                        root.pluginEnabled = false
                        return
                    }
                    if (Array.isArray(cfg.plugins)) {
                        for (var p = 0; p < cfg.plugins.length; p++) {
                            if (cfg.plugins[p] && (cfg.plugins[p].id === "rosakodu.dock" || cfg.plugins[p] === "rosakodu.dock")) {
                                root.pluginEnabled = true
                                return
                            }
                        }
                    }
                    if (cfg.bar && cfg.bar.layout) {
                        for (var s in cfg.bar.layout) {
                            var arr = cfg.bar.layout[s] || []
                            for (var k = 0; k < arr.length; k++) {
                                var entry = arr[k]
                                if (entry && (entry.id === "rosakodu.dock" || entry === "rosakodu.dock")) {
                                    root.pluginEnabled = true
                                    return
                                }
                            }
                        }
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
                if (cfg && cfg.bar) {
                    if (cfg.bar.position) root.detectedBarPosition = cfg.bar.position
                    if (cfg.bar.transparent !== undefined) root.detectedBarTransparent = (cfg.bar.transparent === true)
                }
            } catch(e) {}
        }
        onFileChanged: {
            reload()
            root.updatePluginEnabled()
            try {
                var cfg = JSON.parse(text())
                if (cfg && cfg.bar) {
                    if (cfg.bar.position) root.detectedBarPosition = cfg.bar.position
                    if (cfg.bar.transparent !== undefined) root.detectedBarTransparent = (cfg.bar.transparent === true)
                }
            } catch(e) {}
            root.refreshLayers()
        }
    }

    // Autohide Dock & Folder Settings Configuration
    property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/dock-settings.json"
    property bool dockEnabled: true
    property bool autohide: false
    property bool showFolderTitles: true
    property bool isDockHovered: false
    readonly property bool isDockActive: root.isDockHovered || root.isStackOpen || root.isMenuOpen || (root.dockDragActiveIndex >= 0)
    readonly property bool shouldSlideOut: root.autohide && !root.isDockActive

    onDockEnabledChanged: {
        if (!dockEnabled) {
            root.activeStackItem = null
            root.activeMenuItem = null
            root.isEditMode = false
        }
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.readSettings()
        onFileChanged: { reload(); root.readSettings() }
    }

    function readSettings() {
        try {
            var txt = settingsFile.text()
            if (txt && txt.trim().length > 0) {
                var s = JSON.parse(txt)
                if (s && s.dockEnabled !== undefined) {
                    root.dockEnabled = (s.dockEnabled === true)
                }
                if (s && s.autohide !== undefined) {
                    root.autohide = (s.autohide === true)
                }
                if (s && s.showFolderTitles !== undefined) {
                    root.showFolderTitles = (s.showFolderTitles === true)
                }
            }
        } catch(e) {}
    }

    Timer {
        id: settingsWatcher
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            settingsFile.reload()
            root.readSettings()
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
    }

    onBarPositionChanged: {
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

    // Unified Edit Mode State (Jiggle Mode across dock and open folders)
    property bool isEditMode: false

    function closeAppWindows(appIdOrItem) {
        if (!appIdOrItem) return
        var toplevels = []
        if (typeof appIdOrItem === "string") {
            for (var i = 0; i < root.dockItems.length; i++) {
                if (root.dockItems[i].appId === appIdOrItem && root.dockItems[i].toplevels) {
                    toplevels = root.dockItems[i].toplevels
                    break
                }
            }
        } else if (appIdOrItem.toplevels) {
            toplevels = appIdOrItem.toplevels
        }
        for (var t = 0; t < toplevels.length; t++) {
            if (toplevels[t].close) toplevels[t].close()
        }
    }

    // Right-Click Menu State
    property var activeMenuItem: null
    property int activeMenuItemIndex: 0
    property bool isMenuFromFolder: false
    property int activeMenuItemFolderIndex: 0
    readonly property bool isMenuOpen: activeMenuItem !== null

    property var activeStackItem: null
    property int activeStackItemIndex: 0
    property bool isEditingFolderTitle: false
    readonly property bool isStackOpen: activeStackItem !== null

    onActiveStackItemChanged: {
        if (activeStackItem) {
            stackCard.forceActiveFocus()
        } else {
            root.isEditingFolderTitle = false
        }
    }

    // Pinned apps persistence
    property string userPinnedPath: Quickshell.env("HOME") + "/.config/omarchy/dock-pinned.json"
    property int iconRevision: 0
    property var pinnedIds: []
    property var dockItems: []
    property var appRows: (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : []
    readonly property real itemsCount: Math.max(1, root.dockItems.length)

    // Curated available symbols for folder icon personalization (Clean monochrome vector glyphs)
    readonly property var availableFolderIcons: ["󰉋", "󰒓", "󰞷", "󰝚", "󰊴", "󰏘", "󰭹", "󰖟", "󰕧", "󰈔", "󰍹", "󰖩", "󰌾", "♥"]

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
                if (src && src.length > 0 && src !== Quickshell.iconPath("application-x-executable", true)) {
                    return src
                }
            }
            var qs = Quickshell.iconPath(c, true)
            if (qs && qs.length > 0 && qs !== Quickshell.iconPath("application-x-executable", true)) {
                return qs
            }
        }

        if (shell && shell.appLibrary && typeof shell.appLibrary.iconSource === "function") {
            var f = shell.appLibrary.iconSource(cands[0])
            if (f && f.length > 0) return f
        }
        var f2 = Quickshell.iconPath(cands[0], true)
        if (f2 && f2.length > 0) return f2
        return Quickshell.iconPath("application-x-executable", true)
    }

    // Exact Geometric Horizontal Center for Stack Popup Card (100% centered over folder icon in dock)
    readonly property real calculatedStackLeft: {
        var screenW = dockWindow.screen ? dockWindow.screen.width : 1920
        var dockW = root.isVertical ? (root.slotSize + 4) : Math.max(root.slotSize + 4, root.itemsCount * root.slotSize + 8)
        var dockLeft = (screenW - dockW) / 2
        var iconCenterX = dockLeft + 4 + root.activeStackItemIndex * root.slotSize + (root.slotSize / 2)
        var cardW = stackCard.width
        return Math.round(Math.max(6, Math.min(screenW - cardW - 6, iconCenterX - cardW / 2)))
    }

    readonly property real calculatedStackTop: {
        var screenH = dockWindow.screen ? dockWindow.screen.height : 1080
        var dockH = root.isVertical ? Math.max(root.slotSize + 4, root.itemsCount * root.slotSize + 8) : (root.slotSize + 4)
        var dockTop = (screenH - dockH) / 2
        var iconCenterY = dockTop + 4 + root.activeStackItemIndex * root.slotSize + (root.slotSize / 2)
        var cardH = stackCard.height
        return Math.round(Math.max(6, Math.min(screenH - cardH - 6, iconCenterY - cardH / 2)))
    }

    function refresh() {
        root.pinnedIds = DockModel.parsePinned(userPinnedFile.text() || "")
        root.refreshLayers()
        root.updatePluginEnabled()
        root.updateDockItems()
        return "ok"
    }

    // Coalescing debounce timer to prevent signal storm while keeping UI instantaneous
    Timer {
        id: batchUpdateTimer
        interval: 16
        repeat: false
        onTriggered: root.doUpdateDockItems()
    }

    function updateDockItems() {
        batchUpdateTimer.restart()
    }

    function doUpdateDockItems() {
        root.syncKnownWindows()
        var toplevels = root.knownWindows
        var active = ToplevelManager.activeToplevel
        var lib = root.shell ? root.shell.appLibrary : null
        var allEntries = (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values && DesktopEntries.applications.values.length > 0) ? DesktopEntries.applications.values : root.appRows
        root.dockItems = DockModel.buildDockItems(root.pinnedIds, toplevels, active, allEntries, lib)

        // Refresh active stack item contents if open
        if (root.activeStackItem) {
            var found = false
            for (var i = 0; i < root.dockItems.length; i++) {
                var it = root.dockItems[i]
                if (it && (it.id === root.activeStackItem.id || it.appId === root.activeStackItem.appId)) {
                    if (it.isStack && it.subApps && it.subApps.length >= 2) {
                        root.activeStackItem = it
                        root.activeStackItemIndex = i
                        found = true
                    }
                    break
                }
            }
            if (!found) {
                root.activeStackItem = null
                root.folderDragActiveIndex = -1
                root.folderDragTargetIndex = -1
            }
        }

        // Refresh active menu item (multi-window menu) if open
        if (root.activeMenuItem && !root.activeMenuItem.isStack && root.activeMenuItem.windows) {
            var mAppId = root.activeMenuItem.appId
            var mWinList = []
            for (var mw = 0; mw < toplevels.length; mw++) {
                var mTop = toplevels[mw]
                if (mTop && DockModel.matchToplevel(mTop, mAppId, null)) {
                    var mActive = (active && mTop === active)
                    mWinList.push({
                        index: mWinList.length,
                        title: mTop.title || root.activeMenuItem.name || "",
                        isActive: !!mActive
                    })
                }
            }
            if (mWinList.length === 0) {
                root.activeMenuItem = null
            } else {
                root.activeMenuItem = {
                    id: root.activeMenuItem.id,
                    appId: root.activeMenuItem.appId,
                    name: root.activeMenuItem.name,
                    icon: root.activeMenuItem.icon,
                    rawIcon: root.activeMenuItem.rawIcon,
                    isStack: false,
                    windows: mWinList
                }
            }
        }
    }

    onPinnedIdsChanged: updateDockItems()
    onAppRowsChanged: updateDockItems()
    onShellChanged: {
        root.appRows = (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : []
        root.updateDockItems()
        root.checkAndApplyTheme()
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { root.updateDockItems() }
    }

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() { root.updateDockItems() }
    }

    Connections {
        target: (typeof Hyprland !== "undefined") ? Hyprland : null
        function onActiveToplevelChanged() { root.updateDockItems() }
        function onRawEvent(event) {
            if (!event || !root.pendingFocusAppId) return
            var name = String(event.name || "")
            if (name === "openwindow") {
                if (Date.now() - root.pendingFocusTimestamp > 8000) {
                    root.pendingFocusAppId = ""
                    return
                }
                var args = String(event.args || "")
                var parts = args.split(",")
                if (parts.length >= 3) {
                    var addr = parts[0].trim()
                    var winClass = parts[2].trim().toLowerCase()
                    var pending = root.pendingFocusAppId.toLowerCase()
                    var normClass = winClass.replace(/[^a-z0-9]/g, "")
                    var normPending = pending.replace(/[^a-z0-9]/g, "")
                    if (winClass === pending || (normPending.length > 0 && (normClass.indexOf(normPending) !== -1 || normPending.indexOf(normClass) !== -1))) {
                        root.pendingFocusAppId = ""
                        var cleanAddr = (addr.indexOf("0x") === 0) ? addr : ("0x" + addr)
                        Util.execDetached("hyprctl dispatch focuswindow address:" + cleanAddr)
                    }
                }
            }
        }
    }

    Connections {
        target: Color
        function onAccentChanged() {
            if (shell && shell.appLibrary && typeof shell.appLibrary.refreshIcons === "function") {
                shell.appLibrary.refreshIcons()
            }
            root.appRows = (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : []
            root.doUpdateDockItems()
        }
        function onForegroundChanged() { root.doUpdateDockItems() }
        function onBackgroundChanged() { root.doUpdateDockItems() }
    }

    Connections {
        target: Style
        function onCornerRadiusChanged() {
            root.systemRounding = Style.cornerRadius > 0 ? Style.cornerRadius : 12
            root.doUpdateDockItems()
        }
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            root.appRows = (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : (DesktopEntries.applications.values || [])
            root.iconRevision++
            root.updateDockItems()
        }
    }

    Connections {
        target: shell ? shell.appLibrary : null
        enabled: target !== null
        function onAppsChanged() {
            root.appRows = shell.appLibrary.sortedEntries("")
            root.iconRevision++
            root.updateDockItems()
        }
        function onIconIndexChanged() {
            root.iconRevision++
            root.doUpdateDockItems()
        }
    }

    FileView {
        id: themeWatcher
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (shell && shell.appLibrary && typeof shell.appLibrary.refreshIcons === "function") {
                shell.appLibrary.refreshIcons()
            }
            root.appRows = (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : []
            root.iconRevision++
            root.doUpdateDockItems()
        }
    }

    property bool isGtkSettingsLoaded: false

    FileView {
        id: gtkSettingsFile
        path: Quickshell.env("HOME") + "/.config/gtk-3.0/settings.ini"
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.isGtkSettingsLoaded = true
            root.checkAndApplyTheme()
        }
        onFileChanged: {
            root.isGtkSettingsLoaded = true
            root.checkAndApplyTheme()
        }
    }

    readonly property string configuredIconTheme: {
        var txt = gtkSettingsFile.text()
        if (!txt) return ""
        var m = txt.match(/gtk-icon-theme-name\s*=\s*([^\r\n]+)/)
        return m ? m[1].trim() : ""
    }

    readonly property bool hasCustomIconTheme: {
        var t = root.configuredIconTheme.toLowerCase()
        return t.length > 0 && t !== "hicolor" && t !== "adwaita" && t !== "gnome"
    }

    property bool isPinnedLoaded: false
    property bool iconsReady: false
    property bool isDockVisualReady: false

    function checkAndApplyTheme() {
        if (root.iconsReady) return

        var txt = gtkSettingsFile.text()
        if (!txt || txt.trim().length === 0) {
            return
        }

        var m = txt.match(/gtk-icon-theme-name\s*=\s*([^\r\n]+)/)
        if (!m) {
            return
        }

        var themeName = m[1].trim()
        var isCustom = themeName.length > 0 && themeName.toLowerCase() !== "hicolor" && themeName.toLowerCase() !== "adwaita" && themeName.toLowerCase() !== "gnome"

        // 1. В первую очередь — проверка сторонних иконок темы, если тема установлена
        if (isCustom) {
            if (shell && shell.appLibrary && shell.appLibrary.iconIndex) {
                var keys = Object.keys(shell.appLibrary.iconIndex)
                if (keys && keys.length > 50) {
                    var curThemeLower = themeName.toLowerCase()
                    var hasThemeIcons = false
                    for (var i = 0; i < keys.length; i++) {
                        var pth = shell.appLibrary.iconIndex[keys[i]]
                        if (pth && pth.toLowerCase().indexOf(curThemeLower) >= 0) {
                            hasThemeIcons = true
                            break
                        }
                    }
                    if (hasThemeIcons) {
                        root.iconRevision++
                        root.doUpdateDockItems()
                        root.iconsReady = true
                        return
                    }
                }
            }
            return
        }

        // 2. Если сторонней темы нет — отображаем стандартные системные иконки
        root.doUpdateDockItems()
        root.iconsReady = true
    }

    Timer {
        id: themePollTimer
        interval: 50
        running: !root.iconsReady
        repeat: true
        onTriggered: root.checkAndApplyTheme()
    }

    // Защитный таймер: если поиск сторонней темы затянулся (экстремальный сбой), показываем стандартные
    Timer {
        id: iconsSafetyTimer
        interval: 15000
        running: !root.iconsReady
        repeat: false
        onTriggered: {
            if (!root.iconsReady) {
                root.iconRevision++
                root.doUpdateDockItems()
                root.iconsReady = true
            }
        }
    }

    // Задержка показа дока после поднятия плитки окон Hyprland (220мс на анимацию тайлинга)
    Timer {
        id: dockVisualAppearTimer
        interval: 220
        running: root.iconsReady && !root.isDockVisualReady
        repeat: false
        onTriggered: {
            root.isDockVisualReady = true
        }
    }

    Connections {
        target: (shell && shell.appLibrary) ? shell.appLibrary : null
        function onIconIndexChanged() {
            root.checkAndApplyTheme()
        }
        function onAppsChanged() {
            root.iconRevision++
            root.doUpdateDockItems()
        }
    }

    Component.onCompleted: {
        try {
            var scTxt = shellConfigFile.text()
            if (scTxt && scTxt.trim().length > 0) {
                var sc = JSON.parse(scTxt)
                if (sc && sc.bar) {
                    if (sc.bar.position) root.detectedBarPosition = sc.bar.position
                    if (sc.bar.transparent !== undefined) root.detectedBarTransparent = (sc.bar.transparent === true)
                }
            }
        } catch(e) {}
        try {
            var txt = userPinnedFile.text()
            if (txt && txt.trim().length > 0) {
                var parsed = DockModel.parsePinned(txt)
                if (parsed && parsed.length > 0) {
                    root.pinnedIds = parsed
                    root.isPinnedLoaded = true
                }
            }
        } catch(e) {}
        try {
            var stxt = settingsFile.text()
            if (stxt && stxt.trim().length > 0) {
                var s = JSON.parse(stxt)
                if (s && s.dockEnabled !== undefined) root.dockEnabled = (s.dockEnabled === true)
                if (s && s.autohide !== undefined) root.autohide = (s.autohide === true)
                if (s && s.showFolderTitles !== undefined) root.showFolderTitles = (s.showFolderTitles === true)
            }
        } catch(e) {}
        if (shell && shell.appLibrary && typeof shell.appLibrary.refreshIcons === "function") {
            shell.appLibrary.refreshIcons()
        }
        root.doUpdateDockItems()
    }

    FileView {
        id: userPinnedFile
        path: root.userPinnedPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            var txt = text()
            if (txt && txt.trim().length > 0) {
                var parsed = DockModel.parsePinned(txt)
                root.pinnedIds = parsed
                root.isPinnedLoaded = true
                root.doUpdateDockItems()
            } else {
                root.isPinnedLoaded = true
            }
        }
        onLoadFailed: {
            root.isPinnedLoaded = true
            root.doUpdateDockItems()
        }
        onFileChanged: userPinnedFile.reload()
    }

    function savePinned() {
        var json = DockModel.serializePinned(root.pinnedIds)
        userPinnedFile.setText(json + "\n")
    }

    function setPinned(next) {
        root.pinnedIds = next
        root.savePinned()
        root.doUpdateDockItems()
    }

    readonly property var activeToplevel: ToplevelManager.activeToplevel

    // 1. Outside-click dismissal for Context Menu (closes ONLY the menu)
    HyprlandFocusGrab {
        id: menuGrab
        active: root.isMenuOpen
        windows: [menuWindow]
        onCleared: {
            root.activeMenuItem = null
        }
    }

    // 3. Outside-click & Escape dismissal for Edit Mode
    HyprlandFocusGrab {
        id: editGrab
        active: root.isEditMode && !root.isStackOpen && !root.isMenuOpen
        windows: [dockWindow]
        onCleared: {
            root.isEditMode = false
        }
    }

    onIsEditModeChanged: {
        if (isEditMode) {
            dockSurface.forceActiveFocus()
        }
    }

    onIsStackOpenChanged: {
        if (isStackOpen) {
            stackCard.forceActiveFocus()
        }
    }

    onIsMenuOpenChanged: {
        if (isMenuOpen) {
            menuCard.forceActiveFocus()
            if (root.activeMenuItem && root.activeMenuItem.isStack) {
                var curIcon = root.activeMenuItem.icon || "grid"
                var foundIdx = root.availableFolderIcons.indexOf(curIcon)
                menuCard.selectedIndex = (foundIdx >= 0) ? foundIdx : 0
            } else {
                menuCard.selectedIndex = -1
            }
        }
    }

    // 1. The Main Solid Dock Window
    PanelWindow {
        id: dockWindow
        visible: root.opened && root.pluginEnabled && root.dockEnabled && root.isPinnedLoaded && !remapTimer.running

        WlrLayershell.namespace: "omarchy-dock"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.isEditMode ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: (root.opened && root.pluginEnabled && root.dockEnabled && root.isPinnedLoaded && visible && (!root.autohide || root.isDockActive)) ? ExclusionMode.Auto : ExclusionMode.Ignore
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

        implicitWidth: root.isVertical ? (root.slotSize + 8) : Math.max(root.slotSize + 8, root.itemsCount * root.slotSize + 14)
        implicitHeight: root.isVertical ? Math.max(root.slotSize + 8, root.itemsCount * root.slotSize + 14) : (root.slotSize + 8)

        HoverHandler {
            id: dockHoverHandler
            onHoveredChanged: {
                if (hovered) {
                    autohideLeaveTimer.stop()
                    root.isDockHovered = true
                } else {
                    autohideLeaveTimer.restart()
                }
            }
        }

        // 1.5-second delay before dock autohides when cursor leaves
        Timer {
            id: autohideLeaveTimer
            interval: 1500
            repeat: false
            onTriggered: {
                if (!dockHoverHandler.hovered) {
                    root.isDockHovered = false
                }
            }
        }

        // Main Visual Dock Card
        Rectangle {
            id: dockSurface
            anchors.centerIn: parent
            width: root.isVertical ? (root.slotSize + 4) : Math.max(root.slotSize + 4, root.itemsCount * root.slotSize + 8)
            height: root.isVertical ? Math.max(root.slotSize + 4, root.itemsCount * root.slotSize + 8) : (root.slotSize + 4)
            visible: root.opened && root.pluginEnabled && root.dockEnabled && root.isPinnedLoaded && !remapTimer.running
            opacity: root.isDockVisualReady ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            focus: root.isEditMode

            Keys.onEscapePressed: function(event) {
                event.accepted = true
                if (root.isStackOpen) {
                    root.activeStackItem = null
                }
                root.isEditMode = false
            }

            color: root.isBarTransparent
                ? Util.alpha(Color.bar.background, 0.25)
                : Color.bar.background
            border.width: root.isBarTransparent ? 0 : root.systemBorderSize
            border.color: root.isBarTransparent ? "transparent" : Color.accent
            radius: root.systemRounding
            antialiasing: true
            smooth: true

            Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
            Behavior on border.color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
            Behavior on border.width { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: (root.dockDragActiveIndex >= 0) ? Qt.BlankCursor : (root.isEditMode ? Qt.PointingHandCursor : Qt.ArrowCursor)
                onClicked: {
                    root.isEditMode = false
                    root.activeMenuItem = null
                    root.activeStackItem = null
                }
            }

            transform: Translate {
                id: autohideTranslate
                x: {
                    if (!root.autohide || !root.shouldSlideOut) return 0
                    if (root.barPosition === "right") return -56
                    if (root.barPosition === "left") return 56
                    return 0
                }
                y: {
                    if (!root.autohide || !root.shouldSlideOut) return 0
                    if (root.barPosition === "top") return 56
                    if (root.barPosition === "bottom") return -56
                    return 0
                }
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }

            Behavior on radius { NumberAnimation { duration: 200 } }

            Item {
                id: dockContent
                anchors.centerIn: parent
                width: root.isVertical ? root.slotSize : (root.itemsCount * root.slotSize)
                height: root.isVertical ? (root.itemsCount * root.slotSize) : root.slotSize

                Repeater {
                    model: root.dockItems

                    DockItem {
                        itemData: modelData
                        itemIndex: index
                        totalCount: root.itemsCount
                        barPosition: root.barPosition
                        shell: root.shell
                        slotSize: root.slotSize
                        iconBaseSize: root.iconBaseSize
                        iconRevision: root.iconRevision
                        iconsReady: root.iconsReady
                        systemBorderSize: root.systemBorderSize
                        systemRounding: root.systemRounding
                        isSelected: (!root.isMenuFromFolder && root.activeMenuItem && (root.activeMenuItem.appId === modelData.appId || root.activeMenuItem.id === modelData.id)) || (root.activeStackItem && (root.activeStackItem.id === modelData.id || root.activeStackItem.appId === modelData.appId))
                        isMergeTarget: (root.currentMergeTargetIndex === index)

                        // 1D Live Rail Displacement (Smooth, buttery glide along the track)
                        readonly property int visualSlot: (root.dockDragActiveIndex === index) ? index : root.getDockVisualSlot(index, root.dockDragActiveIndex, root.dockDragTargetIndex)
                        x: root.isVertical ? 0 : (visualSlot * root.slotSize)
                        y: root.isVertical ? (visualSlot * root.slotSize) : 0

                        Behavior on x {
                            enabled: root.dockDragActiveIndex >= 0 && root.dockDragActiveIndex !== index
                            NumberAnimation { duration: 380; easing.type: Easing.OutQuint }
                        }
                        Behavior on y {
                            enabled: root.dockDragActiveIndex >= 0 && root.dockDragActiveIndex !== index
                            NumberAnimation { duration: 380; easing.type: Easing.OutQuint }
                        }

                        isEditMode: root.isEditMode
                        dockDragActiveIndex: root.dockDragActiveIndex

                        onEditModeRequested: {
                            root.isEditMode = true
                            root.activeMenuItem = null
                        }

                        onEditModeExitRequested: {
                            root.isEditMode = false
                        }

                        onTogglePinRequested: function(appId) {
                            root.setPinned(DockModel.togglePinned(root.pinnedIds, appId))
                        }

                        onOriginalAppLaunched: function(appId) {
                            root.requestFocusOnLaunch(appId)
                        }

                        onDissolveRequested: function(stackId) {
                            root.setPinned(DockModel.dissolveStack(root.pinnedIds, stackId))
                            root.isEditMode = false
                        }

                        onItemLeftClicked: function(item) {
                            if (item && item.isStack) {
                                root.toggleStack(item, index)
                            } else {
                                root.activeStackItem = null
                                root.activeMenuItem = null
                                if (root.isEditMode) return
                            }
                        }

                        onItemRightClicked: function(item, targetItem) {
                            if (root.isEditMode) {
                                root.isEditMode = false
                                return
                            }
                            if (item && (item.isStack || (item.isRunning && item.toplevels && item.toplevels.length >= 2))) {
                                root.toggleMenu(item, index, false)
                            }
                        }

                        onDragHoverChanged: function(fromIdx, targetIdx, isMergeIntent) {
                            root.dockDragActiveIndex = (targetIdx >= 0) ? fromIdx : -1
                            root.dockDragTargetIndex = isMergeIntent ? -1 : targetIdx
                            root.currentMergeTargetIndex = isMergeIntent ? targetIdx : -1
                        }

                        onMoveRequested: function(fromIdx, toIdx) {
                            root.dockDragActiveIndex = -1
                            root.dockDragTargetIndex = -1
                            root.currentMergeTargetIndex = -1
                            root.setPinned(DockModel.reorderPinned(root.pinnedIds, root.dockItems, fromIdx, toIdx))
                        }

                        onMergeRequested: function(fromIdx, targetIdx) {
                            root.dockDragActiveIndex = -1
                            root.dockDragTargetIndex = -1
                            root.currentMergeTargetIndex = -1
                            root.setPinned(DockModel.mergeIntoStack(root.pinnedIds, root.dockItems, fromIdx, targetIdx))
                        }
                    }
                }
            }
        }
    }

    // 2. The Isolated Action Card Popup Overlay Window (Strictly centered above Dock, lifts tiles)
    PanelWindow {
        id: menuWindow
        visible: root.isMenuOpen && root.opened && root.pluginEnabled && root.dockEnabled

        readonly property bool isDirectDockPopup: !root.isMenuFromFolder

        WlrLayershell.namespace: "omarchy-dock-menu"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.isMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Auto
        color: "transparent"

        anchors {
            top: (!root.isVertical && root.barPosition === "bottom") ? true : (root.isVertical ? true : false)
            bottom: (!root.isVertical && root.barPosition === "top") ? true : (root.isVertical ? true : false)
            left: (root.isVertical && root.barPosition === "right") ? true : (!root.isVertical ? true : false)
            right: (root.isVertical && root.barPosition === "left") ? true : (!root.isVertical ? true : false)
        }

        margins {
            bottom: (!root.isVertical && root.barPosition === "top")
                ? (isDirectDockPopup ? (Style.gapsOut || 5) : ((Style.gapsOut || 5) + 54 + 6 + stackCard.height + 6))
                : 0
            top: (!root.isVertical && root.barPosition === "bottom")
                ? (isDirectDockPopup ? (Style.gapsOut || 5) : ((Style.gapsOut || 5) + 54 + 6 + stackCard.height + 6))
                : 0
            right: (root.isVertical && root.barPosition === "left")
                ? (isDirectDockPopup ? (Style.gapsOut || 5) : ((Style.gapsOut || 5) + 54 + 6 + stackCard.width + 6))
                : 0
            left: (root.isVertical && root.barPosition === "right")
                ? (isDirectDockPopup ? (Style.gapsOut || 5) : ((Style.gapsOut || 5) + 54 + 6 + stackCard.width + 6))
                : 0
        }

        implicitWidth: root.isVertical ? menuCard.width : (dockWindow.screen ? dockWindow.screen.width : 1920)
        implicitHeight: root.isVertical ? (dockWindow.screen ? dockWindow.screen.height : 1080) : menuCard.height

        // Dismissal MouseArea covering the entire transparent overlay area of menuWindow outside menuCard
        MouseArea {
            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                root.activeMenuItem = null
            }
        }

        // Visual Action Card (Strictly centered above the dock, Folder Icon Picker only)
        Rectangle {
            id: menuCard
            z: 1
            anchors.centerIn: parent
            focus: true

            property int selectedIndex: -1
            property bool isWheelOrKeyNav: false

            readonly property bool isFolderMenu: !!(root.activeMenuItem && (root.activeMenuItem.isStack === true || root.isMenuFromFolder))

            readonly property int totalMenuItems: {
                if (!root.activeMenuItem) return 0
                return root.availableFolderIcons.length + 1
            }

            function triggerCurrentSelection() {
                if (!root.activeMenuItem) return
                if (isFolderMenu) {
                    if (selectedIndex >= 0 && selectedIndex < root.availableFolderIcons.length) {
                        var chosenIcon = root.availableFolderIcons[selectedIndex]
                        var cur = root.activeMenuItem.icon || "grid"
                        var targetIcon = (cur === chosenIcon) ? "grid" : chosenIcon
                        root.setPinned(DockModel.setStackIcon(root.pinnedIds, root.activeMenuItem.id, targetIcon))
                    } else if (selectedIndex === root.availableFolderIcons.length) {
                        root.setPinned(DockModel.dissolveStack(root.pinnedIds, root.activeMenuItem.id))
                        root.activeStackItem = null
                    }
                }
                root.activeMenuItem = null
            }

            Keys.onLeftPressed: function(event) {
                event.accepted = true
                isWheelOrKeyNav = true
                if (totalMenuItems > 0) {
                    selectedIndex = (selectedIndex <= 0) ? (totalMenuItems - 1) : (selectedIndex - 1)
                }
            }

            Keys.onRightPressed: function(event) {
                event.accepted = true
                isWheelOrKeyNav = true
                if (totalMenuItems > 0) {
                    selectedIndex = (selectedIndex + 1) % totalMenuItems
                }
            }

            Keys.onUpPressed: function(event) {
                event.accepted = true
                isWheelOrKeyNav = true
                if (totalMenuItems > 0) {
                    selectedIndex = (selectedIndex <= 0) ? (totalMenuItems - 1) : (selectedIndex - 1)
                }
            }

            Keys.onDownPressed: function(event) {
                event.accepted = true
                isWheelOrKeyNav = true
                if (totalMenuItems > 0) {
                    selectedIndex = (selectedIndex + 1) % totalMenuItems
                }
            }

            Keys.onReturnPressed: function(event) {
                event.accepted = true
                triggerCurrentSelection()
            }

            Keys.onEnterPressed: function(event) {
                event.accepted = true
                triggerCurrentSelection()
            }

            Keys.onSpacePressed: function(event) {
                event.accepted = true
                triggerCurrentSelection()
            }

            Keys.onEscapePressed: function(event) {
                event.accepted = true
                root.activeMenuItem = null
            }

            width: root.isVertical ? 36 : Math.max(36, (root.availableFolderIcons.length + 1) * 30 + 10)
            height: !root.isVertical ? 36 : Math.max(36, (root.availableFolderIcons.length + 1) * 30 + 10)
            color: root.isBarTransparent
                ? Util.alpha(Color.popups.background, 0.45)
                : Color.popups.background
            border.width: root.isBarTransparent ? 0 : root.systemBorderSize
            border.color: root.isBarTransparent ? "transparent" : Color.accent
            radius: Math.min(10, root.systemRounding)
            antialiasing: true
            smooth: true

            Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
            Behavior on border.color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
            Behavior on border.width { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                    menuCard.isWheelOrKeyNav = true
                    if (menuCard.totalMenuItems > 0) {
                        var delta = (event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x)
                        var step = delta > 0 ? -1 : 1
                        menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.ArrowCursor
                onPositionChanged: function(mouse) {
                    menuCard.isWheelOrKeyNav = false
                }
                onWheel: function(wheel) {
                    menuCard.isWheelOrKeyNav = true
                    if (menuCard.totalMenuItems > 0) {
                        var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                        var step = delta > 0 ? -1 : 1
                        menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                    }
                }
            }

            // 1. Horizontal layout when dock is horizontal (Folder Icon Picker)
            Row {
                id: actionRow
                visible: !root.isVertical && menuCard.isFolderMenu
                anchors.centerIn: parent
                spacing: 4

                // Folder Symbols Picker List (Monochrome vector glyphs with optical centering)
                Repeater {
                    model: (!root.isMenuFromFolder && root.activeMenuItem && root.activeMenuItem.isStack) ? root.availableFolderIcons : []

                    Item {
                        id: iconChoiceBtnH
                        width: 26
                        height: 24

                        readonly property bool isCurrentIcon: {
                            if (!root.activeMenuItem) return false
                            return root.activeMenuItem.icon === modelData
                        }
                        readonly property bool isFocused: menuCard.selectedIndex === index

                        DockGlyph {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            text: modelData
                            fontFamily: Style.font.family
                            fontSize: 16
                            color: (iconChoiceBtnH.isFocused || iconChoiceBtnH.isCurrentIcon) ? Color.accent : Color.popups.text

                            scale: iconChoiceBtnH.isFocused ? 1.25 : 1.0
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: iconChoiceMouseH
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.PointingHandCursor
                            onEntered: {
                                if (!menuCard.isWheelOrKeyNav) {
                                    menuCard.selectedIndex = index
                                }
                            }
                            onPositionChanged: function(mouse) {
                                menuCard.isWheelOrKeyNav = false
                                menuCard.selectedIndex = index
                            }
                            onWheel: function(wheel) {
                                menuCard.isWheelOrKeyNav = true
                                if (menuCard.totalMenuItems > 0) {
                                    var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                                    var step = delta > 0 ? -1 : 1
                                    menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                                }
                            }
                            onClicked: {
                                if (root.activeMenuItem && root.activeMenuItem.isStack) {
                                    var cur = root.activeMenuItem.icon || "grid"
                                    var targetIcon = (cur === modelData) ? "grid" : modelData
                                    root.setPinned(DockModel.setStackIcon(root.pinnedIds, root.activeMenuItem.id, targetIcon))
                                }
                                root.activeMenuItem = null
                            }
                        }
                    }
                }

                // Divider before action buttons for folder
                Rectangle {
                    visible: !root.isMenuFromFolder && (root.activeMenuItem && root.activeMenuItem.isStack)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 14
                    color: Color.composed("popups.border", "popups.border-alpha", Color.border, 0.35)
                }

                // 3. Minus Button: Extract app from folder OR Delete entire folder at the end of the bar
                Item {
                    id: minusBtnH
                    visible: root.isMenuFromFolder || (root.activeMenuItem && root.activeMenuItem.isStack)
                    width: 26
                    height: 24

                    readonly property bool isFocused: menuCard.selectedIndex === root.availableFolderIcons.length

                    DockGlyph {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        text: "-"
                        fontFamily: Style.font.family
                        fontSize: 16
                        color: minusBtnH.isFocused ? Color.accent : Color.popups.text

                        scale: minusBtnH.isFocused ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: minusMouseH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.PointingHandCursor
                        onEntered: {
                            if (!menuCard.isWheelOrKeyNav) {
                                menuCard.selectedIndex = root.availableFolderIcons.length
                            }
                        }
                        onPositionChanged: function(mouse) {
                            menuCard.isWheelOrKeyNav = false
                            menuCard.selectedIndex = root.availableFolderIcons.length
                        }
                        onWheel: function(wheel) {
                            menuCard.isWheelOrKeyNav = true
                            if (menuCard.totalMenuItems > 0) {
                                var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                                var step = delta > 0 ? -1 : 1
                                menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                            }
                        }
                        onClicked: {
                            if (!root.activeMenuItem) return
                            if (root.activeMenuItem.isStack) {
                                root.setPinned(DockModel.dissolveStack(root.pinnedIds, root.activeMenuItem.id))
                                root.activeStackItem = null
                            } else if (root.isMenuFromFolder && root.activeStackItem) {
                                root.setPinned(DockModel.extractFromStackToDock(root.pinnedIds, root.activeStackItem.id, root.activeMenuItem.appId, root.activeStackItemIndex + 1))
                            }
                            root.activeMenuItem = null
                        }
                    }
                }
            }

            // 2. Vertical layout when dock is vertical (Folder Icon Picker)
            Column {
                id: actionCol
                visible: root.isVertical && menuCard.isFolderMenu
                anchors.centerIn: parent
                spacing: 4

                // Folder Symbols Picker List (Monochrome vector glyphs with optical centering)
                Repeater {
                    model: (!root.isMenuFromFolder && root.activeMenuItem && root.activeMenuItem.isStack) ? root.availableFolderIcons : []

                    Item {
                        id: iconChoiceBtnV
                        width: 24
                        height: 26

                        readonly property bool isCurrentIcon: {
                            if (!root.activeMenuItem) return false
                            return root.activeMenuItem.icon === modelData
                        }
                        readonly property bool isFocused: menuCard.selectedIndex === index

                        DockGlyph {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            text: modelData
                            fontFamily: Style.font.family
                            fontSize: 16
                            color: (iconChoiceBtnV.isFocused || iconChoiceBtnV.isCurrentIcon) ? Color.accent : Color.popups.text

                            scale: iconChoiceBtnV.isFocused ? 1.25 : 1.0
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: iconChoiceMouseV
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.PointingHandCursor
                            onEntered: {
                                if (!menuCard.isWheelOrKeyNav) {
                                    menuCard.selectedIndex = index
                                }
                            }
                            onPositionChanged: function(mouse) {
                                menuCard.isWheelOrKeyNav = false
                                menuCard.selectedIndex = index
                            }
                            onWheel: function(wheel) {
                                menuCard.isWheelOrKeyNav = true
                                if (menuCard.totalMenuItems > 0) {
                                    var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                                    var step = delta > 0 ? -1 : 1
                                    menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                                }
                            }
                            onClicked: {
                                if (root.activeMenuItem && root.activeMenuItem.isStack) {
                                    var cur = root.activeMenuItem.icon || "grid"
                                    var targetIcon = (cur === modelData) ? "grid" : modelData
                                    root.setPinned(DockModel.setStackIcon(root.pinnedIds, root.activeMenuItem.id, targetIcon))
                                }
                                root.activeMenuItem = null
                            }
                        }
                    }
                }

                // Divider before action buttons for folder
                Rectangle {
                    visible: !root.isMenuFromFolder && (root.activeMenuItem && root.activeMenuItem.isStack)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: 1
                    color: Color.composed("popups.border", "popups.border-alpha", Color.border, 0.35)
                }

                // 3. Minus Button: Extract app from folder OR Delete entire folder at the bottom of the column
                Item {
                    id: minusBtnV
                    visible: root.isMenuFromFolder || (root.activeMenuItem && root.activeMenuItem.isStack)
                    width: 24
                    height: 26

                    readonly property bool isFocused: menuCard.selectedIndex === root.availableFolderIcons.length

                    DockGlyph {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        text: "-"
                        fontFamily: Style.font.family
                        fontSize: 16
                        color: minusBtnV.isFocused ? Color.accent : Color.popups.text

                        scale: minusBtnV.isFocused ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: minusMouseV
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.PointingHandCursor
                        onEntered: {
                            if (!menuCard.isWheelOrKeyNav) {
                                menuCard.selectedIndex = root.availableFolderIcons.length
                            }
                        }
                        onPositionChanged: function(mouse) {
                            menuCard.isWheelOrKeyNav = false
                            menuCard.selectedIndex = root.availableFolderIcons.length
                        }
                        onWheel: function(wheel) {
                            menuCard.isWheelOrKeyNav = true
                            if (menuCard.totalMenuItems > 0) {
                                var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                                var step = delta > 0 ? -1 : 1
                                menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                            }
                        }
                        onClicked: {
                            if (!root.activeMenuItem) return
                            if (root.activeMenuItem.isStack) {
                                root.setPinned(DockModel.dissolveStack(root.pinnedIds, root.activeMenuItem.id))
                                root.activeStackItem = null
                            } else if (root.isMenuFromFolder && root.activeStackItem) {
                                root.setPinned(DockModel.extractFromStackToDock(root.pinnedIds, root.activeStackItem.id, root.activeMenuItem.appId, root.activeStackItemIndex + 1))
                            }
                            root.activeMenuItem = null
                        }
                    }
                }
            }
        }
    }

    // 3. macOS Stacks Folder Grid Overlay Window (Strictly Centered & Sized to Folder Card, lifts tiles)
    PanelWindow {
        id: stackWindow
        visible: root.isStackOpen && root.opened && root.pluginEnabled && root.dockEnabled

        WlrLayershell.namespace: "omarchy-dock-stack"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.isEditingFolderTitle
            ? WlrKeyboardFocus.Exclusive
            : (root.isStackOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
        exclusionMode: ExclusionMode.Auto
        color: "transparent"

        anchors {
            top: (!root.isVertical && root.barPosition === "bottom") ? true : (root.isVertical ? true : false)
            bottom: (!root.isVertical && root.barPosition === "top") ? true : (root.isVertical ? true : false)
            left: (root.isVertical && root.barPosition === "right") ? true : (!root.isVertical ? true : false)
            right: (root.isVertical && root.barPosition === "left") ? true : (!root.isVertical ? true : false)
        }

        margins {
            bottom: (!root.isVertical && root.barPosition === "top") ? (Style.gapsOut || 5) : 0
            top: (!root.isVertical && root.barPosition === "bottom") ? (Style.gapsOut || 5) : 0
            right: (root.isVertical && root.barPosition === "left") ? (Style.gapsOut || 5) : 0
            left: (root.isVertical && root.barPosition === "right") ? (Style.gapsOut || 5) : 0
        }

        implicitWidth: root.isVertical ? stackCard.width : (dockWindow.screen ? dockWindow.screen.width : 1920)
        implicitHeight: root.isVertical ? (dockWindow.screen ? dockWindow.screen.height : 1080) : stackCard.height

        // Dismissal MouseArea covering the entire transparent overlay area of stackWindow outside stackCard
        MouseArea {
            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                if (root.isEditingFolderTitle && typeof titleInput !== "undefined") {
                    titleInput.saveAndClose()
                }
                root.activeStackItem = null
                root.isEditMode = false
                root.isEditingFolderTitle = false
            }
        }

        // Frosted Card for Folder Contents
        Rectangle {
            id: stackCard
            z: 1
            anchors.centerIn: parent
            focus: true

            onVisibleChanged: {
                if (visible) {
                    stackCard.forceActiveFocus()
                }
            }

            Keys.onEscapePressed: function(event) {
                event.accepted = true
                if (root.isEditingFolderTitle) {
                    if (typeof titleInput !== "undefined") {
                        titleInput.text = root.activeStackItem ? root.activeStackItem.name : "Folder"
                    }
                    root.isEditingFolderTitle = false
                    stackCard.forceActiveFocus()
                    return
                }
                if (root.isEditMode) {
                    root.isEditMode = false
                }
                root.activeStackItem = null
            }

            readonly property int totalApps: (root.activeStackItem && root.activeStackItem.subApps) ? root.activeStackItem.subApps.length : 0
            readonly property int gridCols: totalApps <= 4 ? 2 : 3
            readonly property int gridRows: Math.max(1, Math.ceil(totalApps / gridCols))

            readonly property int baseGridWidth: gridCols * 50 - 6 + 24

            width: baseGridWidth
            height: (root.showFolderTitles ? 36 : 0) + (gridRows * 50 - 6) + 24

            color: root.isBarTransparent
                ? Util.alpha(Color.popups.background, 0.45)
                : Color.popups.background
            border.width: root.isBarTransparent ? 0 : root.systemBorderSize
            border.color: root.isBarTransparent ? "transparent" : Color.accent
            radius: root.systemRounding
            antialiasing: true
            smooth: true

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: (root.folderDragActiveIndex >= 0) ? Qt.BlankCursor : (root.isEditMode ? Qt.PointingHandCursor : Qt.ArrowCursor)
                onClicked: function(mouse) {
                    if (root.isEditingFolderTitle && typeof titleInput !== "undefined") {
                        titleInput.saveAndClose()
                    }
                    if (mouse.button === Qt.RightButton || mouse.button === Qt.LeftButton) {
                        root.isEditMode = false
                    }
                }
            }

            // Folder Title Header (shown when root.showFolderTitles is true)
            Item {
                id: titleContainer
                visible: root.showFolderTitles
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 24
                height: 28

                // Silky smooth wiggle animation on hover and in edit mode
                SequentialAnimation {
                    id: titleJiggleAnim
                    running: (root.isEditMode || titleHoverArea.containsMouse) && !root.isEditingFolderTitle && !titleInput.activeFocus
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: titleContainer
                        property: "rotation"
                        to: -3.8
                        duration: 105
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: titleContainer
                        property: "rotation"
                        to: 3.8
                        duration: 105
                        easing.type: Easing.InOutSine
                    }
                }

                NumberAnimation {
                    id: resetTitleRotation
                    target: titleContainer
                    property: "rotation"
                    to: 0.0
                    duration: 120
                    easing.type: Easing.OutCubic
                    running: (!root.isEditMode && !titleHoverArea.containsMouse || root.isEditingFolderTitle || titleInput.activeFocus) && titleContainer.rotation !== 0.0
                }

                readonly property real availableTitleWidth: Math.max(10, width - 16)
                readonly property bool needsMarquee: !root.isEditingFolderTitle && !titleInput.activeFocus && (titleLabel.implicitWidth > availableTitleWidth)
                readonly property real scrollDistance: Math.max(0, titleLabel.implicitWidth - availableTitleWidth)
                property real marqueeOffset: 0

                onNeedsMarqueeChanged: {
                    if (!needsMarquee) {
                        marqueeOffset = 0
                        marqueeAnim.stop()
                    } else {
                        marqueeAnim.restart()
                    }
                }

                    // Background pill (hover / edit)
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: (root.isEditingFolderTitle || titleInput.activeFocus)
                            ? Style.hoverFillFor(Color.popups.text, Color.accent)
                            : (titleHoverArea.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent")
                        border.width: (root.isEditingFolderTitle || titleInput.activeFocus) ? 1 : 0
                        border.color: Color.accent
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Marquee Animation: smooth ticker for long folder names
                    SequentialAnimation {
                        id: marqueeAnim
                        running: titleContainer.needsMarquee && stackWindow.visible
                        loops: Animation.Infinite

                        PauseAnimation { duration: 1200 }
                        NumberAnimation {
                            target: titleContainer
                            property: "marqueeOffset"
                            to: -titleContainer.scrollDistance
                            duration: Math.max(1600, titleContainer.scrollDistance * 32)
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation { duration: 1200 }
                        NumberAnimation {
                            target: titleContainer
                            property: "marqueeOffset"
                            to: 0
                            duration: Math.max(1600, titleContainer.scrollDistance * 32)
                            easing.type: Easing.InOutQuad
                        }
                    }

                    // === DISPLAY: Text Viewport with smooth marquee / ticker ===
                    Item {
                        id: titleViewport
                        anchors.centerIn: parent
                        width: titleContainer.availableTitleWidth
                        height: parent.height
                        clip: true
                        visible: !root.isEditingFolderTitle

                        Text {
                            id: titleLabel
                            x: titleContainer.needsMarquee ? titleContainer.marqueeOffset : Math.round((parent.width - implicitWidth) / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.activeStackItem ? root.activeStackItem.name : "Folder"
                            font.family: Style.font.family
                            font.pixelSize: 12
                            font.bold: true
                            color: Color.popups.text
                            elide: Text.ElideNone
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // === EDIT: TextInput с прокруткой, виден только при фокусе ===
                    TextInput {
                        id: titleInput
                        anchors.centerIn: parent
                        width: parent.width - 12
                        visible: root.isEditingFolderTitle
                        enabled: root.isEditingFolderTitle
                        focus: root.isEditingFolderTitle
                        text: root.activeStackItem ? root.activeStackItem.name : "Folder"
                        font.family: Style.font.family
                        font.pixelSize: 12
                        font.bold: true
                        color: Color.popups.text
                        selectByMouse: true
                        cursorVisible: true
                        clip: true
                        horizontalAlignment: Text.AlignHCenter

                        onVisibleChanged: {
                            if (visible && root.activeStackItem) {
                                text = root.activeStackItem.name
                                selectAll()
                                forceActiveFocus()
                            }
                        }

                        function saveAndClose() {
                            var n = text.trim() || "Folder"
                            if (root.activeStackItem) {
                                root.setPinned(DockModel.renameStack(root.pinnedIds, root.activeStackItem.id, n))
                                root.activeStackItem.name = n
                            }
                            root.isEditingFolderTitle = false
                            focus = false
                            stackCard.forceActiveFocus()
                        }

                        Keys.onReturnPressed: function(event) { event.accepted = true; saveAndClose() }
                        Keys.onEnterPressed:  function(event) { event.accepted = true; saveAndClose() }
                        Keys.onEscapePressed: function(event) {
                            event.accepted = true
                            text = root.activeStackItem ? root.activeStackItem.name : "Folder"
                            root.isEditingFolderTitle = false
                            focus = false
                            stackCard.forceActiveFocus()
                        }
                        onEditingFinished: saveAndClose()
                    }

                    MouseArea {
                        id: titleHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        visible: !root.isEditingFolderTitle
                        enabled: !root.isEditingFolderTitle
                        cursorShape: (root.folderDragActiveIndex >= 0 || titleHoverArea.containsMouse) ? Qt.BlankCursor : Qt.IBeamCursor
                        onClicked: {
                            if (root.activeStackItem) {
                                root.isEditingFolderTitle = true
                            }
                        }
                    }
                }

            // Grid of App Icons inside the Folder (Reordering restricted to 2D grid rails)
            Item {
                id: gridContainer
                anchors.top: root.showFolderTitles ? titleContainer.bottom : parent.top
                anchors.topMargin: root.showFolderTitles ? 6 : 12
                anchors.horizontalCenter: parent.horizontalCenter
                width: stackCard.gridCols * 50 - 6
                height: stackCard.gridRows * 50 - 6

                    Repeater {
                        model: (root.activeStackItem && root.activeStackItem.subApps) ? root.activeStackItem.subApps : []

                        Item {
                            id: subItemRoot
                            readonly property int totalSub: (root.activeStackItem && root.activeStackItem.subApps) ? root.activeStackItem.subApps.length : 0
                            readonly property int visualSubSlot: (root.folderDragActiveIndex === index) ? index : root.getFolderVisualSlot(index, root.folderDragActiveIndex, root.folderDragTargetIndex)
                            readonly property int slotCol: visualSubSlot % stackCard.gridCols
                            readonly property int slotRow: Math.floor(visualSubSlot / stackCard.gridCols)

                            property int subPreviewTopIndex: -1
                            property bool isSubWheelScrolling: false

                            Timer {
                                id: subWheelCursorTimer
                                interval: 1200
                                repeat: false
                                onTriggered: {
                                    subItemRoot.isSubWheelScrolling = false
                                }
                            }

                            readonly property int subRealActiveTopIndex: (modelData && typeof modelData.activeTopIndex === "number") ? modelData.activeTopIndex : 0

                            readonly property int subEffectiveTopIndex: {
                                var total = (modelData && modelData.toplevels) ? modelData.toplevels.length : 0
                                if (total === 0) return 0
                                if (subItemRoot.subPreviewTopIndex >= 0 && subItemRoot.subPreviewTopIndex < total) return subItemRoot.subPreviewTopIndex
                                return subItemRoot.subRealActiveTopIndex
                            }

                            Timer {
                                id: subPreviewResetTimer
                                interval: 1500
                                repeat: false
                                onTriggered: {
                                    if (!subMouse.containsMouse) {
                                        subItemRoot.subPreviewTopIndex = -1
                                    }
                                }
                            }

                            x: slotCol * 50
                            y: slotRow * 50
                            width: 44
                            height: 44
                            z: (root.folderDragActiveIndex === index) ? 100 : (subMouse.containsMouse ? 50 : 1)

                            Behavior on x {
                                enabled: root.folderDragActiveIndex >= 0 && root.folderDragActiveIndex !== index
                                NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
                            }
                            Behavior on y {
                                enabled: root.folderDragActiveIndex >= 0 && root.folderDragActiveIndex !== index
                                NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
                            }

                            property real subClickScaleFactor: 1.0

                            Rectangle {
                                id: subClickRipple
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: Color.accent
                                opacity: 0.0
                                scale: 0.5
                                z: 0
                            }

                            SequentialAnimation {
                                id: subClickEffectAnim
                                alwaysRunToEnd: true

                                ParallelAnimation {
                                    NumberAnimation { target: subItemRoot; property: "subClickScaleFactor"; from: 0.92; to: 1.07; duration: 130; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: subClickRipple; property: "scale"; from: 0.5; to: 1.35; duration: 240; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: subClickRipple; property: "opacity"; from: 0.65; to: 0.0; duration: 240; easing.type: Easing.OutCubic }
                                }
                                NumberAnimation { target: subItemRoot; property: "subClickScaleFactor"; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
                            }

                            // Independent Drag Offset for folder items
                            Item {
                                id: subDragOffset
                                x: 0
                                y: 0
                            }

                            Item {
                                id: subItemWrapper
                                x: (parent.width - width) / 2 + subDragOffset.x
                                y: (parent.height - height) / 2 + subDragOffset.y
                                width: 34
                                height: 34
                                scale: ((root.folderDragActiveIndex === index) ? 1.15 : (root.isEditMode ? 0.82 : (subMouse.pressed ? 0.92 : (subMouse.containsMouse ? 1.10 : 1.0)))) * subItemRoot.subClickScaleFactor
                                opacity: (root.folderDragActiveIndex === index) ? 0.92 : 1.0
                                Behavior on scale {
                                    enabled: !subClickEffectAnim.running && (subMouse.containsMouse || subMouse.pressed || root.isEditMode || root.folderDragActiveIndex >= 0)
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }

                                Image {
                                    id: subIcon
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 28
                                    fillMode: Image.PreserveAspectFit
                                    source: (root.iconRevision, root.resolveIcon(modelData))
                                    sourceSize: Qt.size(Math.max(128, 28 * 4 * Screen.devicePixelRatio), Math.max(128, 28 * 4 * Screen.devicePixelRatio))
                                    asynchronous: false
                                    mipmap: true
                                    smooth: true
                                    antialiasing: true
                                }

                                // Silky smooth, organic wiggle animation
                                SequentialAnimation {
                                    id: subJiggleAnim
                                    running: (root.folderDragActiveIndex === index) || root.isEditMode
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        target: subIcon
                                        property: "rotation"
                                        to: -3.8
                                        duration: 105
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        target: subIcon
                                        property: "rotation"
                                        to: 3.8
                                        duration: 105
                                        easing.type: Easing.InOutSine
                                    }
                                }

                                NumberAnimation {
                                    id: resetSubRotation
                                    target: subIcon
                                    property: "rotation"
                                    to: 0.0
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                    running: root.folderDragActiveIndex !== index && !root.isEditMode && subIcon.rotation !== 0.0
                                }

                                // Multi-instance duplicate capsule under subApp icon (Sliding window viewport)
                                Rectangle {
                                    id: subDuplicateCapsule
                                    visible: opacity > 0
                                    opacity: (modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2 && !root.isEditMode) ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 180 } }

                                    readonly property int totalWindows: (modelData && modelData.toplevels) ? modelData.toplevels.length : 0
                                    readonly property int winCount: Math.min(totalWindows, 3)

                                    function getSubSlotWindowIndex(slotIdx) {
                                        if (totalWindows <= 3) {
                                            return slotIdx
                                        }
                                        var cur = subItemRoot.subEffectiveTopIndex
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

                                    anchors.top: subIcon.bottom
                                    anchors.topMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter

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
                                            model: subDuplicateCapsule.winCount
                                            Rectangle {
                                                readonly property int targetWinIdx: subDuplicateCapsule.getSubSlotWindowIndex(index)
                                                readonly property bool isAppActive: (modelData && modelData.isActive === true)
                                                readonly property bool isPreviewing: (subItemRoot.subPreviewTopIndex >= 0)
                                                readonly property bool isSlotHighlighted: (isAppActive || isPreviewing) && (targetWinIdx === subItemRoot.subEffectiveTopIndex)
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

                                // Running indicator dot under subApp icon (Single instance)
                                Rectangle {
                                    id: subDot
                                    visible: opacity > 0
                                    opacity: (modelData.isRunning && (!modelData.toplevels || modelData.toplevels.length <= 1) && !subMouse.containsMouse && !root.isEditMode) ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                                    anchors.top: subIcon.bottom
                                    anchors.topMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    width: modelData.isActive ? 10 : 4
                                    height: 2
                                    radius: 1
                                    color: modelData.isActive ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.6)
                                    antialiasing: true
                                    smooth: true

                                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            // Long press timer for Edit Mode (450ms, folder only)
                            Timer {
                                id: subLongPressTimer
                                interval: 450
                                repeat: false
                                onTriggered: {
                                    if (root.activeStackItem && root.folderDragActiveIndex < 0) {
                                        subMouse.didSubLongPress = true
                                        root.isEditMode = true
                                    }
                                }
                            }

                            // Extract Glyph (Centered directly above subItemWrapper, folder only)
                            Item {
                                id: subExtractBadge
                                visible: root.activeStackItem && root.isEditMode && (root.folderDragActiveIndex < 0)
                                anchors.horizontalCenter: subItemWrapper.horizontalCenter
                                anchors.bottom: subItemWrapper.top
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
                                    color: subExtractMouse.containsMouse ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.85)

                                    scale: subExtractMouse.containsMouse ? 1.25 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: subExtractMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: (root.folderDragActiveIndex >= 0) ? Qt.BlankCursor : Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            root.isEditMode = false
                                            return
                                        }
                                        if (root.activeStackItem) {
                                            var stackId = root.activeStackItem.id
                                            var remaining = (root.activeStackItem.subApps ? root.activeStackItem.subApps.length : 0) - 1
                                            root.setPinned(DockModel.extractFromStackToDock(root.pinnedIds, stackId, modelData.appId, root.activeStackItemIndex + 1))
                                            if (remaining <= 1) {
                                                root.activeStackItem = null
                                                root.isEditMode = false
                                            }
                                        }
                                    }
                                }
                            }

                            function cycleSubDuplicate(forward) {
                                if (!modelData || !modelData.isRunning || !modelData.toplevels) return
                                var len = modelData.toplevels.length
                                if (len <= 1) return

                                subItemRoot.isSubWheelScrolling = true
                                subWheelCursorTimer.restart()
                                subPreviewResetTimer.stop()
                                var curIdx = subItemRoot.subEffectiveTopIndex
                                var nextIdx = forward ? ((curIdx + 1) % len) : ((curIdx - 1 + len) % len)
                                subItemRoot.subPreviewTopIndex = nextIdx
                            }

                            MouseArea {
                                id: subMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: (root.folderDragActiveIndex >= 0 || subMouse.drag.active || isDraggingActive || subItemRoot.isSubWheelScrolling) ? Qt.BlankCursor : (root.isEditMode ? Qt.PointingHandCursor : Qt.ArrowCursor)

                                drag.target: root.activeStackItem ? subDragOffset : null
                                drag.axis: Drag.XAndYAxis
                                drag.minimumX: - (index % stackCard.gridCols) * 50
                                drag.maximumX: (stackCard.gridCols - 1 - (index % stackCard.gridCols)) * 50
                                drag.minimumY: - Math.floor(index / stackCard.gridCols) * 50
                                drag.maximumY: (stackCard.gridRows - 1 - Math.floor(index / stackCard.gridCols)) * 50
                                drag.threshold: 6

                                property bool isDraggingActive: false
                                property bool didSubLongPress: false

                                focus: containsMouse

                                onEntered: {
                                    subMouse.forceActiveFocus()
                                }

                                Keys.onRightPressed: function(event) {
                                    if (modelData && modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2) {
                                        subItemRoot.cycleSubDuplicate(true)
                                        event.accepted = true
                                    }
                                }

                                Keys.onLeftPressed: function(event) {
                                    if (modelData && modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2) {
                                        subItemRoot.cycleSubDuplicate(false)
                                        event.accepted = true
                                    }
                                }

                                Keys.onTabPressed: function(event) {
                                    if (modelData) {
                                        subClickEffectAnim.restart()
                                        var launchMidId = modelData.desktopId || modelData.appId || ""
                                        if (root.shell && root.shell.appLibrary && typeof root.shell.appLibrary.launch === "function") {
                                            root.shell.appLibrary.launch(launchMidId, modelData.name)
                                        } else {
                                            var targetMid = launchMidId ? (launchMidId.indexOf(".desktop") !== -1 ? launchMidId : (launchMidId + ".desktop")) : (modelData.exec || "")
                                            Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(targetMid) + (modelData.exec ? (" || uwsm-app -- " + modelData.exec) : ""))
                                        }
                                        event.accepted = true
                                    }
                                }

                                Keys.onReturnPressed: function(event) {
                                    if (modelData && modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2 && subItemRoot.subPreviewTopIndex >= 0) {
                                        var top = modelData.toplevels[subItemRoot.subPreviewTopIndex]
                                        if (top && typeof top.activate === "function") {
                                            top.activate()
                                            subItemRoot.subPreviewTopIndex = -1
                                            event.accepted = true
                                        }
                                    }
                                }

                                onPressed: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        isDraggingActive = false
                                        didSubLongPress = false
                                        if (root.activeStackItem) {
                                            subLongPressTimer.restart()
                                        }
                                    }
                                }

                                onPositionChanged: function(mouse) {
                                    if (subItemRoot.isSubWheelScrolling) {
                                        subItemRoot.isSubWheelScrolling = false
                                    }
                                    if (subMouse.drag.active) {
                                        subLongPressTimer.stop()
                                        if (!isDraggingActive) {
                                            isDraggingActive = true
                                            root.folderDragActiveIndex = index
                                        }

                                        var currentPosX = (index % stackCard.gridCols) * 50 + subDragOffset.x
                                        var currentPosY = Math.floor(index / stackCard.gridCols) * 50 + subDragOffset.y

                                        var col = Math.max(0, Math.min(stackCard.gridCols - 1, Math.round(currentPosX / 50)))
                                        var row = Math.max(0, Math.min(stackCard.gridRows - 1, Math.round(currentPosY / 50)))
                                        var targetIdx = Math.max(0, Math.min(totalSub - 1, row * stackCard.gridCols + col))
                                        root.folderDragTargetIndex = targetIdx
                                    }
                                }

                                onReleased: function(mouse) {
                                    subLongPressTimer.stop()
                                    if (isDraggingActive && root.activeStackItem) {
                                        isDraggingActive = false
                                        var finalTarget = root.folderDragTargetIndex
                                        root.folderDragActiveIndex = -1
                                        root.folderDragTargetIndex = -1
                                        subDragOffset.x = 0
                                        subDragOffset.y = 0

                                        if (finalTarget >= 0 && finalTarget !== index) {
                                            root.setPinned(DockModel.reorderInStack(root.pinnedIds, root.activeStackItem.id, index, finalTarget))
                                        }
                                    }
                                }

                                onExited: {
                                    subItemRoot.isSubWheelScrolling = false
                                    subPreviewResetTimer.restart()
                                }

                                onWheel: function(wheel) {
                                    if (modelData && modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2) {
                                        if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) {
                                            subItemRoot.cycleSubDuplicate(true)
                                            wheel.accepted = true
                                        } else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0) {
                                            subItemRoot.cycleSubDuplicate(false)
                                            wheel.accepted = true
                                        }
                                    }
                                }

                                onClicked: function(mouse) {
                                    if (isDraggingActive || didSubLongPress) {
                                        didSubLongPress = false
                                        return
                                    }

                                    // Middle Click (Wheel Button click) -> Immediately launch duplicate
                                    if (mouse.button === Qt.MiddleButton) {
                                        subClickEffectAnim.restart()
                                        var launchMidId = modelData.desktopId || modelData.appId || ""
                                        if (root.shell && root.shell.appLibrary && typeof root.shell.appLibrary.launch === "function") {
                                            root.shell.appLibrary.launch(launchMidId, modelData.name)
                                        } else {
                                            var targetMid = launchMidId ? (launchMidId.indexOf(".desktop") !== -1 ? launchMidId : (launchMidId + ".desktop")) : (modelData.exec || "")
                                            Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(targetMid) + (modelData.exec ? (" || uwsm-app -- " + modelData.exec) : ""))
                                        }
                                        return
                                    }

                                    if (mouse.button === Qt.LeftButton) {
                                        subClickEffectAnim.restart()
                                        if (root.isEditMode) {
                                            return
                                        }
                                        // 1. If not running, launch it (Folder stays open!)
                                        if (!modelData.isRunning || !modelData.toplevels || modelData.toplevels.length === 0) {
                                            var launchId = modelData.desktopId || modelData.appId || ""
                                            root.requestFocusOnLaunch(launchId)
                                            if (root.shell && root.shell.appLibrary && typeof root.shell.appLibrary.launch === "function") {
                                                root.shell.appLibrary.launch(launchId, modelData.name)
                                            } else {
                                                var target = launchId ? (launchId.indexOf(".desktop") !== -1 ? launchId : (launchId + ".desktop")) : (modelData.exec || "")
                                                Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(target) + (modelData.exec ? (" || uwsm-app -- " + modelData.exec) : ""))
                                            }
                                            return
                                        }

                                        // 2. If running: activate chosen window (LMB focuses/switches)
                                        var tops = modelData.toplevels
                                        var targetIdx = subItemRoot.subEffectiveTopIndex
                                        if (targetIdx < 0 || targetIdx >= tops.length) targetIdx = 0

                                        var chosenWin = tops[targetIdx]
                                        if (chosenWin && typeof chosenWin.activate === "function") {
                                            chosenWin.activate()
                                        }
                                        subItemRoot.subPreviewTopIndex = -1
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (root.isEditMode) {
                                            root.isEditMode = false
                                            return
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

