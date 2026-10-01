import Quickshell
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  PlayerLibrary — страница «ЛОКАЛЬНЫЕ»: кнопка обновления фонотеки
//  (PlayerCore.scanLibrary) и список PlayerCore.library. Клик играет
//  файл по пути. Пусто — подсказка про «обновить».
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool pageActive: false

    // зашёл на страницу с пустой фонотекой — сразу сканирую, не гоняю вручную
    onPageActiveChanged: if (pageActive && !PlayerCore.libraryBusy
                             && PlayerCore.library.length === 0) root.rescan()

    // смотрю только ~/Music: по всему дому find слишком тяжёл
    property string scanDir: Quickshell.env("HOME") + "/Music"

    function rescan() {
        if (!PlayerCore.libraryBusy)
            PlayerCore.scanLibrary(root.scanDir)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "ЛОКАЛЬНЫЕ"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(14)
                font.bold: true
                font.letterSpacing: 3
            }

            Text {
                Layout.fillWidth: true
                text: PlayerCore.libraryBusy
                    ? "сканирую…"
                    : (PlayerCore.library && PlayerCore.library.length > 0
                        ? (PlayerCore.library.length + " файл(ов)") : "")
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(10)
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 34
                radius: Theme.radius
                color: PlayerCore.libraryBusy
                    ? Theme.fill
                    : (rescanMouse.containsMouse ? Theme.hoverStrong : Theme.bgCard)
                border.width: 1
                border.color: Theme.border
                opacity: PlayerCore.libraryBusy ? 0.6 : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "\uf021"
                        color: PlayerCore.libraryBusy ? Theme.textFaint : Theme.accent
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(11)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "ОБНОВИТЬ"
                        color: PlayerCore.libraryBusy ? Theme.textDim : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        font.letterSpacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: rescanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !PlayerCore.libraryBusy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.rescan()
                }
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

            model: PlayerCore.library
            emptyText: "фонотека пуста — нажми «ОБНОВИТЬ»\n(папка: " + root.scanDir + ")"
            showRight: false

            titleFor: function(item, index) {
                return item && item.name ? item.name : "файл"
            }
            subtitleFor: function(item, index) {
                return item && item.path ? item.path : ""
            }

            onActivated: (index) => {
                var item = PlayerCore.library[index]
                if (item && item.path)
                    PlayerCore.playUrls([item.path])
            }
        }
    }
}
