import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarLeftZone — левая зона бара: фазы столов и PERF. Всё «плоское»,
//  без плашек. Состав/порядок/видимость — из BarSettings (bar.json).
//  host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Item {
    id: leftZone
    property var host

    implicitWidth: zoneRow.implicitWidth + 2 * Theme.barPad
    implicitHeight: Theme.barH
    clip: true

    // id ячейки → её компонент
    function compFor(id) {
        if (id === "workspaces") return wsComp
        if (id === "perf") return perfComp
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
            // PERF показываю только когда governor уехал с performance:
            // в норме это мёртвая надпись, а как красный сигнал сбоя — нужна.
            visible: leftZone.host.cpuGovernor !== "performance"
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
}
