// DockMatcher.js — Window matching, icon resolution, and dock item builder for Omarchy Dock

.pragma library

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
    "discord": { id: "discord", icon: "omarchy-discord", rawIcon: "omarchy-discord", name: "Discord" },
    "google-photos": { id: "Google Photos", icon: "google-photos", rawIcon: "google-photos", name: "Google Photos" },
    "photos.google.com": { id: "Google Photos", icon: "google-photos", rawIcon: "google-photos", name: "Google Photos" },
    "chrome-photos.google.com__-default": { id: "Google Photos", icon: "google-photos", rawIcon: "google-photos", name: "Google Photos" },
    "google-contacts": { id: "Google Contacts", icon: "google-contacts", rawIcon: "google-contacts", name: "Google Contacts" },
    "contacts.google.com": { id: "Google Contacts", icon: "google-contacts", rawIcon: "google-contacts", name: "Google Contacts" },
    "chrome-contacts.google.com__-default": { id: "Google Contacts", icon: "google-contacts", rawIcon: "google-contacts", name: "Google Contacts" },
    "google-messages": { id: "Google Messages", icon: "google-messages", rawIcon: "google-messages", name: "Google Messages" },
    "messages.google.com": { id: "Google Messages", icon: "google-messages", rawIcon: "google-messages", name: "Google Messages" },
    "chrome-messages.google.com__web_conversations-default": { id: "Google Messages", icon: "google-messages", rawIcon: "google-messages", name: "Google Messages" },
    "google-maps": { id: "Google Maps", icon: "google-maps", rawIcon: "google-maps", name: "Google Maps" },
    "maps.google.com": { id: "Google Maps", icon: "google-maps", rawIcon: "google-maps", name: "Google Maps" },
    "chrome-maps.google.com__-default": { id: "Google Maps", icon: "google-maps", rawIcon: "google-maps", name: "Google Maps" },
    "gmail": { id: "Gmail", icon: "gmail", rawIcon: "gmail", name: "Gmail" },
    "mail.google.com": { id: "Gmail", icon: "gmail", rawIcon: "gmail", name: "Gmail" },
    "google-calendar": { id: "Google Calendar", icon: "google-calendar", rawIcon: "google-calendar", name: "Google Calendar" },
    "calendar.google.com": { id: "Google Calendar", icon: "google-calendar", rawIcon: "google-calendar", name: "Google Calendar" },
    "google-drive": { id: "Google Drive", icon: "google-drive", rawIcon: "google-drive", name: "Google Drive" },
    "drive.google.com": { id: "Google Drive", icon: "google-drive", rawIcon: "google-drive", name: "Google Drive" },
    "google-keep": { id: "Google Keep", icon: "google-keep", rawIcon: "google-keep", name: "Google Keep" },
    "keep.google.com": { id: "Google Keep", icon: "google-keep", rawIcon: "google-keep", name: "Google Keep" },
    "youtube": { id: "YouTube", icon: "youtube", rawIcon: "youtube", name: "YouTube" },
    "youtube.com": { id: "YouTube", icon: "youtube", rawIcon: "youtube", name: "YouTube" },
    "youtube-music": { id: "YouTube Music", icon: "youtube-music", rawIcon: "youtube-music", name: "YouTube Music" },
    "music.youtube.com": { id: "YouTube Music", icon: "youtube-music", rawIcon: "youtube-music", name: "YouTube Music" },
    "yandex-mail": { id: "Яндекс Почта", icon: "yandex-mail", rawIcon: "yandex-mail", name: "Яндекс Почта" },
    "mail.yandex.ru": { id: "Яндекс Почта", icon: "yandex-mail", rawIcon: "yandex-mail", name: "Яндекс Почта" },
    "yandex-music": { id: "Яндекс Музыка", icon: "yandex-music", rawIcon: "yandex-music", name: "Яндекс Музыка" },
    "music.yandex.ru": { id: "Яндекс Музыка", icon: "yandex-music", rawIcon: "yandex-music", name: "Яндекс Музыка" },
    "photoshop": { id: "Photoshop 2017", icon: "Photoshop2017", rawIcon: "Photoshop2017", name: "Photoshop 2017" },
    "photoshop 2017": { id: "Photoshop 2017", icon: "Photoshop2017", rawIcon: "Photoshop2017", name: "Photoshop 2017" }
};

var FALLBACK_ICON_CANDIDATES = {
    "ghostty": ["com.mitchellh.ghostty", "ghostty"],
    "com.mitchellh.ghostty": ["com.mitchellh.ghostty", "ghostty"],
    "code": ["com.visualstudio.code", "visual-studio-code", "visualstudiocode", "code-oss", "vscode", "code"],
    "vscode": ["com.visualstudio.code", "visual-studio-code", "visualstudiocode", "code-oss", "vscode", "code"],
    "com.visualstudio.code": ["com.visualstudio.code", "visual-studio-code", "visualstudiocode", "code-oss", "vscode", "code"],
    "dolphin": ["org.kde.dolphin", "dolphin", "system-file-manager"],
    "org.kde.dolphin": ["org.kde.dolphin", "dolphin", "system-file-manager"],
    "nautilus": ["org.gnome.Nautilus", "org.gnome.nautilus", "nautilus", "system-file-manager", "file-manager"],
    "org.gnome.nautilus": ["org.gnome.Nautilus", "org.gnome.nautilus", "nautilus", "system-file-manager", "file-manager"],
    "org.gnome.Nautilus": ["org.gnome.Nautilus", "org.gnome.nautilus", "nautilus", "system-file-manager", "file-manager"],
    "files": ["org.gnome.Nautilus", "org.gnome.nautilus", "nautilus", "system-file-manager", "file-manager"],
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
    "telegram": ["org.telegram.desktop", "telegram", "telegramdesktop", "org.telegram"],
    "org.telegram": ["org.telegram.desktop", "telegram", "telegramdesktop", "org.telegram"],
    "telegramdesktop": ["org.telegram.desktop", "telegram", "telegramdesktop", "org.telegram"],
    "obsidian": ["obsidian", "md.obsidian.Obsidian"],
    "spotify": ["spotify", "spotify-client"],
    "google-photos": ["google-photos", "photos", "googlephotos"],
    "photos": ["google-photos", "photos"],
    "photos.google.com": ["google-photos", "photos"],
    "chrome-photos.google.com__-default": ["google-photos", "photos"],
    "google-contacts": ["google-contacts", "contacts", "googlecontacts"],
    "contacts": ["google-contacts", "contacts"],
    "contacts.google.com": ["google-contacts", "contacts"],
    "chrome-contacts.google.com__-default": ["google-contacts", "contacts"],
    "google-messages": ["google-messages", "messages", "googlemessages"],
    "messages": ["google-messages", "messages"],
    "messages.google.com": ["google-messages", "messages"],
    "chrome-messages.google.com__web_conversations-default": ["google-messages", "messages"],
    "google-maps": ["google-maps", "maps", "googlemaps"],
    "maps.google.com": ["google-maps", "maps"],
    "chrome-maps.google.com__-default": ["google-maps", "maps"],
    "gmail": ["gmail", "google-gmail", "mail-google"],
    "mail.google.com": ["gmail", "google-gmail"],
    "google-calendar": ["google-calendar", "calendar-google"],
    "calendar.google.com": ["google-calendar", "calendar-google"],
    "google-drive": ["google-drive", "drive-google"],
    "drive.google.com": ["google-drive", "drive-google"],
    "google-keep": ["google-keep", "keep-google"],
    "keep.google.com": ["google-keep", "keep-google"],
    "youtube": ["youtube", "youtube-browser"],
    "youtube.com": ["youtube", "youtube-browser"],
    "youtube-music": ["youtube-music", "music-youtube"],
    "music.youtube.com": ["youtube-music", "music-youtube"],
    "yandex-mail": ["yandex-mail", "mail-yandex", "yandex-browser-mail"],
    "mail.yandex.ru": ["yandex-mail", "mail-yandex"],
    "yandex-music": ["yandex-music", "music-yandex"],
    "music.yandex.ru": ["yandex-music", "music-yandex"],
    "photoshop": ["Photoshop2017", "photoshop", "adobe-photoshop"],
    "photoshop 2017": ["Photoshop2017", "photoshop", "adobe-photoshop"]
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

    if (clean.indexOf("org.omarchy.") === 0 || clean.indexOf("omarchy-") === 0 || clean.indexOf("omarchy.") === 0) {
        if (clean.indexOf("update") !== -1) {
            add("system-software-update");
            add("software-update-available");
            add("update-manager");
            add("system-upgrade");
        }
        if (clean.indexOf("config") !== -1 || clean.indexOf("settings") !== -1 || clean.indexOf("edit") !== -1) {
            add("preferences-system");
            add("configuration-section");
            add("system-settings");
            add("preferences-desktop");
        }
        if (clean.indexOf("about") !== -1 || clean.indexOf("info") !== -1) {
            add("help-about");
            add("help");
            add("dialog-information");
        }
        add("omarchy");
        add("utilities-terminal");
        add("com.mitchellh.ghostty");
        add("ghostty");
    }

    var chromeDom = extractChromeDomain(clean);
    if (chromeDom) {
        add(chromeDom);
        if (FALLBACK_ICON_CANDIDATES[chromeDom]) {
            var fbc = FALLBACK_ICON_CANDIDATES[chromeDom];
            for (var fc = 0; fc < fbc.length; fc++) add(fbc[fc]);
        }
        var domParts = chromeDom.split(".");
        for (var dp = 0; dp < domParts.length; dp++) {
            var dpart = domParts[dp];
            if (dpart.length >= 3 && dpart !== "com" && dpart !== "org" && dpart !== "net") {
                add(dpart);
                if (FALLBACK_ICON_CANDIDATES[dpart]) {
                    var fbd = FALLBACK_ICON_CANDIDATES[dpart];
                    for (var fd = 0; fd < fbd.length; fd++) add(fbd[fd]);
                }
            }
        }
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

function unwrapEntry(e) {
    if (!e) return null;
    if (e.entry && typeof e.entry === "object") return e.entry;
    return e;
}

function findEntry(desktopEntries, appId) {
    var id = stripDesktop(appId);
    if (!id) return null;

    if (desktopEntries && desktopEntries.length > 0) {
        var list = toArray(desktopEntries);
        var target = id.toLowerCase();
        var targetNorm = normalizeKey(target);
        var chromeDom = extractChromeDomain(id);

        // 1. Exact match on entry.id (with and without .desktop / .exe)
        for (var i = 0; i < list.length; i++) {
            var entry = unwrapEntry(list[i]);
            if (!entry) continue;
            var entryId = stripDesktop(entry.id || "").toLowerCase();
            if (entryId === target) return entry;
        }

        // 1b. Exact match on entry.name (case-insensitive)
        for (var m = 0; m < list.length; m++) {
            var em = unwrapEntry(list[m]);
            if (!em) continue;
            var emName = String(em.name || "").toLowerCase();
            if (emName === target) return em;
        }

        // 1c. Exact URL / Domain match in exec or entry.id for Chrome Web Apps
        if (chromeDom.length > 0) {
            for (var c = 0; c < list.length; c++) {
                var ce = unwrapEntry(list[c]);
                if (!ce) continue;
                var cExec = String(ce.exec || "").toLowerCase();
                var cId = stripDesktop(ce.id || "").toLowerCase();
                if (cExec.indexOf(chromeDom) !== -1 || cId.indexOf(chromeDom) !== -1) {
                    return ce;
                }
            }
        }

        // 2. Normalized key match on entry.id, name, or icon
        for (var j = 0; j < list.length; j++) {
            var e = unwrapEntry(list[j]);
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

        // 2b. Known App Default ID match (e.g. target "photoshop" matching "Photoshop 2017.desktop")
        if (KNOWN_APP_DEFAULTS[target]) {
            var defId = stripDesktop(KNOWN_APP_DEFAULTS[target].id || "").toLowerCase();
            if (defId && defId !== target) {
                for (var kd = 0; kd < list.length; kd++) {
                    var kde = unwrapEntry(list[kd]);
                    if (!kde) continue;
                    var kdeId = stripDesktop(kde.id || "").toLowerCase();
                    if (kdeId === defId) return kde;
                }
            }
        }

        // 3. Web App / Chrome domain token word matching (matching whole words, NOT substring like photos in photoshop)
        if (chromeDom.length > 0) {
            var domParts = chromeDom.split(".");
            var meaningfulParts = [];
            for (var p = 0; p < domParts.length; p++) {
                var part = domParts[p];
                if (part.length >= 3 && part !== "com" && part !== "org" && part !== "net" && part !== "web" && part !== "app" && part !== "google" && part !== "yandex" && part !== "microsoft" && part !== "apple") {
                    meaningfulParts.push(part);
                }
            }

            if (meaningfulParts.length > 0) {
                for (var c2 = 0; c2 < list.length; c2++) {
                    var ce2 = unwrapEntry(list[c2]);
                    if (!ce2) continue;
                    var cNameTokens = String(ce2.name || "").toLowerCase().split(/[\s\-_\.]+/);
                    var cIdTokens = stripDesktop(ce2.id || "").toLowerCase().split(/[\s\-_\.]+/);
                    var cIconTokens = String(ce2.icon || "").toLowerCase().split(/[\s\-_\.]+/);
                    var allTokens = cNameTokens.concat(cIdTokens).concat(cIconTokens);

                    var allMatched = true;
                    for (var mp = 0; mp < meaningfulParts.length; mp++) {
                        var mpart = meaningfulParts[mp];
                        var partFound = false;
                        for (var t = 0; t < allTokens.length; t++) {
                            var tok = allTokens[t];
                            if (tok === mpart || (mpart.endsWith("s") && tok === mpart.slice(0, -1)) || (tok.endsWith("s") && tok.slice(0, -1) === mpart)) {
                                partFound = true;
                                break;
                            }
                        }
                        if (!partFound) {
                            allMatched = false;
                            break;
                        }
                    }
                    if (allMatched) {
                        return ce2;
                    }
                }
            }
        }

        // 4. Substring / Exec binary match (exact binary name or exact name)
        for (var k = 0; k < list.length; k++) {
            var el = unwrapEntry(list[k]);
            if (!el) continue;
            var exec = String(el.exec || "").toLowerCase();
            var execBin = exec.split(/\s+/)[0].split("/").pop();
            var name = String(el.name || "").toLowerCase();
            if (execBin === target || name === target) return el;
        }
    }

    var cleanId = id.toLowerCase();
    if (KNOWN_APP_DEFAULTS[cleanId]) return KNOWN_APP_DEFAULTS[cleanId];
    if (chromeDom && KNOWN_APP_DEFAULTS[chromeDom]) return KNOWN_APP_DEFAULTS[chromeDom];

    return null;
}

function resolveIcon(entry, appId, appLibrary) {
    if (entry && entry.iconSource && entry.iconSource.length > 0 && entry.iconSource.indexOf("application-x-executable") === -1) {
        return entry.iconSource;
    }
    if (entry && entry.icon) {
        var iconVal = String(entry.icon).trim();
        if (iconVal.indexOf("file://") === 0 || iconVal.indexOf("image://") === 0) return iconVal;
        if (iconVal.charAt(0) === "/") return "file://" + iconVal;
        if (appLibrary && typeof appLibrary.iconSource === "function") {
            var src = appLibrary.iconSource(iconVal);
            if (src && src.length > 0 && src.indexOf("application-x-executable") === -1) return src;
        }
        return iconVal;
    }
    var id = stripDesktop(appId);
    if (appLibrary && typeof appLibrary.iconSource === "function") {
        var candidates = getCandidates(entry ? entry.icon : "", "", id);
        for (var i = 0; i < candidates.length; i++) {
            var cand = candidates[i];
            if (cand.indexOf("file://") === 0 || cand.indexOf("image://") === 0) return cand;
            if (cand.charAt(0) === "/") return "file://" + cand;
            var cSrc = appLibrary.iconSource(cand);
            if (cSrc && cSrc.length > 0 && cSrc.indexOf("application-x-executable") === -1) return cSrc;
        }

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

    var appClassClean = stripDesktop(appClass);

    var chromeDom = extractChromeDomain(appClass);
    var isWebAppWindow = (chromeDom.length > 0);

    // If this window is a Chrome Web App (e.g. chrome-maps.google.com__-Default):
    // Standard web browser dock items (Google Chrome, Chromium, Brave) should NOT swallow it!
    if (isWebAppWindow && isBrowserApp(cleanId)) {
        return false;
    }

    // 1. Direct class match (with and without .desktop / .exe)
    if (cleanId && (appClass === cleanId || appClassClean === cleanId || appClass === (cleanId + ".desktop") || appClass === (cleanId + ".exe"))) return true;

    // 2. Normalized match
    var normClass = normalizeKey(appClassClean);
    var normId = cleanId ? normalizeKey(cleanId) : "";
    if (normId.length > 0 && normClass === normId) return true;

    // 3. Entry ID, Name, Icon and Exec match
    if (entry) {
        var entryId = stripDesktop(entry.id || "").toLowerCase();
        if (entryId && (appClass === entryId || appClassClean === entryId || normClass === normalizeKey(entryId))) return true;

        var entryName = String(entry.name || "").toLowerCase();
        if (entryName) {
            var normEntryName = normalizeKey(entryName);
            if (normClass === normEntryName) return true;
            var nameTokens = entryName.split(/[\s\-_\.]+/);
            for (var nt = 0; nt < nameTokens.length; nt++) {
                if (nameTokens[nt] === appClassClean) return true;
            }
        }

        var entryIcon = String(entry.icon || "").toLowerCase();
        if (entryIcon && (normClass === normalizeKey(entryIcon))) return true;

        if (entry.exec) {
            var execStr = String(entry.exec).trim().toLowerCase();
            var execBase = execStr.split(/\s+/)[0].split("/").pop();
            if (execBase && !isWebAppWindow && (appClass === execBase || appClassClean === execBase)) return true;
        }
    }

    // 4. Chrome / Web App Matching
    if (isWebAppWindow) {
        if (entry && entry.exec && entry.exec.toLowerCase().indexOf(chromeDom) !== -1) return true;
        if (entry && entry.id && entry.id.toLowerCase().indexOf(chromeDom) !== -1) return true;
        if (cleanId && cleanId.indexOf(chromeDom) !== -1) return true;
        if (normId.length > 0 && normId.indexOf(normalizeKey(chromeDom)) !== -1) return true;

        // Check specific service keywords (e.g. "photos" in "photos.google.com") matching candidate dock item tokens
        var domParts = chromeDom.split(".");
        for (var p = 0; p < domParts.length; p++) {
            var part = domParts[p];
            if (part.length >= 3 && part !== "com" && part !== "org" && part !== "net" && part !== "web" && part !== "app" && part !== "google" && part !== "yandex" && part !== "microsoft" && part !== "apple") {
                var eNameTokens = entry && entry.name ? String(entry.name).toLowerCase().split(/[\s\-_\.]+/) : [];
                var eIdTokens = entry && entry.id ? stripDesktop(entry.id).toLowerCase().split(/[\s\-_\.]+/) : [];
                var eIconTokens = entry && entry.icon ? String(entry.icon).toLowerCase().split(/[\s\-_\.]+/) : [];
                var cleanIdTokens = cleanId ? cleanId.split(/[\s\-_\.]+/) : [];
                var allETokens = eNameTokens.concat(eIdTokens).concat(eIconTokens).concat(cleanIdTokens);

                for (var t = 0; t < allETokens.length; t++) {
                    var tok = allETokens[t];
                    if (tok === part || (part.endsWith("s") && tok === part.slice(0, -1)) || (tok.endsWith("s") && tok.slice(0, -1) === part)) {
                        return true;
                    }
                }
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

function toCanonical(str) {
    if (!str || typeof str !== "string") return "";
    var raw = str.trim().toLowerCase();
    if (!raw) return "";

    // 1. First-class desktop & Web App service aliases
    if (raw.indexOf("telegram") !== -1) return "telegram";
    if (raw.indexOf("whatsapp") !== -1) return "whatsapp";
    if (raw.indexOf("chatgpt") !== -1 || raw.indexOf("openai") !== -1) return "chatgpt";
    if (raw.indexOf("claude") !== -1 || raw.indexOf("anthropic") !== -1) return "claude";
    if (raw.indexOf("gemini") !== -1) return "gemini";
    if (raw.indexOf("notion") !== -1) return "notion";
    if (raw.indexOf("figma") !== -1) return "figma";
    if (raw.indexOf("github") !== -1) return "github";
    if (raw.indexOf("gitlab") !== -1) return "gitlab";
    if (raw.indexOf("linear") !== -1) return "linear";
    if (raw.indexOf("trello") !== -1) return "trello";
    if (raw.indexOf("jira") !== -1) return "jira";
    if (raw.indexOf("slack") !== -1) return "slack";
    if (raw.indexOf("discord") !== -1 || raw.indexOf("vesktop") !== -1 || raw.indexOf("webcord") !== -1) return "discord";
    if (raw.indexOf("spotify") !== -1) return "spotify";
    if (raw.indexOf("gmail") !== -1 || raw.indexOf("mail.google.com") !== -1) return "gmail";
    if (raw.indexOf("outlook") !== -1) return "outlook";
    if (raw.indexOf("proton") !== -1 || raw.indexOf("protonmail") !== -1) return "protonmail";
    if (raw.indexOf("antigravity") !== -1) return "antigravity";
    if (raw.indexOf("code") !== -1 || raw.indexOf("vscodium") !== -1 || raw.indexOf("vscode") !== -1) return "code";
    if (raw.indexOf("nautilus") !== -1 || raw.indexOf("org.gnome.nautilus") !== -1 || raw.indexOf("thunar") !== -1 || raw.indexOf("dolphin") !== -1) return "nautilus";
    if (raw.indexOf("kitty") !== -1 || raw.indexOf("alacritty") !== -1 || raw.indexOf("ghostty") !== -1 || raw.indexOf("foot") !== -1 || raw.indexOf("terminal") !== -1) return "terminal";
    if (raw.indexOf("chrome") !== -1 || raw.indexOf("chromium") !== -1) return "chrome";
    if (raw.indexOf("firefox") !== -1 || raw.indexOf("zen-browser") !== -1) return "firefox";

    // 2. Extract domain core from Web App URLs
    var urlMatch = raw.match(/https?:\/\/(?:www\.|web\.|app\.|mail\.)?([a-zA-Z0-9-]+)\./i);
    if (urlMatch && urlMatch[1]) {
        var dom = urlMatch[1].toLowerCase();
        if (["com", "org", "net", "io", "app", "dev"].indexOf(dom) === -1) {
            return dom;
        }
    }

    // 3. Generic stripping
    var s = raw;
    s = s.replace(/\.desktop$/i, "");
    s = s.replace(/\.appimage$/i, "");
    s = s.replace(/-(?:bin|git|stable|nightly|electron|desktop)$/i, "");
    s = s.replace(/^(?:org|com|io|net|edu|dev)\.[a-z0-9_]+\./i, "");
    s = s.replace(/^(?:org|com|io|net|edu|dev)\./i, "");
    return s.replace(/[^a-z0-9]/g, "");
}

function getBadgeInfo(badgeCounts, urgentCounts, appId, entry, name, desktopId) {
    if (!badgeCounts || typeof badgeCounts !== "object") return { count: 0, hasUrgent: false };
    var rawKeys = [
        appId,
        entry ? entry.id : "",
        entry ? stripDesktop(entry.id) : "",
        desktopId,
        desktopId ? stripDesktop(desktopId) : "",
        name,
        entry ? entry.name : "",
        entry ? entry.exec : ""
    ];
    var keys = [];
    for (var k = 0; k < rawKeys.length; k++) {
        var r = String(rawKeys[k] || "").trim();
        if (!r) continue;
        if (keys.indexOf(r) === -1) keys.push(r);
        var canon = toCanonical(r);
        if (canon && keys.indexOf(canon) === -1) keys.push(canon);
    }

    var count = 0;
    var isUrgent = false;
    for (var i = 0; i < keys.length; i++) {
        var raw = String(keys[i] || "").trim().toLowerCase();
        if (!raw) continue;
        if (badgeCounts[raw] != null && Number(badgeCounts[raw]) > count) {
            count = Number(badgeCounts[raw]);
        }
        if (urgentCounts && urgentCounts[raw] === true) {
            isUrgent = true;
        }
        var clean = raw.replace(/[^a-z0-9]/g, "");
        if (clean && badgeCounts[clean] != null && Number(badgeCounts[clean]) > count) {
            count = Number(badgeCounts[clean]);
        }
        if (clean && urgentCounts && urgentCounts[clean] === true) {
            isUrgent = true;
        }
    }
    return { count: count, hasUrgent: isUrgent };
}

function buildDockItems(pinnedList, toplevelsList, activeToplevel, desktopEntries, appLibrary, badgeCounts, urgentCounts, maxItems) {
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
                var sDesktopId = (sEntry && sEntry.id) ? sEntry.id : (sAppId.indexOf(".desktop") !== -1 ? sAppId : (sAppId + ".desktop"));

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

                var sInfo = getBadgeInfo(badgeCounts, urgentCounts, sAppId, sEntry, sName, sDesktopId);

                subApps.push({
                    appId: sAppId,
                    desktopId: sDesktopId,
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
                    badgeCount: sInfo.count,
                    hasUrgent: sInfo.hasUrgent,
                    toplevels: sTops
                });
            }

            var totalStackBadge = 0;
            var hasStackUrgent = false;
            for (var sb = 0; sb < subApps.length; sb++) {
                totalStackBadge += (subApps[sb].badgeCount || 0);
                if (subApps[sb].hasUrgent) hasStackUrgent = true;
            }

            items.push({
                id: p.id || ("stack_" + i),
                appId: p.id || ("stack_" + i),
                desktopId: "",
                exec: "",
                name: p.name !== undefined ? p.name : "Folder",
                icon: p.icon || "folder",
                rawIcon: p.icon || "folder",
                isStack: true,
                isPinned: true,
                isDuplicate: false,
                isRunning: isAnySubRunning,
                isActive: isAnySubActive,
                windowCount: 0,
                badgeCount: totalStackBadge,
                hasUrgent: hasStackUrgent,
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

            var itemInfo = getBadgeInfo(badgeCounts, urgentCounts, appId, entry, name, desktopId);

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
                badgeCount: itemInfo.count,
                hasUrgent: itemInfo.hasUrgent,
                toplevels: matching
            });
        }
    }

    // 2. Process Running Unpinned Toplevels (Stop if limit reached)
    for (var j = 0; j < toplevels.length; j++) {
        if (maxItems && maxItems > 0 && items.length >= maxItems) {
            break;
        }

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

        var rInfo = getBadgeInfo(badgeCounts, urgentCounts, rAppId, rEntry, rName, rDesktopId);

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
            badgeCount: rInfo.count,
            hasUrgent: rInfo.hasUrgent,
            toplevels: rMatching
        });
    }

    return items;
}
