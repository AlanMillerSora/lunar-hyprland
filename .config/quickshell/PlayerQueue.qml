import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  PlayerQueue — страница «ОЧЕРЕДЬ»: список PlayerCore.queue.
//  Клик — прыжок к треку, крестик — удалить, текущий подсвечен.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool pageActive: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "ОЧЕРЕДЬ"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(14)
                font.bold: true
                font.letterSpacing: 3
            }
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

            titleFor: function(item, index) {
                return item && item.title ? item.title : "трек " + (index + 1)
            }
            subtitleFor: function(item, index) {
                if (!item) return ""
                var d = item.duration > 0 ? PlayerCore.fmt(item.duration) : ""
                return d
            }
            rightIconFor: function(item, index) { return "\uf00d" }

            onActivated: (index) => PlayerCore.jumpTo(index)
            onRightClicked: (index) => PlayerCore.removeAt(index)
        }
    }
}
