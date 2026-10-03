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
    id: mediaInline
    visible: host.mediaActive
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
                spacing: 4
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: host.playing ? "\uf04c" : "\uf04b"
                    color: host.playing ? Theme.accent : Theme.barFaint
                    font.family: Theme.iconFont
                    font.pixelSize: 10
                }
                Text {
                    width: parent.width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: host.track
                    color: Theme.barText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
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
        }
    }
}
