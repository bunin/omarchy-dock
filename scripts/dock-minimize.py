#!/usr/bin/env python3
import glob
import json
import os
import re
import shlex
import socket
import subprocess
import sys

def normalize(s):
    if not s:
        return ""
    val = str(s).lower().strip()
    if val.endswith(".desktop"):
        val = val[:-8]
    if val.endswith(".exe"):
        val = val[:-4]
    val = val.replace("org.", "").replace("com.", "").replace("net.", "").replace("io.", "")
    return "".join(c for c in val if c.isalnum())

KNOWN_CLI_COMMANDS = [
    "yazi", "nvim", "neovim", "vim", "nano", "micro", "helix", "hx", "emacs", "kakoune", "kak", "amp",
    "btop", "htop", "top", "bottom", "btm", "glances", "bashtop", "bpytop", "nvtop", "gotop",
    "ranger", "superfile", "broot", "vifm", "nnn", "lf", "fff", "mc", "midnight-commander", "clifm",
    "lazygit", "lazydocker", "tig", "gitui", "k9s", "ox", "bandwhich", "gping",
    "ncmpcpp", "cmus", "mocp", "cava", "cliamp", "rmpc", "spotify-tui", "spt", "mopidy", "musikcube",
    "weechat", "irssi", "profanity", "neomutt", "mutt", "aerc", "gomuks", "senpai",
    "tmux", "zellij", "cmatrix", "pipes.sh", "fastfetch", "neofetch", "cbonsai", "tty-clock", "peaclock", "termshark", "glow", "curseofwar"
]

IGNORED_COMMAND_PREFIXES = [
    "sudo", "doas", "pkexec", "pacman", "yay", "paru", "apt", "dnf", "zypper",
    "cargo", "npm", "pnpm", "yarn", "bun", "git", "make", "ninja", "cmake",
    "pip", "python", "python3", "node", "go", "rustc", "gcc", "clang",
    "find", "grep", "cat", "less", "more", "tail", "journalctl", "systemctl",
    "sh", "bash", "zsh", "fish", "exec", "run", "echo", "rm", "cp", "mv",
    "which", "whereis", "man", "info", "curl", "wget", "tar", "unzip", "zip",
    "home", "user", "usr", "etc", "bin", "tmp", "var", "opt", "desktop", "documents", "downloads", "music", "pictures", "videos"
]

KNOWN_TERMINALS = [
    "foot", "footclient", "kitty", "alacritty", "ghostty", "wezterm",
    "org.wezfurlong.wezterm", "gnome-terminal", "konsole", "xfce4-terminal",
    "xterm", "urxvt", "rxvt", "termite", "tilix", "st", "rio"
]

def get_terminal_child_app(pid):
    if not pid or not isinstance(pid, int) or pid <= 0:
        return ""
    try:
        # Check command line of terminal (e.g. "foot -e cliamp", "ghostty -e yazi")
        cmd_path = f"/proc/{pid}/cmdline"
        if os.path.exists(cmd_path):
            with open(cmd_path, "rb") as f:
                cmd_raw = f.read().decode("utf-8", errors="ignore").replace("\x00", " ").strip()
            cmd_tokens = [t for t in re.split(r'[\s:,\-_/\\()\[\]{}|]+', cmd_raw.lower()) if t]
            for t in cmd_tokens:
                if (t in KNOWN_CLI_COMMANDS or t == "cliamp") and not is_terminal_identifier(t):
                    if t in ("neovim", "vim"): return "nvim"
                    if t == "hx": return "helix"
                    if t == "btm": return "bottom"
                    return t

        # Check child processes
        children_path = f"/proc/{pid}/task/{pid}/children"
        if os.path.exists(children_path):
            with open(children_path, "r") as f:
                child_pids = f.read().split()
            for cpid in child_pids:
                comm_path = f"/proc/{cpid}/comm"
                if os.path.exists(comm_path):
                    with open(comm_path, "r") as f:
                        comm = f.read().strip().lower()
                    if comm in KNOWN_CLI_COMMANDS or comm == "cliamp":
                        if comm in ("neovim", "vim"): return "nvim"
                        if comm == "hx": return "helix"
                        if comm == "btm": return "bottom"
                        return comm
                c_cmd_path = f"/proc/{cpid}/cmdline"
                if os.path.exists(c_cmd_path):
                    with open(c_cmd_path, "rb") as f:
                        c_cmd_raw = f.read().decode("utf-8", errors="ignore").replace("\x00", " ").strip()
                    c_tokens = [t for t in re.split(r'[\s:,\-_/\\()\[\]{}|]+', c_cmd_raw.lower()) if t]
                    for ct in c_tokens:
                        if (ct in KNOWN_CLI_COMMANDS or ct == "cliamp") and not is_terminal_identifier(ct):
                            if ct in ("neovim", "vim"): return "nvim"
                            if ct == "hx": return "helix"
                            if ct == "btm": return "bottom"
                            return ct
                # Check grandchild processes in case child was a wrapper shell
                g_children_path = f"/proc/{cpid}/task/{cpid}/children"
                if os.path.exists(g_children_path):
                    with open(g_children_path, "r") as gf:
                        gchild_pids = gf.read().split()
                    for gcpid in gchild_pids:
                        gcomm_path = f"/proc/{gcpid}/comm"
                        if os.path.exists(gcomm_path):
                            with open(gcomm_path, "r") as gf2:
                                gcomm = gf2.read().strip().lower()
                            if gcomm in KNOWN_CLI_COMMANDS or gcomm == "cliamp":
                                if gcomm in ("neovim", "vim"): return "nvim"
                                if gcomm == "hx": return "helix"
                                if gcomm == "btm": return "bottom"
                                return gcomm
    except Exception:
        pass
    return ""

def extract_cli_app(title, pid=None):
    if pid:
        proc_app = get_terminal_child_app(pid)
        if proc_app:
            return proc_app

    if not title:
        return ""
    raw = str(title).lower().strip()
    tokens = [t for t in re.split(r'[\s:,\-_/\\()\[\]{}|]+', raw) if t]
    if not tokens:
        return ""
    
    # 1. Check all tokens against known commands
    for tok in tokens:
        if tok in IGNORED_COMMAND_PREFIXES:
            continue
        if tok in KNOWN_CLI_COMMANDS or tok == "cliamp":
            if tok in ("neovim", "vim"):
                return "nvim"
            if tok == "hx":
                return "helix"
            if tok == "btm":
                return "bottom"
            return tok

    # 2. Check special phrases
    if "nvim" in raw and "nvim" in tokens:
        return "nvim"
    if "whips" in raw or "terminal's ass" in raw or "cliamp" in raw:
        return "cliamp"

    return ""

def is_terminal_identifier(s):
    if not s:
        return False
    norm = normalize(s)
    for term in KNOWN_TERMINALS:
        if norm == normalize(term):
            return True
    return False

def get_hypr_socket():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if sig:
        p = f"{runtime}/hypr/{sig}/.socket.sock"
        if os.path.exists(p):
            return p
    socks = glob.glob(f"{runtime}/hypr/*/.socket.sock")
    if socks:
        return socks[0]
    return None

def hypr_cmd(sock_path, cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        s.sendall(cmd.encode())
        res = b""
        while True:
            data = s.recv(4096)
            if not data:
                break
            res += data
        s.close()
        return res.decode()
    except Exception:
        return ""

def close_any_special(sock_path):
    try:
        monitors_raw = hypr_cmd(sock_path, "j/monitors")
        monitors = json.loads(monitors_raw)
        for m in monitors:
            sw = m.get("specialWorkspace", {})
            sw_name = str(sw.get("name", ""))
            if sw_name and sw_name != "":
                clean_name = sw_name.replace("special:", "")
                hypr_cmd(sock_path, f'dispatch hl.dsp.workspace.toggle_special({{ workspace = "{clean_name}" }})')
    except Exception:
        pass

def parse_desktop_exec_argv(exec_str):
    if not exec_str or not isinstance(exec_str, str):
        return []
    # Remove FreeDesktop field codes (%f, %F, %u, %U, %i, %c, %k, %v, %m, %d, %D, %n, %N, %v)
    raw = re.sub(r'%%', '\x00', exec_str)
    raw = re.sub(r'%[a-zA-Z]', '', raw)
    raw = raw.replace('\x00', '%').strip()
    if not raw:
        return []
    try:
        return shlex.split(raw)
    except Exception:
        return raw.split()

def find_desktop_file(desktop_id):
    if not desktop_id or not isinstance(desktop_id, str):
        return ""
    if "/" in desktop_id or " " in desktop_id:
        return ""
    clean = desktop_id if desktop_id.endswith(".desktop") else (desktop_id + ".desktop")
    search_dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/share/applications",
        "/usr/local/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications")
    ]
    xdg_dirs = os.environ.get("XDG_DATA_DIRS", "").split(":")
    for d in xdg_dirs:
        if d:
            app_d = os.path.join(d, "applications")
            if app_d not in search_dirs:
                search_dirs.append(app_d)

    for base in search_dirs:
        candidate = os.path.join(base, clean)
        if os.path.isfile(candidate):
            return clean
    return ""

def launch_fallback(queries):
    # 1. First priority: desktop entry files that actually exist on disk via gtk-launch
    for q in queries:
        if not q or q.startswith("0x") or q.startswith("--"):
            continue
        desktop_id = find_desktop_file(q)
        if desktop_id:
            try:
                subprocess.Popen(["uwsm-app", "--", "gtk-launch", desktop_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                try:
                    subprocess.Popen(["gtk-launch", desktop_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    return
                except Exception:
                    pass

    # 2. Second priority: executable argv lists without shell=True
    for q in queries:
        if not q or q.startswith("0x") or q.startswith("--"):
            continue
        argv = parse_desktop_exec_argv(q)
        if argv:
            try:
                subprocess.Popen(["uwsm-app", "--"] + argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                try:
                    subprocess.Popen(argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    return
                except Exception:
                    pass

def main():
    if len(sys.argv) < 2:
        return

    mode = "minimize"
    arg_start = 1
    if sys.argv[1] in ("minimize", "restore", "restore-or-launch", "toggle-active", "toggle-or-cycle", "toggle-instance", "activate-instance", "toggle", "activate", "scan-cli"):
        mode = sys.argv[1]
        arg_start = 2

    queries = [q.strip() for q in sys.argv[arg_start:] if q.strip()]
    if not queries and mode != "scan-cli":
        return

    sock_path = get_hypr_socket()
    if not sock_path:
        if mode == "restore-or-launch":
            launch_fallback(queries)
        return

    clients_raw = hypr_cmd(sock_path, "j/clients")
    if not clients_raw:
        if mode == "restore-or-launch":
            launch_fallback(queries)
        return

    try:
        clients = json.loads(clients_raw)
    except Exception:
        if mode == "restore-or-launch":
            launch_fallback(queries)
        return

    if mode == "scan-cli":
        detected_apps = []
        for c in clients:
            c_cls = str(c.get("class", "")).lower()
            if is_terminal_identifier(c_cls):
                pid = c.get("pid")
                title = c.get("title", "")
                app = extract_cli_app(title, pid)
                if app and app not in detected_apps:
                    detected_apps.append(app)
        print(json.dumps(detected_apps))
        return

    target_index = -1
    filtered_queries = []
    for q in queries:
        if q.startswith("--index="):
            try:
                target_index = int(q.split("=")[1])
            except Exception:
                pass
        elif q.isdigit() and target_index == -1:
            try:
                target_index = int(q)
            except Exception:
                pass
        else:
            filtered_queries.append(q)
    queries = filtered_queries

    norm_queries = [normalize(q) for q in queries]
    raw_queries = [q.lower() for q in queries]
    addr_queries = [q.lower() for q in queries if q.startswith("0x") or (len(q) > 4 and all(c in "0123456789abcdef" for c in q.lower().replace("0x", "")))]

    is_terminal_query = bool(queries and is_terminal_identifier(queries[0]))
    target_cli = ""
    for q in queries:
        norm_q = normalize(q)
        clean_q = q.replace(".desktop", "").lower().strip()
        if clean_q in KNOWN_CLI_COMMANDS or clean_q == "cliamp":
            target_cli = clean_q
            if target_cli in ("neovim", "vim"): target_cli = "nvim"
            elif target_cli == "hx": target_cli = "helix"
            elif target_cli == "btm": target_cli = "bottom"
            break
        if norm_q in KNOWN_CLI_COMMANDS:
            target_cli = norm_q
            if target_cli in ("neovim", "vim"): target_cli = "nvim"
            elif target_cli == "hx": target_cli = "helix"
            elif target_cli == "btm": target_cli = "bottom"
            break
        exec_tokens = [t for t in re.split(r'[\s:,\-_/\\()\[\]{}|]+', q.lower()) if t]
        for et in exec_tokens:
            if (et in KNOWN_CLI_COMMANDS or et == "cliamp") and not is_terminal_identifier(et):
                target_cli = et
                if target_cli in ("neovim", "vim"): target_cli = "nvim"
                elif target_cli == "hx": target_cli = "helix"
                elif target_cli == "btm": target_cli = "bottom"
                break
        if target_cli:
            break

    if target_cli:
        is_terminal_query = False

    matching = []
    for c in clients:
        c_addr = str(c.get("address", "")).lower()
        c_class = str(c.get("class", "")).lower()
        c_init_class = str(c.get("initialClass", "")).lower()
        c_title = str(c.get("title", "")).lower()
        
        c_norm_class = normalize(c_class)
        c_norm_init = normalize(c_init_class)
        c_pid = c.get("pid")
        is_client_terminal = is_terminal_identifier(c_class) or is_terminal_identifier(c_init_class)
        cli_app = extract_cli_app(c_title, c_pid) if is_client_terminal else ""

        if addr_queries:
            if c_addr in addr_queries:
                matching.append(c)
            continue

        if target_cli:
            # When clicking a dedicated CLI app icon (e.g. yazi, nvim), match if the terminal window is running that CLI app
            if cli_app == target_cli:
                matching.append(c)
                continue
            elif is_client_terminal:
                continue

        if is_terminal_query:
            # When clicking a generic terminal icon (e.g. foot), never swallow a dedicated CLI app window (e.g. yazi, nvim)
            if cli_app:
                continue

        is_match = False
        for i, q in enumerate(raw_queries):
            nq = norm_queries[i]
            if q == c_addr or q == c_class or q == c_init_class:
                is_match = True
                break
            if nq and (nq == c_norm_class or nq == c_norm_init):
                is_match = True
                break
            if nq and len(nq) >= 3 and (nq == c_norm_class or nq == c_norm_init):
                is_match = True
                break

        if is_match:
            matching.append(c)

    cache_file = "/tmp/omarchy_dock_minimized.json"
    saved = {}
    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r") as f:
                saved = json.load(f)
        except Exception:
            saved = {}

    focused_ws = "1"
    try:
        monitors_raw = hypr_cmd(sock_path, "j/monitors")
        monitors = json.loads(monitors_raw)
        for m in monitors:
            if m.get("focused"):
                ws = m.get("activeWorkspace", {})
                focused_ws = str(ws.get("name") or ws.get("id") or "1")
                break
    except Exception:
        pass

    visible_windows = []
    minimized_windows = []

    for c in matching:
        ws_name = str(c.get("workspace", {}).get("name", ""))
        if ws_name.startswith("special:"):
            minimized_windows.append(c)
        else:
            visible_windows.append(c)

    if mode in ("toggle-instance", "toggle", "toggle-active", "minimize"):
        if not matching:
            return

        target_c = None
        if target_index >= 0 and target_index < len(matching):
            target_c = matching[target_index]
        else:
            active_addr = ""
            try:
                active_raw = hypr_cmd(sock_path, "j/activewindow")
                if active_raw:
                    active_obj = json.loads(active_raw)
                    active_addr = str(active_obj.get("address", "")).lower()
            except Exception:
                pass
            active_matches = [c for c in matching if str(c.get("address", "")).lower() == active_addr]
            if active_matches:
                target_c = active_matches[0]
            elif visible_windows:
                target_c = visible_windows[0]
            elif minimized_windows:
                target_c = minimized_windows[0]
            else:
                target_c = matching[0]

        addr = target_c["address"]
        is_min = str(target_c.get("workspace", {}).get("name", "")).startswith("special:")

        if is_min:
            # RESTORE target_c
            target_ws = focused_ws
            if not target_ws or str(target_ws).startswith("special:"):
                target_ws = saved.get(addr, "1")
            if str(target_ws).startswith("special:"):
                target_ws = "1"

            cmd_move = f'dispatch hl.dsp.window.move({{ window = "address:{addr}", workspace = "{target_ws}" }})'
            res = hypr_cmd(sock_path, cmd_move)
            if "error" in res.lower():
                hypr_cmd(sock_path, f"dispatch movetoworkspacesilent {target_ws},address:{addr}")

            cmd_focus = f'dispatch hl.dsp.focus({{ window = "address:{addr}" }})'
            res_focus = hypr_cmd(sock_path, cmd_focus)
            if "error" in res_focus.lower():
                hypr_cmd(sock_path, f"dispatch focuswindow address:{addr}")

            saved.pop(addr, None)
            close_any_special(sock_path)
        else:
            # MINIMIZE target_c
            ws_obj = target_c.get("workspace", {})
            orig_ws = str(ws_obj.get("name") or ws_obj.get("id") or focused_ws)
            if orig_ws.startswith("special:"):
                orig_ws = focused_ws
            saved[addr] = orig_ws

            cmd = f'dispatch hl.dsp.window.move({{ window = "address:{addr}", workspace = "special:minimized" }})'
            res = hypr_cmd(sock_path, cmd)
            if "error" in res.lower():
                hypr_cmd(sock_path, f"dispatch movetoworkspacesilent special:minimized,address:{addr}")

            close_any_special(sock_path)

            other_visible = [c for c in visible_windows if str(c.get("address", "")).lower() != str(addr).lower()]
            if other_visible:
                target_addr = other_visible[0]["address"]
                cmd_focus = f'dispatch hl.dsp.focus({{ window = "address:{target_addr}" }})'
                res_focus = hypr_cmd(sock_path, cmd_focus)
                if "error" in res_focus.lower():
                    hypr_cmd(sock_path, f"dispatch focuswindow address:{target_addr}")
            else:
                remaining = [
                    c for c in clients
                    if str(c.get("address", "")).lower() != str(addr).lower()
                    and not str(c.get("workspace", {}).get("name", "")).startswith("special:")
                    and str(c.get("workspace", {}).get("name") or c.get("workspace", {}).get("id") or "") == focused_ws
                ]
                if remaining:
                    target_addr = remaining[0]["address"]
                    hypr_cmd(sock_path, f'dispatch hl.dsp.focus({{ window = "address:{target_addr}" }})')

        try:
            with open(cache_file, "w") as f:
                json.dump(saved, f)
        except Exception:
            pass
        return

    elif mode in ("activate-instance", "activate", "restore", "restore-or-launch"):
        if not matching:
            launch_fallback(queries)
            return

        target_c = None
        if target_index >= 0 and target_index < len(matching):
            target_c = matching[target_index]
        else:
            if visible_windows:
                target_c = visible_windows[0]
            elif minimized_windows:
                target_c = minimized_windows[0]
            else:
                target_c = matching[0]

        addr = target_c["address"]
        is_min = str(target_c.get("workspace", {}).get("name", "")).startswith("special:")

        if is_min:
            target_ws = focused_ws
            if not target_ws or str(target_ws).startswith("special:"):
                target_ws = saved.get(addr, "1")
            if str(target_ws).startswith("special:"):
                target_ws = "1"

            cmd_move = f'dispatch hl.dsp.window.move({{ window = "address:{addr}", workspace = "{target_ws}" }})'
            res = hypr_cmd(sock_path, cmd_move)
            if "error" in res.lower():
                hypr_cmd(sock_path, f"dispatch movetoworkspacesilent {target_ws},address:{addr}")

            cmd_focus = f'dispatch hl.dsp.focus({{ window = "address:{addr}" }})'
            res_focus = hypr_cmd(sock_path, cmd_focus)
            if "error" in res_focus.lower():
                hypr_cmd(sock_path, f"dispatch focuswindow address:{addr}")

            saved.pop(addr, None)
            close_any_special(sock_path)
            try:
                with open(cache_file, "w") as f:
                    json.dump(saved, f)
            except Exception:
                pass
        else:
            cmd_focus = f'dispatch hl.dsp.focus({{ window = "address:{addr}" }})'
            res_focus = hypr_cmd(sock_path, cmd_focus)
            if "error" in res_focus.lower():
                hypr_cmd(sock_path, f"dispatch focuswindow address:{addr}")
        return

if __name__ == "__main__":
    main()
