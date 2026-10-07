import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  PlayerSearch — страница «ПОИСК»: результаты PlayerCore.searchResults
//  сеткой карточек с обложками (превью YouTube). Клик играет
//  (playUrls), «+» на карточке кладёт в очередь (enqueue).
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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid
                anchors.fill: parent
                clip: true
                cellWidth: 164
                cellHeight: 186
                boundsBehavior: Flickable.StopAtBounds
                model: PlayerCore.searchResults

                delegate: PlayerCard {
                    required property var modelData
                    required property int index

                    width: grid.cellWidth - 16
                    height: grid.cellHeight - 14

                    title: modelData && modelData.title ? modelData.title : "без названия"
                    subtitle: modelData && modelData.uploader ? modelData.uploader : ""
                    art: modelData && modelData.url ? PlayerCore.youtubeArt(modelData.url) : ""
                    actionVisible: true
                    actionIcon: "󰐕"

                    onActivated: if (modelData && modelData.url) PlayerCore.playUrls([modelData.url])
                    onAction: if (modelData && modelData.url) PlayerCore.enqueue([modelData.url])
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: !PlayerCore.searchResults || PlayerCore.searchResults.length === 0
                text: PlayerCore.searching
                    ? "ищу…"
                    : "введи запрос в строке сверху и нажми Enter"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(12)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
