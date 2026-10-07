import QtQuick

// ════════════════════════════════════════════════════════════════
//  TuiPanel — панель в стиле 43PR «text»: плоский бокс с рамкой 1px,
//  без скруглений, с ярлыком прямо на верхней кромке (линия под
//  подписью «рвётся» патчем фона). Содержимое кладу в default —
//  оно ляжет внутрь с отступом pad.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property string label: ""
    property int pad: 12
    default property alias contentData: inner.data

    Rectangle {
        id: frame
        anchors.fill: parent
        color: Theme.bgSolid
        border.width: 1
        border.color: Theme.border
    }

    // прорезь под ярлык: фон панели поверх верхней кромки
    Rectangle {
        x: 11
        y: -Math.round(labelText.implicitHeight / 2)
        width: labelText.implicitWidth + 8
        height: labelText.implicitHeight
        visible: root.label !== ""
        color: Theme.bgSolid
        z: 2
    }
    Text {
        id: labelText
        x: 15
        y: -Math.round(implicitHeight / 2)
        visible: root.label !== ""
        text: root.label
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize(10)
        font.letterSpacing: 2
        z: 3
    }

    // сюда приходит содержимое панели (padded)
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.pad
    }
}
