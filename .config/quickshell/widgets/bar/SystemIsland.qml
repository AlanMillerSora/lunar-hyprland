import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  SystemIsland — систем-остров бара: мини-полосы CPU · RAM · GPU.
//  Источник — eclipse-status.sh (опрос раз в 3 с, GPU из кэша на 10 с).
//  Клик открывает «Телеметрию». Вынесено из LunarPanel (host = корень).
// ════════════════════════════════════════════════════════════════
            Cell {
                property var host
                id: sysCell
                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                accent: host.teleHot ? Theme.danger : Theme.barDim
                tip: "Телеметрия"
                onClicked: BarState.togglePanel("sys")
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space3
                    Repeater {
                        model: [
                            { label: "CPU", v: host.teleCpu, avail: true },
                            { label: "RAM", v: host.teleRam, avail: true },
                            { label: "GPU", v: host.teleGpu, avail: host.teleGpu >= 0 }
                        ]
                        delegate: Row {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: Theme.barFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.letterSpacing: 1
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (modelData.avail && modelData.v >= 0) ? (modelData.v + "%") : "--"
                                color: (modelData.avail && modelData.v >= 90) ? Theme.danger : Theme.barText
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                            MiniBar {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 4
                                barColor: modelData.v >= 90 ? Theme.danger : Theme.accent
                                value: modelData.avail ? modelData.v : -1
                            }
                        }
                    }
                }
            }
