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
    property bool showLabel: label.length > 0 || icon.length > 0

    // значение во время перетаскивания (не трогаем value, чтобы не рвать
    // привязку вызывающей стороны — иначе ползунок «застревает»)
    property real dragValue: 0
    readonly property real displayValue: dragArea.pressed ? root.dragValue : root.value

    signal moved(real value)
    signal committed(real value)

    implicitHeight: 50

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            height: root.showLabel ? implicitHeight : 0
            visible: root.showLabel
            spacing: 0

            Text {
                text: root.icon
                font.family: Theme.iconFont
                font.pixelSize: 15
                color: root.accentColor
                width: 22
            }

            Text {
                text: root.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
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
                            duration: Theme.animFast
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

                    x: fill.width - width / 2

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
                    var v =
                        Math.max(
                            0,
                            Math.min(
                                1,
                                px / track.width
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
