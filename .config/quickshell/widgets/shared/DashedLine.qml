import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  DashedLine — штриховая техническая линия (горизонт./вертик.).
//  Размер задаёт вызывающий; цвет/толщина из токенов Theme.
// ════════════════════════════════════════════════════════════════
Canvas {
    id: root

    anchors.fill: parent
    property bool vertical: false
    property int dash: 6
    property int gap: 6
    property color lineColor: Theme.hair
    property int weight: Theme.line

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = root.lineColor
        ctx.lineWidth = root.weight
        ctx.beginPath()
        if (root.vertical) {
            for (var y = 0; y < height; y += root.dash + root.gap) {
                ctx.moveTo(root.weight / 2, y)
                ctx.lineTo(root.weight / 2, Math.min(height, y + root.dash))
            }
        } else {
            for (var x = 0; x < width; x += root.dash + root.gap) {
                ctx.moveTo(x, height / 2)
                ctx.lineTo(Math.min(width, x + root.dash), height / 2)
            }
        }
        ctx.stroke()
    }
}
