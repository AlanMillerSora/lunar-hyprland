import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  PlayerSeek — «лунный seek»: большой ползунок трека с засечками фаз,
//  мягким ореолом и перемоткой. Вынес из страницы «Сейчас», чтобы
//  жить в нижней панели Playing. Вид и логика прежние.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    implicitHeight: 52

    // позицию подтягиваю из PlayerCore, между его обновлениями тикаю сам,
    // чтобы дорожка не «стояла» и не прыгала
    property real shownPos: 0
    function syncPos() { root.shownPos = PlayerCore.position || 0 }

    Timer {
        interval: 250
        repeat: true
        running: PlayerCore.playing
        onTriggered: {
            if (PlayerCore.length > 0)
                root.shownPos = Math.min(PlayerCore.length, root.shownPos + 0.25)
        }
    }
    Connections {
        target: PlayerCore
        function onPositionChanged() { root.syncPos() }
    }

    property real dragFrac: 0
    property real shownFill: 0
    property bool primed: false
    // доля проигранного: при перетаскивании — доля курсора, иначе показанная
    readonly property real frac: {
        if (PlayerCore.length <= 0) return 0
        var p = seekArea.pressed ? dragFrac : root.shownPos
        return Math.max(0, Math.min(1, p / PlayerCore.length))
    }
    readonly property real useFrac: seekArea.pressed ? dragFrac : shownFill
    onFracChanged: if (primed) shownFill = frac

    Component.onCompleted: { root.syncPos(); primeTimer.restart() }
    Timer {
        id: primeTimer
        interval: 60
        onTriggered: { root.shownFill = root.frac; root.primed = true }
    }

    // засечки фаз: 9 отметок по дорожке
    Repeater {
        model: 9

        delegate: Rectangle {
            required property int index
            width: 1
            height: 6
            x: root.width * (index / 8) - width / 2
            anchors.top: parent.top
            anchors.topMargin: 2
            color: Theme.alpha(Theme.accent, 0.10 + 0.06 * (index % 3))
        }
    }

    Rectangle {
        id: seekBg
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 2
        width: parent.width
        height: 4
        radius: height / 2
        color: Theme.trackBg
        border.color: Theme.border
        border.width: 1

        Rectangle {
            id: seekFill
            width: parent.width * root.useFrac
            height: parent.height
            radius: parent.radius
            color: PlayerCore.seekable ? Theme.accent : Theme.textDim
            Behavior on width {
                enabled: !seekArea.pressed
                NumberAnimation { duration: Theme.animMed }
            }
        }
    }

    // мягкий ореол при наведении
    Rectangle {
        x: Math.max(0, Math.min(seekBg.width, seekBg.width * root.useFrac)) - width / 2
        anchors.verticalCenter: seekHandle.verticalCenter
        width: 30
        height: 30
        radius: width / 2
        color: "transparent"
        border.color: Theme.alpha(Theme.accent, 0.35)
        border.width: 1
        opacity: (seekArea.pressed || seekArea.containsMouse) && PlayerCore.seekable ? 1 : 0
        scale: seekArea.pressed ? 1.1 : 1.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    }

    Rectangle {
        id: seekHandle
        width: 12
        height: 12
        radius: width / 2
        anchors.verticalCenter: seekBg.verticalCenter
        x: Math.max(0, Math.min(seekBg.width, seekBg.width * root.useFrac)) - width / 2
        color: Theme.text
        border.color: Theme.accent
        border.width: 2
        opacity: (seekArea.pressed || seekArea.containsMouse) && PlayerCore.seekable ? 1 : 0.9
        scale: seekArea.pressed ? 1.15 : 1.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: seekBg.bottom
        anchors.topMargin: 7
        Text {
            text: PlayerCore.fmt(seekArea.pressed ? root.dragFrac * PlayerCore.length : root.shownPos)
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(10)
        }
        Item { Layout.fillWidth: true }
        Text {
            text: PlayerCore.fmt(PlayerCore.length)
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(10)
        }
    }

    MouseArea {
        id: seekArea
        anchors.fill: parent
        anchors.margins: -8
        preventStealing: true
        hoverEnabled: true
        enabled: PlayerCore.seekable
        cursorShape: PlayerCore.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor

        function setFromX(px) {
            var p = seekArea.mapToItem(seekBg, px, 0).x
            root.dragFrac = Math.max(0, Math.min(1, p / seekBg.width))
        }
        onPressed: (mouse) => setFromX(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
        onReleased: {
            if (PlayerCore.seekable && PlayerCore.length > 0) {
                var target = Math.max(0, Math.min(1, root.dragFrac)) * PlayerCore.length
                PlayerCore.seekTo(target)
                root.shownPos = target
            }
        }
    }
}
