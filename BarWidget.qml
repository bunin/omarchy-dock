import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "rosakodu.dock"

  property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/dock-settings.json"
  property bool dockEnabled: true
  property bool autohide: false
  property bool showFolderTitles: true
  property bool widgetsEnabled: true
  property bool settingsOpen: false

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.readSettings()
    onFileChanged: { reload(); root.readSettings() }
  }

  function readSettings() {
    try {
      var txt = settingsFile.text()
      if (txt && txt.trim().length > 0) {
        var s = JSON.parse(txt)
        if (s && s.dockEnabled !== undefined) {
          root.dockEnabled = (s.dockEnabled === true)
        }
        if (s && s.autohide !== undefined) {
          root.autohide = (s.autohide === true)
        }
        if (s && s.showFolderTitles !== undefined) {
          root.showFolderTitles = (s.showFolderTitles === true)
        }
        if (s && s.widgetsEnabled !== undefined) {
          root.widgetsEnabled = (s.widgetsEnabled === true)
        }
      }
    } catch(e) {}
  }

  function saveSettings() {
    var s = {}
    try {
      var txt = settingsFile.text()
      if (txt && txt.trim().length > 0) {
        s = JSON.parse(txt) || {}
      }
    } catch(e) {}

    s.dockEnabled = root.dockEnabled
    s.autohide = root.autohide
    s.showFolderTitles = root.showFolderTitles
    s.widgetsEnabled = root.widgetsEnabled
    if (!root.widgetsEnabled) {
      s.dockWidgets = []
    } else if (!Array.isArray(s.dockWidgets)) {
      s.dockWidgets = []
    }
    if (!s.widgetSavedPositions) s.widgetSavedPositions = {}
    if (!s.widgetPosition) s.widgetPosition = "right"

    settingsFile.setText(JSON.stringify(s, null, 2) + "\n")
  }

  function setDockEnabled(val) {
    root.dockEnabled = val
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setDockEnabled " + (val ? "true" : "false"))
    } else {
      saveSettings()
    }
  }

  function setAutohide(val) {
    root.autohide = val
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setAutohide " + (val ? "true" : "false"))
    } else {
      saveSettings()
    }
  }

  function setShowFolderTitles(val) {
    root.showFolderTitles = val
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setShowFolderTitles " + (val ? "true" : "false"))
    } else {
      saveSettings()
    }
  }

  function setWidgetsEnabled(val) {
    root.widgetsEnabled = val
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run("omarchy-shell rosakodu.dock setWidgetsEnabled " + (val ? "true" : "false"))
    } else {
      saveSettings()
    }
  }

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
        root.settingsOpen = !root.settingsOpen
      }
    }
  }

  onSettingsOpenChanged: {
    if (settingsOpen) {
      settingsCard.forceActiveFocus()
    }
  }

  // Outside-click dismissal for Settings popup
  HyprlandFocusGrab {
    id: settingsGrab
    active: root.settingsOpen
    windows: [settingsWindow]
    onCleared: {
      root.settingsOpen = false
    }
  }

  // Settings Popup Overlay Window (Strictly centered horizontally on screen, matching Weather panel)
  PanelWindow {
    id: settingsWindow
    visible: root.settingsOpen

    WlrLayershell.namespace: "omarchy-dock-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    readonly property bool isBarBottom: root.bar && root.bar.position === "bottom"
    readonly property bool isBarLeft: root.bar && root.bar.position === "left"
    readonly property bool isBarRight: root.bar && root.bar.position === "right"

    readonly property real screenWidth: root.bar && root.bar.screen ? root.bar.screen.width : (Screen.width || 1920)
    readonly property real screenHeight: root.bar && root.bar.screen ? root.bar.screen.height : (Screen.height || 1080)
    // Strictly centered horizontally on screen for top/bottom bar, vertically for left/right bar
    readonly property real calculatedLeft: Math.round((screenWidth - 280) / 2)
    readonly property real calculatedTop: Math.round((screenHeight - (settingsCard.height || 120)) / 2)

    anchors {
      top: (isBarRight || isBarLeft) ? true : !isBarBottom
      bottom: isBarBottom
      left: isBarRight ? false : true
      right: isBarRight
    }

    margins {
      top: (isBarLeft || isBarRight) ? calculatedTop : (isBarBottom ? 0 : ((Style.gapsOut || 5) + 38))
      bottom: isBarBottom ? ((Style.gapsOut || 5) + 38) : 0
      left: isBarRight ? 0 : (isBarLeft ? ((Style.gapsOut || 5) + 38) : calculatedLeft)
      right: isBarRight ? ((Style.gapsOut || 5) + 38) : 0
    }

    implicitWidth: 280
    implicitHeight: settingsCard.height

    Rectangle {
      id: settingsCard
      focus: true
      Keys.onEscapePressed: function(event) {
        root.settingsOpen = false
        event.accepted = true
      }
      Keys.onBackPressed: function(event) {
        root.settingsOpen = false
        event.accepted = true
      }
      width: 280
      height: cardColumn.height + 24
      color: Color.composed("popups.background", "popups.background-alpha", Color.background, 0.96)
      border.width: Style.borderWidth || 2
      border.color: Color.accent
      radius: Style.cornerRadius >= 0 ? Style.cornerRadius : 12
      antialiasing: true
      smooth: true

      ColumnLayout {
        id: cardColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
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

        // Toggle Enable Dock Row (at the very top)
        Rectangle {
          id: enableDockRow
          Layout.fillWidth: true
          height: 48
          radius: 8
          color: toggleEnableMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 2

              Text {
                text: "Enable dock"
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
              }

              Text {
                text: "Show or hide dock bar"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchEnableTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.dockEnabled ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchEnableThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.dockEnabled ? (switchEnableTrack.width - width - 3) : 3
                color: root.dockEnabled ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleEnableMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setDockEnabled(!root.dockEnabled)
            }
          }
        }

        // Toggle Autohide Row
        Rectangle {
          id: autohideRow
          Layout.fillWidth: true
          height: 48
          radius: 8
          opacity: root.dockEnabled ? 1.0 : 0.4
          enabled: root.dockEnabled
          color: toggleMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on opacity { NumberAnimation { duration: 150 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 2

              Text {
                text: "Autohide dock"
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
              }

              Text {
                text: "Hide dock when not hovered"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
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

        // Toggle Folder Names Row
        Rectangle {
          id: folderTitlesRow
          Layout.fillWidth: true
          height: 48
          radius: 8
          opacity: root.dockEnabled ? 1.0 : 0.4
          enabled: root.dockEnabled
          color: toggleTitlesMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on opacity { NumberAnimation { duration: 150 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 2

              Text {
                text: "Folder names"
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
              }

              Text {
                text: "Show titles in folder popups"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchTitlesTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.showFolderTitles ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchTitlesThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.showFolderTitles ? (switchTitlesTrack.width - width - 3) : 3
                color: root.showFolderTitles ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleTitlesMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setShowFolderTitles(!root.showFolderTitles)
            }
          }
        }

        // Toggle Widgets in Dock Row
        Rectangle {
          id: widgetsRow
          Layout.fillWidth: true
          height: 48
          radius: 8
          opacity: root.dockEnabled ? 1.0 : 0.4
          enabled: root.dockEnabled
          color: toggleWidgetsMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on opacity { NumberAnimation { duration: 150 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 2

              Text {
                text: "Dock widgets"
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
              }

              Text {
                text: "Display bar widgets on dock"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
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
          opacity: (root.dockEnabled && root.widgetsEnabled) ? 1.0 : 0.4
          enabled: root.dockEnabled && root.widgetsEnabled
          color: configureWidgetsMouse.containsMouse ? Color.composed("accent", "accent-alpha", Color.accent, 0.2) : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.08)
          border.width: 1
          border.color: configureWidgetsMouse.containsMouse ? Color.accent : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }
          Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

          Text {
            anchors.centerIn: parent
            text: "Configure dock widgets"
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
              root.settingsOpen = false
              var sh = root.shell || (root.bar ? root.bar.shell : null)
              if (sh && typeof sh.summon === "function") {
                sh.summon("rosakodu.dock", { action: "openWidgetPicker" })
              } else if (root.bar && typeof root.bar.run === "function") {
                root.bar.run("omarchy-shell shell summon rosakodu.dock '{\"action\":\"openWidgetPicker\"}'")
              } else {
                Util.execDetached("omarchy-shell shell summon rosakodu.dock '{\"action\":\"openWidgetPicker\"}'")
              }
            }
          }
        }
      }
    }
  }
}
