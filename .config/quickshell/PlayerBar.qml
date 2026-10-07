import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// ════════════════════════════════════════════════════════════════
//  PlayerBar — нижняя панель Playing: миниатюра обложки (монохром),
//  название — артист (бегущая строка), управление (prev / play-pause /
//  next, shuffle), громкость и «лунный seek» во всю ширину.
//  Анимации стоят, когда active = false (окно скрыто).
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool active: true

    implicitHeight: 96

    readonly property bool overflow: root.active && PlayerCore.hasMedia
        && titleText.contentWidth > titleClip.width
    readonly property real span: titleText.contentWidth + 48

    // бегущая строка: линейно уезжает и начинает заново
    property real marqueeX: 0
    NumberAnimation on marqueeX {
        from: 0
        to: -root.span
        duration: Math.max(3200, root.span * 28)
        loops: Animation.Infinite
        running: root.overflow
        easing.type: Easing.Linear
    }
    onOverflowChanged: if (!overflow) marqueeX = 0

    // рамку и фон даёт обёртка TuiPanel («Playing») — тут только контент
    Rectangle {
        anchors.fill: parent
        color: "transparent"

        // клики по полосе не уходят на backdrop
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: Theme.space3

                // ── миниатюра ──
                Item {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44

                    Image {
                        id: barCover
                        anchors.fill: parent
                        source: PlayerCore.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: barCover
                        visible: PlayerCore.artUrl.length > 0 && barCover.status !== Image.Error
                        saturation: -1.0
                        brightness: 0.04
                        colorization: 0.28
                        colorizationColor: Theme.accent
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        visible: PlayerCore.artUrl.length === 0 || barCover.status === Image.Error
                        color: Theme.bgCard
                        border.color: Theme.border
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "󰎇"
                            color: Theme.textFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(16)
                        }
                    }
                }

                // ── название — артист ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Item {
                        id: titleClip
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        clip: true

                        Row {
                            x: root.marqueeX
                            spacing: 48
                            Text {
                                id: titleText
                                text: PlayerCore.title.length > 0 ? PlayerCore.title : "ничего не играет"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                                font.bold: true
                            }
                            Text {
                                text: titleText.text
                                visible: root.overflow
                                color: Theme.text
                                font: titleText.font
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: PlayerCore.artist.length > 0
                        text: PlayerCore.artist
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // ── управление ──
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.space4

                    Text {
                        text: "󰒫"
                        color: prevMouse.containsMouse ? Theme.accent : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(16)
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PlayerCore.prev()
                        }
                    }
                    Text {
                        text: PlayerCore.playing ? "󰏤" : "󰐊"
                        color: playMouse.containsMouse ? Theme.accent : Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(20)
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PlayerCore.toggle()
                        }
                    }
                    Text {
                        text: "󰒬"
                        color: nextMouse.containsMouse ? Theme.accent : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(16)
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PlayerCore.next()
                        }
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 0
                        anchors.verticalCenter: parent.verticalCenter
                        color: PlayerCore.shuffle
                            ? Theme.active
                            : (shuffleMouse.containsMouse ? Theme.hover : "transparent")
                        border.width: PlayerCore.shuffle ? 1 : 0
                        border.color: Theme.alpha(Theme.accent, 0.5)
                        Text {
                            anchors.centerIn: parent
                            text: "󰒝"
                            color: PlayerCore.shuffle ? Theme.accent : Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(12)
                        }
                        MouseArea {
                            id: shuffleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PlayerCore.toggleShuffle()
                        }
                    }

                    // ── громкость: слайдер + динамик (клик — mute, колесо — шаг) ──
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space2

                        Slider {
                            width: 84
                            implicitHeight: 26
                            trackHeight: 3
                            handleSize: 10
                            showLabel: false
                            value: PlayerCore.volume / 100
                            accentColor: PlayerCore.muted ? Theme.textFaint : Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                            onMoved: (v) => PlayerCore.setVolume(v * 100)
                        }

                        Text {
                            id: volIcon
                            text: (PlayerCore.muted || PlayerCore.volume <= 0)
                                ? "󰖁"
                                : (PlayerCore.volume < 50 ? "󰕿" : "󰕾")
                            color: (PlayerCore.muted || PlayerCore.volume <= 0)
                                ? Theme.textFaint
                                : (volMouse.containsMouse ? Theme.accent : Theme.textDim)
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(14)
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                id: volMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PlayerCore.toggleMute()
                                onWheel: (e) => PlayerCore.volumeStep(e.angleDelta.y > 0 ? 5 : -5)
                            }
                        }
                    }

                    // правые служебные иконки (как вPlaying у Spotify)
                    Text {
                        text: "󰎄"
                        color: Theme.textFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(13)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "󰓃"
                        color: Theme.textFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(13)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ── «лунный seek» во всю ширину ──
            PlayerSeek {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
