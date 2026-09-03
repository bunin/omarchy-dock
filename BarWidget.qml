import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "DockSettings.js" as DockSettings
import "components"

BarWidget {
  id: root
  moduleName: "rosakodu.dock"

  property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/dock-settings.json"
  property bool dockEnabled: true
  property string visibilityMode: "always"
  readonly property bool autohide: root.visibilityMode !== "always"
  property bool overlayMode: false
  property string visibleWorkspace: "all"
  property string dockPosition: DockSettings.DOCK_POSITION_AUTO
  property bool showFolderTitles: true
  property bool showBadges: true
  property bool widgetsEnabled: true
  readonly property bool settingsOpen: settingsWindow.open
  property bool isSavingSettings: false

  Timer {
    id: saveSettingsTimer
    interval: 350
    repeat: false
    onTriggered: {
      root.isSavingSettings = false
    }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.readSettings()
    onFileChanged: {
      if (!root.isSavingSettings) {
        reload()
        root.readSettings()
      }
    }
  }

  property var dockWidgets: ["omarchy.apps"]
  property string appMenuPosition: "left"
  property string widgetPosition: "right"
  property var widgetSavedPositions: ({})
  property string preferredVisibilityMode: "hover"
  readonly property string effectiveMode: root.autohide ? root.visibilityMode : (root.preferredVisibilityMode || "hover")

  function readSettings() {
    if (root.isSavingSettings) return
    try {
      var txt = settingsFile.text()
      if (txt && txt.trim().length > 0) {
        var s = JSON.parse(txt)
        var normalized = DockSettings.normalize(s)
        root.visibilityMode = normalized.visibilityMode
        if (s && s.preferredVisibilityMode !== undefined) {
          var pvm = String(s.preferredVisibilityMode).trim().toLowerCase()
          if (pvm === "hover" || pvm === "keybind") root.preferredVisibilityMode = pvm
        } else if (normalized.visibilityMode === "hover" || normalized.visibilityMode === "keybind") {
          root.preferredVisibilityMode = normalized.visibilityMode
        }
        root.overlayMode = normalized.overlayMode
        root.visibleWorkspace = normalized.visibleWorkspace
        root.dockPosition = normalized.dockPosition
        if (s && s.dockEnabled !== undefined) {
          root.dockEnabled = (s.dockEnabled === true || s.dockEnabled === "true" || s.dockEnabled === 1 || s.dockEnabled === "1")
        } else {
          root.dockEnabled = true
        }
        if (s && s.showFolderTitles !== undefined) {
          root.showFolderTitles = (s.showFolderTitles === true)
        }
        if (s && s.showBadges !== undefined) {
          root.showBadges = (s.showBadges === true)
        }
        if (s && s.widgetsEnabled !== undefined) {
          root.widgetsEnabled = (s.widgetsEnabled === true)
        }
        if (s && s.appMenuPosition !== undefined) {
          root.appMenuPosition = s.appMenuPosition
        }
        if (s && s.widgetPosition !== undefined) {
          root.widgetPosition = s.widgetPosition
        }
        if (s && s.dockWidgets !== undefined && Array.isArray(s.dockWidgets)) {
          root.dockWidgets = s.dockWidgets
        }
        if (s && s.widgetSavedPositions !== undefined && typeof s.widgetSavedPositions === "object") {
          root.widgetSavedPositions = s.widgetSavedPositions
        }
      }
    } catch(e) {}
  }

  function saveSettings() {
    root.isSavingSettings = true
    saveSettingsTimer.restart()
    var s = {}
    try {
      var txt = settingsFile.text()
      if (txt && txt.trim().length > 0) {
        s = JSON.parse(txt) || {}
      }
    } catch(e) {}

    s.dockEnabled = root.dockEnabled
    s.visibilityMode = root.visibilityMode
    s.preferredVisibilityMode = root.preferredVisibilityMode
    s.autohide = DockSettings.legacyAutohide(root.visibilityMode)
    s.overlayMode = root.overlayMode
    s.visibleWorkspace = root.visibleWorkspace
    s.dockPosition = root.dockPosition
    s.showFolderTitles = root.showFolderTitles
    s.showBadges = root.showBadges
    s.widgetsEnabled = root.widgetsEnabled
    s.appMenuPosition = root.appMenuPosition || s.appMenuPosition || "left"
    s.widgetPosition = root.widgetPosition || s.widgetPosition || "right"
    s.widgetSavedPositions = root.widgetSavedPositions || s.widgetSavedPositions || {}
    if (!root.widgetsEnabled) {
      s.dockWidgets = []
    } else if (Array.isArray(s.dockWidgets) && s.dockWidgets.length > 0) {
      s.dockWidgets = s.dockWidgets.slice(0, 2)
    } else if (Array.isArray(root.dockWidgets) && root.dockWidgets.length > 0) {
      s.dockWidgets = root.dockWidgets.slice(0, 2)
    } else {
      s.dockWidgets = ["omarchy.apps"]
    }

    settingsFile.setText(JSON.stringify(s, null, 2) + "\n")
  }

  function setDockEnabled(val) {
    root.dockEnabled = val
    saveSettings()
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setDockEnabled " + (val ? "true" : "false"))
    }
  }

  function setAutohide(val) {
    if (val) {
      if (!root.dockEnabled) {
        root.dockEnabled = true
      }
      root.visibilityMode = root.preferredVisibilityMode || "hover"
    } else {
      if (root.visibilityMode === "hover" || root.visibilityMode === "keybind") {
        root.preferredVisibilityMode = root.visibilityMode
      }
      root.visibilityMode = "always"
    }
    saveSettings()
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setAutohide " + (val ? "true" : "false"))
    }
  }

  function setOverlayMode(val) {
    root.overlayMode = val
    saveSettings()
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setOverlayMode " + (val ? "true" : "false"))
    }
  }

  function setVisibilityMode(mode) {
    var norm = DockSettings.normalizeVisibilityMode(mode, false)
    if (norm === "hover" || norm === "keybind") {
      root.preferredVisibilityMode = norm
    }
    root.visibilityMode = norm
    saveSettings()
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setVisibilityMode " + root.visibilityMode)
    }
  }

  function setVisibleWorkspace(workspace) {
    root.visibleWorkspace = DockSettings.normalizeVisibleWorkspace(workspace)
    saveSettings()
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setVisibleWorkspace " + root.visibleWorkspace)
    }
  }

  function setDockPosition(position) {
    root.dockPosition = DockSettings.normalizeDockPosition(position)
    saveSettings()
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setDockPosition " + root.dockPosition)
    }
  }

  readonly property var dockPositionOptions: [
    { value: "auto", label: "Auto (opposite the bar)" },
    { value: "top", label: "Top edge" },
    { value: "bottom", label: "Bottom edge" },
    { value: "left", label: "Left edge" },
    { value: "right", label: "Right edge" }
  ]

  function buildWorkspaceOptions() {
    var opts = [
      { value: "all", label: "All workspaces" }
    ]
    var existingIds = [1, 2, 3, 4, 5]
    if (Hyprland && Hyprland.workspaces && Hyprland.workspaces.values) {
      var values = Hyprland.workspaces.values
      for (var i = 0; i < values.length; i++) {
        var ws = values[i]
        if (ws && ws.id > 0 && ws.id <= 10 && existingIds.indexOf(ws.id) === -1) {
          existingIds.push(ws.id)
        }
      }
    }
    if (root.visibleWorkspace !== "all") {
      var selId = parseInt(root.visibleWorkspace, 10)
      if (!isNaN(selId) && selId > 0 && selId <= 10 && existingIds.indexOf(selId) === -1) {
        existingIds.push(selId)
      }
    }
    existingIds.sort(function(a, b) { return a - b })
    for (var j = 0; j < existingIds.length; j++) {
      var id = existingIds[j]
      var label = (id === 10 || id === 0) ? "Workspace 0" : ("Workspace " + id)
      opts.push({
        value: String(id),
        label: label
      })
    }
    return opts
  }

  readonly property var workspaceOptions: {
    var _dummy = Hyprland && Hyprland.workspaces && Hyprland.workspaces.values ? Hyprland.workspaces.values.length : 0
    var _sel = root.visibleWorkspace
    return root.buildWorkspaceOptions()
  }

  function setShowFolderTitles(val) {
    root.showFolderTitles = val
    saveSettings()
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setShowFolderTitles " + (val ? "true" : "false"))
    }
  }

  function setShowBadges(val) {
    root.showBadges = val
    saveSettings()
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setShowBadges " + (val ? "true" : "false"))
    }
  }

  function setWidgetsEnabled(val) {
    root.widgetsEnabled = val
    saveSettings()
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setWidgetsEnabled " + (val ? "true" : "false"))
    }
  }

  readonly property bool opened: settingsWindow.open
  function open() { settingsWindow.open = true }
  function close() { settingsWindow.open = false }
  function toggle() { settingsWindow.open = !settingsWindow.open }
  function closeForPopoutSwitch() { close() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "···"
    tooltipText: "Dock Settings"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        root.toggle()
      }
    }
  }

  // Standard Omarchy KeyboardPanel (Exact same screen level, gap, and animation as Weather & Audio)
  KeyboardPanel {
    id: settingsWindow
    anchorItem: button
    owner: root
    bar: root.bar
    centerOnBar: true
    contentWidth: (Style && typeof Style.space === "function") ? Style.space(410) : 410
    contentHeight: (root.autohide && root.effectiveMode === "keybind") ? 550 : 480
    borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.accent, Color.accent, Math.max(1, Style.space(2)))

    ColumnLayout {
      id: cardColumn
      anchors.fill: parent
      spacing: 10

        // Header Row
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          DockGlyph {
            width: 16
            height: 16
            text: "⚙"
            fontFamily: Style.font.family
            fontSize: 14
            color: Color.accent
          }

          Text {
            text: "Dock Settings"
            textFormat: Text.PlainText
            font.family: Style.font.family
            font.pixelSize: 13
            font.bold: true
            color: Color.popups.text
            Layout.fillWidth: true
          }
        }

        // Divider
        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: Color.composed("popups.border", "popups.border-alpha", Color.border, 0.35)
        }

        // Top Slot (Fixed 42px: crossfades Enable Dock switch <-> Reveal Method dropdown)
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 42
          Layout.minimumHeight: 42
          Layout.maximumHeight: 42

          // Mode A: Enable dock toggle row
          Rectangle {
            id: dockEnabledRow
            anchors.fill: parent
            radius: 8
            opacity: !root.autohide ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: !root.autohide
            color: toggleDockEnabledMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8

              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                  Layout.fillWidth: true
                  text: "Enable dock"
                  textFormat: Text.PlainText
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: Color.popups.text
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  text: "Show dock panel on screen"
                  textFormat: Text.PlainText
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.muted
                  elide: Text.ElideRight
                }
              }

              // Custom Smooth Toggle Switch
              Rectangle {
                id: switchDockEnabledTrack
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                Layout.preferredWidth: 36
                Layout.minimumWidth: 36
                Layout.maximumWidth: 36
                Layout.preferredHeight: 20
                width: 36
                height: 20
                radius: 10
                color: root.dockEnabled ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
                Behavior on color { ColorAnimation { duration: 180 } }

                Rectangle {
                  id: switchDockEnabledThumb
                  width: 14
                  height: 14
                  radius: 7
                  anchors.verticalCenter: parent.verticalCenter
                  x: root.dockEnabled ? (switchDockEnabledTrack.width - width - 3) : 3
                  color: root.dockEnabled ? Color.background : Color.popups.text
                  Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
              }
            }

            MouseArea {
              id: toggleDockEnabledMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.setDockEnabled(!root.dockEnabled)
              }
            }
          }

          // Mode B: Reveal Method Dropdown
          DockDropdown {
            id: revealMethodDropdown
            anchors.fill: parent
            opacity: root.autohide ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.autohide
            value: root.effectiveMode === "keybind" ? "keybind" : "hover"
            options: [
              { value: "hover", label: "Screen-edge hover" },
              { value: "keybind", label: "Keyboard shortcut" }
            ]
            onChanged: function(value) { root.setVisibilityMode(value) }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          }
        }

        DockDropdown {
          Layout.fillWidth: true
          showLabel: false
          value: root.visibleWorkspace
          options: root.workspaceOptions
          onChanged: function(value) { root.setVisibleWorkspace(value) }
        }

        DockDropdown {
          Layout.fillWidth: true
          showLabel: false
          value: root.dockPosition
          options: root.dockPositionOptions
          onChanged: function(value) { root.setDockPosition(value) }
        }

        // Toggle Autohide Row
        Rectangle {
          id: autohideRow
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Autohide dock"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Reveal dock only on demand"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.minimumWidth: 36
              Layout.maximumWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.autohide ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.autohide ? (switchTrack.width - width - 3) : 3
                color: root.autohide ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setAutohide(!root.autohide)
            }
          }
        }

        // Snippet Block (smoothly expands ONLY when Keyboard shortcut mode is active)
        ColumnLayout {
          id: hintBlock
          Layout.fillWidth: true
          Layout.leftMargin: 2
          Layout.rightMargin: 2
          Layout.topMargin: 0
          Layout.bottomMargin: (root.autohide && root.effectiveMode === "keybind") ? 4 : 0
          Layout.preferredHeight: (root.autohide && root.effectiveMode === "keybind") ? 64 : 0
          clip: true
          visible: (root.autohide && root.effectiveMode === "keybind")
          opacity: (root.autohide && root.effectiveMode === "keybind") ? 1.0 : 0.0
          spacing: 4

          Text {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            text: "Add to ~/.config/hypr/bindings.lua:"
            textFormat: Text.PlainText
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
            color: Color.popups.text
            elide: Text.ElideRight
          }

          Rectangle {
            id: cmdPill
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.minimumHeight: 44
            Layout.maximumHeight: 44
            radius: 6
            color: cmdMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : Color.composed("popups.border", "popups.border-alpha", Color.border, 0.25)
            border.width: 1
            border.color: cmdMouse.containsMouse ? Color.accent : Color.composed("popups.border", "popups.border-alpha", Color.border, 0.4)
            Behavior on color { ColorAnimation { duration: 120 } }

            property bool copied: false
            Timer {
              id: copyTimer
              interval: 1800
              repeat: false
              onTriggered: cmdPill.copied = false
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8

              Text {
                id: cmdText
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: cmdPill.copied ? "✓ Copied to clipboard!" : "o.bind(\"SUPER + D\", \"Toggle Dock\",\n  \"omarchy-shell -q rosakodu.dock toggleReveal\")"
                textFormat: Text.PlainText
                font.family: !cmdPill.copied ? (Style.font.monospace || "monospace") : Style.font.family
                font.pixelSize: !cmdPill.copied ? 9 : 10
                lineHeight: 1.18
                font.bold: cmdPill.copied
                color: cmdPill.copied ? Color.accent : Color.popups.text
                wrapMode: Text.Wrap
                verticalAlignment: Text.AlignVCenter
              }

              DockGlyph {
                width: 14
                height: 14
                text: cmdPill.copied ? "󰄬" : "󰆏"
                fontFamily: Style.font.family
                fontSize: 11
                color: cmdPill.copied ? Color.accent : Color.muted
              }
            }

            MouseArea {
              id: cmdMouse
              anchors.fill: parent
              enabled: root.autohide && root.effectiveMode === "keybind"
              hoverEnabled: root.autohide && root.effectiveMode === "keybind"
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var cmd = 'o.bind("SUPER + D", "Toggle Dock", "omarchy-shell -q rosakodu.dock toggleReveal")'
                try {
                  Quickshell.clipboardText = cmd
                } catch(e) {}
                if (root.bar && typeof root.bar.run === "function") {
                  root.bar.run(["wl-copy", cmd])
                }
                cmdPill.copied = true
                copyTimer.restart()
              }
            }
          }
        }

        // Toggle Overlay Mode Row
        Rectangle {
          id: overlayRow
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleOverlayMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Overlay mode"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Float on top of application windows"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchOverlayTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.overlayMode ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchOverlayThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.overlayMode ? (switchOverlayTrack.width - width - 3) : 3
                color: root.overlayMode ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleOverlayMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setOverlayMode(!root.overlayMode)
            }
          }
        }

        // Toggle Notification Badges Row
        Rectangle {
          id: badgesRow
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleBadgesMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Notification badges"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Show unread counter on app icons"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchBadgesTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.showBadges ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchBadgesThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.showBadges ? (switchBadgesTrack.width - width - 3) : 3
                color: root.showBadges ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleBadgesMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setShowBadges(!root.showBadges)
            }
          }
        }

        // Toggle Widgets in Dock Row
        Rectangle {
          id: widgetsRow
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleWidgetsMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Dock widgets"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Integrate app menu and bar widgets"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchWidgetsTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.widgetsEnabled ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchWidgetsThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.widgetsEnabled ? (switchWidgetsTrack.width - width - 3) : 3
                color: root.widgetsEnabled ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleWidgetsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setWidgetsEnabled(!root.widgetsEnabled)
            }
          }
        }

        // Configure Widgets Action Button
        Rectangle {
          id: configureWidgetsRow
          Layout.fillWidth: true
          Layout.preferredHeight: 40
          radius: 8
          opacity: root.widgetsEnabled ? 1.0 : 0.4
          enabled: root.widgetsEnabled
          color: configureWidgetsMouse.containsMouse ? Color.composed("accent", "accent-alpha", Color.accent, 0.2) : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.08)
          border.width: 1
          border.color: configureWidgetsMouse.containsMouse ? Color.accent : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }
          Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

          Text {
            anchors.centerIn: parent
            text: "Configure dock widgets"
            textFormat: Text.PlainText
            font.family: Style.font.family
            font.pixelSize: 11
            font.bold: true
            color: configureWidgetsMouse.containsMouse ? Color.accent : Color.popups.text
            renderType: Text.CurveRendering
            font.hintingPreference: Font.PreferNoHinting
            Behavior on color { ColorAnimation { duration: 120 } }
          }

          MouseArea {
            id: configureWidgetsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
              var sh = root.shell || (root.bar ? root.bar.shell : null)
              var dockSvc = (sh && typeof sh.serviceFor === "function") ? sh.serviceFor("rosakodu.dock") : null
              if (dockSvc && typeof dockSvc.openWidgetPicker === "function") {
                dockSvc.openWidgetPicker()
              } else if (root.bar && typeof root.bar.run === "function") {
                root.bar.run("omarchy-shell rosakodu.dock openWidgetPicker")
              } else {
                Util.execDetached("omarchy-shell rosakodu.dock openWidgetPicker")
              }
            }
          }
        }
      }
    }
  }
