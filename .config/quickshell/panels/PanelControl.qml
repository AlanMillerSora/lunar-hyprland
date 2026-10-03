import QtQuick
import QtQuick.Layouts
import ".."
import "../widgets/shared"

        Item {
            property var host
            id: ctlBody
            visible: BarState.mode === "control"
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
                                id: stateRow
                                required property var modelData
                                width: parent.width
                                height: 36
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radius
                                    color: stateMouse.containsMouse ? Theme.hover : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }
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
                                        visible: modelData.act === "power"
                                        text: "\u203a"
                                        color: stateMouse.containsMouse ? Theme.text : Theme.textFaint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                    }
                                    Toggle {
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: modelData.act !== "power"
                                        on: modelData.on
                                        danger: modelData.danger
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
                                tip: modelData.label
                                onClicked: {
                                    if (modelData.act === "hub")
                                        host.openHub()
                                    else if (modelData.act === "wall")
                                        host.openWallpapers()
                                    else if (modelData.act === "search")
                                        BarState.openPanel("search")
                                    else if (modelData.act === "sys")
                                        BarState.openPanel("sys")
                                }
                            }
                        }
                    }

                    SectionLabel { text: "ТЕЛЕМЕТРИЯ" }

                    Card {
                        width: parent.width
                        Repeater {
                            // фиксированный model: 3 — иначе JS-массив с SysInfo.*
                            // пересобирался на каждом замере и пересоздавал MetricRow
                            model: 3
                            delegate: MetricRow {
                                required property int index
                                width: parent.width
                                label: index === 0 ? "CPU" : (index === 1 ? "RAM" : "GPU")
                                value: index === 0 ? SysInfo.cpu : (index === 1 ? SysInfo.ram : SysInfo.gpu)
                                extra: index === 0
                                    ? (SysInfo.cpuTemp > 0 ? (SysInfo.cpuTemp + "°C") : "")
                                    : (index === 1
                                        ? (SysInfo.ramTotal > 0 ? (SysInfo.ramTotal + " МБ") : "")
                                        : (SysInfo.gpuTemp >= 0 ? (SysInfo.gpuTemp + "°C") : ""))
                            }
                        }
                    }
                }
            }
        }
