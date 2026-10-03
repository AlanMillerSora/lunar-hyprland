import QtQuick

// ════════════════════════════════════════════════════════════════
//  PlayerList — переиспользуемый прокручиваемый список строк для
//  плеера (очередь / поиск / фонотека). Разметку строки задаёт
//  вызывающий через функции-слоты titleFor/subtitleFor/rightIconFor;
//  клики уходят сигналами activated/rightClicked. Текущий трек
//  подсвечивается через highlightIndex. Появление строк — мягкое.
//  При reorderable=true строки тащатся: за порогом 8px поднимаю
//  выбранную и по отпусканию шлю reordered(from, to).
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property var model: []
    property string emptyText: "пусто"
    property int rowHeight: 46
    property int highlightIndex: -1
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
    property var rightIconFor: function(item, index) { return "" }

    signal activated(int index)
    signal rightClicked(int index)
    // перетащил строку from на место to — что делать, решает вызывающий
    signal reordered(int from, int to)

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: root.model
        spacing: 3
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
        // длина могла не измениться — ловлю и переподстановку модели
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
            radius: Theme.radius

            readonly property bool current: index === root.highlightIndex
            // строку поднял курсором — приподнимаю её над соседями
            readonly property bool lifting: root.dragActive && root.dragFrom === index

            color: lifting
                ? Theme.hoverStrong
                : (current ? Theme.active
                           : (rowMouse.containsMouse ? Theme.hover : "transparent"))
            border.width: (current || lifting) ? 1 : 0
            border.color: Theme.activeBorder

            // поднятая строка выше остальных и чуть крупнее — «взял в руку»
            z: lifting ? 2 : 0
            scale: lifting ? 1.02 : 1.0

            // мягкое появление новых строк (у переиспользованных делегатов
            // Component.onCompleted повторно не срабатывает — не мигают)
            property bool appeared: false
            opacity: appeared ? 1 : 0
            Component.onCompleted: appeared = true
            Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOut } }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: rightHit.left
                anchors.rightMargin: 10
                spacing: 3

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
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // правый слот (крестик очереди, «+» поиска)
            Text {
                id: rightHit
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 12
                visible: root.showRight && root.rightIconFor(modelData, index) !== ""
                text: root.rightIconFor(modelData, index)
                color: rightMouse.containsMouse ? Theme.danger : Theme.textFaint
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(12)
            }

            // клик по строке — поверх мыши строки, но ниже правой кнопки.
            // Тут же живой драг: ход меньше 8px — это клик, иначе тащу строку.
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                anchors.rightMargin: rightHit.visible ? rightHit.width + 18 : 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                property real pressY: 0

                onPressed: (mouse) => {
                    // самолечение: если прошлый драг оборвался на пересборке
                    // модели, состояние могло залипнуть — сбрасываю
                    root.dragActive = false
                    root.dragFrom = -1
                    root.dragTarget = -1
                    root.justDragged = false
                    pressY = mouse.y
                }

                onPositionChanged: (mouse) => {
                    if (!root.reorderable)
                        return
                    // порог: мелкое дрожание остаётся кликом
                    if (!root.dragActive && Math.abs(mouse.y - pressY) < 8)
                        return
                    if (!root.dragActive) {
                        root.dragActive = true
                        root.dragFrom = index
                    }
                    if (root.dragFrom !== index)
                        return
                    // цель считаю по курсору в содержимом списка: contentY уже
                    // сдвинул делегат, а rowHeight + spacing задают шаг строки
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
                    // драг кончился — гашу грядущий clicked, это не активация
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
                anchors.centerIn: rightHit
                width: Math.max(28, rightHit.width + 16)
                height: 28
                enabled: rightHit.visible
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
