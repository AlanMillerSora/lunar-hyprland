import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  PlayerQueue — страница «ОЧЕРЕДЬ»: плотная таблица PlayerCore.queue.
//  Клик — прыжок к треку, крестик — удалить, текущий подсвечен.
//  Тяну строку — переставляю порядок (mpv playlist-move).
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool pageActive: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            PlayerHeader { text: "ОЧЕРЕДЬ" }

            Text {
                Layout.fillWidth: true
                text: PlayerCore.queue && PlayerCore.queue.length > 0
                    ? (PlayerCore.queue.length + " трек(ов)")
                    : ""
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(10)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        PlayerList {
            Layout.fillWidth: true
            Layout.fillHeight: true

            model: PlayerCore.queue
            emptyText: "очередь пуста"
            highlightIndex: PlayerCore.queueIndex
            numbered: true
            reorderable: true

            titleFor: function(item, index) {
                return item && item.title ? item.title : "трек " + (index + 1)
            }
            subtitleFor: function(item, index) { return "" }
            rightTextFor: function(item, index) {
                return item && item.duration > 0 ? PlayerCore.fmt(item.duration) : ""
            }
            rightIconFor: function(item, index) { return "󰅖" }

            onActivated: (index) => PlayerCore.jumpTo(index)
            onRightClicked: (index) => PlayerCore.removeAt(index)
            onReordered: (from, to) => PlayerCore.moveInQueue(from, to)
        }
    }
}
