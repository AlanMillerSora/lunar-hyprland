import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarOverview — живой обзор девяти столов (идея как в ArchEclipse).
//  Карточки столов с настоящими миниатюрами окон (ScreencopyView),
//  окно перетаскивается мышью на другой стол -> window.move.
//  ЛКМ по окну — фокус, СКМ — закрыть, клик по пустой карточке —
//  перейти на стол, Esc/клик по фону — закрыть.
//  IPC: qs ipc call overview toggle|open|close
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "lunar-overview"

    mask: Region { item: root.showing ? backdrop : null }

    property bool showing: false
    property int cols: 3
    property int rows: 3
    property real gap: 12
    property real cardW: 360
    readonly property real cardH: cardW * monH / monW
    readonly property real boardW: cols * cardW + (cols - 1) * gap
    readonly property real boardH: rows * cardH + (rows - 1) * gap
    readonly property real scale: cardW / monW

    // монитор: один, DP-2; беру сфокусированный
    readonly property var mon: Hyprland.focusedMonitor
    readonly property real monX: mon ? mon.x : 0
    readonly property real monY: mon ? mon.y : 0
    readonly property real monW: (mon && mon.width > 0) ? mon.width : 3440
    readonly property real monH: (mon && mon.height > 0) ? mon.height : 1440
    readonly property int monId: mon ? mon.id : -1
    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    function openPanel() { showing = true }
    function closePanel() { showing = false }
    function toggle() { if (showing) closePanel(); else openPanel() }

    IpcHandler {
        target: "overview"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    onShowingChanged: {
        if (showing) {
            Theme.activeOverlay = "overview"
            refreshGeo()
        }
    }
    Connections {
        target: Theme
        function onActiveOverlayChanged() {
            if (Theme.activeOverlay !== "overview" && root.showing) root.closePanel()
        }
    }

    // ── геометрия окон: опрос hyprctl clients -j (ключ — адрес) ──
    function normAddr(a) {
        var s = "" + (a || "")
        if (s.indexOf("0x") === 0 || s.indexOf("0X") === 0) s = s.substring(2)
        // только hex: адрес уходит в Lua-строку window.move
        return s.toLowerCase().replace(/[^0-9a-f]/g, "")
    }
    property var winGeo: ({})
    property Process geoProc: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text)
                    var m = {}
                    for (var i = 0; i < arr.length; i++) m[root.normAddr(arr[i].address)] = arr[i]
                    root.winGeo = m
                } catch (e) {}
            }
        }
    }
    function refreshGeo() { geoProc.running = true }
    Timer {
        interval: 1000
        running: root.showing
        repeat: true
        onTriggered: root.refreshGeo()
    }

    // стабильная модель: сами toplevel'ы (не пересоздаются на опросе),
    // геометрию каждый делегат берёт из winGeo по адресу
    readonly property var toplevels: Hyprland.toplevels.values

    // ── края карточек и разрешение попадания ──
    function cardX(ws) { return ((ws - 1) % cols) * (cardW + gap) }
    function cardY(ws) { return Math.floor((ws - 1) / cols) * (cardH + gap) }
    function wsAt(px, py) {
        var col = Math.floor(px / (cardW + gap))
        var row = Math.floor(py / (cardH + gap))
        if (col < 0 || col >= cols || row < 0 || row >= rows) return -1
        return row * cols + col + 1
    }

    // ── действия через Lua-диспетчеры Hyprland ──
    function dsp(expr) { Hyprland.dispatch(expr) }
    function focusWindow(addr) {
        dsp("hl.dsp.focus({window=\"address:0x" + normAddr(addr) + "\"})")
    }
    function closeWindow(addr) {
        dsp("hl.dsp.window.close({window=\"address:0x" + normAddr(addr) + "\"})")
    }
    function focusWorkspace(id) {
        dsp("hl.dsp.focus({workspace=" + id + "})")
        closePanel()
    }
    function moveWindow(fromWs, addr, targetWs) {
        if (targetWs < 1 || targetWs > cols * rows || targetWs === fromWs) return
        dsp("hl.dsp.window.move({workspace=" + targetWs + ", follow=false, window=\"address:0x"
            + normAddr(addr) + "\"})")
    }
    // отпустил перетаскиваемую миниатюру: куда попал — туда и окно
    function finishDrag(fromWs, addr, wrap) {
        var target = -1
        try {
            // tiles выровнен по сетке карточек (board сдвинут на заголовок и
            // отступ), поэтому цель беру в координатах tiles, а не board
            var p = wrap.mapToItem(tiles, wrap.width / 2, wrap.height / 2)
            target = wsAt(p.x, p.y)
        } catch (e) {}
        if (target !== -1 && target !== fromWs)
            moveWindow(fromWs, addr, target)
        // в любом случае возвращаю биндинги позиции: при переносе плитка
        // вскоре сама переедет на новый стол по геометрии, при отмене — на место
        try { wrap.snapBack() } catch (e) {}
        refreshGeo()
    }

    // клик по фону / Esc — закрыть
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: root.showing ? Theme.alpha(Theme.bgPanel, 0.62) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animMed } }
        focus: root.showing
        Keys.onEscapePressed: root.closePanel()

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closePanel()
        }
    }

    // ── доска обзора ──
    Item {
        id: board
        anchors.centerIn: parent
        width: root.boardW + Theme.space6
        height: header.height + Theme.space3 + root.boardH + Theme.space4
        visible: root.showing
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.97
        transformOrigin: Item.Center
        Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
        // клики по промежуткам доски не должны её закрывать
        MouseArea { anchors.fill: parent; onClicked: {} }

        SectionHeader {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: Theme.space1
            text: "ОБЗОР СТОЛОВ"
            textColor: Theme.text
            size: Theme.fontSmall
        }
        Text {
            anchors.left: header.right
            anchors.leftMargin: Theme.space3
            anchors.baseline: header.baseline
            text: "тяни окно на другой стол · ЛКМ фокус · СКМ закрыть"
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(10)
        }

        // карточки столов
        Grid {
            id: grid
            anchors.top: header.bottom
            anchors.topMargin: Theme.space3
            anchors.horizontalCenter: parent.horizontalCenter
            columns: root.cols
            columnSpacing: root.gap
            rowSpacing: root.gap

            Repeater {
                model: root.cols * root.rows

                delegate: Rectangle {
                    id: wsCard
                    required property int modelData
                    readonly property int wid: modelData + 1
                    readonly property bool focused: wsCard.wid === root.focusedId

                    width: root.cardW
                    height: root.cardH
                    radius: Theme.radiusL
                    color: Theme.bgCard
                    border.color: wsCard.focused ? Theme.accent : Theme.border
                    border.width: wsCard.focused ? 2 : 1
                    clip: true

                    // крупный номер стола
                    Text {
                        anchors.centerIn: parent
                        text: wsCard.wid
                        color: Theme.textFaint
                        opacity: 0.35
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(40)
                        font.bold: true
                    }

                    // клик по пустому — перейти на стол
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWorkspace(wsCard.wid)
                    }
                }
            }
        }

        // ── слой миниатюр окон поверх карточек ──
        Item {
            id: tiles
            anchors.top: grid.top
            anchors.left: grid.left
            width: grid.width
            height: grid.height

            Repeater {
                model: root.toplevels

                delegate: Item {
                    id: winWrap
                    required property var modelData

                    readonly property string addr: winWrap.modelData.address || ""
                    readonly property var geo: root.winGeo[root.normAddr(winWrap.addr)] || null
                    readonly property int ws: (winWrap.geo && winWrap.geo.workspace) ? winWrap.geo.workspace.id : -1
                    readonly property bool onThisMon:
                        (winWrap.geo && (winWrap.geo.monitor === undefined || winWrap.geo.monitor === root.monId))
                    readonly property bool shown: root.showing && winWrap.geo !== null
                        && winWrap.ws >= 1 && winWrap.ws <= root.cols * root.rows && winWrap.onThisMon

                    function gx() {
                        if (!winWrap.geo || !winWrap.geo.at) return 0
                        return root.cardX(winWrap.ws)
                            + (winWrap.geo.at[0] - root.monX) * root.scale
                    }
                    function gy() {
                        if (!winWrap.geo || !winWrap.geo.at) return 0
                        return root.cardY(winWrap.ws)
                            + (winWrap.geo.at[1] - root.monY) * root.scale
                    }
                    function gw() {
                        if (!winWrap.geo || !winWrap.geo.size) return 0
                        return Math.max(16, winWrap.geo.size[0] * root.scale)
                    }
                    function gh() {
                        if (!winWrap.geo || !winWrap.geo.size) return 0
                        return Math.max(12, winWrap.geo.size[1] * root.scale)
                    }
                    function snapBack() {
                        winWrap.x = Qt.binding(function() { return winWrap.gx() })
                        winWrap.y = Qt.binding(function() { return winWrap.gy() })
                    }

                    visible: winWrap.shown
                    x: winWrap.gx()
                    y: winWrap.gy()
                    width: winWrap.shown ? winWrap.gw() : 0
                    height: winWrap.shown ? winWrap.gh() : 0
                    z: tile.drag.active ? 1000 : 1

                    ClippingRectangle {
                        id: preview
                        anchors.fill: parent
                        radius: Theme.radiusM
                        color: Theme.bgPanel
                        border.color: tile.hovered ? Theme.accent : Theme.border
                        border.width: 1

                        ScreencopyView {
                            id: cap
                            anchors.fill: parent
                            captureSource: winWrap.modelData.wayland || null
                            // капчу держу только для видимых плиток — иначе
                            // живые захваты всех окон всех столов впустую
                            live: winWrap.shown
                        }

                        // пока кадр не пришёл — название окна
                        Text {
                            anchors.fill: parent
                            anchors.margins: 6
                            visible: !cap.hasContent
                            text: winWrap.geo ? (winWrap.geo.title || "") : ""
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: tile.pressDown ? Theme.active
                                : tile.hovered ? Theme.hover : "transparent"
                        }
                    }

                    MouseArea {
                        id: tile
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        drag.target: winWrap

                        property bool hovered: containsMouse
                        property bool pressDown: false
                        property real pressX: 0
                        property real pressY: 0

                        onPressed: function(m) {
                            if (m.button === Qt.LeftButton) {
                                tile.pressDown = true
                                tile.pressX = m.x
                                tile.pressY = m.y
                            }
                        }
                        onReleased: function(m) {
                            if (m.button !== Qt.LeftButton) return
                            tile.pressDown = false
                            if (!winWrap.shown) return
                            // клик почти без движения не переносит окно (иначе
                            // центром плитки легко попасть в соседний стол)
                            if (Math.abs(m.x - tile.pressX) + Math.abs(m.y - tile.pressY) < 8) {
                                winWrap.snapBack()
                                return
                            }
                            root.finishDrag(winWrap.ws, winWrap.addr, winWrap)
                        }
                        onClicked: function(m) {
                            if (m.button === Qt.LeftButton) {
                                root.focusWindow(winWrap.addr)
                                root.closePanel()
                            } else if (m.button === Qt.MiddleButton) {
                                root.closeWindow(winWrap.addr)
                                root.refreshGeo()
                            }
                        }
                    }
                }
            }
        }
    }
}
