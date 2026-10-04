import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  MediaCell — медиа-ячейка бара: трек, play/pause, мини-спектр cava;
//  клик открывает медиа-панель. Собрана на общем Cell (host = корень):
//  штрих-акцент, отступы и ховер — те же, что у прочих ячеек бара.
// ════════════════════════════════════════════════════════════════
Cell {
    property var host
    // прогресс задаёт зона (BarCenterZone): через var-хост эти значения не
    // пересчитываются в Loader'е, поэтому приходят типизированными свойствами
    property real progressLength: 0
    property real progressPosition: 0
    id: mediaInline
    // видимостью медиа-ячейки рулит зона (BarCenterZone): она знает и про
    // настройки состава, и про «играет ли что-то». Свой биндинг на
    // host.mediaActive тут ставить нельзя — через Loader он не пересчитывается.
    anchors.verticalCenter: parent.verticalCenter
    interactive: true
    accent: host.playing ? Theme.accent : Theme.barFaint
    tip: "Медиа — открыть панель"
    onClicked: BarState.togglePanel("media")

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
        // только пульс: медиа-попап сам не раскрываю (мешает)
        function onTrackChanged() { if (host.pulsePrimed) mediaInline.trackPulse.restart() }
    }

    // обёртка-Item: Column нельзя вешать на якоря прямо в Row-позиционере
    Item {
        width: 168
        height: Theme.barCellH

        Column {
            id: mediaCol
            anchors.centerIn: parent
            width: parent.width
            spacing: 1

            Row {
                width: parent.width
                height: 12
                spacing: Theme.space1
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: host.playing ? "\uf04c" : "\uf04b"
                    color: host.playing ? Theme.accent : Theme.barFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(10)
                }
                Text {
                    width: parent.width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: host.track
                    color: Theme.barText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }
            }

            // нижний ряд — мини-спектр cava
            Row {
                width: parent.width
                height: 9
                spacing: 2
                Repeater {
                    model: 14
                    delegate: Item {
                        required property int index
                        width: 2
                        height: 9
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2 + (host.barValues[index] || 0) * 7
                            radius: 1
                            color: Theme.alpha(Theme.accent, 0.35 + 0.65 * (host.barValues[index] || 0))
                        }
                    }
                }
            }

            // тонкая линия прогресса трека; гаснет, если длина неизвестна
            // (радио/стримы) — тогда не показываю мёртвую полосу
            Rectangle {
                width: parent.width
                height: 2
                radius: 1
                color: Theme.trackBg
                visible: mediaInline.progressLength > 0
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1,
                        mediaInline.progressLength > 0
                            ? mediaInline.progressPosition / mediaInline.progressLength : 0))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    Behavior on width { Anim { type: Anim.FastEffects } }
                }
            }
        }
    }
}
