import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarTasks — список дел отдельным layer-оверлеем (PanelWindow).
//  По мотивам 43PR: панель перетаскивается за «ручку» сверху,
//  масштабируется кнопками −/+ (60…200%), позиция и размер живут
//  рядом с задачами в ~/.config/lunar/todo.json. Ввод многострочный:
//  Enter — добавить, Shift+Enter — новая строка. Задачи правятся
//  прямо в карточке, чекбокс зачёркивает, × удаляет.
//  IPC:  qs ipc call tasks toggle|open|close
//  Хоткей: SUPER + Z
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    // ── состояние панели ──
    property bool showing: false
    property bool dragging: false
    property int remaining: 0

    // масштаб 60…200% и смещение от правого-верхнего угла (переживают рестарт)
    property int menuSize: 100
    property real offsetX: 0
    property real offsetY: 0

    readonly property int defaultSize: 100
    readonly property real ui: menuSize / 100
    readonly property int baseWidth: 440
    readonly property int baseRow: Theme.rowHComfy
    readonly property int maxItems: 200
    // панель открывается под баром, у правого края
    readonly property int topGap: Theme.barH + Theme.barTop + Theme.space2
    readonly property int sideGap: Theme.space3
    readonly property int cardWidth: Math.round(baseWidth * ui)
    readonly property int rowHeight: Math.round(baseRow * ui)
    readonly property bool movedFromDefault: offsetX !== 0 || offsetY !== 0 || menuSize !== defaultSize

    // ── файл: todo.json (как bar.json/record.json) ──
    property bool ready: false
    property bool writeBlocked: false
    property bool pendingWrite: false

    readonly property string stateDir: Quickshell.env("HOME") + "/.config/lunar"
    readonly property string statePath: stateDir + "/todo.json"

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lunar-tasks"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // прозрачный оверлей ловит ввод только когда панель открыта
    mask: Region { item: root.showing ? menuRoot : null }

    ListModel { id: todos }

    // ── масштаб и позиция ──
    function px(n) { return Math.round(n * ui) }

    function setSize(v) {
        menuSize = Math.max(60, Math.min(200, Math.round(v)))
        scheduleSave()
    }

    function setPosition(x, y) {
        if (root.width <= 0 || root.height <= 0) {
            offsetX = x
            offsetY = y
            return
        }
        // offsetX=0 — прижат к правому краю; тянем вправо — уходим за край
        var maxX = sideGap
        var minX = Math.min(maxX, cardWidth + 2 * sideGap - root.width)
        var minY = 0
        var maxY = Math.max(minY, root.height - panel.height - 2 * topGap)
        offsetX = Math.max(minX, Math.min(maxX, x))
        offsetY = Math.max(minY, Math.min(maxY, y))
        scheduleSave()
    }

    function resetPosition() {
        offsetX = 0
        offsetY = 0
        menuSize = defaultSize
        scheduleSave()
    }

    // ── модель ──
    function recount() {
        var n = 0
        for (var i = 0; i < todos.count; i++)
            if (!todos.get(i).done)
                n++
        remaining = n
    }

    function addTodo(t) {
        var s = ("" + t).replace(/^\s+|\s+$/g, "")
        if (s === "" || todos.count >= maxItems)
            return
        todos.insert(0, { title: s, done: false })
        recount()
        scheduleSave()
    }

    function editTodo(i, t) {
        if (i < 0 || i >= todos.count)
            return
        todos.setProperty(i, "title", t)
        scheduleSave()
    }

    function toggleTodo(i) {
        if (i < 0 || i >= todos.count)
            return
        todos.setProperty(i, "done", !todos.get(i).done)
        recount()
        scheduleSave()
    }

    function removeTodo(i) {
        if (i < 0 || i >= todos.count)
            return
        todos.remove(i)
        recount()
        scheduleSave()
    }

    function clearDone() {
        for (var i = todos.count - 1; i >= 0; i--)
            if (todos.get(i).done)
                todos.remove(i)
        recount()
        scheduleSave()
    }

    // ── сохранение с дебаунсом (drag пишет десятки раз в секунду) ──
    function scheduleSave() {
        if (writeBlocked)
            return
        pendingWrite = true
        saveTimer.restart()
    }

    function saveNow() {
        if (!ready || writeBlocked)
            return
        var out = []
        for (var i = 0; i < todos.count; i++) {
            var e = todos.get(i)
            out.push({ title: e.title, done: e.done })
        }
        adapter.items = out
        adapter.menuSize = menuSize
        adapter.offsetX = offsetX
        adapter.offsetY = offsetY
        pendingWrite = false
        file.writeAdapter()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: root.saveNow()
    }

    // ── открытие/закрытие ──
    function openPanel() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr)
                root.screen = scr
        }
        dragging = false
        showing = true
        Qt.callLater(function () {
            if (root.showing) {
                input.forceActiveFocus()
                root.setPosition(root.offsetX, root.offsetY)
            }
        })
    }

    function closePanel() {
        showing = false
        dragging = false
    }
    function toggle() { showing ? closePanel() : openPanel() }

    IpcHandler {
        target: "tasks"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    // ── файл ──
    FileView {
        id: file
        path: root.statePath
        // Файл читаю один раз на старте, дальше владею им сам: watchChanges
        // гонял бы reload после каждой нашей записи, а adopt() пересобирал бы
        // ListModel и рвал правку/фокус (модель — источник, не адаптер).
        atomicWrites: true

        onLoaded: {
            // адаптер о битом JSON молчит, поэтому читаю и разбираю текст сам;
            // модель наполняю из данных файла (JsonAdapter — буфер записи).
            var raw = file.text()
            var data = null
            var healthy = true
            if (raw && raw.trim() !== "") {
                try {
                    data = JSON.parse(raw)
                } catch (e) {
                    healthy = false
                }
            }
            if (!healthy) {
                root.writeBlocked = true
                root.ready = true
                console.warn("[LunarTasks] todo.json повреждён — не перезаписываю, копия .bak")
                Quickshell.execDetached(["cp", "-f", file.path, file.path + ".bak"])
                return
            }
            root.ready = true
            root.writeBlocked = false
            root.adopt(data)
            if (root.pendingWrite)
                saveTimer.restart()
        }

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                // первого файла нет — создаю каталог и пустой список
                Quickshell.execDetached(["mkdir", "-p", root.stateDir])
                root.ready = true
                root.pendingWrite = false
                file.writeAdapter()
            } else {
                root.writeBlocked = true
                root.ready = true
                console.warn("[LunarTasks] todo.json не прочитан: " + FileViewError.toString(error))
                Quickshell.execDetached(["cp", "-f", file.path, file.path + ".bak"])
            }
        }

        JsonAdapter {
            id: adapter
            property var items: []
            property int menuSize: 100
            property real offsetX: 0
            property real offsetY: 0
        }
    }

    // прочитанное из файла → модель и геометрия панели
    function adopt(data) {
        if (writeBlocked)
            return
        if (!data || typeof data !== "object")
            data = {}
        todos.clear()
        var arr = Array.isArray(data.items) ? data.items : []
        for (var i = 0; i < arr.length && i < maxItems; i++) {
            if (arr[i] && typeof arr[i].title === "string")
                todos.append({ title: arr[i].title, done: arr[i].done === true })
        }
        menuSize = Math.max(60, Math.min(200, Math.round(Number(data.menuSize) || defaultSize)))
        offsetX = Number(data.offsetX) || 0
        offsetY = Number(data.offsetY) || 0
        recount()
    }

    // ── мелкие кнопки подвала ──
    component FooterButton: Rectangle {
        id: fb
        property string label: ""
        property int fontSize: Theme.fontSmall
        readonly property bool hovered: fbArea.containsMouse
        signal clicked()

        width: Math.round(26 * root.ui)
        height: width
        radius: Theme.radius
        color: fb.hovered ? Theme.hoverStrong : Theme.fill
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text: fb.label
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(fb.fontSize * root.ui)
            color: fb.hovered ? Theme.text : Theme.textDim
        }

        MouseArea {
            id: fbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fb.clicked()
        }
    }

    component SizeBtn: Text {
        signal clicked()
        width: 18
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        color: sizeHover.hovered ? Theme.text : Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Item {
        id: menuRoot
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.closePanel()

        // клик мимо панели — закрыть
        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }

        Rectangle {
            id: panel
            width: root.cardWidth
            height: panelCol.height + root.px(Theme.space4)
            radius: Theme.radiusL
            color: Theme.surfacePanel
            border.width: 1
            border.color: Theme.border

            anchors.top: parent.top
            anchors.topMargin: root.topGap + root.offsetY
            anchors.right: parent.right
            anchors.rightMargin: root.sideGap - root.offsetX

            opacity: root.showing ? 1 : 0
            visible: opacity > 0

            Behavior on anchors.rightMargin {
                enabled: !root.dragging && root.showing
                NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
            }
            Behavior on anchors.topMargin {
                enabled: !root.dragging && root.showing
                NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOut }
            }

            onHeightChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)

            // ловлю клики внутри панели, чтобы не сработал «клик мимо»
            MouseArea { anchors.fill: parent }

            HudNodes { inset: 6; size: 4 }
            HudInnerFrame { variant: 1 }
            HudDiagonals {}
            HudCorners { color: Theme.accent; size: 14; thickness: 1; margin: 8 }

            Column {
                id: panelCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: root.px(Theme.space3)
                spacing: root.px(Theme.space2)

                // ── «ручка» перетаскивания ──
                Item {
                    id: dragStrip
                    width: parent.width
                    height: root.px(14)

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.px(38)
                        height: root.px(4)
                        radius: root.px(2)
                        color: Theme.text
                        opacity: (dragArea.containsMouse || root.dragging) ? 0.9 : 0.15
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        property real pressX: 0
                        property real pressY: 0
                        property real startX: 0
                        property real startY: 0

                        onPressed: function (mouse) {
                            var p = dragArea.mapToItem(menuRoot, mouse.x, mouse.y)
                            pressX = p.x
                            pressY = p.y
                            startX = root.offsetX
                            startY = root.offsetY
                            root.dragging = true
                        }
                        onPositionChanged: function (mouse) {
                            if (!root.dragging)
                                return
                            var p = dragArea.mapToItem(menuRoot, mouse.x, mouse.y)
                            root.setPosition(startX + (p.x - pressX), startY + (p.y - pressY))
                        }
                        onReleased: {
                            if (!root.dragging)
                                return
                            root.dragging = false
                            root.scheduleSave()
                        }
                        onCanceled: {
                            if (!root.dragging)
                                return
                            root.dragging = false
                            root.scheduleSave()
                        }
                        onDoubleClicked: root.resetPosition()
                    }
                }

                // ── шапка ──
                RowLayout {
                    width: parent.width
                    spacing: Theme.space2

                    SectionHeader {
                        text: "ЗАДАЧИ"
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.remaining + " / " + todos.count
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: root.px(Theme.fontMicro)
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        id: closeBtn
                        text: "✕"
                        color: closeMouse.containsMouse ? Theme.danger : Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: root.px(Theme.fontSmall)
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closePanel()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.dividerLine
                }

                // ── ввод ──
                Rectangle {
                    width: parent.width
                    height: Math.max(root.rowHeight, input.contentHeight + root.px(Theme.space4))
                    radius: Theme.radiusM
                    color: Theme.bgCard
                    border.width: 1
                    border.color: input.activeFocus ? Theme.accent : Theme.border
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    Rectangle {
                        id: addThumb
                        width: root.px(30)
                        height: width
                        radius: Theme.radius
                        anchors.left: parent.left
                        anchors.leftMargin: root.px(Theme.space2)
                        anchors.top: parent.top
                        anchors.topMargin: root.px(Theme.space2)
                        color: addArea.containsMouse ? Theme.accent : "transparent"
                        border.width: 1
                        border.color: Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.family: Theme.fontFamily
                            font.pixelSize: root.px(Theme.fontBody)
                            color: addArea.containsMouse ? Theme.onAccent : Theme.accent
                        }

                        MouseArea {
                            id: addArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.addTodo(input.text)
                                input.text = ""
                                input.forceActiveFocus()
                            }
                        }
                    }

                    TextEdit {
                        id: input
                        anchors.left: addThumb.right
                        anchors.leftMargin: root.px(Theme.space2)
                        anchors.right: parent.right
                        anchors.rightMargin: root.px(Theme.space3)
                        anchors.top: parent.top
                        anchors.topMargin: root.px(Theme.space2)
                        font.family: Theme.fontFamily
                        font.pixelSize: root.px(Theme.fontSmall)
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        textFormat: TextEdit.PlainText

                        Keys.onPressed: function (e) {
                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                e.accepted = true
                                if (e.modifiers & Qt.ShiftModifier) {
                                    input.insert(input.cursorPosition, "\n")
                                } else {
                                    root.addTodo(input.text)
                                    input.text = ""
                                }
                            } else if (e.key === Qt.Key_Escape) {
                                e.accepted = true
                                root.closePanel()
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            visible: input.text === "" && !input.inputMethodComposing
                            text: "добавить задачу…  (Shift+Enter — строка)"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: root.px(Theme.fontSmall)
                        }
                    }
                }

                Text {
                    visible: todos.count === 0
                    width: parent.width
                    height: root.px(36)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "задач нет"
                    font.family: Theme.fontFamily
                    font.pixelSize: root.px(Theme.fontTiny)
                    color: Theme.textFaint
                }

                // ── список карточек ──
                ListView {
                    id: list
                    visible: todos.count > 0
                    width: parent.width
                    // длинный список прокручивается, а не вылезает за экран
                    height: Math.max(0, Math.min(contentHeight,
                        root.height - root.topGap - root.offsetY - root.px(260)))
                    clip: true
                    spacing: root.px(Theme.space2)
                    model: todos
                    boundsBehavior: Flickable.StopAtBounds

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"; from: 0; to: 1
                            duration: Theme.animMed; easing.type: Theme.easeOut
                        }
                        NumberAnimation {
                            property: "scale"; from: 0.96; to: 1
                            duration: Theme.animMed; easing.type: Theme.easeOut
                        }
                    }
                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"; to: 0
                            duration: Theme.animFast; easing.type: Theme.easeOut
                        }
                    }
                    displaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: Theme.animMed; easing.type: Theme.easeOut
                        }
                    }

                    delegate: Rectangle {
                        id: entry
                        required property int index
                        required property string title
                        required property bool done

                        width: list.width
                        height: Math.max(root.rowHeight, edit.contentHeight + root.px(Theme.space4))
                        radius: Theme.radiusM
                        color: Theme.cardBg
                        border.width: 1
                        border.color: edit.activeFocus ? Theme.accent : Theme.border
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                        HoverHandler { id: cardHover }

                        // квадратный чекбокс
                        Rectangle {
                            id: check
                            width: root.px(20)
                            height: width
                            radius: Theme.radiusTile
                            anchors.left: parent.left
                            anchors.leftMargin: root.px(Theme.space3)
                            anchors.top: parent.top
                            anchors.topMargin: root.px(Theme.space3)
                            color: entry.done ? Theme.accent : "transparent"
                            border.width: 1
                            border.color: entry.done ? Theme.accent : Theme.borderAccent
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                visible: entry.done
                                text: "✓"
                                font.family: Theme.fontFamily
                                font.pixelSize: root.px(Theme.fontTiny)
                                font.bold: true
                                color: Theme.onAccent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleTodo(entry.index)
                            }
                        }

                        // многострочный текст — правится на месте
                        TextEdit {
                            id: edit
                            anchors.left: check.right
                            anchors.leftMargin: root.px(Theme.space3)
                            anchors.right: delBtn.left
                            anchors.rightMargin: root.px(Theme.space2)
                            anchors.top: parent.top
                            anchors.topMargin: root.px(Theme.space3)
                            font.family: Theme.fontFamily
                            font.pixelSize: root.px(Theme.fontSmall)
                            font.strikeout: entry.done
                            color: entry.done ? Theme.textFaint : Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.onAccent
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            textFormat: TextEdit.PlainText

                            Component.onCompleted: edit.text = entry.title

                            onTextChanged: {
                                if (edit.activeFocus)
                                    root.editTodo(entry.index, edit.text)
                            }

                            Keys.onPressed: function (e) {
                                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    e.accepted = true
                                    if (e.modifiers & Qt.ShiftModifier) {
                                        edit.insert(edit.cursorPosition, "\n")
                                    } else {
                                        input.forceActiveFocus()
                                    }
                                } else if (e.key === Qt.Key_Escape) {
                                    e.accepted = true
                                    root.closePanel()
                                }
                            }
                        }

                        Item {
                            id: delBtn
                            width: root.px(22)
                            height: width
                            anchors.right: parent.right
                            anchors.rightMargin: root.px(Theme.space2)
                            anchors.top: parent.top
                            anchors.topMargin: root.px(Theme.space3)

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.family: Theme.fontFamily
                                font.pixelSize: root.px(Theme.fontBody)
                                color: delArea.containsMouse ? Theme.danger : Theme.textFaint
                                opacity: (cardHover.hovered || delArea.containsMouse) ? 1 : 0.35
                                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                            }

                            MouseArea {
                                id: delArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeTodo(entry.index)
                            }
                        }
                    }
                }

                // ── подвал: масштаб, сброс, убрать готовые ──
                Item {
                    width: parent.width
                    height: root.px(26)

                    Row {
                        id: sizeRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.px(2)

                        HoverHandler { id: sizeHover }
                        opacity: sizeHover.hovered ? 0.9 : 0.4
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                        SizeBtn { text: "−"; onClicked: root.setSize(root.menuSize - 10) }
                        SizeBtn { text: "+"; onClicked: root.setSize(root.menuSize + 10) }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.remaining + " открытых · " + todos.count + " всего"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: root.px(Theme.fontMicro)
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.px(Theme.space2)

                        FooterButton {
                            label: "↺"
                            fontSize: Theme.fontBody
                            opacity: root.movedFromDefault ? 1 : 0.4
                            onClicked: root.resetPosition()
                        }
                        FooterButton {
                            label: "✓"
                            fontSize: Theme.fontSmall
                            opacity: (todos.count - root.remaining) > 0 ? 1 : 0.4
                            onClicked: root.clearDone()
                        }
                    }
                }
            }
        }
    }
}
