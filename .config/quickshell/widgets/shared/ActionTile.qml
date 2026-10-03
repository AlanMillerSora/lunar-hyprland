import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  ActionTile — единая плитка-кнопка панелей: иконка + подпись,
//  hover, активный акцент. Размер задаёт вызывающий.
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property bool active: false
    property color activeColor: Theme.accent
    property int glyphSize: 16
    property int labelSize: 10
    signal clicked()

    radius: Theme.radius
    color: active
        ? Theme.alpha(activeColor, 0.16)
        : (ma.containsMouse ? Theme.hoverStrong : Theme.fill)
    border.width: 1
    border.color: active ? Theme.alpha(activeColor, 0.5) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Column {
        anchors.centerIn: parent
        spacing: 3

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.glyph
            color: root.active ? root.activeColor
                : (ma.containsMouse ? Theme.text : Theme.textDim)
            font.family: Theme.iconFont
            font.pixelSize: root.glyphSize
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.active ? Theme.text : Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: root.labelSize
            font.letterSpacing: 1
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
