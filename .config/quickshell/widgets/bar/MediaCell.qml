import QtQuick
import QtQuick.Effects
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  MediaCell — медиа-полоса бара: обложка (монохром) + значок
//  воспроизведения + название трека (до ~2/3 ширины) + мини-кава.
//  Сквозной прогресс рисует LunarPanel линией во всю ширину бара.
//  Ширина — по содержимому, но не шире stripWidth (задаёт зона).
//  Клик раскрывает плашку МЕДИА вниз. host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Cell {
    property var host
    // максимум ширины полосы (в центре — широкий)
    property int stripWidth: 640
    signal clickedBubble()
    id: mediaInline
    anchors.verticalCenter: parent.verticalCenter
    interactive: true
    active: BarState.mode === "media"
    accent: host.playing ? Theme.accent : Theme.barFaint
    tip: "Медиа — раскрыть в баре"
    onClicked: clickedBubble()

    readonly property string art: (host.player && host.player.trackArtUrl)
        ? host.player.trackArtUrl : ""

    // мягкий пульс при смене трека
    property SequentialAnimation trackPulse: SequentialAnimation {
        NumberAnimation {
            target: mediaInline; property: "scale"; to: 1.15
            duration: Theme.animMed / 2; easing.type: Theme.easeOut
        }
        NumberAnimation {
            target: mediaInline; property: "scale"; to: 1.0
            duration: Theme.animMed / 2; easing.type: Theme.easeOut
        }
    }
    property Connections trackWatch: Connections {
        target: host
        // только пульс: медиа-попуп сам не раскрываю (мешает)
        function onTrackChanged() { if (host.pulsePrimed) mediaInline.trackPulse.restart() }
    }

    Item {
        id: strip
        readonly property int cavaW: 98
        // название — не длиннее ~2/3 ширины полосы
        readonly property int titleCap: Math.round(mediaInline.stripWidth * 0.6)
        readonly property int natural: ppText.x + ppText.implicitWidth + 8
            + Math.min(titleText.implicitWidth, strip.titleCap)
            + 12 + strip.cavaW + 2
        width: Math.min(mediaInline.stripWidth, natural)
        height: Theme.barCellH
        // «выходит из линии»: поднимается снизу и проявляется, когда играет
        property real reveal: mediaInline.host.mediaActive ? 1 : 0
        opacity: strip.reveal
        transform: Translate { y: (1 - strip.reveal) * 14 }
        Behavior on reveal {
            NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
        }

        // обложка (монохром) или нота, если арта нет
        Item {
            id: artBox
            x: 0
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: artImg
                anchors.fill: parent
                source: mediaInline.art
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: artImg
                visible: artImg.status === Image.Ready
                saturation: -1.0
                brightness: 0.12
                maskEnabled: true
                maskSource: artMask
            }
            Rectangle {
                id: artMask
                anchors.fill: parent
                radius: Theme.radiusS
                color: "white"
                visible: false
                layer.enabled: true
            }
            Text {
                anchors.centerIn: parent
                visible: artImg.status !== Image.Ready
                text: "\uf001"
                color: Theme.barFaint
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(13)
            }
        }

        // значок воспроизведения (индикатор; клик по ячейке — пузырь)
        Text {
            id: ppText
            x: artBox.x + artBox.width + 8
            anchors.verticalCenter: parent.verticalCenter
            text: mediaInline.host.playing ? "\uf04c" : "\uf04b"
            color: mediaInline.host.playing ? Theme.accent : Theme.barFaint
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSize(13)
        }

        // трек: до 2/3 полосы, дальше — многоточие
        Text {
            id: titleText
            x: ppText.x + ppText.implicitWidth + 8
            width: Math.min(implicitWidth, strip.titleCap)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: mediaInline.host.track
            color: Theme.barText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(12)
        }

        // мини-кава: тонкие столбики по правому краю полосы
        Row {
            id: cavaRow
            x: titleText.x + titleText.width + 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: 20

                delegate: Item {
                    required property int index
                    width: 3
                    height: Theme.barCellH

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Math.max(1, (mediaInline.host.barValues[index] || 0)
                            * (Theme.barCellH * 0.55))
                        radius: 1
                        color: Theme.alpha(Theme.accent, 0.85)
                        Behavior on height {
                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}
