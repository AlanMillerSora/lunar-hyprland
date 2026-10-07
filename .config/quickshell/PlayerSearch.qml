import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  PlayerSearch — страница «ПОИСК»: результаты PlayerCore.searchResults.
//  Поле ввода живёт в верхней полосе Nav, здесь только список.
//  Клик играет (playUrls), «+» кладёт в очередь (enqueue).
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

            PlayerHeader { text: "ПОИСК" }

            Text {
                Layout.fillWidth: true
                visible: PlayerCore.searching || PlayerCore.searchError.length > 0
                text: PlayerCore.searching ? "поиск…" : PlayerCore.searchError
                color: PlayerCore.searchError.length > 0 ? Theme.danger : Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(10)
                elide: Text.ElideRight
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

            model: PlayerCore.searchResults
            emptyText: PlayerCore.searching
                ? "ищу…"
                : "введи запрос в строке сверху и нажми Enter"
            showRight: true
            numbered: true

            titleFor: function(item, index) {
                return item && item.title ? item.title : "без названия"
            }
            subtitleFor: function(item, index) {
                return item && item.uploader ? item.uploader : ""
            }
            rightTextFor: function(item, index) {
                return item && item.duration > 0 ? PlayerCore.fmt(item.duration) : ""
            }
            rightIconFor: function(item, index) { return "󰐕" }

            onActivated: (index) => {
                var item = PlayerCore.searchResults[index]
                if (item && item.url)
                    PlayerCore.playUrls([item.url])
            }
            onRightClicked: (index) => {
                var item = PlayerCore.searchResults[index]
                if (item && item.url)
                    PlayerCore.enqueue([item.url])
            }
        }
    }
}
