import QtQuick

// ════════════════════════════════════════════════════════════════
//  HudCorners — скобки по четырём углам (мотив «чертёж»).
//  В стиль-профиле architect — крупнее и толще.
// ════════════════════════════════════════════════════════════════
Item {
    id: root
    anchors.fill: parent
    property color color: Theme.accent
    property int size: 40
    property int thickness: 2
    property int margin: 10

    readonly property real s: Theme.hudCornerSizeFor(root.size)
    readonly property real t: Theme.hudCornerThicknessFor(root.thickness)

    Rectangle {
        width: root.s; height: root.t; color: root.color
        anchors { top: parent.top; left: parent.left; margins: root.margin }
    }
    Rectangle {
        width: root.t; height: root.s; color: root.color
        anchors { top: parent.top; left: parent.left; margins: root.margin }
    }
    Rectangle {
        width: root.s; height: root.t; color: root.color
        anchors { top: parent.top; right: parent.right; margins: root.margin }
    }
    Rectangle {
        width: root.t; height: root.s; color: root.color
        anchors { top: parent.top; right: parent.right; margins: root.margin }
    }
    Rectangle {
        width: root.s; height: root.t; color: root.color
        anchors { bottom: parent.bottom; left: parent.left; margins: root.margin }
    }
    Rectangle {
        width: root.t; height: root.s; color: root.color
        anchors { bottom: parent.bottom; left: parent.left; margins: root.margin }
    }
    Rectangle {
        width: root.s; height: root.t; color: root.color
        anchors { bottom: parent.bottom; right: parent.right; margins: root.margin }
    }
    Rectangle {
        width: root.t; height: root.s; color: root.color
        anchors { bottom: parent.bottom; right: parent.right; margins: root.margin }
    }
}
