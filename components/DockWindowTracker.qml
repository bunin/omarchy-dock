import QtQuick
import Quickshell.Io
import "DockModel.js" as DockModel

Item {
    id: tracker

    required property var toplevelManager
    required property var hyprland
    required property var util

    signal refreshRequested()
    signal iconRefreshRequested()
    signal focusRequested(string address)

    // Persistent stable chronological window registry (never reordered on focus or workspace switch)
    property var knownWindows: []
    property string pendingFocusAppId: ""
    property double pendingFocusTimestamp: 0

    function requestFocusOnLaunch(appId) {
        var clean = DockModel.stripDesktop(appId || "").toLowerCase()
        if (!clean) return
        tracker.pendingFocusAppId = clean
        tracker.pendingFocusTimestamp = Date.now()
    }

    function syncKnownWindows() {
        var live = tracker.toplevelManager && tracker.toplevelManager.toplevels ? tracker.toplevelManager.toplevels.values : []
        var nextKnown = []
        // 1. Preserve existing known windows in their original creation order if still alive
        for (var i = 0; i < tracker.knownWindows.length; i++) {
            var k = tracker.knownWindows[i]
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

        var unchanged = nextKnown.length === tracker.knownWindows.length
        if (unchanged) {
            for (var m = 0; m < nextKnown.length; m++) {
                if (nextKnown[m] !== tracker.knownWindows[m]) {
                    unchanged = false
                    break
                }
            }
        }
        if (!unchanged) {
            tracker.knownWindows = nextKnown
        }
        return tracker.knownWindows
    }

    function isFastTerminal(id) {
        return ["foot", "ghostty", "kitty", "alacritty", "wezterm"].indexOf(String(id || "")) !== -1
    }

    function refreshSoon() {
        minimizeRefreshTimer.restart()
    }

    property double lastWindowOpenTime: 0
    property double lastTerminalOpenTime: 0

    Process {
        id: cliScannerProc
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/dock-minimize.py").toString().replace(/^file:\/\//, ""), "scan-cli"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var apps = JSON.parse(text)
                    if (Array.isArray(apps)) {
                        DockModel.setDetectedCliApps(apps)
                        tracker.refreshRequested()
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: iconScannerProc
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/dock-minimize.py").toString().replace(/^file:\/\//, ""), "scan-icons"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var icons = JSON.parse(text)
                    if (icons && typeof icons === "object") {
                        DockModel.setDiskIcons(icons)
                        tracker.iconRefreshRequested()
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: iconScanDebounceTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (!iconScannerProc.running) {
                iconScannerProc.running = true
            }
        }
    }

    function requestIconScan() {
        iconScanDebounceTimer.restart()
    }

    Timer {
        id: terminalSettleTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (Date.now() - tracker.lastTerminalOpenTime < 2000) {
                cliScannerProc.running = true
            }
            tracker.refreshRequested()
        }
    }

    Timer {
        id: titleChangeDebounceTimer
        interval: 250
        repeat: false
        onTriggered: tracker.refreshRequested()
    }

    Timer {
        id: minimizeRefreshTimer
        interval: 65
        repeat: false
        onTriggered: tracker.refreshRequested()
    }

    Connections {
        target: tracker.toplevelManager ? tracker.toplevelManager.toplevels : null
        function onValuesChanged() {
            var live = tracker.toplevelManager && tracker.toplevelManager.toplevels ? tracker.toplevelManager.toplevels.values : []
            var hasNewTerm = false
            for (var i = 0; i < live.length; i++) {
                var t = live[i]
                if (t && tracker.isFastTerminal(t.appId)) {
                    if (tracker.knownWindows.indexOf(t) === -1) {
                        hasNewTerm = true
                        break
                    }
                }
            }
            if (hasNewTerm) {
                tracker.lastTerminalOpenTime = Date.now()
                cliScannerProc.running = true
                terminalSettleTimer.restart()
            } else if (Date.now() - tracker.lastTerminalOpenTime < 150) {
                terminalSettleTimer.restart()
            } else {
                tracker.refreshRequested()
            }
        }
    }

    Connections {
        target: tracker.toplevelManager
        function onActiveToplevelChanged() {
            if (Date.now() - tracker.lastTerminalOpenTime < 150) {
                terminalSettleTimer.restart()
            } else {
                tracker.refreshRequested()
            }
        }
    }

    Connections {
        target: tracker.hyprland
        function onActiveToplevelChanged() {
            if (Date.now() - tracker.lastTerminalOpenTime < 150) {
                terminalSettleTimer.restart()
            } else {
                tracker.refreshRequested()
            }
        }
        function onRawEvent(event) {
            if (!event) return
            var name = String(event.name || "")
            if (name === "windowtitle" || name === "windowtitlev2") {
                if (Date.now() - tracker.lastWindowOpenTime < 2000) {
                    tracker.refreshRequested()
                } else {
                    titleChangeDebounceTimer.restart()
                }
                return
            }
            if (name === "movewindow" || name === "movewindowv2" || name === "activewindow" || name === "activewindowv2" || name === "closewindow" || name === "workspace" || name === "workspacev2" || name === "focusedmon") {
                tracker.refreshRequested()
                return
            }
            if (name === "openwindow") {
                tracker.lastWindowOpenTime = Date.now()
                tracker.requestIconScan()
                var openArgs = String(event.args || "")
                var openParts = openArgs.split(",")
                var openClass = openParts.length >= 3 ? openParts[2].trim().toLowerCase() : ""
                var isTerm = tracker.isFastTerminal(openClass)

                if (isTerm) {
                    tracker.lastTerminalOpenTime = Date.now()
                    cliScannerProc.running = true
                    terminalSettleTimer.restart()
                } else {
                    tracker.refreshRequested()
                }

                if (tracker.pendingFocusAppId) {
                    if (Date.now() - tracker.pendingFocusTimestamp > 8000) {
                        tracker.pendingFocusAppId = ""
                        return
                    }
                    if (openParts.length >= 3) {
                        var addr = openParts[0].trim()
                        var winClass = openParts[2].trim().toLowerCase()
                        var pending = tracker.pendingFocusAppId.toLowerCase()
                        var normClass = winClass.replace(/[^a-z0-9]/g, "")
                        var normPending = pending.replace(/[^a-z0-9]/g, "")
                        if (winClass === pending || (normPending.length > 0 && (normClass.indexOf(normPending) !== -1 || normPending.indexOf(normClass) !== -1))) {
                            tracker.pendingFocusAppId = ""
                            var cleanAddr = (addr.indexOf("0x") === 0) ? addr : ("0x" + addr)
                            if (/^0x[0-9a-f]+$/i.test(cleanAddr)) {
                                tracker.focusRequested(cleanAddr)
                            }
                        }
                    }
                }
            }
        }
    }
}
