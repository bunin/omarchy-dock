import QtQuick
import qs.Commons

Item {
    id: root

    property string text: ""
    property string fontFamily: Style.font.family
    property real fontSize: 14
    property color color: Color.foreground

    readonly property int renderedFontSize: Math.max(1, Math.round(fontSize))
    readonly property real tightWidth: Math.max(1, glyphMetrics.tightBoundingRect.width)
    readonly property real horizontalCorrection: glyph.implicitWidth / 2 - (glyphMetrics.tightBoundingRect.x + tightWidth / 2)

    TextMetrics {
        id: glyphMetrics
        font.family: root.fontFamily
        font.pixelSize: root.renderedFontSize
        font.hintingPreference: Font.PreferNoHinting
        text: root.text
    }

    Text {
        id: glyph
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.horizontalCorrection
        text: root.text
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.renderedFontSize
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.CurveRendering
        antialiasing: true
        smooth: true
    }
}
