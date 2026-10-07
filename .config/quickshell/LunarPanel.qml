import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "widgets/shared"
import "panels"
import "widgets/bar"

// ────────────────────────────────────────────────────────────────
//  Lunar top bar — монохромный HUD
//    единая плашка: фазы столов · PERF · часы/сеть/погода · статус
//  Ввод ловит только плашка и открытая карточка (mask) — зазоры
//  пропускают клики (важно для fullscreen). exclusiveZone держит окна
//  вне полосы бара. Клик по ячейке открывает карточку-«пузырь» ПОД ней
//  (в тон Hub: surface + рамка + зерно + шапка), бар при этом не сжимается.
// ────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    // окно выше бара — под выезжающую вниз панель (вариант 3)
    implicitHeight: Theme.barH + 660
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "lunar-panel"
    // клавиатуру забираю, пока открыт режим — чтобы Esc закрывал
    WlrLayershell.keyboardFocus: BarState.expanded
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // окна не заезжают под полосу бара (плюс небольшой зазор снизу)
    WlrLayershell.exclusiveZone: Theme.barTop + Theme.barH + Theme.space1
    WlrLayershell.anchors.top: true
    WlrLayershell.anchors.left: true
    WlrLayershell.anchors.right: true
    exclusionMode: ExclusionMode.Normal

    // клик-сквозь: ввод ловит единый бар и раскрытая панель.
    // Пока панель открыта, ловлю ещё и фон вокруг (clickShield) — клик мимо
    // закрывает панель, а не проваливается сквозь окно. В покое зазоры
    // по-прежнему пропускают клики (важно для fullscreen).
    mask: Region {
        Region { item: BarState.expanded ? clickShield : null }
        Region { item: bar }
        Region { item: BarState.expanded ? bubble : null }
        Region { item: BarSettings.hotZone ? hotZoneLeft : null }
        Region { item: BarSettings.hotZone ? hotZoneRight : null }
        Region { item: root.recording ? recPill : null }
    }

    // фон-ловушка: есть при открытой панели, самый нижний слой
    Item {
        id: clickShield
        anchors.fill: parent
        visible: BarState.expanded
        MouseArea {
            anchors.fill: parent
            onClicked: { BarState.closePanel() }
        }
    }

    // Esc закрывает открытый режим (поиск сам обрабатывает Esc)
    Shortcut {
        sequence: "Escape"
        enabled: BarState.expanded && BarState.mode !== "search"
        onActivated: { BarState.closePanel() }
    }
    // тот же Esc через Keys — надёжнее на layer-поверхности
    Item {
        anchors.fill: parent
        focus: BarState.expanded && BarState.mode !== "search"
        Keys.onEscapePressed: { BarState.closePanel() }
    }

    // Палитра из системной темы (Hub / лаунчер / настройки):
    //   фон «таблеток» — как у оверлеев (Theme.bg, реагирует на ползунок
    //   «прозрачность интерфейса»), рамки — Theme.border,
    //   акценты — Theme.accent через Theme.alpha().
    readonly property color pillBg: Theme.barPill
    readonly property color pillHover: Theme.hoverStrong

    // ─────────────── workspaces (Hyprland) ───────────────
    readonly property var wsList: Hyprland.workspaces.values
    readonly property var focusedWs: Hyprland.focusedWorkspace

    function wsFor(id) {
        var ws = root.wsList
        for (var i = 0; i < ws.length; i++)
            if (ws[i].id === id)
                return ws[i]
        return null
    }

    // ── живые столы: фаза мигает, когда в неактивном столе открылось окно ──
    property var _wsCounts: ({})
    property bool _wsCountsInit: false
    property var wsBlink: ({})
    property bool wsBlinkPhase: true
    readonly property int focusedWsId: (root.focusedWs && root.focusedWs.id !== undefined) ? root.focusedWs.id : -1
    readonly property var wsCounts: {
        var m = {}
        for (var i = 1; i <= 9; i++)
            m[i] = 0
        var tops = Hyprland.toplevels.values
        for (var j = 0; j < tops.length; j++) {
            var id = (tops[j].workspace && tops[j].workspace.id !== undefined) ? tops[j].workspace.id : -1
            if (id >= 1 && id <= 9)
                m[id] = (m[id] || 0) + 1
        }
        return m
    }
    onWsCountsChanged: {
        var cur = root.wsCounts
        if (!root._wsCountsInit) {
            root._wsCounts = cur
            root._wsCountsInit = true
            return
        }
        var prev = root._wsCounts
        var nb = Object.assign({}, root.wsBlink)
        var touch = false
        for (var i = 1; i <= 9; i++) {
            if ((cur[i] || 0) > (prev[i] || 0) && i !== root.focusedWsId) {
                nb[i] = 6
                touch = true
            } else if (i === root.focusedWsId && nb[i] !== undefined) {
                delete nb[i]
                touch = true
            }
        }
        root._wsCounts = cur
        if (touch)
            root.wsBlink = nb
    }
    onFocusedWsIdChanged: {
        if (root.wsBlink[root.focusedWsId] !== undefined) {
            var nb = Object.assign({}, root.wsBlink)
            delete nb[root.focusedWsId]
            root.wsBlink = nb
        }
    }
    Timer {
        interval: 220
        repeat: true
        running: Object.keys(root.wsBlink).length > 0
        onTriggered: {
            root.wsBlinkPhase = !root.wsBlinkPhase
            var nb = {}
            for (var k in root.wsBlink) {
                var r = root.wsBlink[k] - 1
                if (r > 0)
                    nb[k] = r
            }
            root.wsBlink = nb
        }
    }

    // Hyprland 0.55+ умеет Lua-конфиг: старый "workspace N" там не парсится,
    // нужен Lua-диспетчер hl.dsp.focus({workspace=N}).
    // Hyprland.usingLua в Quickshell 0.3.1 это не определяет, поэтому смотрим
    // configProvider в `hyprctl -j status`.
    property bool luaMode: false

    Process {
        id: luaCheck
        running: true
        // без jq — он не входит в базовую группу Arch (M30)
        command: ["bash", "-c",
            "hyprctl -j status 2>/dev/null | grep -o '\"configProvider\"[^,}]*'"]
        stdout: StdioCollector { onStreamFinished: root.luaMode = (text.indexOf("lua") >= 0) }
    }

    function focusWs(id) {
        if (root.luaMode || Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({workspace=" + id + "})")
        else
            Hyprland.dispatch("workspace " + id)
    }

    // ─────────────── clock ───────────────
    readonly property var dayNames: ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]
    property string clockText: Qt.formatTime(new Date(), "HH:mm")
    property string dayText: dayNames[new Date().getDay()]
    property string dateText: Qt.formatDate(new Date(), "dd.MM")
    property bool colonOn: true

    // живое двоеточие: плавно гаснет и зажигается
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: root.colonOn = !root.colonOn
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            root.clockText = Qt.formatTime(now, "HH:mm")
            root.dayText = root.dayNames[now.getDay()]
            root.dateText = Qt.formatDate(now, "dd.MM")
        }
    }

    // ─────────────── audio (PipeWire) ───────────────
    // Слежу и за выводом, и за входом: в пульте два инлайн-ползунка.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false
    readonly property var src: Pipewire.defaultAudioSource
    readonly property real micVol: (src && src.audio) ? src.audio.volume : 0
    readonly property bool micMuted: (src && src.audio) ? src.audio.muted : false
    readonly property bool micAvailable: !!(src && src.audio)

    function setVol(v) {
        if (!sink || !sink.audio)
            return
        sink.audio.muted = false
        sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleMute() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted
    }

    function bumpVol(d) {
        if (!sink || !sink.audio)
            return
        sink.audio.muted = false
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + d))
    }

    // колесо над медиа-ячейкой: перемотка на ±5 с. Пишу позицию через MPRIS
    // seek(offset). Полосу двигаю сразу — MPRIS шлёт позицию «догоняющими»
    // значениями, и без этого прогресс на миг откатывался бы назад.
    function seekBy(d) {
        if (!player || player.canSeek !== true)
            return
        player.seek(d)
        var p = root.shownPos + d
        root.shownPos = Math.max(0, root.trackLength > 0 ? Math.min(root.trackLength, p) : p)
    }

    function setMicVol(v) {
        if (!src || !src.audio)
            return
        src.audio.muted = false
        src.audio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleMicMute() {
        if (src && src.audio)
            src.audio.muted = !src.audio.muted
    }

    function bumpMic(d) {
        if (!src || !src.audio)
            return
        src.audio.muted = false
        src.audio.volume = Math.max(0, Math.min(1, src.audio.volume + d))
    }

    // ─────────────── mpris ───────────────
    // Идентификатор mpv-демона (mpv-mpris: identity/desktopEntry «mpv»,
    // шина org.mpris.MediaPlayer2.mpv) всегда начинается с «mpv» — по нему
    // узнаю наш плеер среди чужих (Firefox и т.п.).
    function isMpvPlayer(p) {
        if (!p)
            return false
        var names = [p.identity || "", p.desktopEntry || "", p.dbusName || ""]
        for (var i = 0; i < names.length; i++)
            if (names[i].toLowerCase().indexOf("mpv") === 0)
                return true
        return false
    }
    // Приоритет выбора: сперва играющий mpv-демон, иначе любой играющий,
    // и лишь в последнюю очередь — первый из списка.
    readonly property var player: {
        var ps = Mpris.players.values
        var playingAny = null
        for (var i = 0; i < ps.length; i++) {
            if (!ps[i].isPlaying)
                continue
            if (playingAny === null)
                playingAny = ps[i]
            if (root.isMpvPlayer(ps[i]))
                return ps[i]
        }
        if (playingAny !== null)
            return playingAny
        return ps.length > 0 ? ps[0] : null
    }
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string track: player
        ? ((player.trackTitle || "") + (player.trackArtist ? "  —  " + player.trackArtist : ""))
        : ""
    // прогресс трека для тонкой линии в медиа-ячейке. lengthSupported —
    // чтобы у радио/стримов не показывать залитую на 100% полосу (MPRIS
    // отдаёт length = position, если длины нет). Позицию MPRIS шлёт редко,
    // поэтому тикаю сам и синхронизируюсь по positionChanged (как MediaCore).
    readonly property real trackLength:
        (player && player.lengthSupported === true && player.length > 0) ? player.length : 0
    property real shownPos: 0
    readonly property real trackPosition: shownPos
    function syncPos() {
        var p = (player && player.position > 0) ? player.position : 0
        // MPRIS шлёт позицию редко и «догоняющими» значениями: после seek
        // прилетают 92.7 → 90.0 → 32.0 → 30.0. Назад на доли секунды не
        // откатываю (это догон, а не перемотка), но большой скачок принимаю
        // как реальную перемотку. Вперёд двигаю всегда.
        if (p + 1.5 < root.shownPos && Math.abs(p - root.shownPos) < 3)
            return
        root.shownPos = p
    }
    onPlayerChanged: {
        root.syncPos()
        // перезапускаю тик только когда он и так должен идти — иначе
        // restart() задирал running мимо декларативного условия
        if (root.playing && root.trackLength > 0)
            posTimer.restart()
    }
    property Timer posTimer: Timer {
        interval: 500
        repeat: true
        running: root.playing && root.trackLength > 0
        onTriggered: root.shownPos = Math.min(root.trackLength, root.shownPos + 0.5)
    }
    property Connections posConn: Connections {
        target: root.player
        function onPositionChanged() { root.syncPos() }
        function onTrackChanged() { root.syncPos() }
        function onLengthChanged() { root.syncPos() }
        function onLengthSupportedChanged() { root.syncPos() }
    }


    // ── cava: спектр для полосы «сейчас играет» ──
    // Столбики рисуем только когда реально играет; иначе — линия.
    readonly property bool mediaActive: root.playing && root.track.length > 0
    readonly property int barCount: 20
    property var barValues: []

    function feedCava(line) {
        var t = ("" + line).trim()
        if (t.length === 0)
            return
        var parts = t.split(/\s+/)
        var out = []
        for (var i = 0; i < root.barCount; i++) {
            var v = parseInt(parts[i] === undefined ? "0" : parts[i]) || 0
            out.push(Math.max(0, Math.min(1, v / 1000)))
        }
        root.barValues = out
    }

    Process {
        id: cavaProc
        running: root.mediaActive
        command: ["cava", "-p", Quickshell.shellPath("cava-lunar.conf")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.feedCava(line)
        }
        stderr: StdioCollector {}
    }

    // ─────────────── power ───────────────
    // Кнопки питания на панели нет — меню открывается по SUPER + ESC.

    Process { id: pavuProc; running: false }
    function openMixer() {
        // pavucontrol может отсутствовать — проверяем перед запуском
        pavuProc.command = ["bash", "-c",
            "command -v pavucontrol >/dev/null 2>&1 && setsid pavucontrol >/dev/null 2>&1 &"]
        pavuProc.running = true
    }

    // (пустой ползунок убран: громкость/микрофон живут в пузыре звука
    //  PanelAudio — открывается кликом по значку звука и SUPER + C)

    // ─────────── системный трей ───────────
    // сколько значков показываем в панели, остальные — в списке (Theme.trayVisible)
    readonly property int trayMax: Theme.trayVisible
    // общее число значков: по нему видно, прятать ли «+N» в списке
    readonly property int trayCount: SystemTray.items.values.length

    // Кэш видимых значков: SystemTray.items.values отдаёт новый массив на любое
    // изменение, и Repeater пересоздавал бы делегаты даже без смены состава.
    property var trayItems: []
    function sameTray(a, b) {
        if (a.length !== b.length)
            return false
        for (var i = 0; i < a.length; i++)
            if (a[i] !== b[i])
                return false
        return true
    }
    function refreshTray() {
        var v = SystemTray.items.values.slice(0, root.trayMax)
        if (!sameTray(v, root.trayItems))
            root.trayItems = v
    }
    Connections {
        target: SystemTray.items
        function onValuesChanged() { root.refreshTray() }
    }
    Connections {
        target: Theme
        function onTrayVisibleChanged() { root.refreshTray() }
    }
    // маркер телеметрии держу всё время, пока жив бар: систем-остров
    // показывает CPU/RAM/GPU, а eclipse-status.sh кэширует GPU-замер на
    // 10 с — nvidia-smi в горячий путь (опрос раз в 3 с) не попадает
    Component.onCompleted: { root.syncPos(); root.refreshTray(); root.setTeleMark(true) }

    Process { id: trayPanelProc; running: false }
    function openTrayPanel() {
        trayPanelProc.command = ["bash", "-c", "qs ipc call tray toggle"]
        trayPanelProc.running = true
    }

    // Значки без Activate (Steam/ayatana) не умеют активироваться, а штатные
    // меню Quickshell на Wayland не создаются — поэтому ЛКМ просто открываю
    // приложение. Набор команд маленький и явный.
    Process { id: trayLaunchProc; running: false }
    function openTrayApp(item) {
        if (!item) return
        var key = ((item.id || "") + " " + (item.tooltipTitle || "") + " "
            + (item.title || "")).toLowerCase()
        var cmd = ""
        if (key.indexOf("steam") >= 0)
            cmd = "steam steam://open/games"
        if (!cmd) return
        trayLaunchProc.command = ["bash", "-c", "setsid " + cmd + " >/dev/null 2>&1 &"]
        trayLaunchProc.running = true
    }

    // icon у SNI бывает: путь, file:///image:// или имя темы — приводим к Image source.
    // Важно: если иконки нет в теме, image://icon отдаёт заглушку, поэтому
    // сначала проверяем hasThemeIcon и иначе возвращаем "" (в UI будет точка).
    function trayIconSource(item) {
        if (!item) return ""
        var ic = item.icon || ""
        if (ic.indexOf("file://") === 0 || ic.indexOf("qrc:") === 0) return ic
        if (ic.indexOf("image://icon/") === 0) {
            // значок с явным путём темы (Steam: «?path=…») провайдер резолвит сам
            if (ic.indexOf("?") !== -1) return ic
            var n = ic.substring("image://icon/".length)
            return Quickshell.hasThemeIcon(n) ? ic : ""
        }
        if (ic.indexOf("image://") === 0) return ic
        if (ic.charAt(0) === "/") return "file://" + ic
        if (ic && Quickshell.hasThemeIcon(ic)) return Quickshell.iconPath(ic)
        var id = item.id || ""
        if (id && Quickshell.hasThemeIcon(id)) return Quickshell.iconPath(id)
        return ""
    }

    // Индикатор Steam (ayatana) не умеет Activate — только меню; ЛКМ по нему
    // открывает приложение, а не бесполезный activate. Прочие меню-онли —
    // обычное меню (ПКМ/ЛКМ).
    function isSteamApp(item) {
        if (!item) return false
        var key = (item.id || "") + " " + (item.title || "") + " " + (item.tooltipTitle || "")
        return /steam/i.test(key)
    }

    // показать родное меню приложения (ПКМ)
    function trayMenu(item, mouseArea, mx, my) {
        if (!item || !item.hasMenu) return
        var ci = root.contentItem
        var pt = ci ? mouseArea.mapToItem(ci, mx, my) : Qt.point(0, root.implicitHeight)
        item.display(root, Math.round(pt.x), Math.round(pt.y))
    }

    // ─────────── сеть / раскладка / уведомления ───────────
    property string netKind: "off"      // eth | wifi | off
    property string kbLayout: "EN"
    property string kbDevice: ""
    // DND и число активных уведомлений — из нашего демона (NotifModel),
    // а не из makoctl в eclipse-status.sh
    readonly property bool dnd: NotifModel.dnd
    readonly property int notifCount: NotifModel.count
    // помню прошлое число, чтобы пульс колокола шёл только на рост
    property int prevNotifCount: 0
    // не пульсирую на самые первые значения vol/track при старте шелла
    property bool pulsePrimed: false
    Timer { interval: 800; running: true; onTriggered: root.pulsePrimed = true }
    property bool gameMode: false
    property string cpuGovernor: ""
    property bool recording: false

    // телеметрия — в сервисе SysInfo (читают бар/панели)
    readonly property int focusedPhase:
        (root.focusedWs && root.focusedWs.id > 0) ? root.focusedWs.id : 0

    Process {
        id: statusProc
        running: false
        command: ["bash", "-c", "~/.config/hypr/scripts/eclipse-status.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rxRaw = -1, txRaw = -1
                var gotData = false
                var parts = text.trim().split("\u001f")
                for (var i = 0; i < parts.length; i++) {
                    var kv = parts[i].split("=")
                    if (kv.length !== 2)
                        continue
                    var k = kv[0], v = kv[1]
                    if (k === "net") {
                        // сигнал не показываем — только вид подключения
                        root.netKind = v.indexOf("wifi:") === 0 ? "wifi" : v
                    } else if (k === "kb") {
                        root.kbLayout = v
                    } else if (k === "kbdev") {
                        root.kbDevice = v
                    } else if (k === "gm") {
                        root.gameMode = (v === "1")
                    } else if (k === "pp") {
                        root.cpuGovernor = v
                    } else if (k === "rec") {
                        root.recording = (v === "1")
                    } else if (k === "cpu") {
                        SysInfo.cpu = Math.round(parseFloat(v) || 0)
                        gotData = true
                    } else if (k === "ctemp") {
                        SysInfo.cpuTemp = Math.round(parseFloat(v) || 0)
                    } else if (k === "ram") {
                        SysInfo.ram = Math.round(parseFloat(v) || 0)
                        gotData = true
                    } else if (k === "rtot") {
                        SysInfo.ramTotal = parseInt(v) || 0
                    } else if (k === "gpu") {
                        // есть только в режиме телеметрии (иначе пусто)
                        SysInfo.gpu = (v === "") ? -1 : (Math.round(parseFloat(v) || 0))
                    } else if (k === "gput") {
                        SysInfo.gpuTemp = (v === "") ? -1 : (Math.round(parseFloat(v) || 0))
                    } else if (k === "rx") {
                        rxRaw = parseFloat(v) || 0
                    } else if (k === "tx") {
                        txRaw = parseFloat(v) || 0
                    }
                }

                // скорость сети: дельта сырых счётчиков (получаю их в одной
                // строке статуса — отдельный опрос не нужен)
                if (rxRaw >= 0)
                    SysInfo.feedNet(rxRaw, txRaw, Date.now())
                // историю пополняю только по валидному замеру — иначе битый
                // статус забивал спарклайн «полками»
                if (gotData)
                    SysInfo.sample()
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: statusProc.running = true
    }

    // По отдельному Process на каждое действие: общий процесс затирал команду,
    // если новое действие приходило, пока выполнялось предыдущее.
    Process { id: hubOpenProc; running: false }
    Process { id: layoutProc; running: false }
    Process { id: gameProc; running: false }
    Process { id: recordProc; running: false }

    function openPlayer() {
        quitProc.command = ["qs", "ipc", "call", "player", "toggle"]
        quitProc.running = true
    }
    Process { id: quitProc; running: false }

    function openNetwork() {
        hubOpenProc.command = ["bash", "-c",
            "qs ipc call hub open; sleep 0.15; qs ipc call hub nav 3"]
        hubOpenProc.running = true
    }

    function switchLayout() {
        if (kbDevice.length === 0)
            return
        // без bash: имя устройства отдельным argv — одинарные кавычки в имени
        // клавиатуры ломали команду
        layoutProc.command = ["hyprctl", "switchxkblayout", root.kbDevice, "next"]
        layoutProc.running = true
    }

    function toggleDnd() {
        NotifModel.toggleDnd()
    }

    function toggleGameMode() {
        gameProc.command = ["bash", "-c",
            "~/.config/hypr/scripts/eclipse-gamemode.sh toggle"]
        gameProc.running = true
    }

    function toggleRecording() {
        recordProc.command = ["bash", "-c",
            "~/.config/hypr/scripts/eclipse-record.sh toggle"]
        recordProc.running = true
    }

    // ─────────────── панель бара: карточка-«пузырь» под ячейкой ───────────────
    // Бар всегда остаётся на всю ширину; режим открывается отдельной карточкой
    // ПОД кликнутой ячейкой (в тон Hub), а не «сворачивает» бар в одну плашку.
    // Появление — opacity + scale от верхней кромки, раскладка per-frame не дёргается.
    // reveal: 0 — закрыто, 1 — открыто.
    property real reveal: BarState.mode !== "" ? 1 : 0
    Behavior on reveal { Anim { type: Anim.Standard } }
    // высота карточки по режиму (анимируется при смене режима)
    function panelHeightFor(m) {
        if (m === "audio") return Theme.panelHeaderH + audioBody.implicitHeight + Theme.space3
        if (m === "media") return Theme.panelHeaderH + mediaPanel.implicitHeight + Theme.space3
        if (m === "search") return Theme.panelHSearch
        if (m === "notifs") return Theme.panelHNotifs
        if (m === "sys") return Theme.panelHeaderH + sysBody.implicitHeight + Theme.space3
        if (m === "weather") return Theme.panelHeaderH + wxBody.implicitHeight + Theme.space5
        return Theme.barH
    }
    property real panelTargetH: root.panelHeightFor(BarState.mode)
    Behavior on panelTargetH { Anim { type: Anim.Standard } }

    // ширина панели по режиму: пульт/поиск — фикс, медиа/погода — по содержимому
    function panelWidthFor(m) {
        if (m === "search") return Theme.panelWSearchWide
        if (m === "audio") return Theme.panelWAudio
        if (m === "media") return Theme.panelWMedia
        if (m === "notifs") return Theme.panelWNotifs
        if (m === "sys") return Theme.panelWSys
        if (m === "weather") return wxBody.implicitWidth + 2 * Theme.space5
        return Theme.panelWSearch
    }

    // ── привязка карточки к ячейке: где кликнули, под тем и всплывает.
    //    x ячейки беру в координатах контента (contentItem), клампинг в
    //    `bubbleX` не даёт карточке вылезти за края экрана. ──
    function cellOriginX(item) {
        // невидимая/неразложенная ячейка (напр. медиа без трека) координаты
        // не имеет — тогда карточка идёт по центру, а маркер ячейки не рисуем.
        if (!item || !item.visible || item.width <= 0)
            return -1
        return item.mapToItem(root.contentItem, item.width / 2, 0).x
    }
    function originForMode(m) {
        if (m === "weather") return cellOriginX(centerZone.weatherCellRef)
        if (m === "media") return centerZone.mediaActive
            ? cellOriginX(centerZone.mediaCellRef) : -1
        if (m === "notifs") return cellOriginX(rightZone.notifCellRef)
        if (m === "sys") return cellOriginX(rightZone.sysCellRef)
        if (m === "audio") return cellOriginX(rightZone.volumeCellRef)
        return -1
    }
    property real panelTargetW: root.panelWidthFor(BarState.mode)
    Behavior on panelTargetW { Anim { type: Anim.Standard } }

    // геометрия карточки-пузыря: центр под ячейкой, зажат в края экрана
    readonly property real bubbleY: Theme.barTop + Theme.barH + Theme.space2
    readonly property real bubbleX: {
        var w = root.panelTargetW
        var c = BarState.originX >= 0 ? BarState.originX : root.width / 2
        var min = Theme.barMargin
        var max = Math.max(min, root.width - w - Theme.barMargin)
        return Math.max(min, Math.min(max, c - w / 2))
    }
    readonly property bool panelHasHeader: BarState.mode === "audio"
        || BarState.mode === "media"
        || BarState.mode === "notifs"
        || BarState.mode === "sys"
        || BarState.mode === "weather"
    readonly property string panelTitle: {
        if (BarState.mode === "audio") return "ЗВУК"
        if (BarState.mode === "media") return "МЕДИА"
        if (BarState.mode === "search") return "ПОИСК"
        if (BarState.mode === "notifs") return "УВЕДОМЛЕНИЯ"
        if (BarState.mode === "sys") return "ТЕЛЕМЕТРИЯ"
        if (BarState.mode === "weather") return "ПОГОДА"
        return ""
    }
    // Контент появляется вместе с выпадением — отдельного «всплытия» нет.
    readonly property real panelContentOpacity: root.reveal
    // игра — синхронизирую в BarState, чтобы пульсы не всплывали
    Binding {
        target: BarState
        property: "gameMode"
        value: root.gameMode
    }

    // панель закрывается кликом по её фону, Esc (поиск) или повторным режимом

    // IPC: qs ipc call bar volume|mixer|media|search|notifs|sys|weather|reset
    IpcHandler {
        target: "bar"
        function volume() { BarState.togglePanel("audio") }
        function mixer() { root.openMixer() }
        function media() { BarState.togglePanel("media") }
        function search() { BarState.togglePanel("search") }
        function notifs() { BarState.togglePanel("notifs") }
        function sys() { BarState.togglePanel("sys") }
        function weather() { BarState.togglePanel("weather") }
        function reset() { BarState.closePanel() }
    }

    // поиск — в сервисе Launcher (панель биндится к нему)

    // при открытии режима: уведы — обновить, поиск — фокус на поле,
    // прочие — свежий статус (телеметрия в sys)
    Connections {
        target: BarState
        function onModeChanged() {
            // морф плашки — теперь для ВСЕХ режимов: плашка сама
            // раскрывается вниз и становится панелью.
            // запоминаю ячейку-источник: морф раскрывается от неё, а не
            // от центра. При закрытии (mode "") origin не трогаю — плашка
            // плавно возвращается на своё место.
            if (BarState.mode !== "")
                BarState.originX = root.originForMode(BarState.mode)
            if (BarState.mode === "notifs")
                NotifModel.load()
            else if (BarState.mode === "search") {
                Launcher.open()
                Qt.callLater(function() { if (searchPanel) searchPanel.focusInput() })
            }
            if (BarState.mode !== "" && BarState.mode !== "search")
                statusProc.running = true
            if (BarState.mode !== "search")
                Launcher.reset()
        }
    }

    // быстрые действия «пульта»
    Process { id: powerProc; running: false }
    Process { id: hubToggleProc; running: false }
    Process { id: wallpapersProc; running: false }
    // маркер ~/.cache/lunar/tele разрешает eclipse-status.sh читать GPU
    // (кэш на 30 с). Держу его, пока жив бар, и снимаю при завершении.
    // execDetached — без Process: в onDestruction очередь процессов может
    // не успеть, и маркер оставался.
    function setTeleMark(on) {
        Quickshell.execDetached(on
            ? ["bash", "-c", "mkdir -p \"$HOME/.cache/lunar\" && : > \"$HOME/.cache/lunar/tele\""]
            : ["rm", "-f", Quickshell.env("HOME") + "/.cache/lunar/tele"])
    }
    // шелл упал/перезапустился в режиме sys — маркер мог остаться:
    // снимаю при завершении, иначе nvidia-smi дёргается вечно в горячем пути
    // (при старте тоже — см. общий Component.onCompleted у трея)
    Component.onDestruction: setTeleMark(false)
    function openPower() {
        powerProc.command = ["qs", "ipc", "call", "power", "toggle"]
        powerProc.running = true
    }
    function openHub() {
        hubToggleProc.command = ["qs", "ipc", "call", "hub", "toggle"]
        hubToggleProc.running = true
    }
    function openWallpapers() {
        wallpapersProc.command = ["qs", "ipc", "call", "wallpapers", "toggle"]
        wallpapersProc.running = true
    }

    // ───────────────────────────── layout ─────────────────────────────
    // Единый бар: слева LUNAR+фазы и PERF·раскладка, в центре
    // часы/медиа/пульт, справа статус (систем-остров·погода·сеть·трей·звук).
    // Левую и правую группы держу одной ширины, чтобы часы стояли ровно
    // по центру экрана, а фон был одной плашкой без разрыва.
    // Метрики моношрифта: по ним считаем ширины числовых полей, чтобы
    // цифры при скачках значений не дёргали раскладку.
    FontMetrics { id: fm11; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize(11) }
    FontMetrics { id: fm13; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize(13) }
    FontMetrics { id: fm14; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize(14) }
    // иконки из разных наборов Nerd Font бывают разной ширины — тоже чиним
    FontMetrics { id: fmIcon15; font.family: Theme.iconFont; font.pixelSize: Theme.fontSize(15) }
    FontMetrics { id: fmIcon17; font.family: Theme.iconFont; font.pixelSize: Theme.fontSize(17) }
    FontMetrics { id: fmIcon19; font.family: Theme.iconFont; font.pixelSize: Theme.fontSize(19) }

    // ── ЕДИНЫЙ БАР: один фон на весь верх, содержимое внутри ──
    Rectangle {
        id: bar
        // плашка бара — всегда на всю ширину и только высотой строки.
        // Раскрытый режим живёт отдельной карточкой ниже (bubble), бар не сжимается.
        x: Theme.barMargin
        width: parent.width - 2 * Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barTop
        height: Theme.barH
        radius: Theme.barOuterRadius
        color: root.pillBg
        border.width: Theme.barOuterBorder
        border.color: Theme.border
        clip: true

        HoverHandler { onHoveredChanged: BarState.barHovered = hovered }

        // architect: верхняя кромка бара — как нижняя (акцент + рельса + узел)
        Rectangle {
            visible: Theme.arch
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: Theme.line
            color: Theme.accent
        }
        Rectangle {
            visible: Theme.arch
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.topMargin: 3
            height: Theme.line
            color: Theme.hair
        }
        Rectangle {
            visible: Theme.arch
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
            anchors.topMargin: 1
            width: 5
            height: 5
            color: Theme.hairAccent
        }
        // architect: линия по нижней кромке бара + скобки по углам
        Rectangle {
            visible: Theme.arch
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Theme.line
            color: Theme.accent
        }
        // парная тонкая линия — «рельса»
        Rectangle {
            visible: Theme.arch
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.bottomMargin: 3
            height: Theme.line
            color: Theme.hair
        }
        // центральный узел на линии
        Rectangle {
            visible: Theme.arch
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            anchors.bottomMargin: 1
            width: 5; height: 5
            color: Theme.hairAccent
        }

        // зерно: один тайл на весь бар, маска по скруглению
        Image {
            id: nzBar
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/noise.png")
            fillMode: Image.Tile
            smooth: false
            cache: true
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: nzBar
            maskEnabled: true
            maskSource: nmBar
            // зерно есть всегда — плашка теперь постоянная
            opacity: 0.07
        }
        Rectangle {
            id: nmBar
            anchors.fill: parent
            radius: Theme.barRadius
            color: "white"
            visible: false
            layer.enabled: true
        }

    }

    // ── маркер ячейки: короткое accent-подчёркивание внизу бара под открытой
    //    ячейкой — сразу видно, чей это пузырь (и куда вернётся после закрытия).
    Rectangle {
        id: cellMark
        visible: root.reveal > 0.001 && BarState.originX >= 0
        opacity: root.reveal
        width: 18
        height: 2
        radius: height / 2
        color: Theme.accent
        x: (BarState.originX >= 0 ? BarState.originX : root.width / 2) - width / 2
        y: Theme.barTop + Theme.barH - 2
    }

    // ── КАРТОЧКА-«ПУЗЫРЬ»: режим выпадает под ячейкой, бар остаётся. ──
    // Поверхность — та же, что у плашки бара (palette.barPill из мутагена):
    // меняются обои → обновляется palette.json → пузырь меняет тон вместе
    // с баром. Из анимации — только мягкое выпадение (без масштаба/пружины).
    Rectangle {
        id: bubble
        visible: root.reveal > 0.001
        opacity: root.reveal
        x: root.bubbleX
        y: root.bubbleY - (1 - root.reveal) * 10
        width: root.panelTargetW
        height: root.panelTargetH
        radius: Theme.barRadius
        color: Theme.barPill
        border.width: 1
        border.color: Theme.border
        clip: true
        transformOrigin: Item.Top

        HoverHandler { onHoveredChanged: BarState.panelHovered = hovered }

        // architect: линия по всей длине верхней кромки
        Rectangle {
            visible: Theme.arch
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: Theme.lineThick
            color: Theme.hairAccent
        }
        // architect: линия по нижней кромке
        Rectangle {
            visible: Theme.arch
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Theme.line
            color: Theme.hairAccent
        }

        // architect: визиры в полях (без диагоналей — панель и так «техничная»)
        HudCrosshairs { inset: 10; arm: 5 }
        HudNodes { inset: 5; size: 4 }
        HudInnerFrame { variant: 0 }

        // зерно в тон бару
        Image {
            id: nzPop
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/noise.png")
            fillMode: Image.Tile
            smooth: false
            cache: true
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: nzPop
            maskEnabled: true
            maskSource: nmPop
            opacity: 0.05
        }
        Rectangle {
            id: nmPop
            anchors.fill: parent
            radius: Theme.barRadius
            color: "white"
            visible: false
            layer.enabled: true
        }

        // HUD-скобки — тот же почерк, что у Hub (верх-лево / низ-право)
        Rectangle {
            width: 16; height: 1.5; color: Theme.alpha(Theme.accent, 0.30)
            anchors { top: parent.top; left: parent.left; margins: Theme.space2 }
        }
        Rectangle {
            width: 1.5; height: 16; color: Theme.alpha(Theme.accent, 0.30)
            anchors { top: parent.top; left: parent.left; margins: Theme.space2 }
        }
        Rectangle {
            width: 16; height: 1.5; color: Theme.alpha(Theme.accent, 0.30)
            anchors { bottom: parent.bottom; right: parent.right; margins: Theme.space2 }
        }
        Rectangle {
            width: 1.5; height: 16; color: Theme.alpha(Theme.accent, 0.30)
            anchors { bottom: parent.bottom; right: parent.right; margins: Theme.space2 }
        }

        // клик по фону карточки — закрыть (по кнопкам не срабатывает: они выше)
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: BarState.closePanel()
        }

            // ── ШАПКА ОСТРОВА: имя режима, действия, закрытие ──
            Item {
                id: panelHeader
                visible: root.panelHasHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.panelHeaderH

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.barPad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space2

                    SectionHeader {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.panelTitle
                        textColor: Theme.textDim
                        bold: false
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: BarState.mode === "notifs" && root.notifCount > 0
                        text: root.notifCount
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        font.bold: true
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.barPad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space3

                    // DND и «очистить» — только у уведомлений
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: BarState.mode === "notifs"
                        text: NotifModel.dnd ? "DND ВКЛ" : "DND"
                        color: NotifModel.dnd ? Theme.danger
                            : (dndHeadMouse.containsMouse ? Theme.accent : Theme.textFaint)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        font.letterSpacing: 1
                        MouseArea {
                            id: dndHeadMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotifModel.toggleDnd()
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: BarState.mode === "notifs"
                        text: "очистить"
                        color: clearHeadMouse.containsMouse ? Theme.accent : Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        MouseArea {
                            id: clearHeadMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotifModel.clear()
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"
                        color: headCloseMouse.containsMouse ? Theme.danger : Theme.textFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(13)
                        MouseArea {
                            id: headCloseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BarState.closePanel()
                        }
                    }
                }

                Rectangle {
                    visible: !Theme.arch
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.border
                }

                // architect: штриховая линия под шапкой + засечка-акцент
                DashedLine {
                    visible: Theme.arch
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.leftMargin: Theme.barPad
                    anchors.rightMargin: Theme.barPad
                    height: 1
                    dash: 5
                    gap: 5
                    lineColor: Theme.hairAccent
                }
                Rectangle {
                    visible: Theme.arch
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.barPad
                    width: 42
                    height: Theme.lineThick
                    color: Theme.hairAccent
                }
            }

            // ── МЕДИА: обложка, seek, транспорт, shuffle/repeat, очередь ──
            LunarMediaPanel {
                id: mediaPanel
                visible: BarState.mode === "media"
                opacity: root.panelContentOpacity
                width: parent.width - 2 * Theme.space3
                anchors.top: parent.top
                anchors.topMargin: Theme.panelHeaderH + Theme.space2
                anchors.horizontalCenter: parent.horizontalCenter
                onOpenPlayerRequested: root.openPlayer()
            }

            // ── ТЕЛЕМЕТРИЯ: плашки CPU · RAM · GPU + сеть ──
            PanelTelemetry { host: root; id: sysBody }

            // ── ЗВУК: вывод и вход — выбор устройства + ползунки ──
            PanelAudio { host: root; id: audioBody }

            // ── ПОГОДА: карточка «сейчас» + детали, компактным превью ──
            BarBubble {
                id: wxBody
                kind: "weather"
                visible: BarState.mode === "weather"
                anchors.top: parent.top
                anchors.topMargin: Theme.panelHeaderH + Theme.space2
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // ── ПОИСК ──
            PanelSearch { host: root; id: searchPanel }

            // ── УВЕДОМЛЕНИЯ ──
            PanelNotifs { host: root }
        }

    // ── СТРОКА БАРА: три зоны на всю ширину. Левая прижата к краю, правая —
    // к другому, ЧАСЫ стоят ровно по центру экрана и служат осью композиции. ──
    BarLeftZone {
        id: leftZone
        host: root
        anchors.top: parent.top
        anchors.topMargin: Theme.barTop
        anchors.left: parent.left
    }

    BarCenterZone {
        id: centerZone
        host: root
        anchors.top: parent.top
        anchors.topMargin: Theme.barTop
        anchors.horizontalCenter: parent.horizontalCenter
    }

    BarRightZone {
        id: rightZone
        host: root
        anchors.top: parent.top
        anchors.topMargin: Theme.barTop
        anchors.right: parent.right
    }

    // ── ГОРЯЧИЕ ЗОНЫ у краёв бара: ховер раскрывает сайдбар ──
    // Узкая полоса во всю высоту бара у левого/правого края. Dwell не даёт
    // случайно раскрыть при проносе курсора; выключено — по BarSettings.hotZone.
    Process { id: sidebarOpenProc; running: false }
    Process { id: rsidebarOpenProc; running: false }
    // открываю по ховеру через `hover`, а НЕ `open`: open пиннит панель
    // навсегда, и она висела поверх контента, перехватывая ввод
    function openSidebar() {
        sidebarOpenProc.command = ["bash", "-c", "qs ipc call sidebar hover"]
        sidebarOpenProc.running = true
    }
    function openRsidebar() {
        rsidebarOpenProc.command = ["bash", "-c", "qs ipc call rsidebar hover"]
        rsidebarOpenProc.running = true
    }

    Item {
        id: hotZoneLeft
        anchors.left: parent.left
        anchors.top: parent.top
        width: 5
        height: Theme.barH
        visible: BarSettings.hotZone && !BarState.expanded
        HoverHandler {
            onHoveredChanged: {
                if (hovered) hotZoneLeftTimer.restart()
                else hotZoneLeftTimer.stop()
            }
        }
        Timer {
            id: hotZoneLeftTimer
            interval: BarSettings.revealIn
            repeat: false
            onTriggered: root.openSidebar()
        }
    }

    Item {
        id: hotZoneRight
        anchors.right: parent.right
        anchors.top: parent.top
        width: 5
        height: Theme.barH
        visible: BarSettings.hotZone && !BarState.expanded
        HoverHandler {
            onHoveredChanged: {
                if (hovered) hotZoneRightTimer.restart()
                else hotZoneRightTimer.stop()
            }
        }
        Timer {
            id: hotZoneRightTimer
            interval: BarSettings.revealIn
            repeat: false
            onTriggered: root.openRsidebar()
        }
    }

    // ── REC: отдельная правая пилюля (видна только при записи) ──
    Rectangle {
        id: recPill
        visible: root.recording
        anchors.right: parent.right
        anchors.rightMargin: Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barTop
        height: Theme.barH
        radius: Theme.barRadius
        color: Theme.alpha(Theme.danger, 0.16)
        border.width: 1
        border.color: Theme.alpha(Theme.danger, 0.5)
        width: recPillRow.implicitWidth + 2 * Theme.barPad
        opacity: root.recording ? 1 : 0

        Row {
            id: recPillRow
            anchors.centerIn: parent
            spacing: Theme.space2
            Text {
                id: recPillDot
                anchors.verticalCenter: parent.verticalCenter
                text: "󰝥"
                color: Theme.danger
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(10)
                SequentialAnimation on opacity {
                    running: root.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "REC"
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.bold: true
                font.letterSpacing: 1
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleRecording()
        }
    }


}