import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarMediaPanel — содержимое медиа-режима панели бара.
//  Обложка (монохром), трек/исполнитель, seek с временем, транспорт,
//  shuffle/repeat и очередь «далее». Источник — MediaCore (MPRIS/mpv).
//  Панель сама задаёт высоту по этому implicitHeight.
// ════════════════════════════════════════════════════════════════
Item {
    id: mp

    // просьба открыть полный плеер — ловит LunarPanel (там есть openPlayer)
    signal openPlayerRequested()

    implicitWidth: 430
    implicitHeight: col.implicitHeight

    readonly property bool has: MediaCore.has
    readonly property var player: MediaCore.player
    readonly property bool playing: MediaCore.playing
    readonly property string title: MediaCore.title.length > 0 ? MediaCore.title : "ничего не играет"
    readonly property string artist: MediaCore.artist
    readonly property real len: MediaCore.len
    readonly property real pos: MediaCore.pos
    readonly property bool seekable: MediaCore.seekable

    Column {
        id: col
        width: parent.width
        spacing: Theme.space2

        // верхний блок — карточка: трек, seek, транспорт
        Card {
            width: parent.width
            contentMargins: 14
            contentSpacing: 10

        // ── трек: обложка + название/исполнитель + к плееру ──
        Row {
            width: parent.width
            spacing: Theme.space4

            Item {
                width: 60
                height: 60
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Image {
                    id: cover
                    anchors.fill: parent
                    source: MediaCore.art
                    sourceSize: Qt.size(120, 120)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: cover
                    visible: cover.status === Image.Ready
                    saturation: -1.0
                    brightness: 0.05
                    maskEnabled: true
                    maskSource: coverMask
                }
                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: Theme.radiusS
                    color: "white"
                    visible: false
                    layer.enabled: true
                }
                Rectangle {
                    anchors.fill: parent
                    visible: cover.status !== Image.Ready
                    radius: Theme.radiusS
                    color: Theme.fill
                    Text {
                        anchors.centerIn: parent
                        text: "󰎇"
                        color: Theme.barFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(22)
                    }
                }
            }

            Column {
                width: parent.width - 60 - openBtn.width - Theme.space4 * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: mp.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(15)
                    font.bold: true
                }
                Text {
                    width: parent.width
                    visible: mp.artist.length > 0
                    elide: Text.ElideRight
                    text: mp.artist
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                }
            }

            // открыть полный плеер (LunarPlayer)
            Text {
                id: openBtn
                anchors.verticalCenter: parent.verticalCenter
                text: "󰊓"
                color: openMouse.containsMouse ? Theme.accent : Theme.barDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(15)
                MouseArea {
                    id: openMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mp.openPlayerRequested()
                }
            }
        }

        // ── seek-полоса с временем ──
        Item {
            id: seek
            width: parent.width
            height: Theme.barCellH

            readonly property real frac: MediaCore.progress
            property real dragFrac: 0
            readonly property real useFrac: seekArea.pressed ? dragFrac : frac

            Rectangle {
                id: seekBg
                anchors.top: parent.top
                width: parent.width
                height: 5
                radius: height / 2
                color: Theme.alpha(Theme.text, 0.12)

                Rectangle {
                    width: parent.width * seek.useFrac
                    height: parent.height
                    radius: parent.radius
                    color: mp.seekable ? Theme.accent : Theme.textDim
                    Behavior on width {
                        enabled: !seekArea.pressed
                        NumberAnimation { duration: Theme.animMed }
                    }
                }

                Rectangle {
                    width: 12
                    height: 12
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(seekBg.width, seekBg.width * seek.useFrac)) - width / 2
                    color: Theme.text
                    border.color: Theme.accent
                    border.width: 2
                    opacity: (seekArea.pressed || seekArea.containsMouse) && mp.seekable ? 1 : 0
                    scale: seekArea.pressed ? 1.15 : 1.0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                }
            }

            Row {
                anchors.top: seekBg.bottom
                anchors.topMargin: 6
                width: parent.width
                Text {
                    width: 44
                    text: MediaCore.fmt(seekArea.pressed ? seek.dragFrac * mp.len : mp.pos)
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }
                Item { width: parent.width - 88; height: 1 }
                Text {
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: MediaCore.fmt(mp.len)
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }
            }

            MouseArea {
                id: seekArea
                anchors.fill: parent
                anchors.margins: -8
                preventStealing: true
                hoverEnabled: true
                enabled: mp.seekable
                cursorShape: mp.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                function setFromX(px) {
                    var p = seekArea.mapToItem(seekBg, px, 0).x
                    seek.dragFrac = Math.max(0, Math.min(1, p / seekBg.width))
                }
                onPressed: (mouse) => setFromX(mouse.x)
                onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
                onReleased: MediaCore.seekFrac(seek.dragFrac)
            }
        }

        // ── транспорт ──
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.space5
            height: 30

            // shuffle
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰒝"
                color: !MediaCore.shuffleSupported ? Theme.textFaint
                    : (MediaCore.shuffle ? Theme.accent : Theme.barDim)
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(15)
                opacity: MediaCore.shuffleSupported ? 1 : 0.4
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MediaCore.toggleShuffle()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰒫"
                color: Theme.barDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(18)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (mp.player) mp.player.previous()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: mp.playing ? "󰏤" : "󰐊"
                color: mp.playing ? Theme.accent : Theme.barText
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(22)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (mp.player) mp.player.togglePlaying()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰒬"
                color: Theme.barDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(18)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (mp.player) mp.player.next()
                }
            }

            // repeat: выкл → все → один
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: MediaCore.loopState === 1 ? "󰑘" : "󰑖"
                color: !MediaCore.loopSupported ? Theme.textFaint
                    : (MediaCore.loopState !== 0 ? Theme.accent : Theme.barDim)
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(15)
                opacity: MediaCore.loopSupported ? 1 : 0.4
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MediaCore.cycleLoop()
                }
            }
        }
        }

        // ── разделитель + вход в полный плеер ──
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        SectionHeader { text: "ОЧЕРЕДЬ И ПОИСК — В ПОЛНОМ ПЛЕЕРЕ"; bold: false }

        Rectangle {
            width: parent.width
            height: 30
            radius: Theme.radius
            color: openFullMouse.containsMouse ? Theme.hoverStrong : Theme.cardBg
            border.width: 1
            border.color: Theme.border

            Row {
                anchors.centerIn: parent
                spacing: Theme.space2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰕧"
                    color: Theme.barDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(13)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "открыть плеер"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }
            }

            MouseArea {
                id: openFullMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mp.openPlayerRequested()
            }
        }
    }
}
