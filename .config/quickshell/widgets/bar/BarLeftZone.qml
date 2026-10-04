import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarLeftZone — левая зона бара (arch-стиль): фазы столов, PERF,
//  ресурсы CPU·RAM·GPU тонкими полосками и погода. Всё «плоское», без
//  плашек. Состав/порядок/видимость — из BarSettings (bar.json).
//  host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Item {
    id: leftZone
    property var host

    implicitWidth: zoneRow.implicitWidth + 2 * Theme.barPad
    implicitHeight: Theme.barH
    clip: true

    // открыть пузырь погоды как при клике (для IPC/хоткея)
    function openWeatherBubble() {
        if (weatherCellRef)
            weatherCellRef.openBubbleFromHere()
    }
    property var weatherCellRef: null

    // id ячейки → её компонент
    function compFor(id) {
        if (id === "workspaces") return wsComp
        if (id === "perf") return perfComp
        if (id === "system") return sysComp
        if (id === "weather") return weatherComp
        return null
    }

    Row {
        id: zoneRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPad
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: Theme.space4

        Repeater {
            model: BarSettings.leftVisible

            delegate: Loader {
                required property var modelData
                height: Theme.barH
                anchors.verticalCenter: parent.verticalCenter
                // скрытая ячейка (например, медиа без трека) не занимает место
                visible: item === null ? true : item.visible
                sourceComponent: leftZone.compFor(modelData.id)
            }
        }
    }

    // ── рабочие столы (лунные фазы) ──
    Component {
        id: wsComp
        BarWorkspaces { anchors.verticalCenter: parent.verticalCenter; host: leftZone.host }
    }

    // ── PERF: governor; индикатор, что система работает на performance.
    //    при уходе — красным. ──
    Component {
        id: perfComp
        Item {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: perfText.implicitWidth
            implicitHeight: Theme.barCellH
            Text {
                id: perfText
                anchors.verticalCenter: parent.verticalCenter
                text: "PERF"
                color: leftZone.host.cpuGovernor === "performance" ? Theme.barFaint : Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.letterSpacing: 1
                font.bold: leftZone.host.cpuGovernor !== "performance"
            }
        }
    }

    // ── ресурсы: три тонкие полоски CPU · RAM · GPU ──
    Component {
        id: sysComp
        SystemIsland { host: leftZone.host }
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
            Component.onCompleted: leftZone.weatherCellRef = weatherCell
            Component.onDestruction: if (leftZone.weatherCellRef === weatherCell)
                leftZone.weatherCellRef = null
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
}
