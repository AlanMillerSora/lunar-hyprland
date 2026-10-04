import QtQuick
import QtQuick.Layouts
import ".."
import "../widgets/shared"

        // ── Пульт: приборная панель. Три яруса на всю ширину ──
        //  1) крупные плитки состояний (игра/запись/питание);
        //  2) две карточки звука в ряд (вывод · микрофон);
        //  3) ряд действий (hub/обои/поиск/телеметрия).
        //  Телеметрию сюда не кладу — она уже в систем-острове бара.
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

            Column {
                id: ctlCol
                width: parent.width
                spacing: Theme.space3

                // ── ярус 1: крупные плитки состояний ──
                Row {
                    width: parent.width
                    spacing: Theme.space2

                    Repeater {
                        model: [
                            { g: "\uf11b", label: "ИГРА",    on: host.gameMode,  danger: false, act: "game" },
                            { g: "\uf111", label: "ЗАПИСЬ",  on: host.recording, danger: true,  act: "rec" },
                            { g: "\uf011", label: "ПИТАНИЕ", on: false,          danger: false, act: "power" }
                        ]
                        delegate: Rectangle {
                            id: stateTile
                            required property var modelData
                            readonly property bool lit: modelData.on
                            readonly property color litColor: modelData.danger ? Theme.danger : Theme.accent

                            width: (ctlCol.width - ctlCol.spacing * 2) / 3
                            height: 64
                            radius: Theme.radiusM
                            color: stateTile.lit
                                ? Theme.alpha(stateTile.litColor, 0.16)
                                : (stateMouse.containsMouse ? Theme.hoverStrong : Theme.fill)
                            border.width: 1
                            border.color: stateTile.lit
                                ? Theme.alpha(stateTile.litColor, 0.5)
                                : (stateMouse.containsMouse ? Theme.borderAccent : Theme.border)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.space1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: stateTile.modelData.g
                                    color: stateTile.lit ? stateTile.litColor
                                        : (stateMouse.containsMouse ? Theme.text : Theme.textDim)
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.fontSize(22)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: stateTile.modelData.label
                                    color: stateTile.lit ? Theme.text : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    font.bold: true
                                    font.letterSpacing: 2
                                }
                            }

                            MouseArea {
                                id: stateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (stateTile.modelData.act === "game")
                                        host.toggleGameMode()
                                    else if (stateTile.modelData.act === "rec")
                                        host.toggleRecording()
                                    else if (stateTile.modelData.act === "power")
                                        host.openPower()
                                }
                            }
                        }
                    }
                }

                // ── ярус 2: звук — две карточки в ряд ──
                Row {
                    width: parent.width
                    spacing: Theme.space3

                    // вывод
                    Card {
                        width: (parent.width - parent.spacing) / 2
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
                                    font.pixelSize: Theme.fontSize(16)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: host.toggleMute()
                                    }
                                }
                                SectionLabel {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "ВЫВОД"
                                    textColor: Theme.textDim
                                }
                                Item { Layout.fillWidth: true; implicitHeight: 1 }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: host.muted ? "mute" : Math.round(host.vol * 100) + "%"
                                    color: host.muted ? Theme.textFaint : Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                    font.bold: true
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
                    }

                    // микрофон
                    Card {
                        width: (parent.width - parent.spacing) / 2
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
                                    font.pixelSize: Theme.fontSize(16)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: host.toggleMicMute()
                                    }
                                }
                                SectionLabel {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "МИКРОФОН"
                                    textColor: Theme.textDim
                                }
                                Item { Layout.fillWidth: true; implicitHeight: 1 }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: host.micMuted ? "off" : Math.round(host.micVol * 100) + "%"
                                    color: host.micMuted ? Theme.textFaint : Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                    font.bold: true
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
                }

                // ── ярус 3: действия одной строкой ──
                Row {
                    width: parent.width
                    spacing: Theme.space2

                    Repeater {
                        model: [
                            { g: "\uf009", label: "HUB",        act: "hub" },
                            { g: "\uf03e", label: "ОБОИ",       act: "wall" },
                            { g: "\uf002", label: "ПОИСК",      act: "search" },
                            { g: "\uf080", label: "ТЕЛЕМЕТРИЯ", act: "sys" }
                        ]
                        delegate: ActionTile {
                            required property var modelData
                            width: (ctlCol.width - ctlCol.spacing * 3) / 4
                            height: Theme.rowHComfy
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
            }
        }
