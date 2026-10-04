import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Cell — ячейка-сегмент бара в arch-стиле: НЕ плашка, а «плоский»
//  носитель содержимого. В покое фон прозрачный, на наведении — тихая
//  подсветка, у открытого режима — accent. Никаких флажков и штрихов:
//  минимализм, как в баре ArchEclipse (там всё это просто текст/иконки).
//  accent оставлен ради совместимости (им красят содержимое снаружи).
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: cell

    default property alias content: cellContent.children
    property color accent: Theme.barFaint
    property bool interactive: false
    // ячейка — «активный» режим (его панель сейчас открыта): подсветка
    property bool active: false
    property string tip: ""
    signal clicked()

    height: Theme.barCellH
    implicitWidth: cellContent.implicitWidth + Theme.space3 * 2
    width: implicitWidth
    radius: Theme.radius
    // arch: в покое ничего не рисуем; hover — слабый surface, active — сильнее
    color: cell.active ? Theme.active
         : cellHover.hovered && cell.interactive ? Theme.hoverStrong
         : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    HoverHandler {
        id: cellHover
    }

    Row {
        id: cellContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.space3
        anchors.rightMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space2
    }

    MouseArea {
        anchors.fill: parent
        enabled: cell.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cell.clicked()
    }

    AppTooltip {
        visible: cell.tip !== "" && cellHover.hovered
        text: cell.tip
    }
}
