#!/usr/bin/env python3
import glob
import json
import os
import re
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
    "yazi", "nvim", "neovim", "vim", "nano", "micro", "helix", "hx", "emacs",
    "btop", "htop", "top", "bottom", "btm", "glances", "bashtop", "nvtop",
    "ranger", "superfile", "broot", "vifm", "nnn", "lf", "fff", "mc",
    "lazygit", "lazydocker", "tig", "gitui", "k9s",
    "ncmpcpp", "cmus", "mocp", "cava",
    "tmux", "zellij", "cmatrix", "pipes.sh", "fastfetch", "neofetch", "cbonsai", "tty-clock"
]

KNOWN_TERMINALS = [
    "foot", "footclient", "kitty", "alacritty", "ghostty", "wezterm",
    "org.wezfurlong.wezterm", "gnome-terminal", "konsole", "xfce4-terminal",
    "xterm", "urxvt", "rxvt", "termite", "tilix", "st", "rio"
]

def extract_cli_app(title):
    if not title:
        return ""
    raw = str(title).lower().strip()
    tokens = [t for t in re.split(r'[\s:,\-_/\\()\[\]{}|]+', raw) if t]
    if not tokens:
        return ""
    first = tokens[0]
    if first in KNOWN_CLI_COMMANDS:
        if first in ("neovim", "vim"):
            return "nvim"
        if first == "hx":
            return "helix"
        if first == "btm":
            return "bottom"
        return first
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

def launch_fallback(queries):
    # Try finding desktop id or exec to launch via uwsm-app
    for q in queries:
        if not q or q.startswith("0x"):
            continue
        if q.endswith(".desktop"):
            try:
                subprocess.Popen(["uwsm-app", "--", "gtk-launch", q], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                try:
                    subprocess.Popen(["gtk-launch", q], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    return
                except Exception:
                    pass
    for q in queries:
        if not q or q.startswith("0x"):
            continue
        if " " in q or "/" in q:
            try:
                subprocess.Popen(f"uwsm-app -- {q}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                try:
                    subprocess.Popen(q, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    return
                except Exception:
                    pass
        elif len(q) >= 2:
            try:
                subprocess.Popen(["uwsm-app", "--", "gtk-launch", q], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                try:
                    subprocess.Popen(["uwsm-app", "--", q], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    return
                except Exception:
                    pass

def main():
    if len(sys.argv) < 2:
        return

    mode = "minimize"
    arg_start = 1
    if sys.argv[1] in ("minimize", "restore", "restore-or-launch"):
        mode = sys.argv[1]
        arg_start = 2

    queries = [q.strip() for q in sys.argv[arg_start:] if q.strip()]
    if not queries:
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

    norm_queries = [normalize(q) for q in queries]
    raw_queries = [q.lower() for q in queries]
    addr_queries = [q.lower() for q in queries if q.startswith("0x") or (len(q) > 4 and all(c in "0123456789abcdef" for c in q.lower().replace("0x", "")))]

    is_terminal_query = any(is_terminal_identifier(q) for q in queries)
    target_cli = ""
    for q in queries:
        norm_q = normalize(q)
        if norm_q in KNOWN_CLI_COMMANDS:
            target_cli = norm_q
            break

    matching = []
    for c in clients:
        c_addr = str(c.get("address", "")).lower()
        c_class = str(c.get("class", "")).lower()
        c_init_class = str(c.get("initialClass", "")).lower()
        c_title = str(c.get("title", "")).lower()
        
        c_norm_class = normalize(c_class)
        c_norm_init = normalize(c_init_class)
        is_client_terminal = is_terminal_identifier(c_class) or is_terminal_identifier(c_init_class)
        cli_app = extract_cli_app(c_title) if is_client_terminal else ""

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

    if mode == "minimize":
        if visible_windows:
            active_addr = ""
            try:
                active_raw = hypr_cmd(sock_path, "j/activewindow")
                if active_raw:
                    active_obj = json.loads(active_raw)
                    active_addr = str(active_obj.get("address", "")).lower()
            except Exception:
                active_addr = ""

            minimized_had_focus = False
            for c in visible_windows:
                addr = c["address"]
                if active_addr and str(addr).lower() == active_addr:
                    minimized_had_focus = True
                ws_obj = c.get("workspace", {})
                orig_ws = str(ws_obj.get("name") or ws_obj.get("id") or focused_ws)
                if orig_ws.startswith("special:"):
                    orig_ws = focused_ws
                saved[addr] = orig_ws

                cmd = f'dispatch hl.dsp.window.move({{ window = "address:{addr}", workspace = "special:minimized" }})'
                res = hypr_cmd(sock_path, cmd)
                if "error" in res.lower():
                    hypr_cmd(sock_path, f"dispatch movetoworkspacesilent special:minimized,address:{addr}")

            close_any_special(sock_path)
            # Focus handling:
            # 1. If the window that was minimized had active focus -> focus the adjacent visible window on the workspace!
            # 2. If minimizing a background window or a window on another workspace -> preserve your active window focus untouched!
            minimized_addrs = [str(c["address"]).lower() for c in visible_windows]
            if minimized_had_focus:
                # Find remaining visible windows on the active workspace
                remaining = [
                    c for c in clients
                    if str(c.get("address", "")).lower() not in minimized_addrs
                    and not str(c.get("workspace", {}).get("name", "")).startswith("special:")
                    and str(c.get("workspace", {}).get("name") or c.get("workspace", {}).get("id") or "") == focused_ws
                ]
                if remaining:
                    target_addr = remaining[0]["address"]
                    hypr_cmd(sock_path, f'dispatch hl.dsp.focus({{ window = "address:{target_addr}" }})')
            elif active_addr:
                hypr_cmd(sock_path, f'dispatch hl.dsp.focus({{ window = "address:{active_addr}" }})')
            try:
                with open(cache_file, "w") as f:
                    json.dump(saved, f)
            except Exception:
                pass
        return

    elif mode in ("restore", "restore-or-launch"):
        if minimized_windows:
            for c in minimized_windows:
                addr = c["address"]
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
            return
        elif visible_windows:
            addr = visible_windows[0]["address"]
            hypr_cmd(sock_path, f'dispatch hl.dsp.focus({{ window = "address:{addr}" }})')
            return
        else:
            if mode == "restore-or-launch":
                launch_fallback(queries)

if __name__ == "__main__":
    main()
