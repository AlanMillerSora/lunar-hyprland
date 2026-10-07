pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// ════════════════════════════════════════════════════════════════
//  LunarWheel — радиальное меню быстрых действий (по мотивам
//  Wheel у 43PR). PanelWindow слоя Overlay: прозрачный фон во весь
//  экран + mask, по центру — кольцо секторов-иконок на Shapes.
//  Наведение/стрелки выбирают сектор, клик или Enter выполняет,
//  Esc и клик мимо кольца закрывают. Фон темнит LunarBackdrop
//  (Theme.setModal), модалки взаимоисключающие (Theme.activeOverlay).
//  IPC: qs ipc call wheel toggle|open|close
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lunar-wheel"
    // клавиатуру беру только пока открыт — Esc/стрелки/Enter
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // кликабельно только когда открыт; mask по всему меню — клик мимо
    // кольца ловлю и закрываю (а не пропускаю в окно под ним)
    mask: Region { item: root.showing ? menuRoot : null }

    // ── геометрия кольца (как у 43PR) ──────────────────────────
    property int ringRadius: 118
    property int ringThickness: 46
    property int gapAngle: 5
    property int deadZone: 44

    property bool showing: false
    property int selected: -1

    readonly property int outerZone: ringRadius + ringThickness
    readonly property real step: 360 / items.length

    // действия риса: argv без shell, где можно; трубы grim|wl-copy —
    // через sh -c. Скриншоты кладу в /tmp, как хоткеи PRINT.
    readonly property var items: [
        { icon: "\uf0493", name: "Hub",          cmd: ["qs", "ipc", "call", "hub", "toggle"] },
        { icon: "\uf0100", name: "В буфер",      cmd: ["sh", "-c",
            "f=/tmp/lunar-wheel-shot.png; grim \"$f\" && wl-copy < \"$f\" && qs ipc call screenshot notify \"$f\" copied"] },
        { icon: "\uf019e", name: "Область",      cmd: ["sh", "-c",
            "g=$(slurp) || exit 0; [ -n \"$g\" ] || exit 0; f=/tmp/lunar-wheel-area.png; grim -g \"$g\" \"$f\" && wl-copy < \"$f\" && qs ipc call screenshot notify \"$f\" copied"] },
        { icon: "\uf02e9", name: "Обои",         cmd: ["qs", "ipc", "call", "wallpapers", "toggle"] },
        { icon: "\uf009a", name: "Уведомления",  cmd: ["qs", "ipc", "call", "bar", "notifs"] },
        { icon: "\uf012c", name: "Задачи",       cmd: ["qs", "ipc", "call", "todo", "toggle"] },
        { icon: "\uf05cc", name: "Прозрачность", cmd: [Quickshell.env("HOME") + "/.config/hypr/scripts/eclipse-transparency.sh"] }
    ]

    onShowingChanged: {
        if (showing) {
            Theme.activeOverlay = "wheel"
            Theme.setModal("wheel", true)
        } else {
            Theme.setModal("wheel", false)
            if (Theme.activeOverlay === "wheel")
                Theme.activeOverlay = ""
        }
    }
    // открылась другая модалка — гашу колесо
    Connections {
        target: Theme
        function onActiveOverlayChanged() {
            if (Theme.activeOverlay !== "wheel" && root.showing) root.closeMenu()
        }
    }

    function run(i) {
        if (i < 0 || i >= root.items.length) return
        var a = root.items[i]
        root.closeMenu()
        Quickshell.execDetached(a.cmd)
    }

    function openMenu() {
        root.selected = -1
        root.showing = true
        Qt.callLater(function () {
            if (root.showing)
                menuRoot.forceActiveFocus()
        })
    }
    function closeMenu() { root.showing = false }
    function toggleMenu() { root.showing ? root.closeMenu() : root.openMenu() }

    // угол курсора → номер сектора (0 — вверх, по часовой)
    function pointAt(x, y) {
        var dx = x - menuRoot.width / 2
        var dy = y - menuRoot.height / 2
        var d = Math.sqrt(dx * dx + dy * dy)
        if (d < root.deadZone) {
            root.selected = -1
            return
        }
        var n = root.items.length
        var a = Math.atan2(dy, dx) * 180 / Math.PI + 90
        if (a < 0) a += 360
        root.selected = Math.round(a / root.step) % n
    }

    IpcHandler {
        target: "wheel"
        function toggle(): void { root.toggleMenu() }
        function open(): void { root.openMenu() }
        function close(): void { root.closeMenu() }
    }

    Item {
        id: menuRoot
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            if (!root.showing) return
            var n = root.items.length
            if (event.key === Qt.Key_Escape) {
                root.closeMenu()
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                root.selected = (root.selected + 1) % n
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                root.selected = root.selected < 0 ? n - 1 : (root.selected - 1 + n) % n
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.selected >= 0) root.run(root.selected)
                else root.closeMenu()
            }
            event.accepted = true
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: function (mouse) { root.pointAt(mouse.x, mouse.y) }
            onClicked: function (mouse) {
                var dx = mouse.x - width / 2
                var dy = mouse.y - height / 2
                var d = Math.sqrt(dx * dx + dy * dy)
                if (d <= root.outerZone && root.selected >= 0) root.run(root.selected)
                else root.closeMenu()
            }
        }

        Item {
            id: wheel
            width: 2 * (root.ringRadius + root.ringThickness) + 24
            height: width
            anchors.centerIn: parent
            transformOrigin: Item.Center
            scale: root.showing ? 1 : 0.92
            opacity: root.showing ? 1 : 0
            visible: opacity > 0

            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOut } }
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOut } }

            // ── центр: выбранное действие ──────────────────────
            Rectangle {
                id: hub
                width: 2 * (root.deadZone + 14)
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: Theme.bgPanel
                border.width: 1
                border.color: root.selected >= 0 ? Theme.accent : Theme.alpha(Theme.text, 0.35)
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.selected >= 0 ? root.items[root.selected].icon : "\uf0493"
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(22)
                        color: root.selected >= 0 ? Theme.text : Theme.textDim
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.selected >= 0 ? root.items[root.selected].name : "ДЕЙСТВИЯ"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNano
                        font.bold: true
                        color: root.selected >= 0 ? Theme.text : Theme.textFaint
                    }
                }
            }

            // ── секторы кольца + иконки ────────────────────────
            Repeater {
                model: root.items

                delegate: Item {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool focused: index === root.selected
                    readonly property real midAngle: (index * root.step - 90) * Math.PI / 180
                    property real rad: root.ringRadius + (focused ? 6 : 0)
                    property real thick: root.ringThickness + (focused ? 6 : 0)
                    readonly property real a0: index * root.step - 90 - root.step / 2 + root.gapAngle / 2
                    readonly property real sweep: root.step - root.gapAngle
                    readonly property real cx: wheel.width / 2
                    readonly property real cy: wheel.height / 2
                    readonly property real a0r: a0 * Math.PI / 180
                    readonly property real a1r: (a0 + sweep) * Math.PI / 180

                    anchors.fill: parent
                    Behavior on rad { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOut } }
                    Behavior on thick { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOut } }

                    Shape {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            fillColor: seg.focused ? Theme.active : "transparent"
                            strokeWidth: seg.focused ? 2 : 1.2
                            strokeColor: seg.focused ? Theme.accent : Theme.alpha(Theme.text, 0.28)
                            joinStyle: ShapePath.RoundJoin
                            capStyle: ShapePath.RoundCap
                            startX: seg.cx + Math.cos(seg.a0r) * (seg.rad - seg.thick / 2)
                            startY: seg.cy + Math.sin(seg.a0r) * (seg.rad - seg.thick / 2)
                            PathLine {
                                x: seg.cx + Math.cos(seg.a0r) * (seg.rad + seg.thick / 2)
                                y: seg.cy + Math.sin(seg.a0r) * (seg.rad + seg.thick / 2)
                            }
                            PathAngleArc {
                                moveToStart: false
                                centerX: seg.cx
                                centerY: seg.cy
                                radiusX: seg.rad + seg.thick / 2
                                radiusY: seg.rad + seg.thick / 2
                                startAngle: seg.a0
                                sweepAngle: seg.sweep
                            }
                            PathLine {
                                x: seg.cx + Math.cos(seg.a1r) * (seg.rad - seg.thick / 2)
                                y: seg.cy + Math.sin(seg.a1r) * (seg.rad - seg.thick / 2)
                            }
                            PathAngleArc {
                                moveToStart: false
                                centerX: seg.cx
                                centerY: seg.cy
                                radiusX: seg.rad - seg.thick / 2
                                radiusY: seg.rad - seg.thick / 2
                                startAngle: seg.a0 + seg.sweep
                                sweepAngle: -seg.sweep
                            }
                        }
                    }

                    Text {
                        x: seg.cx + Math.cos(seg.midAngle) * seg.rad - width / 2
                        y: seg.cy + Math.sin(seg.midAngle) * seg.rad - height / 2
                        text: seg.modelData.icon
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(20)
                        color: seg.focused ? Theme.text : Theme.textDim
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }
            }
        }
    }
}
