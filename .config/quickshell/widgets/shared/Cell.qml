import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Cell — ячейка-сегмент бара (по мотивам ArchEclipse): плотный фон
//  + короткий акцентный штрих слева. Внутрь кладу что угодно
//  (текст/иконку/строку) через default-свойство content.
//  Жила инлайном в LunarPanel — вынес в общий слой.
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: cell

    default property alias content: cellContent.children
    property color accent: Theme.barFaint
    property bool interactive: false
    property string tip: ""
    signal clicked()

    height: 26
    implicitWidth: cellContent.implicitWidth + Theme.space3 * 2 + 8
    width: implicitWidth
    radius: Theme.radiusS
    color: cellHover.hovered && cell.interactive ? Theme.hoverStrong : Theme.fill

    HoverHandler {
        id: cellHover
    }

    // короткий штрих-акцент слева (как цветные флажки у ArchEclipse)
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 14
        radius: 1
        color: cell.accent
    }

    Row {
        id: cellContent
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 8
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
