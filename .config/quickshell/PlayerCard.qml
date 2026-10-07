import QtQuick

// ════════════════════════════════════════════════════════════════
//  PlayerCard — карточка-плитка для сетки (как в Spotify): квадратная
//  обложка сверху, название и подпись снизу. Клик — играть/выбрать,
//  правый угол — действие (плюс в очередь / удалить).
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string art: ""
    property string badge: ""
    property bool current: false
    property bool actionVisible: false
    property string actionIcon: "󰐕"

    signal activated()
    signal action()

    Rectangle {
        id: coverBox
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: width
        color: Theme.bgCard
        border.width: 1
        border.color: root.current ? Theme.accent : (hover.containsMouse ? Theme.borderAccent : Theme.border)

        Image {
            id: img
            anchors.fill: parent
            source: root.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.art !== "" && status === Image.Ready
        }
        Text {
            anchors.centerIn: parent
            visible: !img.visible
            text: "󰎇"
            color: Theme.textFaint
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSize(28)
        }
        // «badge» (например, Daily Mix) — маленькая плашка внизу обложки
        Rectangle {
            visible: root.badge !== ""
            anchors { left: parent.left; bottom: parent.bottom }
            height: 16
            width: badgeText.implicitWidth + 10
            color: Theme.bg
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(9)
            }
        }
    }

    Text {
        anchors { left: parent.left; right: parent.right; top: coverBox.bottom; topMargin: 6 }
        text: root.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize(11)
        font.bold: true
        elide: Text.ElideRight
        maximumLineCount: 1
    }
    Text {
        anchors { left: parent.left; right: parent.right; top: coverBox.bottom; topMargin: 21 }
        text: root.subtitle
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize(9)
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    // действие в углу обложки (по ховеру)
    Rectangle {
        visible: root.actionVisible
        anchors { right: coverBox.right; bottom: coverBox.bottom }
        anchors.margins: 6
        width: 26
        height: 26
        color: actMouse.containsMouse ? Theme.accent : Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: hover.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Text {
            anchors.centerIn: parent
            text: root.actionIcon
            color: actMouse.containsMouse ? Theme.bg : Theme.text
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSize(12)
        }
        MouseArea {
            id: actMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.action()
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
