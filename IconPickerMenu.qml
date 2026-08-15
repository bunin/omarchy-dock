import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Ui

Popup {
    id: root

    signal iconSelected(string glyph)

    property var iconsList: [
        { glyph: "󰌨", label: "Command" },
        { glyph: "󰘳", label: "Categories" },
        { glyph: "󰀻", label: "Dock" },
        { glyph: "󰮔", label: "Apps" },
        { glyph: "✦", label: "Sparkle" },
        { glyph: "★", label: "Star" },
        { glyph: "❖", label: "Symbol" },
        { glyph: "◈", label: "Diamond" },
        { glyph: "⊞", label: "Grid" },
        { glyph: "🚀", label: "Rocket" },
        { glyph: "⚡", label: "Bolt" },
        { glyph: "⬡", label: "Hexagon" },
        { glyph: "⚙", label: "Gear" },
        { glyph: "📂", label: "Folder" },
        { glyph: "🖥", label: "Screen" },
        { glyph: "●", label: "Circle" }
    ]

    width: 260
    padding: 10
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: Color.composed("popups.background", "popups.background-alpha", Color.background, 0.95)
        border.width: 1.5
        border.color: Color.accent
        radius: Style.cardRadius || 12
    }

    contentItem: ColumnLayout {
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Select Bar Icon"
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                Layout.fillWidth: true
            }

            Text {
                text: "✕"
                font.pixelSize: 12
                color: Color.muted
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Color.composed("popups.border", "popups.border-alpha", Color.accent, 0.25)
        }

        GridLayout {
            columns: 4
            rowSpacing: 6
            columnSpacing: 6
            Layout.fillWidth: true

            Repeater {
                model: root.iconsList

                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 46
                    radius: 8
                    color: mouseArea.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
                    border.width: 1
                    border.color: mouseArea.containsMouse ? Color.accent : Color.composed("popups.border", "popups.border-alpha", Color.accent, 0.15)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.glyph
                            font.pixelSize: 16
                            color: mouseArea.containsMouse ? Color.accent : Color.popups.text
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            font.family: Style.font.family
                            font.pixelSize: 8
                            color: Color.muted
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.iconSelected(modelData.glyph);
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
