import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  MediaCell — медиа-пилюля бара в arch-стиле: одна строка — play/pause
//  и название трека с обрезкой (как playerPill у ArchEclipse). Спектр
//  cava остался в медиа-панели, в баре его нет — бар тонкий и тихий.
//  Клик раскрывает плашку вниз. host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Cell {
    property var host
    // прогресс задаёт зона (BarRightZone): через var-хост эти значения не
    // пересчитываются в Loader'е, поэтому приходят типизированными свойствами
    property real progressLength: 0
    property real progressPosition: 0
    signal clickedBubble()
    id: mediaInline
    anchors.verticalCenter: parent.verticalCenter
    interactive: true
    active: BarState.mode === "media"
    accent: host.playing ? Theme.accent : Theme.barFaint
    tip: "Медиа — раскрыть в баре"
    onClicked: clickedBubble()

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

    Item {
        width: 200
        height: Theme.barCellH

        Row {
            id: mediaRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: host.playing ? "\uf04c" : "\uf04b"
                color: host.playing ? Theme.accent : Theme.barFaint
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(13)
            }
            Text {
                width: 176
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: host.track
                color: Theme.barText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(12)
            }
        }

        // тонкая линия прогресса трека под строкой; гаснет, если длина
        // неизвестна (радио/стримы) — не показываю мёртвую полосу
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1.5
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
