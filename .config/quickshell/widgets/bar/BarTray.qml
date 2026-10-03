import QtQuick
import QtQuick.Effects
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarTray — значки трея в баре (монохром), лишние — плашкой «+N».
//  Вынесено из LunarPanel (host = корень).
// ════════════════════════════════════════════════════════════════
            Item {
                property var host
                anchors.verticalCenter: parent.verticalCenter
                // место ровно под видимые значки (не под весь лимит); при
                // переполнении добавляю ещё и ширину плашки «+N»
                implicitWidth: {
                    var vis = Math.min(host.trayCount, host.trayMax)
                    return vis * 20 + Math.max(0, vis - 1) * 9
                        + (host.trayCount > host.trayMax ? moreBox.width + 9 : 0)
                }
                implicitHeight: Theme.barCellH

                scale: trayBg.hovered ? Theme.hoverGrow : 1
                Behavior on scale { Anim { type: Anim.FastSpatial } }
                HoverBg { id: trayBg; visible: host.trayCount > 0 }

                Row {
                    id: trayRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: Theme.barCellH
                    spacing: 9

                    Repeater {
                        model: host.trayItems

                        delegate: Item {
                            required property var modelData
                            width: 20
                            height: Theme.barCellH

                            Image {
                                id: trayImg
                                anchors.centerIn: parent
                                source: host.trayIconSource(modelData)
                                sourceSize.width: 18
                                sourceSize.height: 18
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                                visible: false
                            }

                            // монохром: значок трея в тон панели (как иконки лаунчера),
                            // чтобы цветные логи приложений не пестрили в баре
                            MultiEffect {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: trayImg
                                visible: trayImg.source != "" && trayImg.status !== Image.Error
                                saturation: -1.0
                                brightness: 0.12
                                contrast: 0.08
                            }

                            // если у приложения нет иконки — точка-фолбэк
                            Text {
                                anchors.centerIn: parent
                                visible: !(trayImg.source != "" && trayImg.status !== Image.Error)
                                text: "\uf111"
                                color: Theme.barFaint
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(8)
                            }

                            MouseArea {
                                id: trayIconMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function (m) {
                                    if (m.button === Qt.MiddleButton) {
                                        modelData.secondaryActivate()
                                    } else if (m.button === Qt.RightButton) {
                                        host.trayMenu(modelData, trayIconMouse, m.x, m.y)
                                    } else if (host.isSteamApp(modelData)) {
                                        host.openTrayApp(modelData)
                                    } else if (modelData.onlyMenu && modelData.hasMenu) {
                                        host.trayMenu(modelData, trayIconMouse, m.x, m.y)
                                    } else {
                                        modelData.activate()
                                    }
                                }
                            }
                        }
                    }

                    // сколько значков не влезло — открыть список
                    Rectangle {
                        id: moreBox
                        visible: host.trayCount > host.trayMax
                        width: moreText.implicitWidth + 20
                        height: 24
                        radius: Theme.radius
                        anchors.verticalCenter: parent.verticalCenter
                        color: moreMouse.containsMouse ? Theme.active : "transparent"
                        border.width: 1
                        border.color: moreMouse.containsMouse ? Theme.accent : Theme.borderAccent

                        Text {
                            id: moreText
                            anchors.centerIn: parent
                            text: "+" + (host.trayCount - host.trayMax)
                            color: moreMouse.containsMouse ? Theme.accent : Theme.barDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.bold: true
                        }

                        MouseArea {
                            id: moreMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: host.openTrayPanel()
                        }
                    }
                }
            }
