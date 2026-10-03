import QtQuick
import QtQuick.Layouts
import ".."
import "../widgets/shared"

        Column {
            property var host
            id: sysBody
            visible: BarState.mode === "sys"
            opacity: host.panelContentOpacity
            anchors.top: parent.top
            anchors.topMargin: Theme.panelHeaderH + Theme.space2
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.barPad * 2
            spacing: Theme.space2

            Row {
                width: parent.width
                spacing: Theme.space2
                Repeater {
                    // фиксированный model: 3 — JS-массив с SysInfo.* пересобирался
                    // на каждом замере и пересоздавал Card/Sparkline (Canvas)
                    model: 3
                    delegate: Card {
                        required property int index
                        readonly property string label: index === 0 ? "CPU" : (index === 1 ? "RAM" : "GPU")
                        readonly property int v: index === 0 ? SysInfo.cpu : (index === 1 ? SysInfo.ram : SysInfo.gpu)
                        readonly property var hist: index === 0 ? SysInfo.cpuHist : (index === 1 ? SysInfo.ramHist : SysInfo.gpuHist)
                        readonly property string extra: index === 0
                            ? (SysInfo.cpuTemp > 0 ? (SysInfo.cpuTemp + "°C") : "")
                            : (index === 1
                                ? (SysInfo.ramTotal > 0 ? (SysInfo.ramTotal + " МБ") : "")
                                : (SysInfo.gpuTemp >= 0 ? (SysInfo.gpuTemp + "°C") : ""))
                        width: (parent.width - Theme.space2 * 2) / 3
                        contentMargins: 12
                        contentSpacing: 6
                        SectionLabel { text: label }
                        RowLayout {
                            width: parent.width
                            spacing: Theme.space1
                            Text {
                                Layout.alignment: Qt.AlignBottom
                                text: v < 0 ? "--" : (v + "%")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBig
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true; implicitHeight: 1 }
                            Text {
                                Layout.alignment: Qt.AlignBottom
                                text: extra
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                        Sparkline {
                            width: parent.width
                            height: 26
                            values: hist
                            lineColor: v >= 90 ? Theme.danger : Theme.accent
                        }
                    }
                }
            }

            Card {
                width: parent.width
                SectionLabel { text: "СЕТЬ" }
                Row {
                    width: parent.width
                    spacing: Theme.space4
                    Text {
                        text: "↓ " + SysInfo.fmtRate(SysInfo.rx)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }
                    Text {
                        text: "↑ " + SysInfo.fmtRate(SysInfo.tx)
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }
                }
            }
        }
