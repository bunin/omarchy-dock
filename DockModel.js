// DockModel.js — Model & state management for Omarchy Dock

.pragma library

var DEFAULT_PINNED = [
    { id: "kitty", appClass: "kitty", name: "Terminal", icon: "kitty", exec: "kitty" },
    { id: "chrome", appClass: "google-chrome", name: "Google Chrome", icon: "google-chrome", exec: "google-chrome-stable" },
    { id: "code", appClass: "code", name: "VS Code", icon: "com.visualstudio.code", exec: "code" },
    { id: "files", appClass: "org.gnome.Nautilus", name: "Files", icon: "org.gnome.Nautilus", exec: "nautilus" }
];

function loadPinnedApps(storedJson) {
    if (!storedJson) return DEFAULT_PINNED.slice();
    try {
        var parsed = JSON.parse(storedJson);
        if (Array.isArray(parsed) && parsed.length > 0) {
            for (var i = 0; i < parsed.length; i++) {
                if (!parsed[i].appClass) {
                    parsed[i].appClass = parsed[i].id ? parsed[i].id.replace(/^pin_/, "") : (parsed[i].exec || "app");
                }
            }
            return parsed;
        }
    } catch (e) {}
    return DEFAULT_PINNED.slice();
}

function savePinnedApps(pinnedList) {
    try {
        return JSON.stringify(pinnedList);
    } catch (e) {
        return "[]";
    }
}

function normalizeClass(cls) {
    if (!cls) return "";
    return String(cls).toLowerCase().trim()
        .replace(/^org\./, "")
        .replace(/^com\./, "")
        .replace(/^io\./, "")
        .replace(/^dev\./, "")
        .replace(/\.desktop$/, "");
}

var KNOWN_ALIASES = {
    "google-chrome": ["google-chrome-stable", "chrome"],
    "google-chrome-stable": ["google-chrome", "chrome"],
    "visualstudio.code": ["code", "code-oss", "vscodium", "com.visualstudio.code"],
    "code": ["visualstudio.code", "code-oss", "vscodium", "com.visualstudio.code"],
    "mitchellh.ghostty": ["ghostty", "com.mitchellh.ghostty"],
    "ghostty": ["mitchellh.ghostty", "com.mitchellh.ghostty"],
    "telegram.desktop": ["telegramdesktop", "telegram-desktop", "org.telegram.desktop"],
    "telegramdesktop": ["telegram.desktop", "telegram-desktop", "org.telegram.desktop"],
    "kde.dolphin": ["dolphin", "org.kde.dolphin"],
    "dolphin": ["kde.dolphin", "org.kde.dolphin"],
    "gnome.nautilus": ["nautilus", "org.gnome.nautilus"],
    "nautilus": ["gnome.nautilus", "org.gnome.nautilus"]
};

function isMatchingApp(targetClass, targetExec, clientClass, clientInitialClass) {
    var tc = String(targetClass || "").toLowerCase().trim();
    var te = String(targetExec || "").toLowerCase().trim();
    var cc = String(clientClass || "").toLowerCase().trim();
    var cic = String(clientInitialClass || "").toLowerCase().trim();

    // 1. Direct raw exact match
    if (tc && (cc === tc || cic === tc)) return true;
    if (te && (cc === te || cic === te)) return true;

    // 2. Normalized exact match
    var ntc = normalizeClass(tc);
    var nte = normalizeClass(te);
    var ncc = normalizeClass(cc);
    var ncic = normalizeClass(cic);

    if (ntc && (ncc === ntc || ncic === ntc)) return true;
    if (nte && (ncc === nte || ncic === nte)) return true;

    // 3. Known exact aliases
    if (ntc && KNOWN_ALIASES[ntc]) {
        var al1 = KNOWN_ALIASES[ntc];
        if (al1.indexOf(ncc) !== -1 || al1.indexOf(ncic) !== -1 || al1.indexOf(cc) !== -1) return true;
    }
    if (nte && KNOWN_ALIASES[nte]) {
        var al2 = KNOWN_ALIASES[nte];
        if (al2.indexOf(ncc) !== -1 || al2.indexOf(ncic) !== -1 || al2.indexOf(cc) !== -1) return true;
    }

    return false;
}

function togglePinItem(pinnedList, item) {
    if (!item) return pinnedList;
    var isPinned = false;

    for (var i = 0; i < pinnedList.length; i++) {
        var p = pinnedList[i];
        if (isMatchingApp(p.appClass, p.exec, item.appClass, item.exec)) {
            isPinned = true;
            break;
        }
    }

    var next = [];
    if (isPinned) {
        // UNPIN: remove all matching instances
        for (var j = 0; j < pinnedList.length; j++) {
            var pj = pinnedList[j];
            if (!isMatchingApp(pj.appClass, pj.exec, item.appClass, item.exec)) {
                next.push(pj);
            }
        }
    } else {
        // PIN: add cleanly
        next = pinnedList.slice();
        var rawClass = item.appClass || item.exec || "app";
        next.push({
            id: "pin_" + rawClass,
            appClass: rawClass,
            name: item.name || item.appClass || "App",
            icon: item.icon || item.appClass || "application-x-executable",
            exec: item.exec || item.appClass || rawClass
        });
    }
    return next;
}

function reorderDockItem(pinnedList, dockItems, fromIndex, toIndex) {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return pinnedList;
    if (!dockItems || fromIndex >= dockItems.length || toIndex >= dockItems.length) return pinnedList;

    var sourceItem = dockItems[fromIndex];
    if (!sourceItem) return pinnedList;

    var next = [];
    for (var i = 0; i < pinnedList.length; i++) {
        var p = pinnedList[i];
        if (!isMatchingApp(p.appClass, p.exec, sourceItem.appClass, sourceItem.exec)) {
            next.push(p);
        }
    }

    var insertIdx = Math.max(0, Math.min(next.length, toIndex));
    var rawClass = sourceItem.appClass || sourceItem.exec || "app";
    var pinnedEntry = {
        id: "pin_" + rawClass,
        appClass: rawClass,
        name: sourceItem.name || rawClass,
        icon: sourceItem.icon || rawClass || "application-x-executable",
        exec: sourceItem.exec || rawClass
    };

    next.splice(insertIdx, 0, pinnedEntry);
    return next;
}

function buildDockItems(pinnedApps, rawClients) {
    var items = [];
    var matchedClientAddresses = {};
    var clients = [];

    if (Array.isArray(rawClients)) {
        clients = rawClients;
    } else if (typeof rawClients === "string" && rawClients.length > 0) {
        try {
            clients = JSON.parse(rawClients);
        } catch(e) {
            clients = [];
        }
    }

    // 1. Process Pinned Apps
    for (var i = 0; i < pinnedApps.length; i++) {
        var pinned = pinnedApps[i];
        var item = {
            id: pinned.id || ("pinned_" + i),
            appClass: pinned.appClass || "",
            name: pinned.name || "App",
            icon: pinned.icon || pinned.appClass || "application-x-executable",
            exec: pinned.exec || pinned.appClass || "",
            isPinned: true,
            isRunning: false,
            isActive: false,
            windowCount: 0,
            addresses: [],
            windows: []
        };

        for (var c = 0; c < clients.length; c++) {
            var cl = clients[c];
            if (!cl) continue;
            var clClass = String(cl.class || "");
            var clInitial = String(cl.initialClass || "");

            if (isMatchingApp(pinned.appClass, pinned.exec, clClass, clInitial)) {
                item.isRunning = true;
                item.windowCount++;
                var wsId = (cl.workspace && cl.workspace.id !== undefined) ? cl.workspace.id : null;
                if (cl.address) {
                    item.addresses.push(cl.address);
                    item.windows.push({ address: cl.address, workspaceId: wsId });
                }
                if (cl.focusHistoryID === 0 || cl.focusHistoryId === 0 || cl.active === true) {
                    item.isActive = true;
                }
                if (cl.address) matchedClientAddresses[cl.address] = true;
            }
        }
        items.push(item);
    }

    // 2. Process Unpinned Running Apps
    for (var j = 0; j < clients.length; j++) {
        var client = clients[j];
        if (!client) continue;
        if (client.address && matchedClientAddresses[client.address]) continue;

        var clientClass = String(client.class || client.initialClass || "app");
        if (!clientClass || clientClass === "quickshell" || clientClass === "hyprland") continue;

        var clientTitle = String(client.title || clientClass);
        var cWsId = (client.workspace && client.workspace.id !== undefined) ? client.workspace.id : null;

        var existingUnpinned = null;
        for (var k = 0; k < items.length; k++) {
            if (!items[k].isPinned && isMatchingApp(items[k].appClass, items[k].exec, clientClass, client.initialClass)) {
                existingUnpinned = items[k];
                break;
            }
        }

        if (existingUnpinned) {
            existingUnpinned.windowCount++;
            if (client.address) {
                existingUnpinned.addresses.push(client.address);
                existingUnpinned.windows.push({ address: client.address, workspaceId: cWsId });
            }
            if (client.focusHistoryID === 0 || client.focusHistoryId === 0 || client.active === true) {
                existingUnpinned.isActive = true;
            }
        } else {
            var newItem = {
                id: "running_" + (client.address || j),
                appClass: clientClass,
                name: clientTitle.split(" — ")[0].split(" - ")[0] || clientTitle || clientClass,
                icon: clientClass,
                exec: clientClass.toLowerCase(),
                isPinned: false,
                isRunning: true,
                isActive: (client.focusHistoryID === 0 || client.focusHistoryId === 0 || client.active === true),
                windowCount: 1,
                addresses: client.address ? [client.address] : [],
                windows: client.address ? [{ address: client.address, workspaceId: cWsId }] : []
            };
            items.push(newItem);
        }
        if (client.address) matchedClientAddresses[client.address] = true;
    }

    return items;
}
