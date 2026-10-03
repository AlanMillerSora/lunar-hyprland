import QtQuick
import QtQuick.Layouts
import ".."
import "../widgets/shared"

        Column {
            property var host
            id: wxBody
            visible: BarState.mode === "weather"
            opacity: host.panelContentOpacity
            anchors.top: parent.top
            anchors.topMargin: Theme.panelHeaderH + Theme.space2
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.barPad * 2
            spacing: Theme.space2

            // сейчас
            Card {
                width: parent.width
                contentMargins: 14
                Row {
                    width: parent.width
                    spacing: Theme.space4

                    // иконка в подложке
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56
                        height: 56
                        radius: Theme.radius
                        color: Theme.fill
                        border.width: 1
                        border.color: Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: Weather.ok ? Weather.icon : "\uf185"
                            color: Theme.accent
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconXL
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: Weather.ok ? Weather.temp : "—"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHero
                            font.bold: true
                        }
                        Text {
                            text: Weather.city !== "" ? Weather.city : "определяю город…"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }
                        Text {
                            text: Weather.ok ? Weather.descRu : "нет данных — проверь сеть"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                        }
                    }
                }
            }

            // детали
            Row {
                width: parent.width
                spacing: Theme.space2
                Repeater {
                    model: [
                        { label: "ОЩУЩАЕТСЯ", v: Weather.feels },
                        { label: "ВЛАЖНОСТЬ", v: Weather.hum },
                        { label: "ВЕТЕР", v: Weather.wind }
                    ]
                    delegate: Card {
                        required property var modelData
                        width: (parent.width - Theme.space2 * 2) / 3
                        contentMargins: 10
                        contentSpacing: 2
                        SectionLabel {
                            text: modelData.label
                            size: Theme.fontMicro
                        }
                        Text {
                            text: Weather.ok ? modelData.v : "—"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }
            }

            // прогноз на дни
            Card {
                width: parent.width
                visible: Weather.forecast.length > 0
                SectionLabel { text: "ПРОГНОЗ" }
                Row {
                    width: parent.width
                    spacing: Theme.space2
                    Repeater {
                        model: Weather.forecast
                        delegate: Column {
                            required property var modelData
                            width: (parent.width - Theme.space2 * 2) / 3
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTiny
                                font.letterSpacing: 1
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: Theme.accent
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(18)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.max + "° / " + modelData.min + "°"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                            }
                        }
                    }
                }
            }
        }
