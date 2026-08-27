// DockPinned.js — Pinned items & folder management for Omarchy Dock

.pragma library
.import "DockAutoName.js" as AutoName

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
    if (value.slice(-8).toLowerCase() === ".desktop") value = value.slice(0, -8);
    if (value.slice(-4).toLowerCase() === ".exe") value = value.slice(0, -4);
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
                    name: item.name !== undefined ? item.name : "Folder",
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
                name: item.name !== undefined ? item.name : "Folder",
                isStack: true,
                icon: item.icon || "folder",
                apps: cleanApps
            });
        }
    }
    return JSON.stringify({ pinned: cleaned }, null, 2);
}

function togglePinned(pinnedList, appId, maxItems) {
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

    if (maxItems && maxItems > 0 && arr.length >= maxItems) {
        return arr;
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

function createStackFromTwo(pinnedList, targetAppId, sourceAppId, allEntries) {
    var arr = Array.isArray(pinnedList) ? pinnedList.slice() : [];
    var targetClean = stripDesktop(targetAppId);
    var sourceClean = stripDesktop(sourceAppId);

    if (!targetClean || !sourceClean || targetClean === sourceClean) return arr;

    var suggestedName = AutoName.inferFolderName(targetClean, sourceClean, allEntries);

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
                name: suggestedName,
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
        name: suggestedName,
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

    for (var i = 0; i < arr.length; i++) {
        var item = arr[i];
        if (item && typeof item === "object" && item.isStack && (item.id === stackId || !stackId)) {
            var origApps = [];
            for (var a = 0; a < item.apps.length; a++) {
                origApps.push(stripDesktop(item.apps[a]));
            }

            var appIdx = -1;
            for (var a = 0; a < origApps.length; a++) {
                if (origApps[a].toLowerCase() === cleanApp.toLowerCase()) {
                    appIdx = a;
                    break;
                }
            }
            if (appIdx < 0) appIdx = 0;

            var remainingApps = [];
            for (var a = 0; a < origApps.length; a++) {
                if (a !== appIdx) {
                    remainingApps.push(origApps[a]);
                }
            }

            if (remainingApps.length <= 1) {
                // Dissolve folder: replace stack in dock with original ordered apps
                arr.splice(i, 1);
                for (var k = 0; k < origApps.length; k++) {
                    arr.splice(i + k, 0, origApps[k]);
                }
            } else {
                if (appIdx === 0) {
                    // Extracting the first app: place it before the stack so sequential extraction preserves left-to-right order
                    arr[i] = cleanApp;
                    arr.splice(i + 1, 0, {
                        id: item.id,
                        name: item.name,
                        isStack: true,
                        icon: item.icon,
                        apps: remainingApps
                    });
                } else {
                    // Extracting subsequent app: place it after the stack
                    arr[i] = {
                        id: item.id,
                        name: item.name,
                        isStack: true,
                        icon: item.icon,
                        apps: remainingApps
                    };
                    arr.splice(i + 1, 0, cleanApp);
                }
            }
            break;
        }
    }

    // Clean any duplicates while strictly preserving order
    var cleanList = [];
    var seen = {};
    for (var k = 0; k < arr.length; k++) {
        var el = arr[k];
        if (typeof el === "string") {
            var s = stripDesktop(el);
            if (!seen[s]) {
                seen[s] = true;
                cleanList.push(s);
            }
        } else {
            cleanList.push(el);
        }
    }
    return cleanList;
}

function mergeIntoStack(pinnedList, dockItems, fromIndex, targetIndex, allEntries) {
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
        return createStackFromTwo(pinnedList, tgtId, srcId, allEntries);
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
