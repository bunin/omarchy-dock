// DockLauncher.js — Application launcher module for Omarchy Dock

.pragma library

function escapeShellArg(arg) {
    return "'" + String(arg == null ? "" : arg).replace(/'/g, "'\\''") + "'";
}

function parseDesktopExec(execStr) {
    if (!execStr || typeof execStr !== "string") return [];
    // Remove desktop field codes (%f, %u, %F, %U, etc.) according to FreeDesktop spec
    var raw = execStr.replace(/%%/g, "\x00")
                     .replace(/%[a-zA-Z]/g, "")
                     .replace(/\x00/g, "%")
                     .trim();
    if (!raw) return [];

    var args = [];
    var current = "";
    var inQuotes = false;
    var escape = false;

    for (var i = 0; i < raw.length; i++) {
        var ch = raw[i];

        if (escape) {
            current += ch;
            escape = false;
            continue;
        }

        if (ch === "\\") {
            escape = true;
            continue;
        }

        if (ch === '"') {
            inQuotes = !inQuotes;
            continue;
        }

        if (!inQuotes && (ch === " " || ch === "\t")) {
            if (current.length > 0) {
                args.push(current);
                current = "";
            }
            continue;
        }

        current += ch;
    }

    if (current.length > 0) {
        args.push(current);
    }

    return args;
}

function launchApp(shell, itemData, util) {
    if (!itemData) return;
    var launchId = itemData.desktopId || itemData.appId || "";
    var appName = itemData.name || "";

    // 1. Primary: Use Omarchy's official shell.appLibrary launcher
    if (shell && shell.appLibrary && typeof shell.appLibrary.launch === "function") {
        shell.appLibrary.launch(launchId, appName);
        return;
    }

    // 2. Fallback: Launch via gtk-launch or individually-escaped argv
    var target = launchId ? (launchId.indexOf(".desktop") !== -1 ? launchId : (launchId + ".desktop")) : "";
    var quote = (util && typeof util.shellQuote === "function") ? util.shellQuote : escapeShellArg;
    var argv = parseDesktopExec(itemData.exec);

    var fallbackCmd = "";
    if (argv.length > 0) {
        var escapedArgs = [];
        for (var a = 0; a < argv.length; a++) {
            escapedArgs.push(quote(argv[a]));
        }
        fallbackCmd = "uwsm-app -- " + escapedArgs.join(" ");
    }

    var cmd = "";
    if (target) {
        cmd = "uwsm-app -- gtk-launch " + quote(target);
        if (fallbackCmd) {
            cmd += " || (" + fallbackCmd + ")";
        }
    } else if (fallbackCmd) {
        cmd = fallbackCmd;
    }

    if (cmd && util && typeof util.execDetached === "function") {
        util.execDetached(cmd);
    }
}
