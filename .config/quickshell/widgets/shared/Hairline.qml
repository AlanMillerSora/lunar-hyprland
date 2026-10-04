import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Hairline — тонкая техническая линия (горизонт. по умолчанию).
//  Размер задаёт вызывающий; толщина/цвет — из токенов Theme.
// ════════════════════════════════════════════════════════════════
Rectangle {
    property bool vertical: false
    property color lineColor: Theme.hair
    property int weight: Theme.line

    width: vertical ? weight : 0
    height: vertical ? 0 : weight
    color: lineColor
}
