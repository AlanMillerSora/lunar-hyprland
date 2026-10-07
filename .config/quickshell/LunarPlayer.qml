import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarPlayer — плеер обычным окном (FloatingWindow). Hyprland сам
//  даёт тянуть за края, двигать, блюрит (окно полупрозрачное) и
//  скругляет (правило в hyprland.lua по заголовку «Lunar Player»).
//  Так честнее: это не слой — раньше полноэкранный слой с блюром
//  съедал GPU (до +34%).
//  IPC:  qs ipc call player toggle|open|close|nav N
// ════════════════════════════════════════════════════════════════
FloatingWindow {
    id: root

    title: "Lunar Player"
    color: Theme.surfacePanel          // полупрозрачный фон — его и блюрит Hyprland
    visible: Theme.playerOpen
    minimumSize: Qt.size(720, 520)

    // ── размер и позиция между открытиями ───────────────────────────
    // Размер беру у самого окна, а позицию — только у Hyprland: у FloatingWindow
    // нет свойств x/y, окно размещает композитор. Кладу рядом с остальными
    // настройками риса: ~/.config/lunar/player-window.json.
    // Дефолты: x/y = -1 («позиция не задана»), 1180×740 как было раньше.
    readonly property string winStateDir: Quickshell.env("HOME") + "/.config/lunar"
    readonly property string winStatePath: winStateDir + "/player-window.json"

    FileView {
        id: winFile
        path: root.winStatePath
        blockLoading: true          // читаю сразу: размер нужен уже на старте окна
        atomicWrites: true

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                // первый запуск: каталога может не быть — создаю и пишу дефолты
                Quickshell.execDetached(["mkdir", "-p", root.winStateDir])
                writeAdapter()
            }
        }

        JsonAdapter {
            id: winAdapter
            property int x: -1
            property int y: -1
            property int w: 1180
            property int h: 740
        }
    }

    implicitWidth: winAdapter.w
    implicitHeight: winAdapter.h

    // ── восстановление позиции после появления окна ─────────────────
    function normAddr(a) {
        var s = "" + (a || "")
        if (s.indexOf("0x") === 0 || s.indexOf("0X") === 0) s = s.substring(2)
        // только hex: адрес уходит в Lua-строку window.move
        return s.toLowerCase().replace(/[^0-9a-f]/g, "")
    }
    function findPlayerToplevel() {
        var arr = Hyprland.toplevels.values
        for (var i = 0; i < arr.length; i++)
            if (arr[i].title === "Lunar Player" && arr[i].address) return arr[i]
        return null
    }
    property Process moveProc: Process {
        command: []
    }
    function moveTo(addr, x, y) {
        moveProc.command = ["hyprctl", "eval",
            "hl.dispatch(hl.dsp.window.move({window=\"address:0x" + normAddr(addr)
            + "\", x=" + x + ", y=" + y + ", relative=false}))"]
        moveProc.running = true
    }

    property int restoreTries: 0
    // окно появляется не мгновенно (Hyprland сначала центрует его по правилу),
    // поэтому позицию ставлю чуть позже и пробую несколько раз, если ещё не видно
    Timer {
        id: restoreTimer
        interval: 250
        repeat: true
        onTriggered: {
            var t = root.findPlayerToplevel()
            if (t) {
                root.moveTo(t.address, winAdapter.x, winAdapter.y)
                restoreTimer.stop()
            } else if (++root.restoreTries >= 6) {
                restoreTimer.stop()
            }
        }
    }

    readonly property int pageIndex: Theme.playerPage

    // уход со страницы ПОИСК (индекс 1) возвращает фокус окну: иначе строка
    // поиска съедала бы Space/стрелки/N/P — плеер перестал бы их слушать
    onPageIndexChanged: if (pageIndex !== 1) keyRoot.forceActiveFocus()

    // Центральная таблица — очередь и результаты поиска; локальная
    // фонотека живёт в левой панели Library
    property var pages: [
        { name: "ОЧЕРЕДЬ", icon: "󰉹", source: "PlayerQueue.qml" },
        { name: "ПОИСК",   icon: "󰍉", source: "PlayerSearch.qml" }
    ]

    function goto(i) { Theme.playerPage = Math.max(0, Math.min(pages.length - 1, i)) }

    // mpv поднимаю лениво, только когда реально открываю плеер
    function openPanel() {
        // если окно уже «дозакрывалось», отменяю отложенное скрытие
        if (root.closing) { root.closing = false; closeFallback.stop() }
        PlayerCore.ensurePlayer()
        Theme.playerOpen = true
        if (winAdapter.x >= 0 && winAdapter.y >= 0) {
            root.restoreTries = 0
            restoreTimer.restart()
        }
    }

    property bool closing: false

    // Прячу окно только после опроса Hyprland: если спрятать раньше, `clients -j`
    // окно уже не покажет и позиция потеряется. Долго ждать тоже нельзя (окно
    // «залипнет» открытым) — на случай молчания hyprctl есть фолбэк-таймер.
    function closePanel() {
        if (root.closing) return
        root.closing = true
        // размер окна знаю сам, позицию — нет (её даёт только Hyprland)
        winAdapter.w = Math.round(root.width)
        winAdapter.h = Math.round(root.height)
        probeProc.running = true
        closeFallback.restart()
    }

    function finishClose() {
        if (!root.closing) return
        root.closing = false
        closeFallback.stop()
        winFile.writeAdapter()       // сохраняю w/h и позицию из опроса
        Theme.playerOpen = false
        // закрыл и ничего не играет — демон больше не нужен, гашу (освободит память)
        PlayerCore.maybeStopDaemon()
    }

    property Process probeProc: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text)
                    for (var i = 0; i < arr.length; i++) {
                        if (arr[i].title === "Lunar Player" && arr[i].at) {
                            winAdapter.x = Math.round(arr[i].at[0])
                            winAdapter.y = Math.round(arr[i].at[1])
                            break
                        }
                    }
                } catch (e) {}
            }
        }
        onExited: root.finishClose()
    }

    Timer {
        id: closeFallback
        interval: 800
        repeat: false
        onTriggered: root.finishClose()
    }

    function toggle() { Theme.playerOpen ? closePanel() : openPanel() }
    function nav(i) { goto(i) }

    // модальные оверлеи взаимоисключающие (как Hub/Agent): показался плеер —
    // гашу Hub, открылся Hub — гашу плеер, всё в одном процессе и плавно
    onVisibleChanged: {
        if (visible) {
            Theme.activeOverlay = "player"
            Theme.setModal("player", true)
        } else {
            Theme.setModal("player", false)
        }
    }
    // окно закрыли извне — снимаю флаг подложки (см. Hub)
    onClosed: Theme.setModal("player", false)
    Connections {
        target: Theme
        function onActiveOverlayChanged() {
            if (Theme.activeOverlay !== "player" && root.visible)
                root.closePanel()
        }
    }

    IpcHandler {
        target: "player"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
        function nav(i: int): void { root.nav(i) }
        // переключить воспроизведение (пауза/играть) — для тестов и автоматизации
        function playPause(): void { PlayerCore.toggle() }
    }

    // клавиатура обычного окна
    Item {
        id: keyRoot
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closePanel()
        Keys.onSpacePressed: PlayerCore.toggle()
        Keys.onLeftPressed: PlayerCore.seekBy(-5)
        Keys.onRightPressed: PlayerCore.seekBy(5)
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_N) { PlayerCore.next(); e.accepted = true }
            else if (e.key === Qt.Key_P) { PlayerCore.prev(); e.accepted = true }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.bottomMargin: 14
            // сверху запас: ярлык панели лежит на верхней кромке (половина
            // выше линии) — иначе окно его подрезает
            anchors.topMargin: 24
            spacing: 8

            // ── верхняя полоса Nav ──
            TuiPanel {
                label: "Nav"
                Layout.fillWidth: true
                Layout.preferredHeight: 54

                PlayerNavBar {
                    anchors.fill: parent
                    onSearch: (q) => { PlayerCore.search(q); root.goto(1) }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // ── левая колонка: Library (локальная фонотека) ──
                TuiPanel {
                    label: "Library"
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true

                    PlayerLibrary {
                        anchors.fill: parent
                        pageActive: root.visible
                    }
                }

                // ── центр: Main — чипы разделов + таблица ──
                TuiPanel {
                    label: "Main"
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        // чипы разделов
                        Row {
                            spacing: 6

                            Repeater {
                                model: root.pages

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: root.pageIndex === index

                                    width: chipText.implicitWidth + 26
                                    height: 28
                                    radius: Theme.radius
                                    color: active ? Theme.active
                                        : (chipMouse.containsMouse ? Theme.hover : "transparent")
                                    border.width: 1
                                    border.color: active ? Theme.borderAccent : Theme.border

                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        color: active ? Theme.text : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
                                        font.letterSpacing: 1
                                        font.bold: active
                                    }

                                    MouseArea {
                                        id: chipMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.goto(index)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.border
                        }

                        Item {
                            id: pageHost
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Repeater {
                                model: root.pages

                                delegate: Item {
                                    id: pageWrap
                                    required property var modelData
                                    required property int index

                                    anchors.fill: parent
                                    visible: opacity > 0.01
                                    opacity: root.pageIndex === index ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
                                    }

                                    Loader {
                                        anchors.fill: parent
                                        source: modelData.source
                                        onLoaded: {
                                            if (item)
                                                item.pageActive = Qt.binding(function() {
                                                    return root.visible && root.pageIndex === pageWrap.index
                                                })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── правая колонка: Sidebar ──
                TuiPanel {
                    label: "Sidebar"
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true

                    PlayerSidebar {
                        anchors.fill: parent
                        active: root.visible
                    }
                }
            }

            // ── нижняя панель Playing ──
            TuiPanel {
                label: "Playing"
                Layout.fillWidth: true
                Layout.preferredHeight: 110

                PlayerBar {
                    anchors.fill: parent
                    active: root.visible
                }
            }
        }
    }
}
