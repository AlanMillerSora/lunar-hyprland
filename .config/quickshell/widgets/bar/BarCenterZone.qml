import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarCenterZone — центр бара: «пульт», медиа-ячейка и часы/дата.
//  Наружу отдаёт clockCenterFromLeft — по нему корень ставит строку так,
//  чтобы центр часовой ячейки лёг ровно на центр экрана.
// ════════════════════════════════════════════════════════════════
Item {
    id: centerZone
    property var host

    // расстояние от левого края зоны до центра ячейки часов
    readonly property real clockCenterFromLeft:
        Theme.barPad + clockCell.x + clockCell.width / 2

    implicitWidth: defRow.implicitWidth + 2 * Theme.barPad
    implicitHeight: Theme.barH
    clip: true

    // колесо над плашкой — громкость
    WheelHandler {
        onWheel: function (ev) {
            centerZone.host.bumpVol(ev.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    Row {
        id: defRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPad
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: Theme.space2

        // «пульт» — раскрывает панель управления вниз
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: BarState.mode === "control" ? Theme.accent : Theme.barDim
            tip: "Пульт · звук и действия"
            onClicked: BarState.togglePanel("control")
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf013"
                color: BarState.mode === "control" ? Theme.accent : Theme.barDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(14)
            }
        }

        // медиа-ячейка — компонент widgets/bar/MediaCell
        MediaCell { host: centerZone.host }

        // часы + дата — одна ячейка со штрихом-акцентом
        Cell {
            id: clockCell
            anchors.verticalCenter: parent.verticalCenter
            accent: Theme.accent
            Row {
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.barCellH
                spacing: 0
                Text {
                    id: clockLabel
                    text: centerZone.host.clockText.substring(0, 2)
                    color: Theme.barText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(Theme.fontClock)
                    font.bold: true
                    font.letterSpacing: 1
                    height: Theme.barCellH
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    id: clockColon
                    text: ":"
                    color: Theme.barText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(Theme.fontClock)
                    font.bold: true
                    height: Theme.barCellH
                    verticalAlignment: Text.AlignVCenter
                    opacity: centerZone.host.colonOn ? 1.0 : 0.15
                    Behavior on opacity { NumberAnimation { duration: Theme.anim.slowEffects; easing.type: Easing.InOutSine } }
                }
                Text {
                    id: clockMin
                    text: centerZone.host.clockText.substring(3)
                    color: Theme.barText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(Theme.fontClock)
                    font.bold: true
                    font.letterSpacing: 1
                    height: Theme.barCellH
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Text {
                id: dayLabel
                anchors.verticalCenter: parent.verticalCenter
                text: centerZone.host.dayText + " " + centerZone.host.dateText
                color: Theme.barDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                height: Theme.barCellH
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
