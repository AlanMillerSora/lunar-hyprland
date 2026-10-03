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
//    единая плашка: LUNAR+фазы · PERF/раскладка · часы/медиа/пульт · статус
//  Ввод ловит только плашка (mask) — зазоры пропускают клики (важно для
//  fullscreen). exclusiveZone держит окна вне полосы бара. По клику плашка
//  сама раскрывается вниз и показывает панель режима (морф по мотивам
//  ArchEclipse: clip + opacity + scale).
// ────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    // окно выше бара — под выезжающую вниз панель (вариант 3)
    implicitHeight: Theme.barH + 500
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "lunar-panel"
    // клавиатуру забираю, пока открыт любой режим — чтобы Esc закрывал панель
    WlrLayershell.keyboardFocus: BarState.expanded
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // окна не заезжают только под полосу бара
    WlrLayershell.exclusiveZone: Theme.barH
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
        Region { item: root.recording ? recPill : null }
    }

    // фон-ловушка: есть только при открытой панели, самый нижний слой
    Item {
        id: clickShield
        anchors.fill: parent
        visible: BarState.expanded
        MouseArea {
            anchors.fill: parent
            onClicked: BarState.closePanel()
        }
    }

    // Esc закрывает открытый режим (поиск сам обрабатывает Esc — очистка)
    Shortcut {
        sequence: "Escape"
        enabled: BarState.expanded && BarState.mode !== "search"
        onActivated: BarState.closePanel()
    }
    // тот же Esc через Keys — надёжнее на layer-поверхности
    Item {
        anchors.fill: parent
        focus: BarState.expanded && BarState.mode !== "search"
        Keys.onEscapePressed: BarState.closePanel()
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

    // первый класс окна стола — для иконки приложения
    function firstClassFor(id) {
        var ws = root.wsFor(id)
        if (!ws || ws.toplevels.values.length === 0)
            return ""
        var t = ws.toplevels.values[0]
        var cls = (t.lastIpcObject && t.lastIpcObject.class) ? t.lastIpcObject.class : ""
        if (!cls && t.wayland)
            cls = t.wayland.appId || ""
        return cls
    }
    // класс окна → иконка темы (через DesktopEntries, как в лаунчере)
    function appIconFor(cls) {
        if (!cls)
            return ""
        var entry = null
        try {
            entry = DesktopEntries.heuristicLookup(cls)
        } catch (e) {}
        var ic = (entry && entry.icon) ? entry.icon : cls
        if (Quickshell.hasThemeIcon(ic))
            return Quickshell.iconPath(ic, true)
        if (cls && Quickshell.hasThemeIcon(cls))
            return Quickshell.iconPath(cls, true)
        return ""
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
        // «пик» на переключение: фаза на пару секунд показывает иконку стола
        if (root.focusedWsId > 0) {
            root.wsPeek = root.focusedWsId
            wsPeekTimer.restart()
        }
    }
    // стол, который сейчас «пикает» иконкой
    property int wsPeek: -1
    Timer {
        id: wsPeekTimer
        interval: 1400
        onTriggered: root.wsPeek = -1
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

    // Значок звука в баре открывает панель-пульт (там инлайн-громкость и мик).
    function openVolumePanel() { BarState.togglePanel("control") }

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
    Component.onCompleted: { root.refreshTray(); root.setTeleMark(true) }

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
    property bool dnd: false
    property int notifCount: 0
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
                    } else if (k === "dnd") {
                        root.dnd = (v === "1")
                    } else if (k === "notif") {
                        root.notifCount = parseInt(v) || 0
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
    Process { id: dndProc; running: false }
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
        dndProc.command = ["bash", "-c", "makoctl mode -t do-not-disturb"]
        dndProc.running = true
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

    // ─────────────── панель бара (вариант 3) ───────────────
    // Состояния (режим/пульс/холд) — в BarState; здесь только вид: морф,
    // размеры и геометрия. Всё реагирует на BarState.
    // Морф бара — только для «пульта»: плашка сама становится панелью.
    property real morph: 0
    Behavior on morph { Anim { type: Anim.DefaultSpatial } }
    // Раскрытие панели (все режимы): 0 — закрыто, 1 — открыто.
    property real panelOpen: BarState.mode !== "" ? 1 : 0
    Behavior on panelOpen { Anim { type: Anim.DefaultSpatial } }
    // высота панели по режиму (анимируется при смене режима)
    function panelHeightFor(m) {
        if (m === "control") return Theme.panelHeaderH + ctlBody.implicitHeight + Theme.space4
        if (m === "media") return Theme.panelHeaderH + mediaPanel.implicitHeight + Theme.space3
        if (m === "search") return Theme.panelHSearch
        if (m === "notifs") return Theme.panelHNotifs
        if (m === "sys") return Theme.panelHeaderH + sysBody.implicitHeight + Theme.space3
        if (m === "weather") return Theme.panelHeaderH + wxBody.implicitHeight + Theme.space3
        return Theme.barH
    }
    property real panelTargetH: root.panelHeightFor(BarState.mode)
    Behavior on panelTargetH { Anim { type: Anim.DefaultSpatial } }

    // ширина панели по режиму: пульт/поиск/уведы — фикс, медиа — по содержимому
    function panelWidthFor(m) {
        if (m === "control") return Theme.panelWControl
        if (m === "search") return Theme.panelWSearchWide
        if (m === "media") return mediaPanel.implicitWidth + 2 * Theme.space3
        if (m === "notifs") return Theme.panelWNotifs
        return Theme.panelWSearch
    }
    readonly property bool panelHasHeader: BarState.mode === "control"
        || BarState.mode === "notifs" || BarState.mode === "sys"
        || BarState.mode === "weather"
    readonly property string panelTitle: {
        if (BarState.mode === "control") return "ПУЛЬТ"
        if (BarState.mode === "media") return "МЕДИА"
        if (BarState.mode === "search") return "ПОИСК"
        if (BarState.mode === "notifs") return "УВЕДОМЛЕНИЯ"
        if (BarState.mode === "sys") return "ТЕЛЕМЕТРИЯ"
        if (BarState.mode === "weather") return "ПОГОДА"
        return ""
    }
    // появление контента режима (морфинг)
    property real panelContentOpacity: 1
    NumberAnimation {
        id: panelFade
        target: root
        property: "panelContentOpacity"
        to: 1
        duration: 180
        easing.type: Theme.easeOut
    }
    // игра — синхронизирую в BarState, чтобы пульсы не всплывали
    Binding {
        target: BarState
        property: "gameMode"
        value: root.gameMode
    }

    // панель закрывается кликом по её фону, Esc (поиск) или повторным режимом

    // IPC: qs ipc call bar control|media|search|notifs|reset
    IpcHandler {
        target: "bar"
        function volume() { root.openVolumePanel() }
        function control() { BarState.togglePanel("control") }
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
            // морф плашки — только для «пульта»; остальные режимы выезжают
            // карточкой снизу (см. panel)
            root.morph = (BarState.mode === "control" || BarState.mode === "search") ? 1 : 0
            root.panelContentOpacity = 0
            panelFade.restart()
            if (BarState.mode === "notifs")
                NotifModel.load()
            else if (BarState.mode === "search") {
                Launcher.open()
                Qt.callLater(function() { if (searchPanel) searchPanel.focusInput() })
            }
            if (BarState.mode !== "" && BarState.mode !== "search")
                statusProc.running = true
            // «пульт» содержит свой ползунок громкости — OSD при нём не дублирую
            Theme.barControlOpen = (BarState.mode === "control")
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
        // единый остров: в покое — строка по ширине содержимого и по центру
        // экрана; в режиме — плашка морфит к размеру панели (ширина/высота/
        // позиция), а строка бара растворяется. Часы держу по центру экрана.
        readonly property real collapsedW: (rightBar.x + rightBar.width) - leftBar.x
        readonly property real expandedW: root.panelWidthFor(BarState.mode) + 2 * Theme.barPad
        width: collapsedW + (expandedW - collapsedW) * root.morph
        x: leftBar.x + ((parent.width - width) / 2 - leftBar.x) * root.morph
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        height: Theme.barH + root.morph * (root.panelTargetH - Theme.barH)
        radius: Theme.barRadius
        color: root.pillBg
        border.width: 1
        border.color: Theme.border
        clip: true

        HoverHandler { onHoveredChanged: BarState.barHovered = hovered }

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

    // ── ЛЕВО: марка LUNAR + фазы столов — внутри единого бара ──
    // прижимаю группу к центральной, чтобы не было пустого разрыва
    Rectangle {
        id: leftBar
        anchors.right: midBar.left
        anchors.rightMargin: Theme.space3
        anchors.top: bar.top
        height: Theme.barH
        radius: Theme.barRadius
        color: "transparent"
        clip: true
        // строка бара растворяется до начала поджатия плашки
        opacity: Math.max(0, 1 - root.morph * 8)
        enabled: !BarState.expanded
        width: leftLayout.implicitWidth + 2 * Theme.barPad

        RowLayout {
            id: leftLayout
            anchors.fill: parent
            anchors.leftMargin: Theme.barPad
            anchors.rightMargin: Theme.barPad
            spacing: Theme.space3

            // ── марка LUNAR + фаза активного стола ──
            Row {
                Layout.alignment: Qt.AlignVCenter
                height: Theme.barCellH
                spacing: Theme.space2

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 21
                    height: 21
                    source: Qt.resolvedUrl("assets/logo.svg")
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "LUNAR " + (root.focusedPhase > 0
                        ? ("0" + root.focusedPhase).slice(-2) : "--")
                    color: Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    font.letterSpacing: 1.5
                }
            }

            // рабочие столы — компонент widgets/bar/BarWorkspaces
            BarWorkspaces { Layout.alignment: Qt.AlignVCenter; host: root }

            // (PERF и раскладка переехали в центральный бар)
        }
    }

    // ── СОДЕРЖИМОЕ ЦЕНТРА: PERF + раскладка (внутри единого бара) ──
    // Ячейки-сегменты: общий фон fill, слева короткий штрих-акцент.
    Rectangle {
        id: midBar
        anchors.right: centerPill.left
        anchors.top: bar.top
        height: Theme.barH
        color: "transparent"
        clip: true
        opacity: Math.max(0, 1 - root.morph * 8)
        enabled: !BarState.expanded
        width: midLayout.implicitWidth + 2 * Theme.space2

        Row {
            id: midLayout
            anchors.centerIn: parent
            height: Theme.barH
            spacing: Theme.space2

            // PERF: governor; штрих белый на performance, danger — если уехал
            Cell {
                anchors.verticalCenter: parent.verticalCenter
                tip: "CPU governor"
                accent: root.cpuGovernor === "performance" ? Theme.barDim : Theme.danger
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PERF"
                    color: root.cpuGovernor === "performance" ? Theme.barFaint : Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    font.bold: root.cpuGovernor !== "performance"
                }
            }

            // раскладка (клик — переключить)
            Cell {
                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                accent: Theme.barDim
                tip: "Раскладка — переключить"
                onClicked: root.switchLayout()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.kbLayout
                    color: Theme.barText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    font.bold: true
                }
            }
        }
    }

    // ── ПРАВО: статус (сеть · игра/запись · трей · уведомления · звук) ──
    Rectangle {
        id: rightBar
        anchors.left: centerPill.right
        anchors.top: bar.top
        height: Theme.barH
        color: "transparent"
        clip: true
        opacity: Math.max(0, 1 - root.morph * 8)
        enabled: !BarState.expanded
        width: rightLayout.implicitWidth + 2 * Theme.space2

        // ── статус: сеть · игра · трей · уведомления · звук ──
        Row {
            id: rightLayout
            anchors.centerIn: parent
            height: Theme.barH
            spacing: Theme.space2

            // систем-остров — компонент widgets/bar/SystemIsland
            SystemIsland { host: root }

            // ── погода: иконка + температура, клик обновляет ──
            Cell {
                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                accent: Theme.barFaint
                tip: "Погода"
                onClicked: BarState.togglePanel("weather")
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.icon
                        color: Weather.ok ? Theme.barText : Theme.barFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontBody
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.shortTemp
                        color: Weather.ok ? Theme.barText : Theme.barDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                    }
                }
            }

            // ── сеть: ДВУХЭТАЖНАЯ ячейка — иконка сверху, ↓/↑ мелко снизу ──
            Cell {
                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                accent: root.netKind === "off" ? Theme.barFaint : Theme.barDim
                tip: "Сеть (Hub)"
                onClicked: root.openNetwork()
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Row {
                        spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.netKind === "eth" ? "󰈀" : "\uf1eb"
                            color: root.netKind === "off" ? Theme.barFaint : Theme.barText
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontBody
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.netKind === "off" ? "нет" : (root.netKind === "eth" ? "eth" : "wifi")
                            color: Theme.barDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                        }
                    }
                    Text {
                        text: "↓" + SysInfo.fmtRate(SysInfo.rx) + " ↑" + SysInfo.fmtRate(SysInfo.tx)
                        color: Theme.barFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMicro
                    }
                }
            }

            // ── действия: Game Mode (REC вынесен отдельной пилюлей справа) ──
            Cell {
                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                accent: root.gameMode ? Theme.danger : Theme.barFaint
                tip: "Game Mode"
                onClicked: root.toggleGameMode()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf11b"
                    color: root.gameMode ? Theme.danger : Theme.barDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(15)
                }
            }

            // трей — компонент widgets/bar/BarTray
            BarTray { host: root }

            // ── уведомления · громкость — ячейками ──
            Cell {
                id: notifCell
                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                accent: root.notifCount > 0 ? Theme.accent : Theme.barFaint
                tip: "Уведомления"
                onClicked: BarState.togglePanel("notifs")
                // мягкий пульс на НОВОЕ уведомление (только рост счётчика).
                // Слушаю root через Connections: notifCount живёт на корне.
                property SequentialAnimation notifPulse: SequentialAnimation {
                    NumberAnimation {
                        target: notifCell; property: "scale"; to: 1.15
                        duration: Theme.animMed / 2; easing.type: Theme.easeOut
                    }
                    NumberAnimation {
                        target: notifCell; property: "scale"; to: 1.0
                        duration: Theme.animMed / 2; easing.type: Theme.easeOut
                    }
                }
                property Connections notifWatch: Connections {
                    target: root
                    function onNotifCountChanged() {
                        if (root.notifCount > root.prevNotifCount) {
                            notifCell.notifPulse.restart()
                            BarState.activate("notifs", 4000)
                        }
                        root.prevNotifCount = root.notifCount
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dnd ? "\uf1f6" : "\uf0f3"
                    color: BarState.mode === "notifs" ? Theme.accent
                        : (root.dnd ? Theme.barFaint
                           : (root.notifCount > 0 ? Theme.barText : Theme.barDim))
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(14)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.notifCount > 0
                    text: root.notifCount
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.bold: true
                }
            }

            // volume
            Cell {
                id: volCell
                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                accent: root.muted ? Theme.danger : Theme.barDim
                tip: "Звук"
                onClicked: root.openVolumePanel()
                // пульс на изменение громкости или mute
                property SequentialAnimation volPulse: SequentialAnimation {
                    NumberAnimation {
                        target: volCell; property: "scale"; to: 1.15
                        duration: Theme.animMed / 2; easing.type: Theme.easeOut
                    }
                    NumberAnimation {
                        target: volCell; property: "scale"; to: 1.0
                        duration: Theme.animMed / 2; easing.type: Theme.easeOut
                    }
                }
                property Connections volWatch: Connections {
                    target: root
                    function onVolChanged() { if (root.pulsePrimed) { volCell.volPulse.restart(); BarState.activate("control", 2500) } }
                    function onMutedChanged() { if (root.pulsePrimed) { volCell.volPulse.restart(); BarState.activate("control", 2500) } }
                }
                Item {
                    implicitWidth: volContent.implicitWidth
                    implicitHeight: 26
                    Row {
                        id: volContent
                        anchors.centerIn: parent
                        spacing: Theme.space2
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.muted
                                ? "󰖁"
                                : (root.vol < 0.34 ? "󰕿" : (root.vol < 0.67 ? "󰖀" : "󰕾"))
                            color: root.muted ? Theme.barFaint : Theme.barText
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(16)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.muted ? "mute" : Math.round(root.vol * 100) + "%"
                            color: Theme.barDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openMixer()
                    }
                    WheelHandler {
                        onWheel: (wheel) => root.bumpVol(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                    }
                }
            }
        }
    }

    // ── REC: отдельная правая пилюля (видна только при записи) ──
    Rectangle {
        id: recPill
        visible: root.recording
        anchors.right: parent.right
        anchors.rightMargin: Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        height: Theme.barH
        radius: Theme.barRadius
        color: Theme.alpha(Theme.danger, 0.16)
        border.width: 1
        border.color: Theme.alpha(Theme.danger, 0.5)
        width: recPillRow.implicitWidth + 2 * Theme.barPad
        opacity: (1 - root.morph) * (root.recording ? 1 : 0)

        Row {
            id: recPillRow
            anchors.centerIn: parent
            spacing: Theme.space2
            Text {
                id: recPillDot
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf111"
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
    // ── ЦЕНТР: часы/дата + медиа + кнопка пульта (внутри бара) ──
    Rectangle {
        id: centerPill
        // часы (последняя ячейка defRow) ставлю ровно на центр экрана: сдвигаю
        // плашку так, чтобы её правая ячейка легла центром на центр экрана, —
        // тогда ширина midBar/rightBar и рост медиа часы не двигают
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Theme.barPad + clockCell.width / 2 - centerPill.width / 2
        anchors.top: bar.top
        height: Theme.barH
        color: "transparent"
        clip: true
        opacity: Math.max(0, 1 - root.morph * 8)
        enabled: !BarState.expanded
        width: defRow.implicitWidth + 2 * Theme.barPad

        // колесо над плашкой — громкость
        WheelHandler {
            onWheel: function (ev) {
                root.bumpVol(ev.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }

        Row {
            id: defRow
            anchors.centerIn: parent
            height: Theme.barH
            spacing: Theme.space2

            // «пульт» — раскрывает панель управления вниз
            Cell {
                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                accent: BarState.mode === "control" ? Theme.accent : Theme.barDim
                tip: "Пульт · звук и действия"
                onClicked: BarState.togglePanel("control")
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf013"
                    color: BarState.mode === "control" ? Theme.accent : Theme.barDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(14)
                }
            }

            // медиа-ячейка — компонент widgets/bar/MediaCell
            MediaCell { host: root }

            // часы + дата — одна ячейка со штрихом-акцентом
            Cell {
                id: clockCell
                anchors.verticalCenter: parent.verticalCenter
                accent: Theme.accent
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    height: Theme.barCellH
                    spacing: 0
                    Text {
                        id: clockLabel
                        text: root.clockText.substring(0, 2)
                        color: Theme.barText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(Theme.fontClock)
                        font.bold: true
                        font.letterSpacing: 1
                        height: Theme.barCellH
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        id: clockColon
                        text: ":"
                        color: Theme.barText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(Theme.fontClock)
                        font.bold: true
                        height: Theme.barCellH
                        verticalAlignment: Text.AlignVCenter
                        opacity: root.colonOn ? 1.0 : 0.15
                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
                    }
                    Text {
                        id: clockMin
                        text: root.clockText.substring(3)
                        color: Theme.barText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(Theme.fontClock)
                        font.bold: true
                        font.letterSpacing: 1
                        height: Theme.barCellH
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Text {
                    id: dayLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dayText + " " + root.dateText
                    color: Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    height: Theme.barCellH
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // ── ПАНЕЛЬ: контент режима внутри раскрытой вниз плашки бара ──
    // Сама плашка растёт вниз; здесь — только контент (шапка + тело),
    // раскрывается из-под строки бара (clip + opacity + scale). Один режим.
    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: bar.top
        // «пульт» — внутри плашки; прочие режимы — карточкой под строкой бара
        anchors.topMargin: (BarState.mode === "control" || BarState.mode === "search") ? 0 : (Theme.barH + Theme.space1)
        width: root.panelWidthFor(BarState.mode)
        height: root.panelOpen * root.panelTargetH
        color: (BarState.mode === "control" || BarState.mode === "search") ? "transparent" : root.pillBg
        border.width: (BarState.mode === "control" || BarState.mode === "search") ? 0 : 1
        border.color: Theme.border
        radius: Theme.barRadius
        clip: true
        visible: root.panelOpen > 0.001
        opacity: root.panelOpen
        scale: 0.97 + 0.03 * root.panelOpen
        transformOrigin: Item.Top
        Behavior on width { Anim { type: Anim.DefaultSpatial } }

        HoverHandler { onHoveredChanged: BarState.panelHovered = hovered }

        // клик по фону панели — закрыть (по кнопкам не срабатывает: они выше)
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

                SectionLabel {
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
                    text: "\uf00d"
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
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.border
            }
        }

        // ── ПУЛЬТ: две колонки — слева звук и состояние, справа действия
        // и телеметрия. Ровный ритм: подписи секций + карточки.
        PanelControl { host: root; id: ctlBody }

        // ── МЕДИА: обложка, seek, транспорт, shuffle/repeat, очередь ──
        // Единый компонент LunarMediaPanel (источник — MediaCore/MPRIS).
        LunarMediaPanel {
            id: mediaPanel
            visible: BarState.mode === "media"
            opacity: root.panelContentOpacity
            anchors.top: parent.top
            anchors.topMargin: Theme.space3
            anchors.horizontalCenter: parent.horizontalCenter
            onOpenPlayerRequested: root.openPlayer()
        }

        // ── ТЕЛЕМЕТРИЯ: плашки CPU · RAM · GPU + сеть ──
        PanelTelemetry { host: root; id: sysBody }

        // ── ПОГОДА: крупная карточка «сейчас» + три плашки деталей ──
        PanelWeather { host: root; id: wxBody }

        // ── ПОИСК ──
        PanelSearch { host: root; id: searchPanel }

        // ── УВЕДОМЛЕНИЯ ──
        PanelNotifs { host: root }
    }

}
