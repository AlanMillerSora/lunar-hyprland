import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Card — единая подложка панелей в arch-стиле: плотный surfaceCard без
//  рамки (как Card у ArchEclipse: surface + radius, border почти не
//  виден), внутри — колонка с общим ритмом. Контент внутрь (default).
//  Высота — по содержимому; ширину задаёт вызывающий.
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: root

    default property alias content: col.children
    property int contentMargins: Theme.cardPad
    property int contentSpacing: 8
    // рамку оставил опциональной: у arch карточки рамки почти нет
    property bool bordered: false

    color: Theme.surfaceCard
    radius: Theme.radiusM
    border.width: root.bordered ? 1 : 0
    border.color: Theme.border2
    implicitHeight: col.implicitHeight + contentMargins * 2

    // architect: тонкая линия по верхней кромке карточки (технический кант)
    Rectangle {
        visible: Theme.arch
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: root.radius
        anchors.rightMargin: root.radius
        height: Theme.line
        color: Theme.hair
    }
    // architect: и по нижней кромке
    Rectangle {
        visible: Theme.arch
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.leftMargin: root.radius
        anchors.rightMargin: root.radius
        height: Theme.line
        color: Theme.hair
    }
    // architect: узлы-маркеры по углам
    Rectangle {
        visible: Theme.arch
        width: 3; height: 3
        color: Theme.hairAccent
        anchors { left: parent.left; top: parent.top; leftMargin: root.radius }
    }
    Rectangle {
        visible: Theme.arch
        width: 3; height: 3
        color: Theme.hairAccent
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: root.radius }
    }

    Column {
        id: col
        x: root.contentMargins
        y: root.contentMargins
        width: parent.width - root.contentMargins * 2
        spacing: root.contentSpacing
    }
}
