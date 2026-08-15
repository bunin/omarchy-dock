// DockModel.js — Model & state management for Omarchy Dock

.pragma library

var DEFAULT_PINNED = [
    "org.kde.dolphin",
    "com.mitchellh.ghostty",
    "steam",
    "code",
    "google-chrome",
    "org.kde.krita"
];

function stripDesktop(id) {
    var value = String(id == null ? "" : id).trim();
    if (value.slice(-8) === ".desktop") value = value.slice(0, -8);
    return value;
}

function toArray(list) {
    if (Array.isArray(list)) return list;
    if (list && typeof list.length === "number") {
        var out = [];
        for (var i = 0; i < list.length; i++) out.push(list[i]);
        return out;
    }
    return [];
}

function parsePinned(raw) {
    var text = String(raw == null ? "" : raw).trim();
    if (!text) return DEFAULT_PINNED.slice();

    var parsed = null;
    try {
        parsed = JSON.parse(text);
    } catch (e) {
        return DEFAULT_PINNED.slice();
    }
    if (!parsed) return DEFAULT_PINNED.slice();

    var arr = [];
    if (Array.isArray(parsed)) {
        // Support legacy object format or string array format
        for (var k = 0; k < parsed.length; k++) {
            var item = parsed[k];
            if (typeof item === "string") {
                arr.push(item);
            } else if (item && typeof item === "object") {
                var c = item.appClass || item.id || item.exec || "";
                c = c.replace(/^pin_/, "");
                if (c) arr.push(c);
            }
        }
    } else if (typeof parsed === "object" && Array.isArray(parsed.pinned)) {
        arr = parsed.pinned;
    }

    if (arr.length === 0) return DEFAULT_PINNED.slice();

    var out = [];
    var seen = {};
    for (var i = 0; i < arr.length; i++) {
        var id = stripDesktop(arr[i]);
        if (!id || seen[id]) continue;
        seen[id] = true;
        out.push(id);
    }
    return out;
}

function serializePinned(pinnedIds) {
    var arr = Array.isArray(pinnedIds) ? pinnedIds : [];
    var cleaned = [];
    var seen = {};
    for (var i = 0; i < arr.length; i++) {
        var id = stripDesktop(arr[i]);
        if (!id || seen[id]) continue;
        seen[id] = true;
        cleaned.push(id);
    }
    return JSON.stringify({ pinned: cleaned }, null, 2);
}

function togglePinned(pinnedIds, appId) {
    var arr = Array.isArray(pinnedIds) ? pinnedIds.slice() : [];
    var id = stripDesktop(appId);
    if (!id) return arr;
    var idx = arr.indexOf(id);
    if (idx >= 0) arr.splice(idx, 1);
    else arr.push(id);
    return arr;
}

function isPinned(pinnedIds, appId) {
    var arr = Array.isArray(pinnedIds) ? pinnedIds : [];
    return arr.indexOf(stripDesktop(appId)) >= 0;
}

function reorderPinned(pinnedIds, dockItems, fromIndex, toIndex) {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return pinnedIds;
    if (!dockItems || fromIndex >= dockItems.length || toIndex >= dockItems.length) return pinnedIds;

    var sourceItem = dockItems[fromIndex];
    if (!sourceItem || !sourceItem.appId) return pinnedIds;

    var srcId = stripDesktop(sourceItem.appId);
    var next = [];
    for (var i = 0; i < pinnedIds.length; i++) {
        var pid = stripDesktop(pinnedIds[i]);
        if (pid !== srcId) next.push(pid);
    }

    var insertIdx = Math.max(0, Math.min(next.length, toIndex));
    next.splice(insertIdx, 0, srcId);
    return next;
}

function entryFor(appRows, appId) {
    var want = stripDesktop(appId);
    if (!want || !appRows) return null;
    for (var i = 0; i < appRows.length; i++) {
        var row = appRows[i];
        var entry = row && row.entry;
        if (!entry) continue;
        if (stripDesktop(entry.id) === want) return entry;
    }
    return null;
}

function buildDockItems(pinnedIds, toplevels, activeToplevel, appRows, appLibrary) {
    var pinned = Array.isArray(pinnedIds) ? pinnedIds : [];
    var list = toArray(toplevels);

    var runningMap = {};
    var runningOrder = [];

    var activeApp = activeToplevel ? stripDesktop(activeToplevel.appId) : "";

    for (var i = 0; i < list.length; i++) {
        var toplevel = list[i];
        if (!toplevel) continue;
        var appId = stripDesktop(toplevel.appId);
        if (!appId || appId === "quickshell" || appId === "hyprland") continue;

        if (!runningMap[appId]) {
            runningMap[appId] = {
                toplevels: [],
                isActive: false
            };
            runningOrder.push(appId);
        }
        runningMap[appId].toplevels.push(toplevel);
        if (activeApp === appId || toplevel === activeToplevel || toplevel.active === true) {
            runningMap[appId].isActive = true;
        }
    }

    function enrichItem(base) {
        var entry = entryFor(appRows, base.appId);
        if (entry && appLibrary) {
            base.name = appLibrary.entryName(entry) || base.appId;
            base.icon = appLibrary.iconSource(entry.icon) || base.appId;
        } else {
            base.name = base.appId;
            base.icon = base.appId;
        }
        return base;
    }

    var items = [];
    var seen = {};

    // 1. Pinned Apps in specified order
    for (var j = 0; j < pinned.length; j++) {
        var pid = stripDesktop(pinned[j]);
        if (!pid || seen[pid]) continue;
        seen[pid] = true;

        var runInfo = runningMap[pid];
        var isRun = runInfo && runInfo.toplevels.length > 0;
        var item = {
            id: "pin_" + pid,
            appId: pid,
            appClass: pid,
            exec: pid,
            name: pid,
            icon: pid,
            isPinned: true,
            isRunning: isRun,
            isActive: isRun ? runInfo.isActive : false,
            windowCount: isRun ? runInfo.toplevels.length : 0,
            toplevels: isRun ? runInfo.toplevels : []
        };
        items.push(enrichItem(item));
    }

    // 2. Unpinned Running Apps in order of discovery
    for (var k = 0; k < runningOrder.length; k++) {
        var rid = runningOrder[k];
        if (seen[rid]) continue;
        seen[rid] = true;

        var rInfo = runningMap[rid];
        var unpinnedItem = {
            id: "run_" + rid,
            appId: rid,
            appClass: rid,
            exec: rid,
            name: rid,
            icon: rid,
            isPinned: false,
            isRunning: true,
            isActive: rInfo.isActive,
            windowCount: rInfo.toplevels.length,
            toplevels: rInfo.toplevels
        };
        items.push(enrichItem(unpinnedItem));
    }

    return items;
}
