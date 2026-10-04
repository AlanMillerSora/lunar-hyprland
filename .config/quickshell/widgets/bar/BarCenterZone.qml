import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarCenterZone — центр бара в arch-стиле: одна пилюля (accent-подложка),
//  внутри — сеть ↓↑ · пульт · часы. Боковые ячейки равной ширины, поэтому
//  кнопка пульта стоит ровно по центру экрана. Состав/порядок — из
//  BarSettings. Наружу отдаю pillCenterFromLeft: по нему корень центрует
//  строку так, чтобы центр пилюли лёг на центр экрана.
// ════════════════════════════════════════════════════════════════
Item {
    id: centerZone
    property var host

    // ссылка на погодную ячейку — открыть пузырь как при клике (IPC)
    property var weatherCellRef: null
    function openWeatherBubble() {
        if (weatherCellRef)
            weatherCellRef.openBubbleFromHere()
    }

    // равная ширина боковых ячеек — для симметрии пульта по центру
    readonly property real sideW: 104

    implicitWidth: pill.width + 2 * Theme.space2
    implicitHeight: Theme.barH
    clip: true

    // id ячейки → её компонент
    function compFor(id) {
        if (id === "network") return netComp
        if (id === "weather") return weatherComp
        if (id === "control") return controlComp
        if (id === "clock") return clockComp
        return null
    }

    // центр пилюли от левого края зоны — по нему корень центрует строку
    readonly property real pillCenterFromLeft: Theme.space2 + pill.width / 2

    // колесо над пилюлей — громкость
    WheelHandler {
        onWheel: function (ev) {
            centerZone.host.bumpVol(ev.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    // ── пилюля режимов: мягкая accent-подложка (arch surfaceActive) ──
    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: centerRow.implicitWidth + Theme.space3 * 2
        height: Theme.barCellH + 4
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border2
        Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }

        Row {
            id: centerRow
            anchors.centerIn: parent
            height: parent.height
            spacing: Theme.space1

            Repeater {
                id: centerRep
                model: BarSettings.centerVisible

                delegate: Loader {
                    required property var modelData
                    id: centerLoader
                    // боковые ячейки равной ширины, центральная — по содержимому
                    width: (modelData.id === "network" || modelData.id === "clock")
                        ? centerZone.sideW : (item ? item.implicitWidth : 0)
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: centerZone.compFor(modelData.id)
                }
            }
        }
    }

    // ── сеть ↓↑: клик открывает сеть в Hub ──
    Component {
        id: netComp
        Cell {
            id: netCell
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: centerZone.host.netKind === "off" ? Theme.barFaint : Theme.barDim
            tip: "Сеть (Hub)"
            onClicked: centerZone.host.openNetwork()
            // компактная скорость, как fmtSpeed у arch: 4 знака, без «КБ/с»
            function cs(kb) {
                if (kb >= 1024) {
                    var mb = kb / 1024
                    return (mb >= 10 ? Math.round(mb) : mb.toFixed(1)) + "M"
                }
                return Math.round(kb) + "K"
            }
            Row {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: centerZone.host.netKind === "eth" ? "󰈀" : "\uf1eb"
                    color: centerZone.host.netKind === "off" ? Theme.barFaint : Theme.barText
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(14)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // arch: только «вниз» (входящий поток) — компактно
                    text: "↓" + netCell.cs(SysInfo.rx)
                    color: Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
            }
        }
    }

    // ── «пульт» ──
    Component {
        id: controlComp
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            active: BarState.mode === "control"
            accent: Theme.barDim
            tip: "Пульт · звук и действия"
            onClicked: BarState.togglePanel("control")
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf013"
                color: BarState.mode === "control" ? Theme.accent : Theme.barText
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(16)
            }
        }
    }

    // ── погода: иконка + температура; клик раскрывает плашку вниз ──
    Component {
        id: weatherComp
        Cell {
            id: weatherCell
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            active: BarState.mode === "weather"
            accent: Theme.barFaint
            tip: "Погода"
            function openBubbleFromHere() {
                BarState.togglePanel("weather")
            }
            Component.onCompleted: centerZone.weatherCellRef = weatherCell
            Component.onDestruction: if (centerZone.weatherCellRef === weatherCell)
                centerZone.weatherCellRef = null
            onClicked: openBubbleFromHere()
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.icon
                    color: Weather.ok ? Theme.barText : Theme.barFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(15)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.shortTemp
                    color: Weather.ok ? Theme.barText : Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                }
            }
        }
    }

    // ── часы + дата ──
    Component {
        id: clockComp
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            accent: Theme.accent
            tip: centerZone.host.dayText + " " + centerZone.host.dateText
            Row {
                anchors.centerIn: parent
                height: Theme.barCellH
                spacing: centerZone.host.clockText.length > 0 ? 8 : 0
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: centerZone.host.clockText
                    color: Theme.barText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(17)
                    font.bold: true
                    font.letterSpacing: 1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: centerZone.host.dayText + " " + centerZone.host.dateText
                    color: Theme.barFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }
}
