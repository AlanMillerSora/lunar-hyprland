import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  HudCrosshairs — маленькие визиры-крестики по углам (профиль architect).
//  Живут в полях поверхности (контент имеет бо́льшие отступы), поэтому
//  не наезжают на содержимое. Размер/отступ настраиваются.
// ════════════════════════════════════════════════════════════════
Canvas {
    id: root

    anchors.fill: parent
    visible: Theme.arch
    property int inset: 12
    property int arm: 5
    property color c: Theme.hairAccent

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = root.c
        ctx.lineWidth = 1
        var w = width, h = height, i = root.inset, a = root.arm
        ctx.beginPath()
        ctx.moveTo(i - a, i); ctx.lineTo(i + a, i)
        ctx.moveTo(i, i - a); ctx.lineTo(i, i + a)
        ctx.moveTo(w - i - a, i); ctx.lineTo(w - i + a, i)
        ctx.moveTo(w - i, i - a); ctx.lineTo(w - i, i + a)
        ctx.moveTo(i - a, h - i); ctx.lineTo(i + a, h - i)
        ctx.moveTo(i, h - i - a); ctx.lineTo(i, h - i + a)
        ctx.moveTo(w - i - a, h - i); ctx.lineTo(w - i + a, h - i)
        ctx.moveTo(w - i, h - i - a); ctx.lineTo(w - i, h - i + a)
        ctx.stroke()
    }
}
