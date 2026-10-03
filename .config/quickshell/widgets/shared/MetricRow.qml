import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  MetricRow — строка метрики панелей: подпись · значение · полоса ·
//  подробность (температура/объём). Ширины и размеры настраиваются, чтобы
//  одну строку переиспользовать в разных панелях.
// ════════════════════════════════════════════════════════════════
Row {
    id: root

    property string label: ""
    property real value: -1
    property string extra: ""
    property int labelW: 40
    property int valueW: 42
    property int extraW: 60
    property real barHeight: 4
    property int labelSize: Theme.fontTiny
    property int valueSize: Theme.fontSize(13)

    height: 22
    spacing: Theme.space2

    Text {
        width: root.labelW
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: root.labelSize
        font.letterSpacing: 1
    }
    Text {
        width: root.valueW
        horizontalAlignment: Text.AlignRight
        anchors.verticalCenter: parent.verticalCenter
        text: root.value < 0 ? "--" : (root.value + "%")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: root.valueSize
        font.bold: true
    }
    MiniBar {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(10, root.width - root.labelW - root.valueW - root.extraW - root.spacing * 3)
        height: root.barHeight
        value: root.value
    }
    Text {
        width: root.extraW
        visible: root.extraW > 0
        horizontalAlignment: Text.AlignRight
        anchors.verticalCenter: parent.verticalCenter
        text: root.extra
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize(12)
    }
}
