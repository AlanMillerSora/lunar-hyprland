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
                accent: SysInfo.hot ? Theme.danger : Theme.barDim
                tip: "Телеметрия"
                onClicked: BarState.togglePanel("sys")
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space3
                    Repeater {
                        // фиксированный model: 3 — иначе JS-массив с SysInfo.*
                        // пересобирался на каждом замере и пересоздавал делегаты
                        model: 3
                        delegate: Row {
                            required property int index
                            readonly property string label: index === 0 ? "CPU" : (index === 1 ? "RAM" : "GPU")
                            readonly property int v: index === 0 ? SysInfo.cpu : (index === 1 ? SysInfo.ram : SysInfo.gpu)
                            readonly property bool avail: index !== 2 || SysInfo.gpu >= 0
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: label
                                color: Theme.barFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(10)
                                font.letterSpacing: 1
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (avail && v >= 0) ? (v + "%") : "--"
                                color: (avail && v >= 90) ? Theme.danger : Theme.barText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                            }
                            MiniBar {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 5
                                barColor: v >= 90 ? Theme.danger : Theme.accent
                                value: avail ? v : -1
                            }
                        }
                    }
                }
            }
