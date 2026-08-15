# Omarchy Dock

![Omarchy Dock](./screanshot.png)

A native, animated application dock for Omarchy Quattro with Hyprland workspace tracking, Drag & Drop reordering, and seamless Omarchy theme integration.

---

## ✨ Features

- 🚀 **Smart App Switching & Launching** — Click an icon to open the app or instantly switch to the exact workspace where it is already running.
- 📌 **Pin & Unpin Favorites** — Right-click any app to toggle pin status with the star button (`★` / `☆`). Pinned apps persist across reboots.
- 🔀 **Drag & Drop Reordering** — Drag and rearrange icons directly on the dock. Your custom order is automatically saved.
- ⚡ **Quick Window Controls** — Launch an extra window instance (`＋`) or close a running app (`✕`) from the right-click action card.
- 🎨 **Full Omarchy Theme Sync** — Automatically adapts to your active system theme colors, accent borders, and window corner radius.
- 🔘 **Bar Widget with Icon Picker** — Toggle the dock from your status bar. Right-click the bar widget to choose custom glyphs (Command Center, Dock, Rocket, Apps, etc.).
- 💡 **Live Status Indicators** — Glowing accent dots show active and running applications.

---

## 📦 Manual Installation

### 1. Clone the repository
Clone this plugin directly into your Omarchy plugins directory:

```bash
git clone https://github.com/rosakodu/omarchy-dock.git ~/.config/omarchy/plugins/rosakodu.dock
```

### 2. Rescan plugins & restart shell
Reload Omarchy shell to discover and register the new plugin:

```bash
omarchy-shell shell rescanPlugins
omarchy-restart-shell
```

---

## 🗑️ Uninstallation

To remove the dock:

```bash
rm -rf ~/.config/omarchy/plugins/rosakodu.dock
omarchy-shell shell rescanPlugins
omarchy-restart-shell
```

---

## 📄 License
[MIT](./LICENSE) © 2026 rosakodu
