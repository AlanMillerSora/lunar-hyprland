import QtQuick
import "../"

// ════════════════════════════════════════════════════════════════
//  SegmentedPage — вкладка Hub из нескольких разделов-сегментов.
//  items: [{ label, src }] — подписи и файлы-компоненты разделов.
//  Разделы создаются лениво (при первом выборе) и живут до конца
//  сессии; видимость раздела = выбранный сегмент и открытый Hub —
//  по ней разделы гасят свои таймеры-поллинг.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    property var items: []
    property int segment: 0
    // какие сегменты уже созданы (первый — сразу)
    property var segVisited: [true]

    function selectSegment(i) {
        if (i < 0 || i >= page.items.length)
            return
        page.segment = i
        if (page.segVisited[i] !== true) {
            var v = page.segVisited.slice()
            v[i] = true
            page.segVisited = v
        }
    }

    Column {
        anchors.fill: parent
        spacing: 12

        // ── переключатель разделов ──
        Row {
            spacing: 8

            Repeater {
                model: page.items

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: 120
                    height: 32
                    radius: Theme.radius
                    color: page.segment === index
                        ? Theme.active
                        : (segMouse.containsMouse ? Theme.hover : "transparent")
                    border.width: 1
                    border.color: page.segment === index ? Theme.accent : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: page.segment === index ? Theme.accent : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: page.segment === index
                    }

                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.selectSegment(index)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // ── содержимое выбранного раздела ──
        Item {
            width: parent.width
            height: parent.height - y
            clip: true

            Repeater {
                model: page.items

                delegate: Loader {
                    required property var modelData
                    required property int index

                    anchors.fill: parent
                    active: page.segVisited[index] === true
                    source: active ? modelData.src : ""

                    onItemChanged: if (item)
                        item.visible = Qt.binding(function() {
                            return index === page.segment && page.visible
                        })
                }
            }
        }
    }
}
