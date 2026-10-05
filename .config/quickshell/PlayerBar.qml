import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// ════════════════════════════════════════════════════════════════
//  PlayerBar — нижняя полоса плеера: миниатюра обложки (монохром),
//  название — артист (бегущая строка при переполнении), управление
//  (prev / play-pause / next, shuffle, «развернуть»), время и тонкий
//  прогресс. Анимации стоят, когда active = false (окно скрыто).
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool active: true
    // прогресс в полосе: на странице «СЕЙЧАС» он дублирует большой «лунный seek»,
    // поэтому там его прячу — остаётся ровно один ползунок
    property bool showProgress: true
    signal expandRequested()

    implicitHeight: 84

    readonly property bool overflow: root.active && PlayerCore.hasMedia
        && titleText.contentWidth > titleClip.width
    readonly property real span: titleText.contentWidth + 48
    readonly property real progress: PlayerCore.length > 0
        ? Math.max(0, Math.min(1, (PlayerCore.position || 0) / PlayerCore.length))
        : 0

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

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusL
        color: Theme.bgCard
        border.color: Theme.border
        border.width: 1

        // клики по полосе не уходят на backdrop
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: Theme.space2

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
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
                        color: Theme.bg
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
                        radius: Theme.radius
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

                    Text {
                        text: "󰊓"
                        color: expandMouse.containsMouse ? Theme.accent : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(13)
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            id: expandMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expandRequested()
                        }
                    }

                    // ── громкость: динамик (клик — mute, колесо — шаг) + слайдер ──
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
                }
            }

            // ── время + тонкий прогресс (на «СЕЙЧАС» прячу — там свой «лунный seek») ──
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.showProgress ? 12 : 0
                visible: root.showProgress
                spacing: Theme.space2

                Text {
                    text: PlayerCore.fmt(PlayerCore.position || 0)
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(9)
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    id: barProgress
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.trackBg
                    }
                    Rectangle {
                        width: parent.width * root.progress
                        height: parent.height
                        radius: height / 2
                        color: PlayerCore.seekable ? Theme.accent : Theme.textDim
                        Behavior on width {
                            enabled: !progMouse.pressed
                            NumberAnimation { duration: Theme.animMed }
                        }
                    }

                    MouseArea {
                        id: progMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: PlayerCore.seekable
                        preventStealing: true
                        cursorShape: PlayerCore.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onReleased: (mouse) => {
                            if (!PlayerCore.seekable || PlayerCore.length <= 0)
                                return
                            var p = progMouse.mapToItem(barProgress, mouse.x, 0).x
                            var f = Math.max(0, Math.min(1, p / barProgress.width))
                            PlayerCore.seekTo(f * PlayerCore.length)
                        }
                    }
                }

                Text {
                    text: PlayerCore.fmt(PlayerCore.length)
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(9)
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
