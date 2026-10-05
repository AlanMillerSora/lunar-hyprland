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
    // необязательный глиф-иконка перед подписью — рисую отдельным Text
    // в JetBrainsMono NF, чтобы знак не уезжал в чужой фолбэк (B6)
    property string icon: ""
    property color textColor: Theme.textFaint
    property int size: Theme.fontTiny
    property bool bold: true

    readonly property int pad: Theme.sectionHeaderPad
    readonly property real iconW: iconText.visible ? iconText.implicitWidth + root.pad : 0

    implicitWidth: iconW + lb.implicitWidth + label.implicitWidth + rb.implicitWidth + 2 * root.pad
    implicitHeight: Math.max(label.implicitHeight, Theme.sectionHeaderMinH(size))

    Text {
        id: iconText
        visible: root.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        text: root.icon
        color: root.textColor
        font.family: Theme.iconFont
        font.pixelSize: root.size
    }
    Text {
        id: lb
        visible: Theme.arch
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.iconW
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
        anchors.leftMargin: root.iconW + lb.implicitWidth + root.pad
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
        anchors.leftMargin: root.pad
        text: "]"
        color: Theme.hairAccent
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        font.bold: true
    }

    // architect: линия под заголовком + узел на конце. Вторую (короткую)
    // линию убрал — двойное правило по всем сорока заголовкам давало шум.
    Rectangle {
        visible: Theme.arch
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.line
        color: Theme.hair
    }
    // architect: узел на конце подчёркивания
    Rectangle {
        visible: Theme.arch
        anchors { right: parent.right; bottom: parent.bottom }
        width: 3; height: 3
        color: Theme.hairAccent
    }
}
