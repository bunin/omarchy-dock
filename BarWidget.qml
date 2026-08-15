import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "rosakodu.dock"

  readonly property string configuredIcon: setting("iconGlyph", "󰘳")
  readonly property string activeIcon: configuredIcon

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property bool isDockOpen: {
    if (root.bar && root.bar.shell && root.bar.shell.panelLoaders) {
      var loader = root.bar.shell.panelLoaders["rosakodu.dock"]
      if (loader && loader.item && loader.item.opened !== undefined) {
        return loader.item.opened === true
      }
    }
    if (root.bar && root.bar.shell && typeof root.bar.shell.isPluginOpen === "function") {
      return root.bar.shell.isPluginOpen("rosakodu.dock")
    }
    return true
  }

  function toggleDock() {
    if (root.bar && root.bar.shell && typeof root.bar.shell.callIfLoaded === "function") {
      root.bar.shell.callIfLoaded("rosakodu.dock", "toggle", "")
    } else if (root.bar && root.bar.shell && typeof root.bar.shell.toggle === "function") {
      root.bar.shell.toggle("rosakodu.dock", "{}")
    } else if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell shell call rosakodu.dock toggle ''")
    }
  }

  function updateIcon(newIcon) {
    var entry = { id: root.moduleName, iconGlyph: newIcon }
    for (var key in root.settings) {
      if (key !== "id") entry[key] = root.settings[key]
    }
    entry.iconGlyph = newIcon
    root.settings = entry

    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.activeIcon
    fontFamily: Style.font.family
    horizontalMargin: 4.5
    active: root.isDockOpen
    useActiveColor: true
    activeColor: Color.accent
    foreground: Color.bar.text
    dimmed: !root.isDockOpen
    tooltipText: "Dock"

    onPressed: function(pressedButton) {
      if (!root.bar) return
      if (pressedButton === Qt.RightButton) {
        iconPicker.showNear(button)
      } else {
        root.toggleDock()
      }
    }
  }

  IconPickerMenu {
    id: iconPicker

    function showNear(target) {
      if (!target) return
      var pos = target.mapToItem(null, 0, 0)
      x = Math.max(10, pos.x - width / 2 + target.width / 2)
      y = root.vertical ? pos.y : (pos.y + target.height + 8)
      open()
    }

    onIconSelected: function(glyph) {
      root.updateIcon(glyph)
    }
  }
}
