import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  PlayerSearch — страница «ПОИСК»: prompt-строка + кнопка, Enter
//  запускает PlayerCore.search. Результаты — таблица PlayerList;
//  клик играет (playUrls), «+» кладёт в очередь (enqueue).
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool pageActive: false

    // зашёл на страницу — сразу отдаю фокус строке, иначе надо кликать по ней
    onPageActiveChanged: if (pageActive) searchInput.forceActiveFocus()

    function doSearch() {
        var q = searchInput.text.trim()
        if (q.length > 0)
            PlayerCore.search(q)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        PlayerHeader { text: "ПОИСК" }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 0
                color: Theme.bgCard
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.borderAccent : Theme.border

                // prompt как в шелле: > запрос
                Text {
                    text: ">"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    font.bold: true
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 26
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    clip: true
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 0
                        verticalAlignment: Text.AlignVCenter
                        text: "что искать? (Enter)"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        visible: searchInput.text === ""
                    }

                    onTextChanged: if (text === "") PlayerCore.clearResults()
                    Keys.onReturnPressed: root.doSearch()
                    Keys.onEnterPressed: root.doSearch()
                    // Esc чистит поле; пустое — отдаю наверх (закрыть окно)
                    Keys.onEscapePressed: (e) => {
                        if (text !== "") { text = ""; e.accepted = true }
                        else { e.accepted = false }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 104
                Layout.preferredHeight: 36
                radius: 0
                color: searchMouse.containsMouse ? Theme.hoverStrong : Theme.bgCard
                border.width: 1
                border.color: Theme.border

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.space2
                    Text {
                        text: "󰍉"
                        color: Theme.accent
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(12)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "НАЙТИ"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.letterSpacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: searchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doSearch()
                }
            }
        }

        // статус: поиск / ошибка
        Text {
            Layout.fillWidth: true
            visible: PlayerCore.searching || PlayerCore.searchError.length > 0
            text: PlayerCore.searching ? "поиск…" : PlayerCore.searchError
            color: PlayerCore.searchError.length > 0 ? Theme.danger : Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(10)
            elide: Text.ElideRight
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
                : "введи запрос и нажми Enter"
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
