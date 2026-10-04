import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  SectionHeader — технический заголовок секции. В профиле architect:
//  [ ПОДПИСЬ ] акцентными скобками + линия под ним. В classic — просто
//  капс-подпись (скобок и линии нет).
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property string text: ""
    property color textColor: Theme.textFaint
    property int size: Theme.fontTiny
    property bool bold: true

    readonly property int pad: Theme.arch ? 6 : 0

    implicitWidth: lb.implicitWidth + label.implicitWidth + rb.implicitWidth + (Theme.arch ? 2 * root.pad : 0)
    implicitHeight: Math.max(label.implicitHeight, Theme.arch ? size + 2 : 0)

    Text {
        id: lb
        visible: Theme.arch
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        text: "["
        color: Theme.hairAccent
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        font.bold: true
    }
    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: lb.implicitWidth + (Theme.arch ? root.pad : 0)
        text: root.text
        color: root.textColor
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        font.letterSpacing: 2
        font.bold: root.bold
    }
    Text {
        id: rb
        visible: Theme.arch
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: label.right
        anchors.leftMargin: Theme.arch ? root.pad : 0
        text: "]"
        color: Theme.hairAccent
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        font.bold: true
    }

    // architect: линия под заголовком
    Rectangle {
        visible: Theme.arch
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.line
        color: Theme.hair
    }
    // architect: вторая (короткая) линия — двойное правило
    Rectangle {
        visible: Theme.arch
        anchors { left: parent.left; bottom: parent.bottom }
        anchors.bottomMargin: 3
        width: parent.width * 0.6
        height: Theme.line
        color: Theme.hairFaint
    }
    // architect: узел на конце подчёркивания
    Rectangle {
        visible: Theme.arch
        anchors { right: parent.right; bottom: parent.bottom }
        width: 3; height: 3
        color: Theme.hairAccent
    }
}
