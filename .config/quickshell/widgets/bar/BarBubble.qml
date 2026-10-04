import QtQuick
import QtQuick.Effects
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarBubble — компактное превью погоды/медиа для морф-плашки бара.
//  Раньше это был отдельный «пузырь в полке» со своим фоном и
//  позиционированием по ячейке; теперь клик по ячейке раскрывает
//  саму плашку вниз (см. LunarPanel), а это содержимое встраивается
//  в раскрытую плашку. Что рисовать — решает `kind`.
//  Историческое имя оставил, чтобы не плодить сущности.
// ════════════════════════════════════════════════════════════════
Item {
    id: root
    property string kind: ""
    property var host                 // корень LunarPanel (на будущее)

    implicitWidth: inner.width
    implicitHeight: inner.height
    visible: kind !== ""

    // ── содержимое по виду ──
    Item {
        id: inner
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height

        // ПОГОДА: иконка + температура/город/описание + детали
        Item {
            visible: root.kind === "weather"
            width: 380
            height: wxCol.height
            Column {
                id: wxCol
                width: parent.width
                spacing: Theme.space2
            Row {
                width: parent.width
                spacing: Theme.space3
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.ok ? Weather.icon : "\uf185"
                    color: Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconXL
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: Weather.ok ? Weather.temp : "—"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBig
                        font.bold: true
                    }
                    Text {
                        text: Weather.city !== "" ? Weather.city : "определяю город…"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }
                    Text {
                        text: Weather.ok ? Weather.descRu : "нет данных"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border2 }
            Row {
                width: parent.width
                spacing: Theme.space3
                Repeater {
                    model: [
                        { label: "ОЩУЩ", v: Weather.feels },
                        { label: "ВЛАЖН", v: Weather.hum },
                        { label: "ВЕТЕР", v: Weather.wind }
                    ]
                    delegate: Column {
                        required property var modelData
                        spacing: 1
                        SectionHeader { text: modelData.label; size: Theme.fontMicro; textColor: Theme.textFaint }
                        Text {
                            text: Weather.ok ? modelData.v : "—"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                        }
                    }
                }
            }
            }
        }

        // МЕДИА: обложка + трек + транспорт + прогресс
        Row {
            visible: root.kind === "media"
            spacing: Theme.space3

            // обложка (монохром, как в баре/плеере)
            Rectangle {
                width: 56
                height: 56
                radius: Theme.radius
                color: Theme.fill
                border.width: 1
                border.color: Theme.border
                clip: true

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: MediaCore.art
                    sourceSize: Qt.size(112, 112)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                Image {
                    anchors.fill: parent
                    visible: false
                    source: Qt.resolvedUrl("../../assets/logo.svg")
                }
                Text {
                    anchors.centerIn: parent
                    visible: artImg.status !== Image.Ready || MediaCore.art === ""
                    text: "\uf001"
                    color: Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(22)
                }
                MultiEffect {
                    anchors.fill: parent
                    visible: artImg.status === Image.Ready && MediaCore.art !== ""
                    source: artImg
                    saturation: -1.0
                    brightness: 0.15
                    contrast: 0.06
                }
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 240
                height: mediaCol.height
                Column {
                    id: mediaCol
                    width: parent.width
                    spacing: Theme.space1

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: MediaCore.title !== "" ? MediaCore.title : "—"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: MediaCore.artist !== "" ? MediaCore.artist : "неизвестный исполнитель"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }

                // транспорт: prev · play/pause · next
                Row {
                    spacing: Theme.space3
                    Text {
                        text: "\uf048"
                        color: MediaCore.player && MediaCore.player.canGoPrevious
                            ? (prevMa.containsMouse ? Theme.accent : Theme.textDim) : Theme.textFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(14)
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (MediaCore.player && MediaCore.player.canGoPrevious) MediaCore.player.previous()
                        }
                    }
                    Text {
                        text: MediaCore.playing ? "\uf04c" : "\uf04b"
                        color: playMa.containsMouse ? Theme.accent : Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(16)
                        MouseArea {
                            id: playMa
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (MediaCore.player) MediaCore.player.togglePlaying()
                        }
                    }
                    Text {
                        text: "\uf051"
                        color: MediaCore.player && MediaCore.player.canGoNext
                            ? (nextMa.containsMouse ? Theme.accent : Theme.textDim) : Theme.textFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(14)
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (MediaCore.player && MediaCore.player.canGoNext) MediaCore.player.next()
                        }
                    }
                }

                // прогресс
                Item {
                    width: parent.width
                    height: 10
                    visible: MediaCore.len > 0
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 3
                        radius: 1.5
                        color: Theme.trackBg

                        Rectangle {
                            width: parent.width * MediaCore.progress
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                            Behavior on width { Anim { type: Anim.FastEffects } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (m) => MediaCore.seekFrac(m.x / width)
                        }
                    }
                }
                Row {
                    width: parent.width
                    Text {
                        text: MediaCore.fmt(MediaCore.pos)
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMicro
                    }
                    Item { width: parent.width - 60; height: 1 }
                    Text {
                        text: MediaCore.len > 0 ? MediaCore.fmt(MediaCore.len) : "--:--"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMicro
                    }
                }
                }
            }
        }
    }
}
