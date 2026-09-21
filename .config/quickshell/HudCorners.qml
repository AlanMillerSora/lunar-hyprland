import QtQuick

Item {
    id: root
    anchors.fill: parent
    property color color: Theme.accent
    property int size: 40
    property int thickness: 2
    property int margin: 10

    Rectangle {
        width: root.size
        height: root.thickness
        color: root.color
        anchors { top: parent.top; left: parent.left; margins: root.margin }
    }
    Rectangle {
        width: root.thickness
        height: root.size
        color: root.color
        anchors { top: parent.top; left: parent.left; margins: root.margin }
    }
    Rectangle {
        width: root.size
        height: root.thickness
        color: root.color
        anchors { top: parent.top; right: parent.right; margins: root.margin }
    }
    Rectangle {
        width: root.thickness
        height: root.size
        color: root.color
        anchors { top: parent.top; right: parent.right; margins: root.margin }
    }
    Rectangle {
        width: root.size
        height: root.thickness
        color: root.color
        anchors { bottom: parent.bottom; left: parent.left; margins: root.margin }
    }
    Rectangle {
        width: root.thickness
        height: root.size
        color: root.color
        anchors { bottom: parent.bottom; left: parent.left; margins: root.margin }
    }
    Rectangle {
        width: root.size
        height: root.thickness
        color: root.color
        anchors { bottom: parent.bottom; right: parent.right; margins: root.margin }
    }
    Rectangle {
        width: root.thickness
        height: root.size
        color: root.color
        anchors { bottom: parent.bottom; right: parent.right; margins: root.margin }
    }
}
