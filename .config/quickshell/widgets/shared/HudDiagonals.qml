import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  HudDiagonals — короткие диагональные засечки по углам (architect).
//  Технические «штрихи» под 45°.
// ════════════════════════════════════════════════════════════════
Canvas {
    id: root

    anchors.fill: parent
    visible: Theme.arch
    property color c: Theme.hairAccent
    property int len: 12
    property int inset: 2

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = root.c
        ctx.lineWidth = 1
        var w = width, h = height, i = root.inset, l = root.len
        ctx.beginPath()
        ctx.moveTo(i, i + l); ctx.lineTo(i + l, i)
        ctx.moveTo(w - i - l, i); ctx.lineTo(w - i, i + l)
        ctx.moveTo(i, h - i - l); ctx.lineTo(i + l, h - i)
        ctx.moveTo(w - i - l, h - i); ctx.lineTo(w - i, h - i - l)
        ctx.stroke()
    }
}
