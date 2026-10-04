import QtQuick
import "../"
import "../widgets/shared"

// ════════════════════════════════════════════════════════════════
//  BarSection — настройки бара: состав, порядок и видимость ячеек
//  по зонам (лево/центр/право) + число значков трея. Список чипами
//  со стрелками вверх/вниз (без drag) и сбросом к дефолту (текущий
//  порядок). Всё живёт в BarSettings/bar.json.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    property int rightMargin: 36

    readonly property var zones: [
        { key: "left", name: "ЛЕВО" },
        { key: "center", name: "ЦЕНТР" },
        { key: "right", name: "ПРАВО" }
    ]

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight + Theme.space4
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width - page.rightMargin
            spacing: Theme.space3

            Text {
                text: "БАР"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.bold: true
            }

            Text {
                width: parent.width
                text: "состав, порядок и видимость ячеек. Часы в центре скрыть нельзя — по ним считается центровка строки; двигать можно."
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(10)
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: page.zones

                delegate: ZoneBlock {
                    required property var modelData
                    width: col.width
                    zoneKey: modelData.key
                    zoneName: modelData.name
                }
            }

            // ── значков трея видно ──
            Item {
                width: parent.width
                height: Theme.rowHCompact

                SectionLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ЗНАЧКОВ ТРЕЯ"
                    textColor: Theme.text
                    size: Theme.fontSmall
                    bold: true
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: BarSettings.trayVisible + " видно, остальные — в «+N»"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
            }

            Row {
                spacing: Theme.space2

                Repeater {
                    model: [1, 2, 3, 4, 5, 6, 8, 10]

                    delegate: Rectangle {
                        required property int modelData
                        width: 40
                        height: 30
                        radius: Theme.radius
                        color: BarSettings.trayVisible === modelData
                            ? Theme.active : (trayMa.containsMouse ? Theme.hover : Theme.fill)
                        border.width: 1
                        border.color: BarSettings.trayVisible === modelData
                            ? Theme.accent : Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: BarSettings.trayVisible === modelData ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.bold: BarSettings.trayVisible === modelData
                        }
                        MouseArea {
                            id: trayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BarSettings.trayVisible = modelData
                        }
                    }
                }
            }

            // ── горячие зоны у краёв бара → сайдбары по ховеру ──
            Item {
                width: parent.width
                height: Theme.rowHCompact

                SectionLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ГОРЯЧИЕ ЗОНЫ"
                    textColor: Theme.text
                    size: Theme.fontSmall
                    bold: true
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: BarSettings.hotZone ? "ховер у края раскрывает сайдбар" : "выключено"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
            }

            Row {
                spacing: Theme.space3

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    on: BarSettings.hotZone
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BarSettings.hotZone = !BarSettings.hotZone
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: BarSettings.hotZone ? "ВКЛ" : "ВЫКЛ"
                    color: BarSettings.hotZone ? Theme.accent : Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                    font.bold: true
                }
                Item { width: Theme.space3; height: 1 }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "раскрытие"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
                Repeater {
                    model: [0, 150, 250, 500]
                    delegate: Rectangle {
                        required property int modelData
                        readonly property bool sel: BarSettings.revealIn === modelData
                        width: revInTxt.implicitWidth + 22
                        height: 28
                        radius: Theme.radius
                        color: sel ? Theme.active : (revInMa.containsMouse ? Theme.hover : Theme.fill)
                        border.width: 1
                        border.color: sel ? Theme.accent : Theme.border
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: revInTxt
                            anchors.centerIn: parent
                            text: modelData + "мс"
                            color: sel ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.bold: sel
                        }
                        MouseArea {
                            id: revInMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BarSettings.revealIn = modelData
                        }
                    }
                }
            }

            Row {
                spacing: Theme.space3

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "закрытие"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
                Repeater {
                    model: [300, 600, 900, 1500]
                    delegate: Rectangle {
                        required property int modelData
                        readonly property bool sel: BarSettings.revealOut === modelData
                        width: revOutTxt.implicitWidth + 22
                        height: 28
                        radius: Theme.radius
                        color: sel ? Theme.active : (revOutMa.containsMouse ? Theme.hover : Theme.fill)
                        border.width: 1
                        border.color: sel ? Theme.accent : Theme.border
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: revOutTxt
                            anchors.centerIn: parent
                            text: modelData + "мс"
                            color: sel ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.bold: sel
                        }
                        MouseArea {
                            id: revOutMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BarSettings.revealOut = modelData
                        }
                    }
                }
            }

            // ── тон раскрытия островов (клик по ячейке раскрывает плашку) ──
            Item {
                width: parent.width
                height: Theme.rowHCompact

                SectionLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ТОН РАСКРЫТИЯ"
                    textColor: Theme.text
                    size: Theme.fontSmall
                    bold: true
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "кривая раскрытия плашки"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
            }

            Row {
                spacing: Theme.space2

                Repeater {
                    model: [
                        { id: "standard",   name: "СТАНДАРТ" },
                        { id: "expressive", name: "ВЫРАЗИТЕЛЬНЫЙ" },
                        { id: "emphasized", name: "ПЛАВНЫЙ" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: Theme.islandStyle === modelData.id
                        width: isLabel.implicitWidth + 28
                        height: Theme.rowHCompact
                        radius: Theme.radiusM
                        color: sel ? Theme.active : (isMa.containsMouse ? Theme.hoverStrong : Theme.fill)
                        border.width: sel ? 1 : 0
                        border.color: Theme.accent

                        SectionLabel {
                            id: isLabel
                            anchors.centerIn: parent
                            text: modelData.name
                            textColor: sel ? Theme.accent : Theme.textDim
                            size: Theme.fontSmall
                            bold: sel
                        }

                        MouseArea {
                            id: isMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.islandStyle = modelData.id
                        }
                    }
                }
            }

            ActionButton {
                label: "СБРОСИТЬ ВСЁ"
                minWidth: 150
                onClicked: BarSettings.resetAll()
            }
        }
    }

    // ════════════════════════════════════════════════════════════
    //  ZoneBlock — одна зона: заголовок, сброс и карточка-список
    //  ячеек. zoneKey/zoneName передаю свойствами — так вложенный
    //  Repeater не зависит от modelData внешнего делегата.
    // ════════════════════════════════════════════════════════════
    component ZoneBlock: Column {
        id: zb
        property string zoneKey
        property string zoneName

        // реактивно: изменение любой из трёх зон пересобирает список
        readonly property var items: zoneKey === "left" ? BarSettings.left
                                   : zoneKey === "center" ? BarSettings.center
                                   : BarSettings.right

        spacing: Theme.space2

        function moveItem(id, dir) { BarSettings.move(zb.zoneKey, id, dir) }
        function toggleItem(id) { BarSettings.toggle(zb.zoneKey, id) }

        Item {
            width: parent.width
            height: Theme.rowHCompact

            SectionLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: zb.zoneName
                textColor: Theme.text
                size: Theme.fontSmall
                bold: true
            }
            Text {
                id: resetTxt
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "СБРОС"
                color: resetMa.containsMouse ? Theme.accent : Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                font.letterSpacing: 1
                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BarSettings.resetZone(zb.zoneKey)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: listCol.implicitHeight + 2 * Theme.space2
            radius: Theme.radiusM
            color: Theme.fill
            border.width: 1
            border.color: Theme.border

            Column {
                id: listCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Repeater {
                    model: zb.items

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: listCol.width
                        height: 34
                        radius: Theme.radiusS
                        color: rowHover.hovered ? Theme.hover : "transparent"

                        HoverHandler { id: rowHover }

                        // штрих видимости слева (погашен у скрытых)
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: 14
                            radius: 1
                            color: modelData.visible ? Theme.barDim : "transparent"
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: BarSettings.nameOf(modelData.id)
                                + (BarSettings.isLocked(modelData.id) ? "  ·  закреплено" : "")
                            color: modelData.visible ? Theme.text : Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        // глаз: видимость
                        Text {
                            id: eye
                            anchors.right: upBtn.left
                            anchors.rightMargin: Theme.space3
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.visible ? "\uf06e" : "\uf070"
                            color: BarSettings.isLocked(modelData.id) ? Theme.textFaint
                                 : (eyeMa.containsMouse ? Theme.accent
                                    : (modelData.visible ? Theme.textDim : Theme.textFaint))
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSmall
                            MouseArea {
                                id: eyeMa
                                anchors.fill: parent
                                anchors.margins: -7
                                hoverEnabled: true
                                enabled: !BarSettings.isLocked(modelData.id)
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: zb.toggleItem(modelData.id)
                            }
                        }

                        // вверх
                        Text {
                            id: upBtn
                            anchors.right: downBtn.left
                            anchors.rightMargin: Theme.space2
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf077"
                            color: index > 0
                                ? (upMa.containsMouse ? Theme.accent : Theme.textDim)
                                : Theme.border
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontTiny
                            MouseArea {
                                id: upMa
                                anchors.fill: parent
                                anchors.margins: -7
                                hoverEnabled: true
                                enabled: index > 0
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: zb.moveItem(modelData.id, -1)
                            }
                        }

                        // вниз
                        Text {
                            id: downBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf078"
                            color: index < zb.items.length - 1
                                ? (downMa.containsMouse ? Theme.accent : Theme.textDim)
                                : Theme.border
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontTiny
                            MouseArea {
                                id: downMa
                                anchors.fill: parent
                                anchors.margins: -7
                                hoverEnabled: true
                                enabled: index < zb.items.length - 1
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: zb.moveItem(modelData.id, 1)
                            }
                        }
                    }
                }
            }
        }
    }
}
