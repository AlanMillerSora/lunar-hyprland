import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  HudInnerFrame — 1–2 тонкие линии внутри поверхности (architect),
//  с зазорами по углам. variant выбирает пару сторон:
//    0 — верх+лево   1 — верх+право
//    2 — низ+лево    3 — низ+право
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    anchors.fill: parent
    visible: Theme.arch
    property color color: Theme.hair
    property int inset: 8
    property int gap: 16
    property int th: Theme.line
    property int variant: 0
    z: 39

    readonly property bool topOn: variant === 0 || variant === 1
    readonly property bool bottomOn: variant === 2 || variant === 3
    readonly property bool leftOn: variant === 0 || variant === 2
    readonly property bool rightOn: variant === 1 || variant === 3

    Rectangle {
        visible: root.topOn
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: root.inset
        anchors.leftMargin: root.inset + root.gap
        anchors.rightMargin: root.inset + root.gap
        height: root.th
        color: root.color
    }
    Rectangle {
        visible: root.bottomOn
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        anchors.bottomMargin: root.inset
        anchors.leftMargin: root.inset + root.gap
        anchors.rightMargin: root.inset + root.gap
        height: root.th
        color: root.color
    }
    Rectangle {
        visible: root.leftOn
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        anchors.leftMargin: root.inset
        anchors.topMargin: root.inset + root.gap
        anchors.bottomMargin: root.inset + root.gap
        width: root.th
        color: root.color
    }
    Rectangle {
        visible: root.rightOn
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        anchors.rightMargin: root.inset
        anchors.topMargin: root.inset + root.gap
        anchors.bottomMargin: root.inset + root.gap
        width: root.th
        color: root.color
    }
}
