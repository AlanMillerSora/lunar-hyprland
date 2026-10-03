import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Card — единая подложка панелей: фон + радиус + рамка и внутренняя
//  колонка с общим ритмом. Контент складываем внутрь (default property).
//  Высота — по содержимому; ширину задаёт вызывающий.
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: root

    default property alias content: col.children
    property int contentMargins: Theme.cardPad
    property int contentSpacing: 8

    color: Theme.cardBg
    radius: Theme.radiusM
    border.width: 1
    border.color: Theme.border
    implicitHeight: col.implicitHeight + contentMargins * 2

    Column {
        id: col
        x: root.contentMargins
        y: root.contentMargins
        width: parent.width - root.contentMargins * 2
        spacing: root.contentSpacing
    }
}
