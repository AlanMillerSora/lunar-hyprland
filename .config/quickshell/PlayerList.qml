import QtQuick

// ════════════════════════════════════════════════════════════════
//  PlayerList — плотная таблица строк плеера (очередь / поиск /
//  фонотека). Колонки: номер [номер], название+подпись, длительность
//  справа и иконка-действие. Разметку задаёт вызывающий функциями
//  titleFor/subtitleFor/rightTextFor/rightIconFor; клики уходят
//  сигналами activated/rightClicked. Текущий трек — highlightIndex.
//  При reorderable=true строки тащатся (drag за порогом 8px).
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property var model: []
    property string emptyText: "пусто"
    property int rowHeight: 46
    property int highlightIndex: -1
    // показывать колонку с номером строки
    property bool numbered: false
    property bool showRight: true
    // тащу строки за собой: включаю только там, где порядок имеет смысл
    property bool reorderable: false

    // состояние перетаскивания: откуда тащу, куда целюсь, идёт ли драг
    property bool dragActive: false
    property int dragFrom: -1
    property int dragTarget: -1
    // драг только что закончился — грядущий clicked() это не активация
    property bool justDragged: false

    // слоты разметки: (item, index) → текст/иконка
    property var titleFor: function(item, index) { return "" }
    property var subtitleFor: function(item, index) { return "" }
    property var rightTextFor: function(item, index) { return "" }
    property var rightIconFor: function(item, index) { return "" }
    // ведущий глиф строки (вместо обложки) — пусто, если не нужен
    property var iconFor: function(item, index) { return "" }

    signal activated(int index)
    signal rightClicked(int index)
    // перетащил строку from на место to — что делать, решает вызывающий
    signal reordered(int from, int to)

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: root.model
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 400
        maximumFlickVelocity: 2400

        WheelHandler {
            onWheel: function(event) {
                if (event.angleDelta.y === 0)
                    return
                list.contentY = Math.max(0,
                    Math.min(list.contentHeight - list.height,
                             list.contentY - event.angleDelta.y))
                event.accepted = true
            }
        }

        // модель пересобралась (duration/media-title пересобирают очередь) —
        // перетаскивание становится невалидным, снимаю его
        Connections {
            target: list
            function onCountChanged() {
                root.dragActive = false
                root.dragFrom = -1
                root.dragTarget = -1
            }
        }
        Connections {
            target: root
            function onModelChanged() {
                root.dragActive = false
                root.dragFrom = -1
                root.dragTarget = -1
            }
        }

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index

            width: list.width
            height: root.rowHeight
            radius: 0

            readonly property bool current: index === root.highlightIndex
            readonly property bool lifting: root.dragActive && root.dragFrom === index

            color: lifting
                ? Theme.hoverStrong
                : (current ? Theme.active
                           : (rowMouse.containsMouse ? Theme.hover : "transparent"))
            border.width: (current || lifting) ? 1 : 0
            border.color: Theme.activeBorder

            z: lifting ? 2 : 0

            property bool appeared: false
            opacity: appeared ? 1 : 0
            Component.onCompleted: appeared = true
            Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            // ── ведущая «обложка» (квадрат) ──
            Rectangle {
                id: leadingIcon
                visible: root.iconFor(modelData, index) !== ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                width: 28
                height: 28
                radius: 0
                color: Theme.bgCard
                border.width: 1
                border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    text: root.iconFor(modelData, index)
                    color: row.current ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(13)
                }
            }

            // ── номер строки ──
            Text {
                visible: root.numbered
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12 + (leadingIcon.visible ? 36 : 0)
                width: 24
                text: row.current ? "▸" : (index + 1)
                color: row.current ? Theme.accent : Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.bold: row.current
            }

            // ── название + подпись ──
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12 + (leadingIcon.visible ? 36 : 0) + (root.numbered ? 30 : 0)
                anchors.right: rightArea.left
                anchors.rightMargin: 10
                spacing: 2

                Text {
                    width: parent.width
                    text: root.titleFor(modelData, index)
                    color: row.current ? Theme.text : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.subtitleFor(modelData, index)
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // ── длительность + действие ──
            Row {
                id: rightArea
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 12
                spacing: 14

                Text {
                    id: rightHit
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showRight && root.rightTextFor(modelData, index) !== ""
                    text: root.rightTextFor(modelData, index)
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }

                Text {
                    id: actionHit
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showRight && root.rightIconFor(modelData, index) !== ""
                    text: root.rightIconFor(modelData, index)
                    color: rightMouse.containsMouse ? Theme.danger : Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(12)
                }
            }

            // клик по строке — поверх мыши строки, но ниже правой кнопки.
            // Тут же живой драг: ход меньше 8px — это клик, иначе тащу строку.
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                anchors.rightMargin: rightArea.width + 18
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                property real pressY: 0

                onPressed: (mouse) => {
                    root.dragActive = false
                    root.dragFrom = -1
                    root.dragTarget = -1
                    root.justDragged = false
                    pressY = mouse.y
                }

                onPositionChanged: (mouse) => {
                    if (!root.reorderable)
                        return
                    if (!root.dragActive && Math.abs(mouse.y - pressY) < 8)
                        return
                    if (!root.dragActive) {
                        root.dragActive = true
                        root.dragFrom = index
                    }
                    if (root.dragFrom !== index)
                        return
                    var inList = list.mapFromItem(row, 0, mouse.y)
                    var contentY = list.contentY + inList.y
                    var step = root.rowHeight + list.spacing
                    var t = Math.round((contentY - root.rowHeight / 2) / step)
                    root.dragTarget = Math.max(0, Math.min(list.count - 1, t))
                }

                onReleased: (mouse) => {
                    if (!root.dragActive || root.dragFrom !== index)
                        return
                    var to = root.dragTarget
                    root.dragActive = false
                    root.dragFrom = -1
                    root.dragTarget = -1
                    root.justDragged = true
                    if (to >= 0 && to !== index)
                        root.reordered(index, to)
                }

                onClicked: {
                    if (root.justDragged) {
                        root.justDragged = false
                        return
                    }
                    root.activated(index)
                }
            }

            MouseArea {
                id: rightMouse
                anchors.centerIn: actionHit
                width: Math.max(28, actionHit.width + 16)
                height: 28
                enabled: actionHit.visible
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.rightClicked(index)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 40
        visible: !root.model || root.model.length === 0
        text: root.emptyText
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize(12)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
