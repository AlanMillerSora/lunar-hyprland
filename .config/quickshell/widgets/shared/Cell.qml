import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Cell — ячейка-сегмент бара: плотная плашка (Theme.fill → hoverStrong).
//  Акцентный штрих слева показываю ТОЛЬКО когда accent = сигнал (danger
//  или светлый акцент), а не нейтральный серый — так спокойные ячейки
//  выглядят ровно и минималистично, а тревожные (перегрев, mute, игра)
//  по-прежнему кричат штрихом.
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: cell

    default property alias content: cellContent.children
    property color accent: Theme.barFaint
    property bool interactive: false
    property string tip: ""
    signal clicked()

    // штрих — только для «сигнальных» акцентов (danger/accent), не для серых
    readonly property bool signalBar: accent !== Theme.barFaint
        && accent !== Theme.barDim

    height: Theme.barCellH
    implicitWidth: cellContent.implicitWidth + Theme.space3 * 2 + (cell.signalBar ? 8 : 0)
    width: implicitWidth
    radius: Theme.radius
    color: cellHover.hovered && cell.interactive ? Theme.hoverStrong : Theme.fill

    HoverHandler {
        id: cellHover
    }

    // короткий штрих-акцент слева — только у «сигнальных» ячеек
    Rectangle {
        visible: cell.signalBar
        anchors.left: parent.left
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 18
        radius: 1
        color: cell.accent
    }

    Row {
        id: cellContent
        anchors.left: parent.left
        anchors.leftMargin: cell.signalBar ? 15 : Theme.space3
        anchors.right: parent.right
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
