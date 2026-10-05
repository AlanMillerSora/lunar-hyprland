import QtQuick
import QtQuick.Effects
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  MediaCell — медиа-полоса бара: обложка (монохром) + значок
//  воспроизведения + название трека (до ~2/3 ширины) + мини-кава.
//  Полоса занимает фиксированную область stripWidth, а содержимое
//  центрируется — короткое название стоит по центру, а не жмётся
//  к часам. При появлении «выходит из линии» (поднимается снизу).
//  Клик раскрывает плашку МЕДИА вниз. host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Cell {
    property var host
    // ширина области полосы (в центре — широкая, как «рельса» в покое)
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
    readonly property int cavaBars: 32

    // значение полосы кавы: 20 полос источника растягиваю на cavaBars
    function bandVal(i, n) {
        var src = mediaInline.host.barValues
        if (!src || src.length === 0)
            return 0
        if (n <= 1 || src.length === 1)
            return src[0] || 0
        var f = i * (src.length - 1) / (n - 1)
        var lo = Math.floor(f)
        var hi = Math.min(src.length - 1, lo + 1)
        var a = src[lo] || 0
        var b = src[hi] || 0
        return a + (b - a) * (f - lo)
    }

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
        width: mediaInline.stripWidth
        height: Theme.barCellH
        // название — не длиннее ~2/3 ширины полосы
        readonly property int titleCap: Math.round(mediaInline.stripWidth * 0.6)
        // «выходит из линии»: поднимается снизу и проявляется, когда играет
        property real reveal: mediaInline.host.mediaActive ? 1 : 0
        opacity: strip.reveal
        transform: Translate { y: (1 - strip.reveal) * 14 }
        Behavior on reveal {
            NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
        }

        // содержимое центрируется в области полосы
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8

            // обложка (монохром) или нота, если арта нет
            Item {
                id: artBox
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
                    text: "󰎇"
                    color: Theme.barFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(13)
                }
            }

            // значок воспроизведения (индикатор; клик по ячейке — пузырь)
            Text {
                id: ppText
                anchors.verticalCenter: parent.verticalCenter
                text: mediaInline.host.playing ? "󰏤" : "󰐊"
                color: mediaInline.host.playing ? Theme.accent : Theme.barFaint
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(13)
            }

            // трек: до 2/3 полосы, дальше — многоточие
            Text {
                id: titleText
                width: Math.min(implicitWidth, strip.titleCap)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: mediaInline.host.track
                color: Theme.barText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(12)
            }

            // мини-кава: длинный ряд тонких столбиков
            Row {
                id: cavaRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: mediaInline.cavaBars

                    delegate: Item {
                        required property int index
                        width: 3
                        height: Theme.barCellH

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: Math.max(1, mediaInline.bandVal(index, mediaInline.cavaBars)
                                * (Theme.barCellH * 0.55))
                            radius: Theme.radiusHair
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
}
