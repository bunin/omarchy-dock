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
    if (!text) return [];

    var parsed = null;
    try {
        parsed = JSON.parse(text);
    } catch (e) {
        return [];
    }
    if (!parsed) return [];

    var arr = [];
    if (Array.isArray(parsed)) {
        arr = parsed;
    } else if (typeof parsed === "object" && Array.isArray(parsed.pinned)) {
        arr = parsed.pinned;
    }

    var out = [];
    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (typeof item === "string") {
            var id = stripDesktop(item);
            if (id) out.push(id);
        } else if (item && typeof item === "object") {
            if (item.isStack && Array.isArray(item.apps)) {
                var cleanApps = [];
                for (var a = 0; a < item.apps.length; a++) {
                    var ca = stripDesktop(item.apps[a]);
                    if (ca) cleanApps.push(ca);
                }
                out.push({
                    id: item.id || ("stack_" + i),
                    name: item.name || "Folder",
                    isStack: true,
                    icon: item.icon || "folder",
                    apps: cleanApps
                });
            } else {
                var c = item.appClass || item.id || item.exec || "";
                c = stripDesktop(c.replace(/^pin_/, ""));
                if (c) out.push(c);
            }
        }
    }
    return out;
}

function serializePinned(pinnedList) {
    var arr = Array.isArray(pinnedList) ? pinnedList : [];
    var cleaned = [];
    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (typeof item === "string") {
            var id = stripDesktop(item);
            if (id) cleaned.push(id);
        } else if (item && typeof item === "object" && item.isStack) {
            var cleanApps = [];
            for (var a = 0; a < item.apps.length; a++) {
                var ca = stripDesktop(item.apps[a]);
                if (ca) cleanApps.push(ca);
            }
            cleaned.push({
                id: item.id || ("stack_" + Date.now()),
                name: item.name || "Folder",
                isStack: true,
                icon: item.icon || "folder",
                apps: cleanApps
            });
        }
    }
    return JSON.stringify({ pinned: cleaned }, null, 2);
}

function togglePinned(pinnedList, appId) {
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    var id = stripDesktop(appId);
    if (!id) return arr;

    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (typeof item === "string" && stripDesktop(item) === id) {
            arr.splice(i, 1);
            return arr;
        } else if (item && typeof item === "object" && item.isStack) {
            if (item.id === id) {
                arr.splice(i, 1);
                return arr;
            }
        }
    }

    arr.push(id);
    return arr;
}

function dissolveStack(pinnedList, stackId) {
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    var result = [];
    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (item && typeof item === "object" && item.isStack && (item.id === stackId || !stackId)) {
            // Dissolve/remove folder from pinned list
            continue;
        }
        result.push(item);
    }
    return result;
}

function setStackIcon(pinnedList, stackId, iconSymbol) {
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (item && typeof item === "object" && item.isStack && (item.id === stackId || !stackId)) {
            arr[i] = {
                id: item.id,
                name: item.name,
                isStack: true,
                icon: iconSymbol || "grid",
                apps: item.apps.slice()
            };
            break;
        }
    }
    return arr;
}

function createStackFromTwo(pinnedList, targetAppId, sourceAppId) {
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    var targetClean = stripDesktop(targetAppId);
    var sourceClean = stripDesktop(sourceAppId);

    if (!targetClean || !sourceClean || targetClean === sourceClean) return arr;

    var newArr = [];
    var sourceRemoved = false;
    for (var i = 0; i < arr.length; i++) {
        var el = arr[i];
        var cleanEl = (typeof el === "string") ? stripDesktop(el) : "";
        if (cleanEl === sourceClean) {
            sourceRemoved = true;
            continue;
        }
        newArr.push(el);
    }

    for (var j = 0; j < newArr.length; j++) {
        var it = newArr[j];
        var cleanIt = (typeof it === "string") ? stripDesktop(it) : "";
        if (cleanIt === targetClean) {
            var newStack = {
                id: "stack_" + Date.now(),
                name: "Folder",
                isStack: true,
                icon: "folder",
                apps: [targetClean, sourceClean]
            };
            newArr[j] = newStack;
            return newArr;
        }
    }

    newArr.push({
        id: "stack_" + Date.now(),
        name: "Folder",
        isStack: true,
        icon: "folder",
        apps: [targetClean, sourceClean]
    });
    return newArr;
}

function addToStack(pinnedList, stackId, sourceAppId) {
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    var sourceClean = stripDesktop(sourceAppId);
    if (!sourceClean) return arr;

    var newArr = [];
    for (var i = 0; i < arr.length; i++) {
        var el = arr[i];
        var cleanEl = (typeof el === "string") ? stripDesktop(el) : "";
        if (cleanEl === sourceClean) continue;
        newArr.push(el);
    }

    for (var j = 0; j < newArr.length; j++) {
        var item = newArr[j];
        if (item && typeof item === "object" && item.isStack && (item.id === stackId || !stackId)) {
            var apps = item.apps.slice();
            var exists = false;
            for (var a = 0; a < apps.length; a++) {
                if (stripDesktop(apps[a]) === sourceClean) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                apps.push(sourceClean);
            }
            newArr[j] = {
                id: item.id,
                name: item.name,
                isStack: true,
                icon: item.icon,
                apps: apps
            };
            break;
        }
    }
    return newArr;
}

function removeFromStack(pinnedList, stackId, appId) {
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    var cleanApp = stripDesktop(appId);

    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (item && typeof item === "object" && item.isStack && (item.id === stackId || !stackId)) {
            var apps = [];
            for (var a = 0; a < item.apps.length; a++) {
                if (stripDesktop(item.apps[a]) !== cleanApp) {
                    apps.push(stripDesktop(item.apps[a]));
                }
            }
            if (apps.length <= 1) {
                arr.splice(i, 1);
                for (var k = 0; k < apps.length; k++) {
                    arr.splice(i + k, 0, apps[k]);
                }
            } else {
                arr[i] = {
                    id: item.id,
                    name: item.name,
                    isStack: true,
                    icon: item.icon,
                    apps: apps
                };
            }
            break;
        }
    }
    return arr;
}

function renameStack(pinnedList, stackId, newName) {
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (item && typeof item === "object" && item.isStack && (item.id === stackId || !stackId)) {
            arr[i] = {
                id: item.id,
                name: newName,
                isStack: true,
                icon: item.icon,
                apps: item.apps
            };
            break;
        }
    }
    return arr;
}

function reorderInStack(pinnedList, stackId, fromIndex, toIndex) {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return pinnedList;
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];

    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (item && typeof item === "object" && item.isStack && (item.id === stackId || !stackId)) {
            var apps = item.apps.slice();
            if (fromIndex < apps.length && toIndex < apps.length) {
                var moving = apps.splice(fromIndex, 1)[0];
                apps.splice(toIndex, 0, moving);
                arr[i] = {
                    id: item.id,
                    name: item.name,
                    isStack: true,
                    icon: item.icon,
                    apps: apps
                };
            }
            break;
        }
    }
    return arr;
}

function extractFromStackToDock(pinnedList, stackId, appId, targetDockIndex) {
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    var cleanApp = stripDesktop(appId);
    if (!cleanApp) return arr;

    var insertIdx = (targetDockIndex !== undefined && targetDockIndex >= 0) ? targetDockIndex : arr.length;

    // 1. Remove from stack
    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (item && typeof item === "object" && item.isStack && (item.id === stackId || !stackId)) {
            var apps = [];
            for (var a = 0; a < item.apps.length; a++) {
                if (stripDesktop(item.apps[a]) !== cleanApp) {
                    apps.push(stripDesktop(item.apps[a]));
                }
            }
            if (apps.length <= 1) {
                arr.splice(i, 1);
                if (apps.length === 1) {
                    arr.splice(i, 0, apps[0]);
                }
                insertIdx = i + 1;
            } else {
                arr[i] = {
                    id: item.id,
                    name: item.name,
                    isStack: true,
                    icon: item.icon,
                    apps: apps
                };
                insertIdx = i + 1;
            }
            break;
        }
    }

    // 2. Insert into dock at target position (preventing duplicates)
    var cleanList = [];
    for (var k = 0; k < arr.length; k++) {
        var el = arr[k];
        if (typeof el === "string" && stripDesktop(el) === cleanApp) continue;
        cleanList.push(el);
    }
    var safeIdx = Math.max(0, Math.min(cleanList.length, insertIdx));
    cleanList.splice(safeIdx, 0, cleanApp);
    return cleanList;
}

function mergeIntoStack(pinnedList, dockItems, fromIndex, targetIndex) {
    if (fromIndex < 0 || targetIndex < 0 || !dockItems) return pinnedList;
    if (fromIndex >= dockItems.length || targetIndex >= dockItems.length) return pinnedList;
    if (fromIndex === targetIndex) return pinnedList;

    var sourceItem = dockItems[fromIndex];
    var targetItem = dockItems[targetIndex];
    if (!sourceItem || !targetItem) return pinnedList;

    // RULE: Folders CANNOT be merged into other folders!
    if (sourceItem.isStack || (targetItem.isStack && sourceItem.isStack)) return pinnedList;

    var srcId = stripDesktop(sourceItem.appId);
    if (!srcId) return pinnedList;

    if (targetItem.isStack) {
        return addToStack(pinnedList, targetItem.id, srcId);
    } else {
        var tgtId = stripDesktop(targetItem.appId);
        return createStackFromTwo(pinnedList, tgtId, srcId);
    }
}

function reorderPinned(pinnedList, dockItems, fromIndex, toIndex) {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return pinnedList;
    if (!dockItems || fromIndex >= dockItems.length || toIndex >= dockItems.length) return pinnedList;

    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    var sourceItem = dockItems[fromIndex];
    var targetItem = dockItems[toIndex];
    if (!sourceItem || !targetItem) return pinnedList;

    var srcId = sourceItem.isStack ? sourceItem.id : stripDesktop(sourceItem.appId);
    var tgtId = targetItem.isStack ? targetItem.id : stripDesktop(targetItem.appId);
    if (!srcId) return pinnedList;

    // Find actual indices of source and target in pinnedList
    var actualFrom = -1;
    var actualTo = -1;
    for (var i = 0; i < arr.length; i++) {
        var it = arr[i];
        var itId = (it && typeof it === "object" && it.isStack) ? it.id : stripDesktop(it);
        if (itId === srcId) actualFrom = i;
        if (itId === tgtId) actualTo = i;
    }

    if (actualFrom === -1) {
        // Source is an unpinned running app!
        // When dragged to a slot among/near pinned items, automatically PIN IT at target position!
        var insertPos = (actualTo !== -1) ? actualTo : Math.min(arr.length, toIndex);
        if (fromIndex < toIndex && actualTo !== -1) {
            insertPos = actualTo + 1;
        }
        var safeInsert = Math.max(0, Math.min(arr.length, insertPos));
        arr.splice(safeInsert, 0, srcId);
        return arr;
    }

    // Source is already pinned: reorder within pinned list
    if (actualTo === -1) {
        // Moved past all pinned items: move to end of pinned list
        actualTo = arr.length - 1;
    }

    var moved = arr.splice(actualFrom, 1)[0];
    var safeTo = Math.max(0, Math.min(arr.length, actualTo));
    arr.splice(safeTo, 0, moved);
    return arr;
}

var KNOWN_APP_DEFAULTS = {
    "code": { id: "code", icon: "vscode", rawIcon: "vscode", name: "Visual Studio Code" },
    "vscode": { id: "code", icon: "vscode", rawIcon: "vscode", name: "Visual Studio Code" },
    "org.kde.kwrite": { id: "org.kde.kwrite", icon: "kwrite", rawIcon: "kwrite", name: "KWrite" },
    "kwrite": { id: "org.kde.kwrite", icon: "kwrite", rawIcon: "kwrite", name: "KWrite" },
    "org.kde.krita": { id: "org.kde.krita", icon: "krita", rawIcon: "krita", name: "Krita" },
    "krita": { id: "org.kde.krita", icon: "krita", rawIcon: "krita", name: "Krita" },
    "org.kde.dolphin": { id: "org.kde.dolphin", icon: "org.kde.dolphin", rawIcon: "org.kde.dolphin", name: "Dolphin" },
    "dolphin": { id: "org.kde.dolphin", icon: "org.kde.dolphin", rawIcon: "org.kde.dolphin", name: "Dolphin" },
    "com.mitchellh.ghostty": { id: "com.mitchellh.ghostty", icon: "com.mitchellh.ghostty", rawIcon: "com.mitchellh.ghostty", name: "Ghostty" },
    "ghostty": { id: "com.mitchellh.ghostty", icon: "com.mitchellh.ghostty", rawIcon: "com.mitchellh.ghostty", name: "Ghostty" },
    "google-chrome": { id: "google-chrome", icon: "google-chrome", rawIcon: "google-chrome", name: "Google Chrome" },
    "steam": { id: "steam", icon: "steam", rawIcon: "steam", name: "Steam" },
    "antigravity": { id: "antigravity", icon: "antigravity", rawIcon: "antigravity", name: "Antigravity" },
    "libreoffice-writer": { id: "libreoffice-writer", icon: "libreoffice-writer", rawIcon: "libreoffice-writer", name: "LibreOffice Writer" },
    "libreoffice-impress": { id: "libreoffice-impress", icon: "libreoffice-impress", rawIcon: "libreoffice-impress", name: "LibreOffice Impress" },
    "libreoffice-calc": { id: "libreoffice-calc", icon: "libreoffice-calc", rawIcon: "libreoffice-calc", name: "LibreOffice Calc" },
    "discord": { id: "discord", icon: "omarchy-discord", rawIcon: "omarchy-discord", name: "Discord" }
};

var FALLBACK_ICON_CANDIDATES = {
    "ghostty": ["com.mitchellh.ghostty", "ghostty"],
    "com.mitchellh.ghostty": ["com.mitchellh.ghostty", "ghostty"],
    "code": ["vscode", "com.visualstudio.code", "code"],
    "vscode": ["vscode", "com.visualstudio.code", "code"],
    "com.visualstudio.code": ["vscode", "com.visualstudio.code", "code"],
    "dolphin": ["org.kde.dolphin", "dolphin", "system-file-manager"],
    "org.kde.dolphin": ["org.kde.dolphin", "dolphin", "system-file-manager"],
    "kwrite": ["org.kde.kwrite", "kwrite"],
    "org.kde.kwrite": ["org.kde.kwrite", "kwrite"],
    "krita": ["org.kde.krita", "krita"],
    "org.kde.krita": ["org.kde.krita", "krita"],
    "google-chrome": ["google-chrome", "chrome", "google-chrome-stable"],
    "steam": ["steam", "steam-launcher"],
    "antigravity": ["antigravity"],
    "libreoffice-writer": ["libreoffice-writer", "libreoffice-oasis-writer"],
    "libreoffice-calc": ["libreoffice-calc", "libreoffice-oasis-calc"],
    "libreoffice-impress": ["libreoffice-impress", "libreoffice-oasis-impress"],
    "discord": ["omarchy-discord", "discord", "com.discordapp.Discord"],
    "telegram": ["org.telegram.desktop", "telegram", "telegramdesktop"],
    "obsidian": ["obsidian", "md.obsidian.Obsidian"],
    "spotify": ["spotify", "spotify-client"]
};

function getCandidates(rawIcon, icon, appId) {
    var list = [];
    function add(c) {
        if (!c) return;
        var s = String(c).trim();
        if (s.length > 0 && list.indexOf(s) === -1) list.push(s);
    }
    add(rawIcon);
    add(icon);
    add(appId);
    var clean = String(appId || rawIcon || "").toLowerCase().replace(/\.desktop$/, "");
    add(clean);
    var withoutPrefix = clean.replace(/^(org|com|io|net|dev)\.[^.]+\./, "");
    add(withoutPrefix);
    var lastPart = clean.split(".").pop();
    add(lastPart);

    if (FALLBACK_ICON_CANDIDATES[clean]) {
        var fb = FALLBACK_ICON_CANDIDATES[clean];
        for (var i = 0; i < fb.length; i++) add(fb[i]);
    }
    if (FALLBACK_ICON_CANDIDATES[lastPart]) {
        var fb2 = FALLBACK_ICON_CANDIDATES[lastPart];
        for (var j = 0; j < fb2.length; j++) add(fb2[j]);
    }
    return list;
}

function normalizeKey(str) {
    if (!str) return "";
    return String(str).toLowerCase().replace(/[^a-z0-9]/g, "");
}

function extractChromeDomain(appClass) {
    if (!appClass) return "";
    var s = String(appClass).toLowerCase();
    if (s.indexOf("chrome-") === 0 || s.indexOf("chromium-") === 0 || s.indexOf("brave-") === 0 || s.indexOf("edge-") === 0) {
        var dom = s.replace(/^(chrome|chromium|brave|edge)-/, "")
                   .replace(/__-.*$/, "")
                   .replace(/__.*$/, "")
                   .replace(/_\/.*$/, "")
                   .replace(/^-+/, "");
        return dom;
    }
    return "";
}

function findEntry(desktopEntries, appId) {
    var id = stripDesktop(appId);
    if (!id) return null;

    if (desktopEntries && desktopEntries.length > 0) {
        var list = toArray(desktopEntries);
        var target = id.toLowerCase();
        var targetNorm = normalizeKey(target);
        var chromeDom = extractChromeDomain(id);

        // 1. Exact match on entry.id (with and without .desktop)
        for (var i = 0; i < list.length; i++) {
            var entry = list[i];
            if (!entry) continue;
            var entryId = stripDesktop(entry.id || "").toLowerCase();
            if (entryId === target) return entry;
        }

        // 2. Normalized key match on entry.id, name, or icon
        for (var j = 0; j < list.length; j++) {
            var e = list[j];
            if (!e) continue;
            var eId = stripDesktop(e.id || "").toLowerCase();
            var eIdNorm = normalizeKey(eId);
            var eName = String(e.name || "").toLowerCase();
            var eNameNorm = normalizeKey(eName);
            var eIcon = String(e.icon || "").toLowerCase();
            var eIconNorm = normalizeKey(eIcon);

            if (targetNorm.length > 0 && (eIdNorm === targetNorm || eNameNorm === targetNorm || eIconNorm === targetNorm)) {
                return e;
            }
        }

        // 3. Web App / Chrome domain matching in exec or id
        if (chromeDom.length > 0) {
            for (var c = 0; c < list.length; c++) {
                var ce = list[c];
                if (!ce) continue;
                var cExec = String(ce.exec || "").toLowerCase();
                var cId = String(ce.id || "").toLowerCase();
                var cName = String(ce.name || "").toLowerCase();
                if (cExec.indexOf(chromeDom) !== -1 || cId.indexOf(chromeDom) !== -1) {
                    return ce;
                }
                // Check key parts of domain, e.g. "maps" from "maps.google.com"
                var domParts = chromeDom.split(".");
                for (var p = 0; p < domParts.length; p++) {
                    var part = domParts[p];
                    if (part.length >= 3 && part !== "com" && part !== "org" && part !== "net" && part !== "google" && part !== "web" && part !== "app") {
                        if (cName.indexOf(part) !== -1 || cExec.indexOf(part) !== -1) {
                            return ce;
                        }
                    }
                }
            }
        }

        // 4. Substring / Exec binary match
        for (var k = 0; k < list.length; k++) {
            var el = list[k];
            if (!el) continue;
            var exec = String(el.exec || "").toLowerCase();
            var name = String(el.name || "").toLowerCase();
            if (exec === target || exec.indexOf(target) !== -1 || name === target) return el;
        }
    }

    var cleanId = id.toLowerCase();
    if (KNOWN_APP_DEFAULTS[cleanId]) return KNOWN_APP_DEFAULTS[cleanId];

    return null;
}

function resolveIcon(entry, appId, appLibrary) {
    if (entry && entry.iconSource && entry.iconSource.length > 0 && entry.iconSource.indexOf("application-x-executable") === -1) {
        return entry.iconSource;
    }
    if (entry && entry.icon) {
        if (appLibrary && typeof appLibrary.iconSource === "function") {
            var src = appLibrary.iconSource(entry.icon);
            if (src && src.length > 0 && src.indexOf("application-x-executable") === -1) return src;
        }
        return entry.icon;
    }
    var id = stripDesktop(appId);
    if (appLibrary && typeof appLibrary.iconSource === "function") {
        var src2 = appLibrary.iconSource(id);
        if (src2 && src2.length > 0 && src2.indexOf("application-x-executable") === -1) return src2;

        // Try hyphenated/spaced variations (e.g. "Google Maps" -> "google-maps")
        var hyp = id.toLowerCase().replace(/\s+/g, "-");
        var src3 = appLibrary.iconSource(hyp);
        if (src3 && src3.length > 0 && src3.indexOf("application-x-executable") === -1) return src3;

        var spc = id.toLowerCase().replace(/[-_]+/g, " ");
        var src4 = appLibrary.iconSource(spc);
        if (src4 && src4.length > 0 && src4.indexOf("application-x-executable") === -1) return src4;
    }
    return id || "application-x-executable";
}

function isBrowserApp(id) {
    var s = String(id || "").toLowerCase();
    return s === "google-chrome" || s === "google-chrome-stable" || s === "chromium" || s === "brave" || s === "brave-browser" || s === "microsoft-edge" || s === "opera" || s === "vivaldi";
}

function matchToplevel(toplevel, appId, entry) {
    if (!toplevel) return false;
    var appClass = String(toplevel.appId || "").toLowerCase().trim();
    var title = String(toplevel.title || "").toLowerCase().trim();
    var cleanId = stripDesktop(appId).toLowerCase().trim();

    if (!cleanId && !entry) return false;
    if (!appClass) return false;

    var chromeDom = extractChromeDomain(appClass);
    var isWebAppWindow = (chromeDom.length > 0);

    // If this window is a Chrome Web App (e.g. chrome-maps.google.com__-Default):
    // Standard web browser dock items (Google Chrome, Chromium, Brave) should NOT swallow it!
    if (isWebAppWindow && isBrowserApp(cleanId)) {
        return false;
    }

    // 1. Direct class match
    if (cleanId && (appClass === cleanId || appClass === (cleanId + ".desktop"))) return true;

    // 2. Normalized match
    var normClass = normalizeKey(appClass);
    var normId = cleanId ? normalizeKey(cleanId) : "";
    if (normId.length > 0 && normClass === normId) return true;

    // 3. Entry ID, Name, Icon and Exec match
    if (entry) {
        var entryId = stripDesktop(entry.id || "").toLowerCase();
        if (entryId && (appClass === entryId || appClass === (entryId + ".desktop") || normClass === normalizeKey(entryId))) return true;

        var entryName = String(entry.name || "").toLowerCase();
        if (entryName && (normClass === normalizeKey(entryName))) return true;

        var entryIcon = String(entry.icon || "").toLowerCase();
        if (entryIcon && (normClass === normalizeKey(entryIcon))) return true;

        if (entry.exec) {
            var execStr = String(entry.exec).trim().toLowerCase();
            var execBase = execStr.split(/\s+/)[0].split("/").pop();
            if (execBase && !isWebAppWindow && (appClass === execBase || appClass === (execBase + ".desktop"))) return true;
        }
    }

    // 4. Chrome / Web App Matching
    if (isWebAppWindow) {
        if (entry && entry.exec && entry.exec.toLowerCase().indexOf(chromeDom) !== -1) return true;
        if (entry && entry.id && entry.id.toLowerCase().indexOf(chromeDom) !== -1) return true;
        if (cleanId && cleanId.indexOf(chromeDom) !== -1) return true;
        if (normId.length > 0 && normId.indexOf(normalizeKey(chromeDom)) !== -1) return true;

        // Check domain keywords e.g. "maps" in "maps.google.com" matching "Google Maps"
        var domParts = chromeDom.split(".");
        for (var p = 0; p < domParts.length; p++) {
            var part = domParts[p];
            if (part.length >= 3 && part !== "com" && part !== "org" && part !== "net" && part !== "google" && part !== "web" && part !== "app") {
                if (entry && entry.name && entry.name.toLowerCase().indexOf(part) !== -1) return true;
                if (entry && entry.icon && entry.icon.toLowerCase().indexOf(part) !== -1) return true;
                if (cleanId && cleanId.indexOf(part) !== -1) return true;
                if (entry && entry.name && title.indexOf(entry.name.toLowerCase()) !== -1) return true;
            }
        }
    }

    // 5. Window Title Match for web apps / webapp launchers
    if (entry && entry.exec && entry.exec.toLowerCase().indexOf("omarchy-launch-webapp") !== -1) {
        if (entry.name && title.length > 0) {
            var normName = normalizeKey(entry.name);
            var normTitle = normalizeKey(title);
            if (normTitle.indexOf(normName) !== -1 || normName.indexOf(normTitle) !== -1) return true;
        }
    }

    // 6. Normalized prefix matches (e.g., com.mitchellh.ghostty <-> ghostty, org.kde.dolphin <-> dolphin)
    if (!isWebAppWindow) {
        var appClassShort = appClass.replace(/^(org|com|io|net|dev)\.[^.]+\./, "").replace(/\.desktop$/, "");
        if (cleanId && appClassShort === cleanId) return true;

        var cleanIdShort = cleanId.replace(/^(org|com|io|net|dev)\.[^.]+\./, "");
        if (appClass === cleanIdShort || appClassShort === cleanIdShort) return true;
    }

    return false;
}

function buildDockItems(pinnedList, toplevelsList, activeToplevel, desktopEntries, appLibrary) {
    var pinned = Array.isArray(pinnedList) ? pinnedList : [];
    var toplevels = toArray(toplevelsList);
    var entries = toArray(desktopEntries);

    var items = [];
    var assignedTops = {};

    function getTopKey(top, idx) {
        if (!top) return "top_" + idx;
        var app = "";
        var title = "";
        try {
            app = String(top.appId || "");
            title = String(top.title || "");
        } catch (e) {}
        return app + "___" + title + "___" + idx;
    }

    function entryFor(id) {
        return findEntry(entries, id);
    }

    // 1. Process Pinned Items
    for (var i = 0; i < pinned.length; i++) {
        var p = pinned[i];
        if (p && typeof p === "object" && p.isStack) {
            var subApps = [];
            var isAnySubRunning = false;
            var isAnySubActive = false;

            for (var s = 0; s < p.apps.length; s++) {
                var sAppId = stripDesktop(p.apps[s]);
                var sEntry = entryFor(sAppId);
                var sRawIcon = (sEntry && sEntry.icon) ? sEntry.icon : sAppId;
                var sIcon = resolveIcon(sEntry, sAppId, appLibrary);
                var sName = sEntry && sEntry.name ? sEntry.name : sAppId;
                var sIconSource = (sEntry && sEntry.iconSource) ? sEntry.iconSource : "";

                var sTops = [];
                var sActive = false;
                var sActiveIdx = 0;
                for (var st = 0; st < toplevels.length; st++) {
                    var sTop = toplevels[st];
                    var stKey = getTopKey(sTop, st);
                    if (!assignedTops[stKey] && matchToplevel(sTop, sAppId, sEntry)) {
                        sTops.push(sTop);
                        assignedTops[stKey] = true;
                        try {
                            if ((activeToplevel && sTop === activeToplevel) || (sTop && (sTop.activated || sTop.active))) {
                                sActive = true;
                                sActiveIdx = sTops.length - 1;
                            }
                        } catch (e) {}
                    }
                }

                if (sTops.length > 0) isAnySubRunning = true;
                if (sActive) isAnySubActive = true;

                subApps.push({
                    appId: sAppId,
                    desktopId: (sEntry && sEntry.id) ? sEntry.id : (sAppId.indexOf(".desktop") !== -1 ? sAppId : (sAppId + ".desktop")),
                    exec: (sEntry && sEntry.exec) ? sEntry.exec : "",
                    name: sName,
                    icon: sIcon,
                    rawIcon: sRawIcon,
                    iconSource: sIconSource,
                    isPinned: true,
                    isRunning: sTops.length > 0,
                    isActive: sActive,
                    activeTopIndex: sActiveIdx,
                    windowCount: sTops.length,
                    toplevels: sTops
                });
            }

            items.push({
                id: p.id || ("stack_" + i),
                appId: p.id || ("stack_" + i),
                desktopId: "",
                exec: "",
                name: p.name || "Folder",
                icon: p.icon || "folder",
                rawIcon: p.icon || "folder",
                isStack: true,
                isPinned: true,
                isDuplicate: false,
                isRunning: isAnySubRunning,
                isActive: isAnySubActive,
                windowCount: 0,
                subApps: subApps,
                toplevels: []
            });
        } else {
            var appId = stripDesktop(p);
            if (!appId) continue;

            var entry = entryFor(appId);
            var rawIcon = (entry && entry.icon) ? entry.icon : appId;
            var icon = resolveIcon(entry, appId, appLibrary);
            var name = entry && entry.name ? entry.name : appId;
            var iconSource = (entry && entry.iconSource) ? entry.iconSource : "";
            var desktopId = (entry && entry.id) ? entry.id : (appId.indexOf(".desktop") !== -1 ? appId : (appId + ".desktop"));
            var exec = (entry && entry.exec) ? entry.exec : "";

            var matching = [];
            var isAnyActive = false;
            var activeIdx = 0;
            for (var t = 0; t < toplevels.length; t++) {
                var top = toplevels[t];
                var tKey = getTopKey(top, t);
                if (!assignedTops[tKey] && matchToplevel(top, appId, entry)) {
                    matching.push(top);
                    assignedTops[tKey] = true;
                    try {
                        if ((activeToplevel && top === activeToplevel) || (top && (top.activated || top.active))) {
                            isAnyActive = true;
                            activeIdx = matching.length - 1;
                        }
                    } catch (e) {}
                }
            }

            items.push({
                id: appId,
                appId: appId,
                desktopId: desktopId,
                exec: exec,
                name: name,
                icon: icon,
                rawIcon: rawIcon,
                iconSource: iconSource,
                isStack: false,
                isPinned: true,
                isDuplicate: false,
                isRunning: matching.length > 0,
                isActive: isAnyActive,
                activeTopIndex: activeIdx,
                windowCount: matching.length,
                toplevels: matching
            });
        }
    }

    // 2. Process Running Unpinned Toplevels
    for (var j = 0; j < toplevels.length; j++) {
        var topItem = toplevels[j];
        if (!topItem) continue;
        var topItemKey = getTopKey(topItem, j);
        if (assignedTops[topItemKey]) continue;

        var rAppId = "";
        var rTitle = "";
        try {
            rAppId = topItem.appId || "";
            rTitle = topItem.title || "";
        } catch (e) {}

        var rEntry = entryFor(rAppId);
        var rRawIcon = (rEntry && rEntry.icon) ? rEntry.icon : (rAppId || "application-x-executable");
        var rIcon = resolveIcon(rEntry, rAppId, appLibrary);
        var rName = (rEntry && rEntry.name) ? rEntry.name : (rTitle || rAppId || "App");
        var rIconSource = (rEntry && rEntry.iconSource) ? rEntry.iconSource : "";
        var rDesktopId = (rEntry && rEntry.id) ? rEntry.id : (rAppId ? (rAppId.indexOf(".desktop") !== -1 ? rAppId : (rAppId + ".desktop")) : "");
        var rExec = (rEntry && rEntry.exec) ? rEntry.exec : "";

        // Find all unassigned toplevels for this unpinned app
        var rMatching = [];
        var rIsActive = false;
        var rActiveIdx = 0;
        for (var k = 0; k < toplevels.length; k++) {
            var candidate = toplevels[k];
            var cKey = getTopKey(candidate, k);
            if (!assignedTops[cKey] && matchToplevel(candidate, rAppId, rEntry)) {
                rMatching.push(candidate);
                assignedTops[cKey] = true;
                try {
                    if ((activeToplevel && candidate === activeToplevel) || (candidate && (candidate.activated || candidate.active))) {
                        rIsActive = true;
                        rActiveIdx = rMatching.length - 1;
                    }
                } catch (e) {}
            }
        }

        if (rMatching.length === 0) continue;

        items.push({
            id: rAppId,
            appId: rAppId,
            desktopId: rDesktopId,
            exec: rExec,
            name: rName,
            icon: rIcon,
            rawIcon: rRawIcon,
            iconSource: rIconSource,
            isStack: false,
            isPinned: false,
            isDuplicate: false,
            isRunning: true,
            isActive: rIsActive,
            activeTopIndex: rActiveIdx,
            windowCount: rMatching.length,
            toplevels: rMatching
        });
    }

    return items;
}
