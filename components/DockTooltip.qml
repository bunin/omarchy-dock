import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import ".."

// Label for the dock icon under the pointer. Deliberately inert: it never
// takes pointer or keyboard input, because catching the pointer would pull
// hover off the icon that summoned it and flicker the tooltip away.
PanelWindow {
    id: tipWindow

    required property var root
    required property var dockWindow

    readonly property string text: tipWindow.root.tooltipText
    readonly property bool vertical: tipWindow.root.isVertical

    // Clear the dock card and the gap on either side of it.
    readonly property int dockGap: (Style.gapsOut || 5)
    readonly property int dockOffset: dockGap + (tipWindow.root.slotSize + 8) + dockGap

    visible: tipWindow.root.tooltipShown
             && tipWindow.root.dockRevealed
             && tipWindow.text.length > 0

    screen: tipWindow.dockWindow ? tipWindow.dockWindow.screen : null

    WlrLayershell.namespace: "omarchy-dock-tooltip"
    // Matches the dock: a tooltip for a dock summoned over a fullscreen window
    // has to be able to draw there too.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Empty input region: the surface is painted but pointer-transparent.
    mask: Region {}
    color: "transparent"

    // Span the axis the dock runs along, then place the card by hand at the
    // hovered icon; anchor across that axis to sit just off the dock.
    anchors {
        top: tipWindow.vertical || tipWindow.root.oppositeEdge === "bottom"
        bottom: tipWindow.vertical || tipWindow.root.oppositeEdge === "top"
        left: tipWindow.vertical ? (tipWindow.root.oppositeEdge === "right") : true
        right: tipWindow.vertical ? (tipWindow.root.oppositeEdge === "left") : true
    }

    margins {
        top: (!tipWindow.vertical && tipWindow.root.oppositeEdge === "bottom") ? tipWindow.dockOffset : 0
        bottom: (!tipWindow.vertical && tipWindow.root.oppositeEdge === "top") ? tipWindow.dockOffset : 0
        left: (tipWindow.vertical && tipWindow.root.oppositeEdge === "right") ? tipWindow.dockOffset : 0
        right: (tipWindow.vertical && tipWindow.root.oppositeEdge === "left") ? tipWindow.dockOffset : 0
    }

    implicitWidth: tipWindow.vertical ? card.width : (screen ? screen.width : 1920)
    implicitHeight: tipWindow.vertical ? (screen ? screen.height : 1080) : card.height

    BorderSurface {
        id: card

        readonly property int edgePadding: 4

        width: label.implicitWidth + Style.space(16)
        height: label.implicitHeight + Style.space(10)
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border,
                                              Color.popups.border, Style.normalBorderWidth)

        // Centre on the hovered icon, then keep the whole card on screen.
        x: tipWindow.vertical
            ? 0
            : Math.max(edgePadding,
                Math.min(tipWindow.width - width - edgePadding,
                         tipWindow.root.tooltipAxisCenter - width / 2))
        y: tipWindow.vertical
            ? Math.max(edgePadding,
                Math.min(tipWindow.height - height - edgePadding,
                         tipWindow.root.tooltipAxisCenter - height / 2))
            : 0

        opacity: tipWindow.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Text {
            id: label
            anchors.centerIn: parent
            text: tipWindow.text
            textFormat: Text.PlainText
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            renderType: Text.NativeRendering
        }
    }
}
