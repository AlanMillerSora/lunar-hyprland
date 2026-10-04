import QtQuick
import QtQuick.Layouts
import ".."
import "../widgets/shared"

        // ── Пульт в arch-стиле: две колонки — слева звук (вывод + микрофон)
        //  карточками, справа сетка состояний (игра/запись/питание) и ряд
        //  действий. Плотные surface-подложки, без «плит» во всю ширину. ──
        Item {
            property var host
            id: ctlBody
            visible: BarState.mode === "control"
            opacity: host.panelContentOpacity
            anchors.top: parent.top
            anchors.topMargin: Theme.panelHeaderH
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.space3 * 2
            implicitHeight: ctlRow.height
            height: implicitHeight

            Row {
                id: ctlRow
                width: parent.width
                spacing: Theme.space3

                // ── левая колонка: звук ──
                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: Theme.space3

                    // вывод
                    Card {
                        width: parent.width
                        contentMargins: 14
                        contentSpacing: 8
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
                                    font.pixelSize: Theme.fontSize(17)
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
                        width: parent.width
                        contentMargins: 14
                        contentSpacing: 8
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
                                    font.pixelSize: Theme.fontSize(17)
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

                // ── правая колонка: состояния + действия ──
                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: Theme.space3

                    // состояния 2×2 (игра / запись / питание / телеметрия)
                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: Theme.space2
                        rowSpacing: Theme.space2
                        Repeater {
                            model: [
                                { g: "\uf11b", label: "ИГРА",   on: host.gameMode,  act: "game" },
                                { g: "\uf111", label: "ЗАПИСЬ", on: host.recording, act: "rec" },
                                { g: "\uf011", label: "ПИТАНИЕ", on: false,         act: "power" },
                                { g: "\uf080", label: "ТЕЛЕМЕТРИЯ", on: false,      act: "sys" }
                            ]
                            delegate: ActionTile {
                                required property var modelData
                                width: (parent.width - parent.columnSpacing) / 2
                                height: 46
                                glyph: modelData.g
                                glyphSize: Theme.fontSize(18)
                                label: modelData.label
                                active: modelData.on
                                activeColor: modelData.act === "rec" ? Theme.danger : Theme.accent
                                tip: modelData.label
                                onClicked: {
                                    if (modelData.act === "game")
                                        host.toggleGameMode()
                                    else if (modelData.act === "rec")
                                        host.toggleRecording()
                                    else if (modelData.act === "power")
                                        host.openPower()
                                    else if (modelData.act === "sys")
                                        BarState.openPanel("sys")
                                }
                            }
                        }
                    }

                    // ряд действий: hub / обои / поиск
                    Row {
                        width: parent.width
                        spacing: Theme.space2
                        Repeater {
                            model: [
                                { g: "\uf009", label: "HUB",   act: "hub" },
                                { g: "\uf03e", label: "ОБОИ",  act: "wall" },
                                { g: "\uf002", label: "ПОИСК", act: "search" }
                            ]
                            delegate: ActionTile {
                                required property var modelData
                                width: (parent.width - parent.spacing * 2) / 3
                                height: 46
                                glyph: modelData.g
                                glyphSize: Theme.fontSize(18)
                                label: modelData.label
                                tip: modelData.label
                                onClicked: {
                                    if (modelData.act === "hub")
                                        host.openHub()
                                    else if (modelData.act === "wall")
                                        host.openWallpapers()
                                    else if (modelData.act === "search")
                                        BarState.openPanel("search")
                                }
                            }
                        }
                    }
                }
            }
        }
