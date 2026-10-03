import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarCenterZone — центр бара: «пульт», медиа-ячейка и часы/дата.
//  Состав/порядок/видимость — из BarSettings. Наружу отдаёт
//  clockCenterFromLeft (позиция Loader'а часов): по нему корень
//  ставит строку так, чтобы центр часов лёг на центр экрана.
// ════════════════════════════════════════════════════════════════
Item {
    id: centerZone
    property var host
    // Loader, в котором живёт ячейка часов — задаёт центровку
    property Item clockItem: null

    // расстояние от левого края зоны до центра ячейки часов
    readonly property real clockCenterFromLeft:
        clockItem ? (Theme.barPad + clockItem.x
            + Math.max(clockItem.width, clockItem.implicitWidth) / 2)
                  : implicitWidth / 2

    implicitWidth: zoneRow.implicitWidth + 2 * Theme.barPad
    implicitHeight: Theme.barH
    clip: true

    function compFor(id) {
        if (id === "control") return controlComp
        if (id === "media") return mediaComp
        if (id === "clock") return clockComp
        return null
    }

    // колесо над плашкой — громкость
    WheelHandler {
        onWheel: function (ev) {
            centerZone.host.bumpVol(ev.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    Row {
        id: zoneRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPad
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: Theme.space2

        Repeater {
            model: BarSettings.centerVisible

            delegate: Loader {
                id: centerLoader
                required property var modelData
                height: Theme.barH
                anchors.verticalCenter: parent.verticalCenter
                visible: item === null ? true : item.visible
                sourceComponent: centerZone.compFor(modelData.id)
                // часы задают центровку строки: запоминаю их Loader, когда он готов
                onStatusChanged: if (status === Loader.Ready && item
                    && modelData.id === "clock") centerZone.clockItem = centerLoader
                Component.onDestruction: if (centerZone.clockItem === centerLoader)
                    centerZone.clockItem = null
            }
        }
    }

    // ── «пульт» — раскрывает панель управления вниз ──
    Component {
        id: controlComp
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
    }

    // ── медиа-ячейка ──
    Component {
        id: mediaComp
        MediaCell { host: centerZone.host }
    }

    // ── часы + дата — одна ячейка со штрихом-акцентом ──
    Component {
        id: clockComp
        Cell {
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
