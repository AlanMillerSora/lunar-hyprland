import QtQuick

// ════════════════════════════════════════════════════════════════
//  Slider — универсальный ползунок 0..1 в стиле Lunar Eclipse.
//  Дорожка + заполнение + круглая ручка. Размеры настраиваются
//  через trackHeight/handleSize (для OSD и попапа громкости нужен
//  крупный «ползунок», в настройках — тонкий).
//
//  value принадлежит вызывающему; moved — при перетаскивании,
//  committed — один раз при отпускании.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property string label: ""
    property string icon: ""
    property real value: 0
    property color accentColor: Theme.accent
    property int trackHeight: 4
    property int handleSize: 12
    // компактный режим — для инлайн-ползунков в панели: без строки-лейбла,
    // высота по дорожке (иконку и проценты кладёт вызывающий рядом)
    property bool compact: false
    property bool showLabel: !root.compact && (label.length > 0 || icon.length > 0)

    // значение во время перетаскивания (не трогаем value, чтобы не рвать
    // привязку вызывающей стороны — иначе ползунок «застревает»)
    property real dragValue: 0
    // «заполнение» при появлении: старт с нуля → плавно к value (как в «Памяти»)
    property real shown: 0
    property bool primed: false
    onValueChanged: if (primed) shown = value
    Component.onCompleted: primeTimer.restart()
    Timer {
        id: primeTimer
        interval: 60
        onTriggered: { root.shown = root.value; root.primed = true }
    }
    readonly property real displayValue: dragArea.pressed ? root.dragValue : root.shown

    signal moved(real value)
    signal committed(real value)

    implicitHeight: root.compact ? Math.max(16, root.handleSize + 6) : 50

    // содержимое центрирую по вертикали: тогда ползунок стоит ровно и при
    // height = implicitHeight, и когда вызывающий даёт высокую строку —
    // раньше Column прижимался к верху и в настройках звука уезжал вверх.
    Column {
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.compact ? 0 : 8

        Row {
            width: parent.width
            height: root.showLabel ? implicitHeight : 0
            visible: root.showLabel
            spacing: 0

            Text {
                text: root.icon
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(15)
                color: root.accentColor
                width: 22
            }

            Text {
                text: root.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                font.letterSpacing: 1
            }

            Item {
                width: parent.width - 22
                height: 1
            }
        }

        Item {
            width: parent.width
            height: Math.max(16, root.handleSize + 6)

            Rectangle {
                id: track

                width: parent.width
                height: root.trackHeight

                radius: root.trackHeight / 2

                anchors.verticalCenter: parent.verticalCenter

                color: Theme.trackBg

                border.color: Theme.border
                border.width: 1

                Rectangle {
                    id: fill

                    width: track.width
                        * Math.max(
                            0,
                            Math.min(1, root.displayValue)
                        )

                    height: parent.height

                    radius: root.trackHeight / 2

                    color: root.accentColor

                    Behavior on width {
                        enabled: !dragArea.pressed

                        NumberAnimation {
                            duration: Theme.animMed
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2

                        radius: root.trackHeight / 2 + 2

                        color: "transparent"

                        border.width: 2

                        border.color:
                            Theme.alpha(
                                root.accentColor,
                                0.35
                            )
                    }
                }

                Rectangle {
                    id: handle

                    width: root.handleSize
                    height: root.handleSize

                    radius: root.handleSize / 2

                    anchors.verticalCenter:
                        parent.verticalCenter

                    x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))

                    color: Theme.text

                    border.color: root.accentColor
                    border.width: 2

                    scale:
                        dragArea.pressed
                            ? 1.25
                            : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animFast
                        }
                    }
                }
            }

            MouseArea {
                id: dragArea

                anchors.fill: parent
                anchors.margins: -6

                preventStealing: true

                cursorShape: Qt.PointingHandCursor

                function setFromX(px) {
                    if (track.width <= 0) return
                    // mouse.x считается от dragArea, а он шире дорожки на 6px
                    // с каждой стороны — переводим точку в координаты track,
                    // иначе ползунок смещён и ручка не доходит до краёв
                    var p = dragArea.mapToItem(track, px, 0).x
                    var v =
                        Math.max(
                            0,
                            Math.min(
                                1,
                                p / track.width
                            )
                        )

                    root.dragValue = v
                    root.moved(v)
                }

                onPressed: (mouse) => {
                    setFromX(mouse.x)
                }

                onPositionChanged: (mouse) => {
                    if (pressed)
                        setFromX(mouse.x)
                }

                onReleased: {
                    root.committed(root.dragValue)
                }
            }
        }
    }
}
