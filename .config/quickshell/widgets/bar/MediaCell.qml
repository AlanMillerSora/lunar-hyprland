import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  MediaCell — медиа-ячейка бара: трек, play/pause, мини-спектр cava;
//  клик открывает медиа-панель. Вынесено из LunarPanel (host = корень).
// ════════════════════════════════════════════════════════════════
            Rectangle {
                property var host
                id: mediaInline
                visible: host.mediaActive
                anchors.verticalCenter: parent.verticalCenter
                width: mediaCol.width + Theme.space3 * 2 + 8
                height: Theme.barCellH
                radius: Theme.radiusS
                color: mediaHover.hovered ? Theme.hoverStrong : Theme.fill
                // мягкий пульс при смене трека
                property SequentialAnimation trackPulse: SequentialAnimation {
                    NumberAnimation {
                        target: mediaInline; property: "scale"; to: 1.15
                        duration: Theme.animMed / 2; easing.type: Theme.easeOut
                    }
                    NumberAnimation {
                        target: mediaInline; property: "scale"; to: 1.0
                        duration: Theme.animMed / 2; easing.type: Theme.easeOut
                    }
                }
                property Connections trackWatch: Connections {
                    target: host
                    // только пульс: медиа-попап сам не раскрываю (мешает)
                    function onTrackChanged() { if (host.pulsePrimed) mediaInline.trackPulse.restart() }
                }

                HoverHandler { id: mediaHover }

                AppTooltip {
                    visible: mediaHover.hovered
                    text: "Медиа — открыть панель"
                }

                // штрих-акцент слева
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 14
                    radius: 1
                    color: host.playing ? Theme.accent : Theme.barFaint
                }

                Column {
                    id: mediaCol
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 168
                    spacing: 1

                    Row {
                        width: parent.width
                        height: 12
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: host.playing ? "\uf04c" : "\uf04b"
                            color: host.playing ? Theme.accent : Theme.barFaint
                            font.family: Theme.iconFont
                            font.pixelSize: 10
                        }
                        Text {
                            width: parent.width - 16
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: host.track
                            color: Theme.barText
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    // нижний ряд — мини-спектр cava
                    Row {
                        width: parent.width
                        height: 9
                        spacing: 2
                        Repeater {
                            model: 14
                            delegate: Item {
                                required property int index
                                width: 2
                                height: 9
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 2 + (host.barValues[index] || 0) * 7
                                    radius: 1
                                    color: Theme.alpha(Theme.accent, 0.35 + 0.65 * (host.barValues[index] || 0))
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BarState.togglePanel("media")
                }
            }
