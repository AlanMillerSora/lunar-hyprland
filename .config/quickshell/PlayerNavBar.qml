import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  PlayerNavBar — верхняя полоса плеера (Nav): иконки слева, строка
//  поиска по центру, иконки справа. Ввод + Enter уходят сигналом
//  search(); окно само зовёт PlayerCore.search и переключает страницу.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    signal search(string query)

    implicitHeight: 34

    function submit() {
        var q = input.text.trim()
        if (q.length > 0)
            root.search(q)
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.space3

        // левые иконки (навигация — декоративно, в тон)
        Row {
            spacing: Theme.space3
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "‹"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(16)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "›"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(16)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "󰋜"
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(14)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // поиск
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 0
            color: Theme.bgCard
            border.width: 1
            border.color: input.activeFocus ? Theme.borderAccent : Theme.border

            Text {
                text: "󰍉"
                color: input.activeFocus ? Theme.accent : Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(13)
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 34
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(12)
                clip: true
                selectByMouse: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "что хочешь послушать?"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    visible: input.text === ""
                }

                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
            }
        }

        // правые иконки
        Row {
            spacing: Theme.space3
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "󰂚"
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(14)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "󰀄"
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(14)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
