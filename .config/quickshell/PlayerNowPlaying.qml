import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// ════════════════════════════════════════════════════════════════
//  PlayerNowPlaying — «винил»: монохромная обложка в круге (MultiEffect),
//  медленное вращение только когда играет И страница видима, крупные
//  название/артист, спектр cava (64 полосы) и «лунный seek» с засечками
//  фаз. cava запускаю строго при pageActive && playing — иначе не жгу CPU.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool pageActive: false

    readonly property bool spinning: root.pageActive && PlayerCore.playing
    readonly property int barCount: 64
    property var barValues: []

    // позиция: подтягиваю из PlayerCore, между его обновлениями тикаю сам,
    // чтобы дорожка не «стояла» и не прыгала
    property real shownPos: 0
    function syncPos() { root.shownPos = PlayerCore.position || 0 }
    Component.onCompleted: syncPos()
    onPageActiveChanged: if (pageActive) syncPos()

    Timer {
        interval: 250
        repeat: true
        running: root.pageActive && PlayerCore.playing
        onTriggered: {
            if (PlayerCore.length > 0)
                root.shownPos = Math.min(PlayerCore.length, root.shownPos + 0.25)
        }
    }
    Connections {
        target: PlayerCore
        function onPositionChanged() { root.syncPos() }
    }

    // «быстрый подъём / плавный спад» — как во feedCava правого сайдбара
    function feedCava(line) {
        var t = ("" + line).trim()
        if (t.length === 0)
            return
        var parts = t.split(/\s+/)
        var prev = root.barValues
        var out = []
        for (var i = 0; i < root.barCount; i++) {
            var raw = (parseInt(parts[i] === undefined ? "0" : parts[i]) || 0) / 1000
            raw = Math.max(0, Math.min(1, raw))
            var p = prev[i] || 0
            out.push(raw > p ? p + (raw - p) * 0.55 : p * 0.80 + raw * 0.20)
        }
        root.barValues = out
    }

    // cava живёт только пока страница и окно видимы и трек играет
    Process {
        id: cavaProc
        running: root.pageActive && PlayerCore.playing
        command: ["cava", "-p", Quickshell.shellPath("cava-player.conf")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.feedCava(line)
        }
        stderr: StdioCollector {}
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── винил ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 280

            Item {
                id: vinyl
                width: Math.min(260, Math.min(parent.width, parent.height) - 10)
                height: width
                anchors.centerIn: parent

                // мягкое гало-кольцо
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.alpha(Theme.accent, root.spinning ? 0.35 : 0.15)
                    Behavior on border.color { ColorAnimation { duration: Theme.animMed } }
                }

                Item {
                    id: disc
                    anchors.fill: parent
                    anchors.margins: 8

                    Image {
                        id: cover
                        anchors.fill: parent
                        source: PlayerCore.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: cover
                        visible: PlayerCore.artUrl.length > 0 && cover.status !== Image.Error
                        saturation: -1.0
                        brightness: 0.04
                        colorization: 0.28
                        colorizationColor: Theme.accent
                        maskEnabled: true
                        maskSource: circleMask
                    }

                    // заглушка — нота
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: PlayerCore.artUrl.length === 0 || cover.status === Image.Error
                        color: Theme.bgCard
                        border.color: Theme.border
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "\uf001"
                            color: Theme.textFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(52)
                        }
                    }

                    // медленное вращение: только играет И страница видима
                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 24000
                        loops: Animation.Infinite
                        running: root.spinning
                    }
                }

                // круглая маска для обложки (не вращается вместе с диском)
                Rectangle {
                    id: circleMask
                    anchors.fill: disc
                    radius: width / 2
                    color: Theme.text
                    visible: false
                    layer.enabled: true
                }

                // «шпиндель» — статичный центр
                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    color: Theme.bg
                    border.color: Theme.borderAccent
                    border.width: 2
                }
            }
        }

        // ── трек ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: PlayerCore.hasMedia
                    ? (PlayerCore.title.length > 0 ? PlayerCore.title : "без названия")
                    : "ничего не играет"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(22)
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                Layout.fillWidth: true
                visible: PlayerCore.artist.length > 0
                text: PlayerCore.artist
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            // ошибку плеера вижу и здесь, а не только на странице ПОИСК
            Text {
                Layout.fillWidth: true
                visible: PlayerCore.error !== ""
                text: PlayerCore.error
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(10)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        // ── спектр cava ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 104

            Text {
                anchors.centerIn: parent
                visible: !PlayerCore.hasMedia
                text: "\uf001"
                color: Theme.textFaint
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(44)
            }

            Row {
                anchors.fill: parent
                visible: PlayerCore.hasMedia
                spacing: 2

                Repeater {
                    model: root.barCount

                    delegate: Item {
                        id: barItem
                        required property int index
                        readonly property real v: root.barValues[index] || 0
                        width: Math.max(1, (parent.width - (root.barCount - 1) * 2) / root.barCount)
                        height: parent.height

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2 + barItem.v * (barItem.height - 8)
                            radius: 2
                            color: Theme.alpha(Theme.accent, 0.30 + 0.70 * barItem.v)

                            Rectangle {
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                height: 2
                                radius: 1
                                color: Theme.accent
                                opacity: 0.25 + 0.75 * barItem.v
                            }
                        }
                    }
                }
            }
        }

        // ── «лунный seek» ──
        Item {
            id: seek
            Layout.fillWidth: true
            Layout.preferredHeight: 52

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
            Component.onCompleted: primeTimer.restart()
            Timer {
                id: primeTimer
                interval: 60
                onTriggered: { seek.shownFill = seek.frac; seek.primed = true }
            }

            // засечки фаз: 9 отметок по дорожке
            Repeater {
                model: 9

                delegate: Rectangle {
                    required property int index
                    width: 1
                    height: 6
                    x: seek.width * (index / 8) - width / 2
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    color: Theme.alpha(Theme.accent, 0.10 + 0.06 * (index % 3))
                }
            }

            Rectangle {
                id: seekBg
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 4
                width: parent.width
                height: 4
                radius: 2
                color: Theme.trackBg
                border.color: Theme.border
                border.width: 1

                Rectangle {
                    id: seekFill
                    width: parent.width * seek.useFrac
                    height: parent.height
                    radius: parent.radius
                    color: PlayerCore.seekable ? Theme.accent : Theme.textDim
                    Behavior on width {
                        enabled: !seekArea.pressed
                        NumberAnimation { duration: 200 }
                    }
                }
            }

            // мягкий ореол при наведении
            Rectangle {
                x: Math.max(0, Math.min(seekBg.width, seekBg.width * seek.useFrac)) - width / 2
                anchors.verticalCenter: seekHandle.verticalCenter
                width: 30
                height: 30
                radius: 15
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
                radius: 6
                anchors.verticalCenter: seekBg.verticalCenter
                x: Math.max(0, Math.min(seekBg.width, seekBg.width * seek.useFrac)) - width / 2
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
                    text: PlayerCore.fmt(seekArea.pressed ? seek.dragFrac * PlayerCore.length : root.shownPos)
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
                    seek.dragFrac = Math.max(0, Math.min(1, p / seekBg.width))
                }
                onPressed: (mouse) => setFromX(mouse.x)
                onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
                onReleased: {
                    if (PlayerCore.seekable && PlayerCore.length > 0) {
                        var target = Math.max(0, Math.min(1, seek.dragFrac)) * PlayerCore.length
                        PlayerCore.seekTo(target)
                        root.shownPos = target
                    }
                }
            }
        }
    }
}
