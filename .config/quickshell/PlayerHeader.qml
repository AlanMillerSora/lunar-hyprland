import QtQuick

// ════════════════════════════════════════════════════════════════
//  PlayerHeader — TUI-заголовок страниц плеера: [ ПОДПИСЬ ].
//  Скобки приглушённые, сама подпись — яркая, разрядка как в
//  технических заголовках. Общий для «ОЧЕРЕДЬ/ПОИСК/ЛОКАЛЬНЫЕ».
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property string text: ""

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            text: "["
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(14)
            font.bold: true
        }
        Text {
            text: root.text
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(14)
            font.bold: true
            font.letterSpacing: 2
        }
        Text {
            text: "]"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(14)
            font.bold: true
        }
    }
}
