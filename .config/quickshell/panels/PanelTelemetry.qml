import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."
import "../widgets/shared"

        Column {
            property var host
            property string diskText: "…"
            property string sysText: "…"
            id: sysBody
            visible: BarState.mode === "sys"
            opacity: host.panelContentOpacity
            anchors.top: parent.top
            anchors.topMargin: Theme.panelHeaderH + Theme.space1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.barPad * 2
            spacing: Theme.space2

            Item {
                width: parent.width
                height: metricsRow.height

                // architect: вертикальные разделители колонок
                Rectangle {
                    visible: Theme.arch
                    width: Theme.line
                    height: parent.height
                    color: Theme.hairAccent
                    x: (parent.width - Theme.space2) / 3 + Theme.space2 / 2
                }
                Rectangle {
                    visible: Theme.arch
                    width: Theme.line
                    height: parent.height
                    color: Theme.hairAccent
                    x: 2 * (parent.width - Theme.space2) / 3 + Theme.space2 * 1.5
                }

            Row {
                id: metricsRow
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
                        SectionHeader { text: label }
                        RowLayout {
                            width: parent.width
                            spacing: Theme.space1
                            Text {
                                Layout.alignment: Qt.AlignBottom
                                text: v < 0 ? "--" : (Theme.arch ? "[ " + v + "% ]" : (v + "%"))
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
                                font.pixelSize: Theme.fontTiny
                            }
                        }
                        Sparkline {
                            width: parent.width
                            height: Theme.sparkH
                            values: hist
                            lineColor: v >= 90 ? Theme.danger : Theme.accent
                        }
                    }
                }
            }
            }

            Card {
                width: parent.width
                SectionHeader { text: "СЕТЬ" }
                Row {
                    width: parent.width
                    spacing: Theme.space4
                    Text {
                        text: (Theme.arch ? "[ ↓ " : "↓ ") + SysInfo.fmtRate(SysInfo.rx)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }
                    Text {
                        text: "↑ " + SysInfo.fmtRate(SysInfo.tx) + (Theme.arch ? " ]" : "")
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }
                }
            }

            Hairline { width: parent.width }

            Card {
                width: parent.width
                SectionHeader { text: "ДИСКИ" }
                Text {
                    width: parent.width
                    text: sysBody.diskText
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    lineHeight: 1.35
                }
            }

            Hairline { width: parent.width }

            Card {
                width: parent.width
                SectionHeader { text: "СИСТЕМА" }
                Text {
                    width: parent.width
                    text: sysBody.sysText
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    lineHeight: 1.35
                }
            }

            Process {
                id: diskProc
                command: ["bash", "-c",
                    "df -h / /home --output=source,used,size,pcent 2>/dev/null | tail -n +2"]
                stdout: StdioCollector { onStreamFinished: sysBody.diskText = text.trim() }
            }
            Process {
                id: sysInfoProc
                command: ["bash", "-c",
                    "uptime -p 2>/dev/null; awk '{print \"load \"$1\" \"$2\" \"$3}' /proc/loadavg 2>/dev/null; free -h 2>/dev/null | awk '/Mem:/{print \"ram \"$3\"/\"$2} /Swap:/{print \"swap \"$3\"/\"$2}'"]
                stdout: StdioCollector { onStreamFinished: sysBody.sysText = text.trim() }
            }
            Timer {
                interval: 5000
                repeat: true
                running: sysBody.visible
                onTriggered: {
                    diskProc.running = true
                    sysInfoProc.running = true
                }
            }
        }
