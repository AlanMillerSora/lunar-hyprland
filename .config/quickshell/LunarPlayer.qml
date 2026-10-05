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

    // уход со страницы ПОИСК (индекс 2) возвращает фокус окну: иначе строка
    // поиска съедала бы Space/стрелки/N/P — плеер перестал бы их слушать
    onPageIndexChanged: if (pageIndex !== 2) keyRoot.forceActiveFocus()

    property var pages: [
        { name: "СЕЙЧАС",   icon: "󰎇", source: "PlayerNowPlaying.qml" },
        { name: "ОЧЕРЕДЬ",  icon: "󰉹", source: "PlayerQueue.qml" },
        { name: "ПОИСК",    icon: "󰍉", source: "PlayerSearch.qml" },
        { name: "ЛОКАЛЬНЫЕ", icon: "󰉋", source: "PlayerLibrary.qml" }
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
    onVisibleChanged: if (visible) Theme.activeOverlay = "player"
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

        HudNodes { inset: 6; size: 4 }
        HudCorners { color: Theme.accent; size: 16; thickness: 1; margin: 10 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: Theme.space4

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.space4

                // ── навигация: отдельный «остров» (язык 43PR) ──
                Rectangle {
                    Layout.preferredWidth: 196
                    Layout.fillHeight: true
                    radius: Theme.radiusL
                    color: Theme.bgCard
                    border.width: 1
                    border.color: Theme.border

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6

                        Text {
                            text: "LUNAR PLAYER"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(Theme.fontPanelTitle)
                            font.bold: true
                            font.letterSpacing: 3
                        }

                        // вместо жёсткой линии-разделителя — короткий акцент
                        Rectangle {
                            width: 28
                            height: 2
                            radius: height / 2
                            color: Theme.alpha(Theme.accent, 0.30)
                        }

                        Item { width: 1; height: 10 }

                        Repeater {
                            model: root.pages

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 44
                                radius: Theme.radiusM
                                color: root.pageIndex === index
                                    ? Theme.active
                                    : (navMouse.containsMouse ? Theme.hover : "transparent")
                                border.width: root.pageIndex === index ? 1 : 0
                                border.color: Theme.alpha(Theme.accent, 0.35)

                                Rectangle {
                                    visible: root.pageIndex === index
                                    width: 3
                                    height: parent.height - 16
                                    radius: width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    color: Theme.accent
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    spacing: Theme.space3

                                    Text {
                                        text: modelData.icon
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.fontSize(14)
                                        color: root.pageIndex === index ? Theme.accent : Theme.textDim
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.letterSpacing: 1
                                        color: root.pageIndex === index ? Theme.text : Theme.textDim
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.goto(index)
                                }
                            }
                        }
                    }
                }

                // ── страница: Loader'ы живут постоянно, видна только текущая ──
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
                                id: pageLoader
                                anchors.fill: parent
                                source: modelData.source
                                // страница сама решает, когда запускать cava и крутить винил
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

            // ── нижняя полоса ──
            PlayerBar {
                Layout.fillWidth: true
                active: root.visible
                showProgress: root.pageIndex !== 0
                onExpandRequested: root.goto(0)
            }
        }
    }
}
