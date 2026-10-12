import QtQuick
import Quickshell

Region {
    id: root
    required property Item surface
    property real translationX: 0
    property real translationY: 0
    property bool hidden: false

    // Quickshell watches an item's position and size, but not its Translate
    // animation. An item-based Region therefore keeps the input area at the
    // first animation frame even after the dock card has moved on screen.
    // Explicit coordinates update the Wayland input region on every frame.
    x: hidden ? 0 : Math.floor(surface.x + translationX)
    y: hidden ? 0 : Math.floor(surface.y + translationY)
    width: hidden ? 0 : Math.ceil(surface.x + translationX + surface.width) - x
    height: hidden ? 0 : Math.ceil(surface.y + translationY + surface.height) - y
}
