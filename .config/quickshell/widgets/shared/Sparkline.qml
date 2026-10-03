import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Sparkline — мини-график истории (Canvas). Значения 0..maxValue.
//  Монохром: линия акцентом, лёгкая заливка под ней.
// ════════════════════════════════════════════════════════════════
Canvas {
    id: root

    property var values: []
    property real maxValue: 100
    property color lineColor: Theme.accent

    height: Theme.sparkH
    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    Connections {
        target: SysInfo
        function onCpuHistChanged() { root.requestPaint() }
        function onRamHistChanged() { root.requestPaint() }
        function onGpuHistChanged() { root.requestPaint() }
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var n = root.values.length
        if (n < 2)
            return
        var w = width, h = height
        var step = w / (n - 1)
        var mx = root.maxValue > 0 ? root.maxValue : 100
        ctx.beginPath()
        for (var i = 0; i < n; i++) {
            var v = Math.max(0, Math.min(mx, root.values[i]))
            var x = i * step
            var y = h - (v / mx) * (h - 2) - 1
            if (i === 0)
                ctx.moveTo(x, y)
            else
                ctx.lineTo(x, y)
        }
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.strokeStyle = root.lineColor
        ctx.stroke()
        ctx.lineTo(w, h)
        ctx.lineTo(0, h)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.10)
        ctx.fill()
    }
}
