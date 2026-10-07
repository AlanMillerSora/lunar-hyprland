import QtQuick

// ════════════════════════════════════════════════════════════════
//  TuiPanel — панель в стиле Spotify/text: тонкая рамка 1px, а в
//  верхней кромке — разрыв под ярлык (как Nav/Library/Main у 43PR).
//  Линия не рисуется одной плашкой-заглушкой, а двумя отрезками:
//  под текстом кромка честно прерывается, «коробки» нет.
//  Содержимое кладётся в default — ляжет внутрь с отступом pad.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property string label: ""
    property int pad: 12
    default property alias contentData: inner.data

    readonly property int gapX: 10
    readonly property int gapW: labelText.visible ? Math.round(labelText.implicitWidth) + 12 : 0

    // фон панели
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // рамка: низ, лево, право
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 1
        color: Theme.border
    }
    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 1
        color: Theme.border
    }

    // верхняя кромка — двумя отрезками, с разрывом под ярлык
    Rectangle {
        anchors { left: parent.left; top: parent.top }
        width: Math.max(0, root.gapX)
        height: 1
        color: Theme.border
    }
    Rectangle {
        anchors { right: parent.right; top: parent.top }
        width: Math.max(0, parent.width - root.gapX - root.gapW)
        height: 1
        color: Theme.border
    }

    // ярлык прямо в разрыве кромки
    Text {
        id: labelText
        visible: root.label !== ""
        x: root.gapX + 6
        y: -Math.round(implicitHeight / 2)
        text: root.label
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize(10)
        font.letterSpacing: 1
    }

    // содержимое панели (padded)
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.pad
    }
}
