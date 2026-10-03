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
                    model: [
                        { label: "CPU", v: SysInfo.cpu,
                          extra: SysInfo.cpuTemp > 0 ? (SysInfo.cpuTemp + "°C") : "" },
                        { label: "RAM", v: SysInfo.ram,
                          extra: SysInfo.ramTotal > 0 ? (SysInfo.ramTotal + " МБ") : "" },
                        { label: "GPU", v: SysInfo.gpu,
                          extra: SysInfo.gpuTemp >= 0 ? (SysInfo.gpuTemp + "°C") : "" }
                    ]
                    delegate: Card {
                        required property var modelData
                        width: (parent.width - Theme.space2 * 2) / 3
                        contentMargins: 12
                        contentSpacing: 6
                        SectionLabel { text: modelData.label }
                        RowLayout {
                            width: parent.width
                            spacing: Theme.space1
                            Text {
                                Layout.alignment: Qt.AlignBottom
                                text: modelData.v < 0 ? "--" : (modelData.v + "%")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBig
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true; implicitHeight: 1 }
                            Text {
                                Layout.alignment: Qt.AlignBottom
                                text: modelData.extra
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                        MiniBar {
                            width: parent.width
                            height: 5
                            value: modelData.v
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
