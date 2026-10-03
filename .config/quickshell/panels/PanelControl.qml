import QtQuick
import QtQuick.Layouts
import ".."
import "../widgets/shared"

        Item {
            property var host
            id: ctlBody
            visible: host.panelMode === "control"
            opacity: host.panelContentOpacity
            anchors.top: parent.top
            anchors.topMargin: Theme.panelHeaderH
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.space3 * 2
            implicitHeight: ctlCol.height
            height: implicitHeight

            Row {
                id: ctlCol
                width: parent.width
                spacing: Theme.space3

                // ===== ЛЕВАЯ КОЛОНКА: звук + состояние =====
                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: Theme.space2

                    SectionLabel { text: "ЗВУК" }

                    Card {
                        width: parent.width

                        // вывод
                        Column {
                            width: parent.width
                            spacing: Theme.space1
                            RowLayout {
                                width: parent.width
                                spacing: Theme.space2
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: host.muted ? "\uf026" : (host.vol < 0.34 ? "\uf027" : "\uf028")
                                    color: host.muted ? Theme.danger : Theme.accent
                                    font.family: Theme.iconFont
                                    font.pixelSize: 15
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: host.toggleMute()
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "ВЫВОД"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 2
                                }
                                Item { Layout.fillWidth: true; implicitHeight: 1 }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: host.muted ? "mute" : Math.round(host.vol * 100) + "%"
                                    color: host.muted ? Theme.textFaint : Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }
                            Slider {
                                width: parent.width
                                height: 18
                                compact: true
                                trackHeight: 5
                                handleSize: 13
                                value: host.muted ? 0 : host.vol
                                onMoved: (v) => host.setVol(v)
                                onCommitted: (v) => host.setVol(v)
                                WheelHandler {
                                    onWheel: (ev) => host.bumpVol(ev.angleDelta.y > 0 ? 0.05 : -0.05)
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: Theme.border }

                        // микрофон
                        Column {
                            width: parent.width
                            spacing: Theme.space1
                            RowLayout {
                                width: parent.width
                                spacing: Theme.space2
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: host.micMuted ? "\uf131" : "\uf130"
                                    color: host.micMuted ? Theme.danger : Theme.accent
                                    font.family: Theme.iconFont
                                    font.pixelSize: 15
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: host.toggleMicMute()
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "МИКРОФОН"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 2
                                }
                                Item { Layout.fillWidth: true; implicitHeight: 1 }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: host.micMuted ? "off" : Math.round(host.micVol * 100) + "%"
                                    color: host.micMuted ? Theme.textFaint : Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }
                            Slider {
                                width: parent.width
                                height: 18
                                compact: true
                                trackHeight: 5
                                handleSize: 13
                                value: host.micMuted ? 0 : host.micVol
                                onMoved: (v) => host.setMicVol(v)
                                onCommitted: (v) => host.setMicVol(v)
                                WheelHandler {
                                    onWheel: (ev) => host.bumpMic(ev.angleDelta.y > 0 ? 0.05 : -0.05)
                                }
                            }
                        }
                    }

                    SectionLabel { text: "СОСТОЯНИЕ" }

                    Card {
                        width: parent.width
                        Repeater {
                            model: [
                                { g: "\uf11b", label: "ИГРА",    on: host.gameMode,  danger: false, act: "game" },
                                { g: "\uf111", label: "ЗАПИСЬ",  on: host.recording, danger: true,  act: "rec" },
                                { g: "\uf011", label: "ПИТАНИЕ", on: false,          danger: false, act: "power" }
                            ]
                            delegate: Item {
                                required property var modelData
                                width: parent.width
                                height: 30
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: modelData.g
                                        color: modelData.on ? (modelData.danger ? Theme.danger : Theme.accent)
                                            : (stateMouse.containsMouse ? Theme.text : Theme.textDim)
                                        font.family: Theme.iconFont
                                        font.pixelSize: 15
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: modelData.label
                                        color: modelData.on ? Theme.text : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }
                                    Item { Layout.fillWidth: true; implicitHeight: 1 }
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: modelData.act === "power" ? "\u203a"
                                            : (modelData.on ? "ВКЛ" : "ВЫКЛ")
                                        color: modelData.on ? (modelData.danger ? Theme.danger : Theme.accent)
                                            : Theme.textFaint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.letterSpacing: 1
                                    }
                                }
                                MouseArea {
                                    id: stateMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.act === "game")
                                            host.toggleGameMode()
                                        else if (modelData.act === "rec")
                                            host.toggleRecording()
                                        else if (modelData.act === "power")
                                            host.openPower()
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== ПРАВАЯ КОЛОНКА: действия + телеметрия =====
                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: Theme.space2

                    SectionLabel { text: "ДЕЙСТВИЯ" }

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: Theme.space2
                        rowSpacing: Theme.space2
                        Repeater {
                            model: [
                                { g: "\uf009", label: "HUB",        act: "hub" },
                                { g: "\uf03e", label: "ОБОИ",       act: "wall" },
                                { g: "\uf002", label: "ПОИСК",      act: "search" },
                                { g: "\uf080", label: "ТЕЛЕМЕТРИЯ", act: "sys" }
                            ]
                            delegate: ActionTile {
                                required property var modelData
                                width: (parent.width - parent.columnSpacing) / 2
                                height: 48
                                glyph: modelData.g
                                label: modelData.label
                                onClicked: {
                                    if (modelData.act === "hub")
                                        host.openHub()
                                    else if (modelData.act === "wall")
                                        host.openWallpapers()
                                    else if (modelData.act === "search")
                                        host.openPanel("search")
                                    else if (modelData.act === "sys")
                                        host.openPanel("sys")
                                }
                            }
                        }
                    }

                    SectionLabel { text: "ТЕЛЕМЕТРИЯ" }

                    Card {
                        width: parent.width
                        Repeater {
                            model: [
                                { label: "CPU", v: host.teleCpu,
                                  extra: host.teleCpuTemp > 0 ? (host.teleCpuTemp + "°C") : "" },
                                { label: "RAM", v: host.teleRam,
                                  extra: host.teleRamTotal > 0 ? (host.teleRamTotal + " МБ") : "" },
                                { label: "GPU", v: host.teleGpu,
                                  extra: host.teleGpuTemp >= 0 ? (host.teleGpuTemp + "°C") : "" }
                            ]
                            delegate: Row {
                                required property var modelData
                                width: parent.width
                                height: 22
                                spacing: Theme.space2
                                Text {
                                    width: 40
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    font.letterSpacing: 1
                                }
                                Text {
                                    width: 42
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.v < 0 ? "--" : (modelData.v + "%")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    font.bold: true
                                }
                                MiniBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 40 - 42 - 60 - spacing * 3
                                    value: modelData.v
                                }
                                Text {
                                    width: 60
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.extra
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                }
                            }
                        }
                    }
                }
            }
        }
