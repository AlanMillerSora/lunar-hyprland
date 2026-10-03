import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarLeftZone — левая зона бара: марка LUNAR + фазы столов и
//  PERF/раскладка. Раньше это были две отдельные плашки (leftBar +
//  midBar), теперь одна зона; host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Item {
    id: leftZone
    property var host

    implicitWidth: leftRow.implicitWidth + 2 * Theme.barPad
    implicitHeight: Theme.barH
    clip: true

    Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPad
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: Theme.space3

        // марка LUNAR + фаза активного стола
        Row {
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.barCellH
            spacing: Theme.space2

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 21
                height: 21
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
                font.pixelSize: Theme.fontSize(14)
                font.letterSpacing: 1.5
            }
        }

        // рабочие столы — компонент widgets/bar/BarWorkspaces
        BarWorkspaces { anchors.verticalCenter: parent.verticalCenter; host: leftZone.host }

        // PERF: governor; штрих белый на performance, danger — если уехал
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            tip: "CPU governor"
            accent: leftZone.host.cpuGovernor === "performance" ? Theme.barDim : Theme.danger
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PERF"
                color: leftZone.host.cpuGovernor === "performance" ? Theme.barFaint : Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.bold: leftZone.host.cpuGovernor !== "performance"
            }
        }

        // раскладка (клик — переключить)
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
                font.pixelSize: Theme.fontSize(13)
                font.bold: true
            }
        }
    }
}
