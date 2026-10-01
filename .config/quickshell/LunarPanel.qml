import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

// ────────────────────────────────────────────────────────────────
//  Lunar top bar — монохромный HUD (две скруглённые части)
//    слева  : LUNAR + фазы 9 рабочих столов
//    справа : от конца столов до правого края; часы — ровно по центру
//             экрана, а медиа/сеть/статус/действия/CPU-RAM-°C-GPU/трей/звук
//    Панель резервирует место (exclusiveZone), окна не заходят под неё.
// ────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barH
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "lunar-panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: implicitHeight
    WlrLayershell.anchors.top: true
    WlrLayershell.anchors.left: true
    WlrLayershell.anchors.right: true
    exclusionMode: ExclusionMode.Normal

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

    // ─────────────── system stats ───────────────
    property int cpuPct: -1
    property int ramPct: -1
    property int tempC: -1
    property real _prevIdle: -1
    property real _prevTotal: -1

    function applySys(t) {
        var lines = t.trim().split("\n")
        var i
        if (lines.length > 0 && lines[0].indexOf("cpu") === 0) {
            var parts = lines[0].trim().split(/\s+/).slice(1).map(Number)
            var idle = (parts[3] || 0) + (parts[4] || 0)
            var total = 0
            for (i = 0; i < parts.length; i++)
                total += parts[i]
            if (root._prevTotal >= 0 && total > root._prevTotal)
                root.cpuPct = Math.max(0, Math.min(100,
                    Math.round(100 * (1 - (idle - root._prevIdle) / (total - root._prevTotal)))))
            root._prevIdle = idle
            root._prevTotal = total
        }
        var memTotal = 0, memAvail = 0, temp = -1
        for (i = 0; i < lines.length; i++) {
            var l = lines[i]
            if (l.indexOf("MemTotal:") === 0)
                memTotal = parseInt(l.split(/\s+/)[1])
            else if (l.indexOf("MemAvailable:") === 0)
                memAvail = parseInt(l.split(/\s+/)[1])
            else if (/^\d+$/.test(l.trim()))
                temp = Math.round(parseInt(l.trim()) / 1000)
        }
        if (memTotal > 0)
            root.ramPct = Math.round(100 * (memTotal - memAvail) / memTotal)
        if (temp > 0)
            root.tempC = temp
    }

    Process {
        id: sysProc
        running: false
        command: ["bash", "-c",
            "head -1 /proc/stat; " +
            "grep -E '^MemTotal:|^MemAvailable:' /proc/meminfo; " +
            "for h in /sys/class/hwmon/hwmon*; do " +
            "n=$(cat \"$h/name\" 2>/dev/null); " +
            "[ \"$n\" = k10temp ] && cat \"$h/temp1_input\"; done"]
        stdout: StdioCollector { onStreamFinished: root.applySys(text) }
    }
    // каждый замер — это bash + ~5 процессов, поэтому не чаще раза в 2 с
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!sysProc.running) sysProc.running = true
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
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    function bumpVol(d) {
        if (!sink || !sink.audio)
            return
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + d))
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

    // Клик по значку громкости открывает попап с крупным ползунком (LunarVolume)
    Process { id: volPanelProc; running: false }
    function openVolumePanel() {
        volPanelProc.command = ["bash", "-c", "qs ipc call volume toggle"]
        volPanelProc.running = true
    }

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
    Component.onCompleted: root.refreshTray()

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

    // тултип панели: показать текст над элементом
    function showTip(text, area) {
        if (!text) return
        var ci = root.contentItem
        var pt = ci ? area.mapToItem(ci, area.width / 2, 0) : Qt.point(0, 0)
        Theme.tooltipText = text
        Theme.tooltipX = Math.round(pt.x)
        Theme.tooltipShown = true
    }

    // тултип с названием приложения при наведении на значок трея
    function showTrayTip(item, area) {
        if (!item) return
        root.showTip(item.tooltipTitle || item.title || item.id || "", area)
    }

    // ─────────── сеть / раскладка / уведомления ───────────
    property string netKind: "off"      // eth | wifi | off
    property int netSignal: 0
    property real netDown: 0            // байт/с, приём
    property real netUp: 0              // байт/с, передача
    property string kbLayout: "EN"
    property string kbDevice: ""
    property bool dnd: false
    property int notifCount: 0
    property string gpuLoad: ""
    property real gpuEma: -1          // сглаживание gpu_busy_percent (APU дёргается 0/100)
    property string gpuTemp: ""
    property bool gameMode: false
    property string cpuGovernor: ""
    property bool recording: false
    readonly property int focusedPhase:
        (root.focusedWs && root.focusedWs.id > 0) ? root.focusedWs.id : 0

    Process {
        id: statusProc
        running: false
        command: ["bash", "-c", "~/.config/hypr/scripts/eclipse-status.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("\u001f")
                for (var i = 0; i < parts.length; i++) {
                    var kv = parts[i].split("=")
                    if (kv.length !== 2)
                        continue
                    var k = kv[0], v = kv[1]
                    if (k === "net") {
                        if (v.indexOf("wifi:") === 0) {
                            root.netKind = "wifi"
                            root.netSignal = parseInt(v.substring(5)) || 0
                        } else {
                            root.netKind = v
                            root.netSignal = 0
                        }
                    } else if (k === "kb") {
                        root.kbLayout = v
                    } else if (k === "kbdev") {
                        root.kbDevice = v
                    } else if (k === "dnd") {
                        root.dnd = (v === "1")
                    } else if (k === "notif") {
                        root.notifCount = parseInt(v) || 0
                    } else if (k === "gpu") {
                        var g = parseInt(v)
                        if (!isNaN(g)) {
                            root.gpuEma = (root.gpuEma < 0) ? g : (root.gpuEma * 0.6 + g * 0.4)
                            root.gpuLoad = String(Math.round(root.gpuEma))
                        }
                    } else if (k === "gput") {
                        root.gpuTemp = v
                    } else if (k === "gm") {
                        root.gameMode = (v === "1")
                    } else if (k === "pp") {
                        root.cpuGovernor = v
                    } else if (k === "rec") {
                        root.recording = (v === "1")
                    }
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: statusProc.running = true
    }

    // ── скорость сети (байт/с) из /proc/net/dev ───────────────
    // /proc/net/dev отдаёт счётчики байт с момента загрузки. Читаем
    // снимок мгновенно (cat), храним предыдущий снимок и время, дельту
    // и скорость считаем в QML. Так всплески между замерами не теряются
    // (окно — ровно интервал таймера), и нет спящего процесса.
    property double netRxPrev: -1
    property double netTxPrev: -1
    property double netTimePrev: 0

    Process {
        id: netProc
        running: false
        command: ["cat", "/proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                if (lines.length < 3)
                    return
                var rx = 0, tx = 0
                for (var i = 2; i < lines.length; i++) {
                    var line = lines[i]
                    var c = line.indexOf(":")
                    if (c < 0)
                        continue
                    if (line.substring(0, c).trim() === "lo")
                        continue
                    var p = line.substring(c + 1).trim().split(/\s+/)
                    if (p.length < 9)
                        continue
                    rx += parseInt(p[0]) || 0
                    tx += parseInt(p[8]) || 0
                }
                var now = Date.now()
                if (root.netRxPrev >= 0 && now > root.netTimePrev) {
                    var dt = (now - root.netTimePrev) / 1000
                    root.netDown = Math.max(0, (rx - root.netRxPrev) / dt)
                    root.netUp = Math.max(0, (tx - root.netTxPrev) / dt)
                }
                root.netRxPrev = rx
                root.netTxPrev = tx
                root.netTimePrev = now
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    // человекочитаемая скорость: КБ/с и МБ/с одной буквой, без дубля единицы
    function netFmt(bps) {
        if (bps < 1024)
            return Math.round(bps) + "Б"
        if (bps < 1048576)
            return (bps / 1024).toFixed(bps < 10240 ? 1 : 0) + "К"
        return (bps / 1048576).toFixed(1) + "М"
    }

    // По отдельному Process на каждое действие: общий процесс затирал команду,
    // если новое действие приходило, пока выполнялось предыдущее.
    Process { id: hubOpenProc; running: false }
    Process { id: layoutProc; running: false }
    Process { id: dndProc; running: false }
    Process { id: gameProc; running: false }
    Process { id: recordProc; running: false }
    Process {
        id: mediaPanelProc
        running: false
        command: ["qs", "ipc", "call", "media", "toggle"]
    }

    function openNetwork() {
        hubOpenProc.command = ["bash", "-c",
            "qs ipc call hub open; sleep 0.15; qs ipc call hub nav 4"]
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

    // ───────────────────────────── layout ─────────────────────────────
    // Две части бара: слева «LUNAR + фазы столов», справа — блок от конца
    // столов до правого края. Часы в правом блоке держатся ровно по
    // центру экрана, телеметрия — у правого края. Секции разделены 1px (Sep).
    // подсветка интерактивной секции при наведении
    component HoverBg: Rectangle {
        id: hb
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.hoverStrong
        opacity: hh.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        readonly property bool hovered: hh.hovered
        HoverHandler { id: hh }
    }

    // Живость как у 43PR: группа мягко подрастает под курсором.
    // scale — визуальный, раскладку не трогает, поэтому ничего не «плывёт».
    component Grow: Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    // Метрики моношрифта: по ним считаем ширины числовых полей, чтобы
    // цифры при скачках значений не дёргали раскладку.
    FontMetrics { id: fm11; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize(11) }
    FontMetrics { id: fm12; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize(12) }
    FontMetrics { id: fm13; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize(13) }
    FontMetrics { id: fm14; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize(14) }
    FontMetrics { id: fm15; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize(15) }
    // иконки из разных наборов Nerd Font бывают разной ширины — тоже чиним
    FontMetrics { id: fmIcon15; font.family: Theme.iconFont; font.pixelSize: Theme.fontSize(15) }
    FontMetrics { id: fmIcon17; font.family: Theme.iconFont; font.pixelSize: Theme.fontSize(17) }
    FontMetrics { id: fmIcon19; font.family: Theme.iconFont; font.pixelSize: Theme.fontSize(19) }

    // Дополнить строку слева пробелами до ширины w (моношрифт → ровно)
    function padNum(s, w) {
        s = "" + s
        while (s.length < w)
            s = " " + s
        return s
    }

    // ── ЛЕВАЯ ЧАСТЬ: марка LUNAR + рабочие столы ──
    Rectangle {
        id: leftBar
        anchors.left: parent.left
        anchors.leftMargin: Theme.barMargin
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        radius: Theme.barRadius
        color: root.pillBg
        clip: true
        width: leftLayout.implicitWidth + 2 * Theme.barPad

        // зерно на стекле: лежит под содержимым, чтобы буквы оставались чёткими
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/noise.png")
            fillMode: Image.Tile
            smooth: false
            cache: true
            opacity: 0.10
        }

        RowLayout {
            id: leftLayout
            anchors.fill: parent
            anchors.leftMargin: Theme.barPad
            anchors.rightMargin: Theme.barPad
            spacing: Theme.space3

            // ── марка LUNAR + фаза активного стола ──
            Row {
                Layout.alignment: Qt.AlignVCenter
                height: 26
                spacing: 8

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

            // ── рабочие столы: 9 фаз ──
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: wsRow.implicitWidth
                implicitHeight: 26
                scale: wsBg.hovered ? Theme.hoverGrow : 1
                Grow {}

                HoverBg { id: wsBg }

                // тонкая «орбита» за фазами — связывает индикаторы в цикл
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.active
                }

                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: 7

                    Repeater {
                        model: 9

                        delegate: Rectangle {
                            id: wsPill
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property var ws: root.wsFor(wsId)
                            readonly property bool isFocused: root.focusedWs !== null && root.focusedWs.id === wsId
                            readonly property bool isOccupied: ws !== null && ws.toplevels.values.length > 0

                            // импульс кольца при переходе на этот стол
                            onIsFocusedChanged: if (isFocused) focusPulse.restart()

                            width: 28
                            height: 26
                            color: "transparent"

                            // мягкое гало под активной фазой — «стол светится»
                            Rectangle {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                radius: 14
                                color: Theme.alpha(Theme.accent, wsPill.isFocused ? 0.10 : 0)
                                Behavior on color { ColorAnimation { duration: Theme.animMed } }
                            }

                            // тонкое кольцо-выделение активного стола
                            Rectangle {
                                id: focusRing
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                radius: 12
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.alpha(Theme.accent, 0.55)
                                opacity: 0.55
                                visible: wsPill.isFocused
                            }

                            // короткий импульс: вспышка + лёгкое расширение
                            ParallelAnimation {
                                id: focusPulse
                                SequentialAnimation {
                                    NumberAnimation {
                                        target: focusRing
                                        property: "scale"
                                        from: 1.0
                                        to: 1.4
                                        duration: 140
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: focusRing
                                        property: "scale"
                                        from: 1.4
                                        to: 1.0
                                        duration: 160
                                        easing.type: Easing.InCubic
                                    }
                                }
                                SequentialAnimation {
                                    NumberAnimation {
                                        target: focusRing
                                        property: "opacity"
                                        from: 1.0
                                        to: 0.55
                                        duration: 300
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            // только сама фаза; состояние — яркостью (активный — чистый белый)
                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: Qt.resolvedUrl("assets/moon-phases/phase_"
                                    + ("0" + (index + 1)).slice(-2) + ".svg")
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                opacity: wsPill.isFocused
                                    ? 1.0
                                    : (wsMouse.containsMouse ? 0.85 : (wsPill.isOccupied ? 0.78 : 0.26))
                                scale: wsPill.isFocused
                                    ? 1.15
                                    : (wsMouse.containsMouse ? 1.1 : (wsPill.isOccupied ? 1.07 : 1.0))
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                Behavior on scale { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                onClicked: root.focusWs(wsPill.wsId)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── ПРАВАЯ ЧАСТЬ: от конца столов до правого края ──
    // Часы — ровно по центру экрана, телеметрия/управление — у правого края.
    Rectangle {
        id: rightBar
        anchors.right: parent.right
        anchors.rightMargin: Theme.barMargin
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        radius: Theme.barRadius
        color: root.pillBg
        clip: true
        width: rightLayout.implicitWidth + 2 * Theme.barPad

        // зерно на стекле: лежит под содержимым, чтобы буквы оставались чёткими
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/noise.png")
            fillMode: Image.Tile
            smooth: false
            cache: true
            opacity: 0.10
        }

        // ── телеметрия и управление: прижаты к правому краю ──
        RowLayout {
            id: rightLayout
            anchors.fill: parent
            anchors.leftMargin: Theme.barPad
            anchors.rightMargin: Theme.barPad
            spacing: Theme.space3

            // ── сеть: скорость + иконка подключения (клик — сети в Hub) ──
            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 10
                implicitWidth: netRow.implicitWidth
                implicitHeight: 26
                scale: netBg.hovered ? Theme.hoverGrow : 1
                Grow {}

                HoverBg { id: netBg }

                Row {
                    id: netRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: 6

                    // стрелка и число — отдельно: число в поле фикс. ширины
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰁅"
                        color: Theme.barDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fm15.advanceWidth("00.0K")
                        text: root.netFmt(root.netDown)
                        color: Theme.barText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰁝"
                        color: Theme.barDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fm15.advanceWidth("00.0K")
                        text: root.netFmt(root.netUp)
                        color: Theme.barText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(fmIcon17.advanceWidth("󰈀"), fmIcon17.advanceWidth("\uf1eb"))
                        text: root.netKind === "eth" ? "󰈀" : "\uf1eb"
                        color: root.netKind === "off" ? Theme.barFaint : Theme.barText
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(17)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openNetwork()
                }
            }

            // ── действия: Game Mode / питание / запись ──
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: actionRow.implicitWidth
                implicitHeight: 26
                scale: actBg.hovered ? Theme.hoverGrow : 1
                Grow {}
                HoverBg { id: actBg }
                Row {
                    id: actionRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: Theme.space3

                    // Game Mode (клик — переключить)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf11b"
                        color: root.gameMode ? Theme.danger : Theme.barDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(17)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleGameMode()
                        }
                    }

                    // питание: CPU всегда performance, powersave убран.
                    // Красный — сигнал, что юнит не сработал и governor не performance.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fm13.advanceWidth("PERF")
                        text: "PERF"
                        color: root.cpuGovernor === "performance" ? Theme.accent : Theme.danger
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(13)
                        font.bold: true
                    }

                    // запись экрана
                    Rectangle {
                        width: fm11.advanceWidth("● REC") + 20
                        height: 24
                        radius: Theme.radius
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.recording
                            ? Theme.alpha(Theme.danger, 0.16)
                            : (recMouse.containsMouse ? Theme.alpha(Theme.danger, 0.08) : "transparent")
                        border.width: 1
                        border.color: root.recording ? Theme.danger : Theme.borderAccent

                        Text {
                            id: recLabel
                            anchors.centerIn: parent
                            text: root.recording ? "■ REC" : "● REC"
                            color: root.recording ? Theme.danger : Theme.barDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.bold: root.recording
                        }
                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleRecording()
                        }
                    }
                }
            }

            // ── статистика: [CPU °] [RAM] [GPU °] ──
            // Иконки (приглушённые) + значения (белые) + температуры (dim),
            // группы разделены тонкими линиями. Числа — фикс. ширины.
            Row {
                id: statsRow
                Layout.alignment: Qt.AlignVCenter
                height: 26
                spacing: Theme.space3

                // — процессор: загрузка + температура —
                Item {
                    id: cpuGrp
                    height: 26
                    implicitWidth: cpuRow.implicitWidth
                    scale: hCpu.hovered ? Theme.hoverGrow : 1
                    Grow {}
                    HoverHandler { id: hCpu }

                    Row {
                        id: cpuRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            text: "\uf4bc"
                            color: Theme.barFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(14)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: fm14.advanceWidth("100%")
                            text: root.padNum(root.cpuPct < 0 ? "--%" : root.cpuPct + "%", 4)
                            color: Theme.barText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            visible: root.tempC > 0
                            text: "\uf2c8"
                            color: Theme.barFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(13)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            visible: root.tempC > 0
                            width: fm14.advanceWidth("100°")
                            text: root.padNum(root.tempC + "°", 4)
                            color: Theme.barDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: root.showTip("процессор: загрузка и температура", cpuGrp)
                        onExited: Theme.tooltipShown = false
                    }
                }

                // — оперативная память —
                Item {
                    id: ramGrp
                    height: 26
                    implicitWidth: ramRow.implicitWidth
                    scale: hRam.hovered ? Theme.hoverGrow : 1
                    Grow {}
                    HoverHandler { id: hRam }

                    Row {
                        id: ramRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            text: "\u{F035B}"
                            color: Theme.barFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(14)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: fm14.advanceWidth("100%")
                            text: root.padNum(root.ramPct < 0 ? "--%" : root.ramPct + "%", 4)
                            color: Theme.barText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: root.showTip("оперативная память: занято", ramGrp)
                        onExited: Theme.tooltipShown = false
                    }
                }

                // — видеокарта: загрузка + температура —
                Item {
                    id: gpuGrp
                    visible: root.gpuLoad !== ""
                    height: 26
                    implicitWidth: gpuRow.implicitWidth
                    scale: hGpu.hovered ? Theme.hoverGrow : 1
                    Grow {}
                    HoverHandler { id: hGpu }

                    Row {
                        id: gpuRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            text: "\uf108"
                            color: Theme.barFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(14)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: fm14.advanceWidth("100%")
                            text: root.padNum(root.gpuLoad + "%", 4)
                            color: Theme.barText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            visible: root.gpuTemp !== ""
                            text: "\uf2c8"
                            color: Theme.barFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(13)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            visible: root.gpuTemp !== ""
                            width: fm14.advanceWidth("100°")
                            text: root.padNum(root.gpuTemp + "°", 4)
                            color: Theme.barDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: root.showTip("видеокарта: загрузка и температура", gpuGrp)
                        onExited: Theme.tooltipShown = false
                    }
                }
            }

            // ── трей: место под значки (Theme.trayVisible), лишние — в «+N» ──
            Item {
                Layout.alignment: Qt.AlignVCenter
                // место ровно под видимые значки (не под весь лимит); при
                // переполнении добавляю ещё и ширину плашки «+N»
                implicitWidth: {
                    var vis = Math.min(root.trayCount, root.trayMax)
                    return vis * 20 + Math.max(0, vis - 1) * 9
                        + (root.trayCount > root.trayMax ? moreBox.width + 9 : 0)
                }
                implicitHeight: 26

                scale: trayBg.hovered ? Theme.hoverGrow : 1
                Grow {}
                HoverBg { id: trayBg; visible: root.trayCount > 0 }

                Row {
                    id: trayRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    spacing: 9

                    Repeater {
                        model: root.trayItems

                        delegate: Item {
                            required property var modelData
                            width: 20
                            height: 26

                            Image {
                                id: trayImg
                                anchors.centerIn: parent
                                source: root.trayIconSource(modelData)
                                sourceSize.width: 18
                                sourceSize.height: 18
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                                visible: source != "" && status !== Image.Error
                            }

                            // если у приложения нет иконки — точка-фолбэк
                            Text {
                                anchors.centerIn: parent
                                visible: !trayImg.visible
                                text: "\uf111"
                                color: Theme.barFaint
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(8)
                            }

                            MouseArea {
                                id: trayIconMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.showTrayTip(modelData, trayIconMouse)
                                onExited: Theme.tooltipShown = false
                                onClicked: function (m) {
                                    if (m.button === Qt.MiddleButton) {
                                        modelData.secondaryActivate()
                                    } else if (m.button === Qt.RightButton) {
                                        root.trayMenu(modelData, trayIconMouse, m.x, m.y)
                                    } else if (root.isSteamApp(modelData)) {
                                        root.openTrayApp(modelData)
                                    } else if (modelData.onlyMenu && modelData.hasMenu) {
                                        root.trayMenu(modelData, trayIconMouse, m.x, m.y)
                                    } else {
                                        modelData.activate()
                                    }
                                }
                            }
                        }
                    }

                    // сколько значков не влезло — открыть список
                    Rectangle {
                        id: moreBox
                        visible: root.trayCount > root.trayMax
                        width: moreText.implicitWidth + 20
                        height: 24
                        radius: Theme.radius
                        anchors.verticalCenter: parent.verticalCenter
                        color: moreMouse.containsMouse ? Theme.active : "transparent"
                        border.width: 1
                        border.color: moreMouse.containsMouse ? Theme.accent : Theme.borderAccent

                        Text {
                            id: moreText
                            anchors.centerIn: parent
                            text: "+" + (root.trayCount - root.trayMax)
                            color: moreMouse.containsMouse ? Theme.accent : Theme.barDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.bold: true
                        }

                        MouseArea {
                            id: moreMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTip("свёрнутые приложения", moreMouse)
                            onExited: Theme.tooltipShown = false
                            onClicked: root.openTrayPanel()
                        }
                    }
                }
            }

            // ── раскладка · уведомления · громкость — у самого края ──
            Item {
                Layout.alignment: Qt.AlignVCenter
                // отступ от трея, чтобы «+N» не сливалась с раскладкой «RU»
                Layout.leftMargin: 10
                implicitWidth: rightRow.implicitWidth
                implicitHeight: 26
                scale: rrBg.hovered ? Theme.hoverGrow : 1
                Grow {}
                HoverBg { id: rrBg }
                Row {
                    id: rightRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: Theme.space3

                    // раскладка (клик — переключить)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fm14.advanceWidth("EN")
                        text: root.kbLayout
                        color: Theme.barText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(14)
                        font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchLayout()
                        }
                    }

                    // уведомления / «не беспокоить» (клик — переключить)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(fmIcon15.advanceWidth("\uf1f6"), fmIcon15.advanceWidth("\uf0f3"))
                        text: root.dnd ? "\uf1f6" : "\uf0f3"
                        color: root.dnd
                            ? Theme.barFaint
                            : (root.notifCount > 0 ? Theme.barText : Theme.barDim)
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(15)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleDnd()
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fm13.advanceWidth("999")
                        text: root.notifCount > 0 ? root.notifCount : ""
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(13)
                        font.bold: true
                    }

                    // volume
                    Item {
                        width: volRow.implicitWidth
                        height: 26

                        Row {
                            id: volRow
                            anchors.centerIn: parent
                            height: 26
                            spacing: 6

                            Text {
                                width: Math.max(fmIcon19.advanceWidth("󰖁"), fmIcon19.advanceWidth("󰕿"),
                                                fmIcon19.advanceWidth("󰖀"), fmIcon19.advanceWidth("󰕾"))
                                text: root.muted
                                    ? "󰖁"
                                    : (root.vol < 0.34 ? "󰕿" : (root.vol < 0.67 ? "󰖀" : "󰕾"))
                                color: root.muted ? Theme.barFaint : Theme.barText
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(19)
                                height: 26
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                width: fm14.advanceWidth("100%")
                                text: root.muted ? "mute" : Math.round(root.vol * 100) + "%"
                                color: Theme.barDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(14)
                                height: 26
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton)
                                    root.openMixer()
                                else
                                    root.openVolumePanel()
                            }
                            onWheel: function (wheel) {
                                root.bumpVol(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                            }
                        }
                    }
                }
            }
        }
    }
    // ── ЦЕНТР: часы и дата; медиа встаёт рядом, только когда играет ──
    // В покое остров маленький — центр дышит. Играет музыка — слева от часов
    // вырастают столбики cava и бегущее название, не задевая часы.
    Rectangle {
        id: centerBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        radius: Theme.barRadius
        color: root.pillBg
        clip: true
        width: centerRow.implicitWidth + 2 * Theme.barPad
        scale: clockHover.hovered ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        HoverHandler { id: clockHover }

        // зерно на стекле: лежит под содержимым, чтобы буквы оставались чёткими
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/noise.png")
            fillMode: Image.Tile
            smooth: false
            cache: true
            opacity: 0.10
        }

        Row {
            id: centerRow
            anchors.centerIn: parent
            height: 26
            spacing: Theme.space3

            // ── медиа: только когда играет ──
            // Item-обёртка: MouseArea нельзя класть прямо в Row
            // (anchors.fill внутри Row — ошибка верстки)
            Item {
                id: centerMedia
                visible: root.mediaActive
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: centerMediaRow.implicitWidth
                implicitHeight: 26

                Row {
                    id: centerMediaRow
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    spacing: Theme.space2

                    // столбики cava — фиксированные, чтобы не плясали
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        spacing: 2

                        Repeater {
                            model: root.barCount

                            delegate: Item {
                                required property int index
                                width: 3
                                height: 26

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
                                    width: parent.width
                                    height: 2 + (root.barValues[index] || 0) * 18
                                    radius: 1
                                    color: Theme.alpha(Theme.accent, 0.5 + 0.5 * (root.barValues[index] || 0))
                                }
                            }
                        }
                    }

                    Text {
                        id: centerNote
                        width: 18
                        height: 26
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: root.playing ? "\uf04c" : "\uf04b"
                        color: root.playing ? Theme.accent : Theme.barFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(13)
                    }

                    // название трека: в покое — с многоточием, на ходу — плавная
                    // непрерывная прокрутка (две копии), без рывков по символам
                    Item {
                        id: centerTrack
                        width: 170
                        height: 26
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            visible: !root.playing
                            elide: Text.ElideRight
                            text: root.track
                            color: Theme.barText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 26
                            clip: true
                            visible: root.playing

                            Row {
                                id: marqRow
                                spacing: 28
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: marqA
                                    text: root.track
                                    color: Theme.barText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                }
                                Text {
                                    text: root.track
                                    color: Theme.barText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                }

                                // едет только если строка шире поля; линейно и бесшовно
                                NumberAnimation on x {
                                    running: root.playing && marqA.width > centerTrack.width
                                    loops: Animation.Infinite
                                    from: 0
                                    to: -(marqA.width + marqRow.spacing)
                                    duration: Math.max(4000, (marqA.width + marqRow.spacing) * 26)
                                    easing.type: Easing.Linear
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 14
                        color: Theme.border
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mediaPanelProc.running = true   // попап «сейчас играет»
                }
            }

            // ── часы + дата ──
            Row {
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                spacing: Theme.space3

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    spacing: 0

                    Text {
                        id: clockLabel
                        text: root.clockText.substring(0, 2)
                        color: Theme.barText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(Theme.fontClock)
                        font.bold: true
                        font.letterSpacing: 1
                        height: 26
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        id: clockColon
                        text: ":"
                        color: Theme.barText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(Theme.fontClock)
                        font.bold: true
                        font.letterSpacing: 1
                        height: 26
                        verticalAlignment: Text.AlignVCenter
                        opacity: root.colonOn ? 1.0 : 0.15
                        // длительность заметно меньше периода (500 мс), иначе
                        // анимация не успевает затихнуть и двоеточие «плывёт»
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
                        height: 26
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    id: dayLabel
                    text: root.dayText + " " + root.dateText
                    color: Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

}
