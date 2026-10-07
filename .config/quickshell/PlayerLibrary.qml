import Quickshell
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  PlayerLibrary — левая панель Library: заголовок, пилюли-разделы,
//  строка «Recents», список строк с квадратными «обложками». Контент —
//  локальная фонотека (PlayerCore.library), клик играет файл.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool pageActive: false

    onPageActiveChanged: if (pageActive && !PlayerCore.libraryBusy
                             && PlayerCore.library.length === 0) root.rescan()

    property string scanDir: Quickshell.env("HOME") + "/Music"

    function rescan() {
        if (!PlayerCore.libraryBusy)
            PlayerCore.scanLibrary(root.scanDir)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── заголовок ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            Text {
                text: "󰉋"
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(13)
            }
            Text {
                Layout.fillWidth: true
                text: "Your Library"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.bold: true
            }
            Text {
                text: "+"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(15)
            }
            Text {
                text: "↗"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
            }
        }

        // ── пилюли-разделы ──
        Row {
            spacing: 6

            Rectangle {
                width: 82
                height: 26
                radius: Theme.radius
                color: Theme.active
                border.width: 1
                border.color: Theme.borderAccent
                Text {
                    anchors.centerIn: parent
                    text: "Playlists"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                }
            }
            Rectangle {
                width: 74
                height: 26
                radius: Theme.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    text: "Albums"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(14)
            }
        }

        // ── поиск / недавние / сортировка ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            Text {
                text: "󰍉"
                color: Theme.textFaint
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(12)
            }
            Text {
                Layout.fillWidth: true
                text: "Recents"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(11)
            }
            Text {
                text: "≡"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // ── список ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors { left: parent.left; top: parent.top; right: parent.right }
                spacing: Theme.space2

                Text {
                    text: "󰉋"
                    color: Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(12)
                }
                Text {
                    text: "Фонотека"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                }
                Text {
                    text: "▾"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: PlayerCore.libraryBusy ? "сканирую…"
                        : (PlayerCore.library.length + " файл(ов)")
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
                Text {
                    text: "↻"
                    color: rescanMouse.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    MouseArea {
                        id: rescanMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.rescan()
                    }
                }
            }

            PlayerList {
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
                anchors.topMargin: 26

                model: PlayerCore.library
                emptyText: "фонотека пуста — нажми ↻ сверху\n(папка: " + root.scanDir + ")"
                showRight: false
                iconFor: function(item, index) { return "󰎇" }
                titleFor: function(item, index) {
                    return item && item.name ? item.name : "файл"
                }
                subtitleFor: function(item, index) { return "Файл" }

                onActivated: (index) => {
                    var item = PlayerCore.library[index]
                    if (item && item.path)
                        PlayerCore.playUrls([item.path])
                }
            }
        }
    }
}
