import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarLeftZone — левая зона бара: марка LUNAR + фазы столов,
//  PERF и раскладка. Состав, порядок и видимость ячеек беру из
//  BarSettings (bar.json); ячейки описаны Component'ами и
//  подставляются через Repeater→Loader. host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Item {
    id: leftZone
    property var host

    implicitWidth: zoneRow.implicitWidth + 2 * Theme.barPad
    implicitHeight: Theme.barH
    clip: true

    // id ячейки → её компонент
    function compFor(id) {
        if (id === "mark") return markComp
        if (id === "workspaces") return wsComp
        if (id === "perf") return perfComp
        if (id === "layout") return layoutComp
        return null
    }

    Row {
        id: zoneRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPad
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: Theme.space3

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

    // ── марка LUNAR + фаза активного стола ──
    Component {
        id: markComp
        Row {
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.barCellH
            spacing: Theme.space2

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                source: Qt.resolvedUrl("../../assets/logo.svg")
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "LUNAR " + (leftZone.host.focusedPhase > 0
                    ? ("0" + leftZone.host.focusedPhase).slice(-2) : "--")
                color: Theme.barDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(16)
                font.letterSpacing: 1.5
            }
        }
    }

    // ── рабочие столы ──
    Component {
        id: wsComp
        BarWorkspaces { anchors.verticalCenter: parent.verticalCenter; host: leftZone.host }
    }

    // ── PERF: governor; штрих белый на performance, danger — если уехал ──
    Component {
        id: perfComp
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            tip: "CPU governor"
            accent: leftZone.host.cpuGovernor === "performance" ? Theme.barDim : Theme.danger
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PERF"
                color: leftZone.host.cpuGovernor === "performance" ? Theme.barFaint : Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.bold: leftZone.host.cpuGovernor !== "performance"
            }
        }
    }

    // ── раскладка (клик — переключить) ──
    Component {
        id: layoutComp
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: Theme.barDim
            tip: "Раскладка — переключить"
            onClicked: leftZone.host.switchLayout()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: leftZone.host.kbLayout
                color: Theme.barText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(14)
                font.bold: true
            }
        }
    }
}
