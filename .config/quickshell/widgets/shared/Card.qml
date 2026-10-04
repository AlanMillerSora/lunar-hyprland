import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Card — единая подложка панелей в arch-стиле: плотный surface без
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

    color: Theme.surface
    radius: Theme.radiusM
    border.width: root.bordered ? 1 : 0
    border.color: Theme.border2
    implicitHeight: col.implicitHeight + contentMargins * 2

    Column {
        id: col
        x: root.contentMargins
        y: root.contentMargins
        width: parent.width - root.contentMargins * 2
        spacing: root.contentSpacing
    }
}
