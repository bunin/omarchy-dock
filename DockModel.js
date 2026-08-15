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
            // Ensure every pinned item has valid appClass
            for (var i = 0; i < parsed.length; i++) {
                if (!parsed[i].appClass) {
                    parsed[i].appClass = parsed[i].id ? parsed[i].id.replace(/^pin_/, "") : (parsed[i].exec || "app");
                }
            }
            return parsed;
        }
    } catch (e) {
        // Fallback
    }
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

function togglePinItem(pinnedList, item) {
    if (!item) return pinnedList;
    var targetNorm = normalizeClass(item.appClass || item.id || item.name);
    var isPinned = false;

    for (var i = 0; i < pinnedList.length; i++) {
        var p = pinnedList[i];
        var pNorm = normalizeClass(p.appClass || p.id || p.name);
        if (pNorm === targetNorm || (targetNorm.length > 2 && pNorm.indexOf(targetNorm) !== -1)) {
            isPinned = true;
            break;
        }
    }

    var next = [];
    if (isPinned) {
        // UNPIN: remove all instances matching this app
        for (var j = 0; j < pinnedList.length; j++) {
            var pj = pinnedList[j];
            var pjNorm = normalizeClass(pj.appClass || pj.id || pj.name);
            var matches = (pjNorm === targetNorm) || (targetNorm.length > 2 && pjNorm.indexOf(targetNorm) !== -1);
            if (!matches) {
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
    var targetNorm = normalizeClass(sourceItem.appClass || sourceItem.exec || sourceItem.name);

    // Filter out source item from pinnedList if present
    for (var i = 0; i < pinnedList.length; i++) {
        var p = pinnedList[i];
        var pNorm = normalizeClass(p.appClass || p.exec || p.name);
        if (pNorm !== targetNorm) {
            next.push(p);
        }
    }

    // Insert at toIndex (clamped)
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

        var targetNorm = normalizeClass(pinned.appClass);
        var targetRaw = String(pinned.appClass || "").toLowerCase();

        for (var c = 0; c < clients.length; c++) {
            var cl = clients[c];
            if (!cl) continue;
            var clClass = String(cl.class || cl.initialClass || "").toLowerCase();
            var clNorm = normalizeClass(clClass);

            var matches = (clClass === targetRaw) ||
                          (clNorm === targetNorm && targetNorm.length > 0) ||
                          (targetNorm.length > 2 && clNorm.indexOf(targetNorm) !== -1) ||
                          (clNorm.length > 2 && targetNorm.indexOf(clNorm) !== -1);

            if (matches) {
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
        var clientNorm = normalizeClass(clientClass);
        var cWsId = (client.workspace && client.workspace.id !== undefined) ? client.workspace.id : null;

        var existingUnpinned = null;
        for (var k = 0; k < items.length; k++) {
            if (!items[k].isPinned && normalizeClass(items[k].appClass) === clientNorm) {
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
