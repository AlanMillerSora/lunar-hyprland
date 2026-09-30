import QtQuick

// ════════════════════════════════════════════════════════════════
//  PlayerList — переиспользуемый прокручиваемый список строк для
//  плеера (очередь / поиск / фонотека). Разметку строки задаёт
//  вызывающий через функции-слоты titleFor/subtitleFor/rightIconFor;
//  клики уходят сигналами activated/rightClicked. Текущий трек
//  подсвечивается через highlightIndex. Появление строк — мягкое.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property var model: []
    property string emptyText: "пусто"
    property int rowHeight: 46
    property int highlightIndex: -1
    property bool showRight: true

    // слоты разметки: (item, index) → текст/иконка
    property var titleFor: function(item, index) { return "" }
    property var subtitleFor: function(item, index) { return "" }
    property var rightIconFor: function(item, index) { return "" }

    signal activated(int index)
    signal rightClicked(int index)

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

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index

            width: list.width
            height: root.rowHeight
            radius: Theme.radius

            readonly property bool current: index === root.highlightIndex

            color: current
                ? Theme.active
                : (rowMouse.containsMouse ? Theme.hover : "transparent")
            border.width: current ? 1 : 0
            border.color: Theme.alpha(Theme.accent, 0.45)

            // мягкое появление новых строк (у переиспользованных делегатов
            // Component.onCompleted повторно не срабатывает — не мигают)
            property bool appeared: false
            opacity: appeared ? 1 : 0
            Component.onCompleted: appeared = true
            Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

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

            // клик по строке — поверх мыши строки, но ниже правой кнопки
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                anchors.rightMargin: rightHit.visible ? rightHit.width + 18 : 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activated(index)
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
