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

// ────────────────────────────────────────────────────────────────
//  Lunar top bar — монохромный HUD
//    слева  : LUNAR + фазы столов (отдельная плашка)
//    справа : один компактный бар — PERF · раскладка · часы/медиа/пульт · статус
//  Панель во всю ширину, но ввод ловят только сами плашки (mask) —
//  зазоры пропускают клики (важно для fullscreen). exclusiveZone
//  держит окна вне полосы бара. Морф — по мотивам ArchEclipse.
// ────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    // окно выше бара — под выезжающую вниз панель (вариант 3)
    implicitHeight: Theme.barH + 320
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "lunar-panel"
    // фокус нужен только пока открыт поиск (ввод)
    WlrLayershell.keyboardFocus: root.panelMode === "search"
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // окна не заезжают только под полосу бара
    WlrLayershell.exclusiveZone: Theme.barH
    WlrLayershell.anchors.top: true
    WlrLayershell.anchors.left: true
    WlrLayershell.anchors.right: true
    exclusionMode: ExclusionMode.Normal

    // клик-сквозь: ввод ловят левая плашка, бар и раскрытая панель
    mask: Region {
        Region { item: leftBar }
        Region { item: bar }
        Region { item: root.expanded ? panel : null }
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
    property string kbLayout: "EN"
    property string kbDevice: ""
    property bool dnd: false
    property int notifCount: 0
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

    // ─────────────── панель бара (вариант 3) ───────────────
    // Бар в покое — одна строка; по клику вниз выезжает панель одного из
    // режимов: пульт · медиа · поиск · уведомления. Контент разворачивается
    // (clip+opacity); повторный клик, Esc или уход курсора — свернуть.
    property string panelMode: ""   // "" | control | media | search | notifs
    readonly property bool expanded: panelMode !== ""
    property bool panelHovered: false
    property bool barHovered: false

    function openPanel(name) { panelMode = name }
    function closePanel() { panelMode = "" }
    function togglePanel(name) { panelMode = (panelMode === name ? "" : name) }

    // панель сама закрывается, когда курсор ушёл и с бара, и с панели
    Timer {
        id: awayClose
        interval: 500
        repeat: false
        onTriggered: { if (!root.barHovered && !root.panelHovered) root.closePanel() }
    }
    onBarHoveredChanged: { if (!root.barHovered && !root.panelHovered) awayClose.restart(); else awayClose.stop() }
    onPanelHoveredChanged: { if (!root.barHovered && !root.panelHovered) awayClose.restart(); else awayClose.stop() }

    // IPC: qs ipc call bar control|media|search|notifs|reset
    IpcHandler {
        target: "bar"
        function volume() { root.openVolumePanel() }
        function control() { root.togglePanel("control") }
        function media() { root.togglePanel("media") }
        function search() { root.togglePanel("search") }
        function notifs() { root.togglePanel("notifs") }
        function reset() { root.closePanel() }
    }

    // ── поиск в панели (общий SearchModel) ──
    property string searchQuery: ""
    property var searchResults: []
    property int searchIndex: 0
    Timer {
        id: searchDebounce
        interval: 120
        repeat: false
        onTriggered: {
            root.searchResults = SearchModel.search(root.searchQuery)
            root.searchIndex = 0
        }
    }
    function setSearchQuery(q) {
        root.searchQuery = q
        searchDebounce.restart()
    }
    function moveSearch(d) {
        if (root.searchResults.length === 0) return
        root.searchIndex = (root.searchIndex + d + root.searchResults.length) % root.searchResults.length
    }
    function runSearch() {
        var r = root.searchResults[root.searchIndex]
        SearchModel.activate(r)
        root.closePanel()
        root.searchQuery = ""
        root.searchResults = []
        root.searchIndex = 0
    }

    // при открытии режима: уведы — обновить, поиск — фокус на поле
    onPanelModeChanged: {
        if (panelMode === "notifs")
            NotifModel.load()
        else if (panelMode === "search")
            Qt.callLater(function() { if (searchInput) searchInput.forceActiveFocus() })
        else {
            searchQuery = ""
            searchResults = []
        }
    }

    // быстрые действия «пульта»
    Process { id: powerProc; running: false }
    Process { id: hubToggleProc; running: false }
    Process { id: wallpapersProc; running: false }
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
    // Слева отдельная плашка LUNAR+фазы. Справа — один компактный бар:
    // PERF · раскладка · часы/медиа/пульт · статус (по ширине содержимого).
    // Подсветка интерактивной секции при наведении.
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
        // один компактный бар по центру (по ширине содержимого)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        width: midBar.width + centerPill.width + rightBar.width
        height: Theme.barH
        radius: Theme.barRadius
        color: root.pillBg
        clip: true

        HoverHandler { onHoveredChanged: root.barHovered = hovered }

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

    // ── ЛЕВО: марка LUNAR + фазы столов (отдельная плашка) ──
    Rectangle {
        id: leftBar
        anchors.left: parent.left
        anchors.leftMargin: Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        height: Theme.barH
        radius: Theme.barRadius
        color: root.pillBg
        clip: true
        width: leftLayout.implicitWidth + 2 * Theme.barPad

        // зерно на стекле: маска по скруглению — углы плашки остаются чистыми
        Image {
            id: nzL
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
            source: nzL
            maskEnabled: true
            maskSource: nmL
            opacity: 0.07
        }
        Rectangle {
            id: nmL
            anchors.fill: parent
            radius: Theme.barRadius
            color: "white"
            visible: false
            layer.enabled: true
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
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

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

            // (PERF и раскладка переехали в центральный бар)
        }
    }

    // ── СОДЕРЖИМОЕ ЦЕНТРА: PERF + раскладка (внутри единого бара) ──
    Rectangle {
        id: midBar
        anchors.left: bar.left
        anchors.verticalCenter: bar.verticalCenter
        height: Theme.barH
        color: "transparent"
        clip: true
        width: midLayout.implicitWidth + 2 * Theme.barPad

        RowLayout {
            id: midLayout
            anchors.fill: parent
            anchors.leftMargin: Theme.barPad
            anchors.rightMargin: Theme.barPad
            spacing: Theme.space3

            // ── PERF: governor; краснеет, если уехал с performance ──
            Text {
                Layout.alignment: Qt.AlignVCenter
                width: fm13.advanceWidth("PERF")
                text: "PERF"
                color: root.cpuGovernor === "performance" ? Theme.barFaint : Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.bold: root.cpuGovernor !== "performance"
            }

            // ── раскладка (клик — переключить) ──
            Text {
                Layout.alignment: Qt.AlignVCenter
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
        }
    }

    // ── ПРАВО: статус (сеть · игра/запись · трей · уведомления · звук) ──
    Rectangle {
        id: rightBar
        anchors.left: centerPill.right
        anchors.verticalCenter: bar.verticalCenter
        height: Theme.barH
        color: "transparent"
        clip: true
        width: rightLayout.implicitWidth + 2 * Theme.barPad

        // ── статус: сеть · игра/запись · трей · уведомления · звук ──
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
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                HoverBg { id: netBg }

                Row {
                    id: netRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: 6

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
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
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

                    // запись экрана — показываю только когда пишу
                    Rectangle {
                        visible: root.recording
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
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
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
                                visible: false
                            }

                            // монохром: значок трея в тон панели (как иконки лаунчера),
                            // чтобы цветные логи приложений не пестрили в баре
                            MultiEffect {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: trayImg
                                visible: trayImg.source != "" && trayImg.status !== Image.Error
                                saturation: -1.0
                                brightness: 0.12
                                contrast: 0.08
                            }

                            // если у приложения нет иконки — точка-фолбэк
                            Text {
                                anchors.centerIn: parent
                                visible: !(trayImg.source != "" && trayImg.status !== Image.Error)
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

            // ── уведомления · громкость ──
            Item {
                Layout.alignment: Qt.AlignVCenter
                // отступ от трея, чтобы «+N» не сливалась с раскладкой «RU»
                Layout.leftMargin: 10
                implicitWidth: rightRow.implicitWidth
                implicitHeight: 26
                scale: rrBg.hovered ? Theme.hoverGrow : 1
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                HoverBg { id: rrBg }
                Row {
                    id: rightRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: Theme.space3

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
    // ── ЦЕНТР: часы/дата + медиа + кнопка пульта (внутри бара) ──
    Rectangle {
        id: centerPill
        anchors.left: midBar.right
        anchors.verticalCenter: bar.verticalCenter
        height: Theme.barH
        color: "transparent"
        clip: true
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
            height: 26
            spacing: Theme.space3

            // «пульт» — раскрывает панель управления вниз
            Item {
                id: ctlBtn
                width: 18
                height: 26
                Text {
                    anchors.centerIn: parent
                    text: "\uf013"
                    color: root.panelMode === "control" ? Theme.accent : Theme.barDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(14)
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.showTip("пульт: игра · запись · питание · Hub · поиск", ctlBtn)
                    onExited: Theme.tooltipShown = false
                    onClicked: root.togglePanel("control")
                }
            }

            // медиа-полоса (только когда играет) — клик раскрывает панель медиа
            Item {
                id: mediaInline
                visible: root.mediaActive
                width: inlineRow.implicitWidth
                height: 26
                Row {
                    id: inlineRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: Theme.space2
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        spacing: 2
                        Repeater {
                            model: 10
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
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.playing ? "\uf04c" : "\uf04b"
                        color: root.playing ? Theme.accent : Theme.barFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(12)
                    }
                    Item {
                        id: inlineTrack
                        width: 150
                        height: 26
                        clip: true
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            elide: Text.ElideRight
                            text: root.track
                            color: Theme.barText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePanel("media")
                }
            }

            // часы + дата
            Row {
                id: clockRow
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

    // ── ПАНЕЛЬ: выезжает вниз от бара (вариант 3) ──
    // Один режим за раз: пульт · медиа · поиск · уведомления.
    Rectangle {
        id: panel
        anchors.top: bar.bottom
        anchors.topMargin: Theme.space1
        anchors.horizontalCenter: bar.horizontalCenter
        width: Math.max(bar.width, 400)
        height: root.expanded ? 320 : 0
        radius: Theme.barRadius
        color: root.pillBg
        clip: true
        visible: height > 1
        Behavior on height { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

        // зерно
        Image {
            id: nzP
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
            source: nzP
            maskEnabled: true
            maskSource: nmP
            opacity: 0.07
        }
        Rectangle {
            id: nmP
            anchors.fill: parent
            radius: Theme.barRadius
            color: "white"
            visible: false
            layer.enabled: true
        }

        HoverHandler { onHoveredChanged: root.panelHovered = hovered }

        // ── ПУЛЬТ ──
        Row {
            visible: root.panelMode === "control"
            anchors.left: parent.left
            anchors.leftMargin: Theme.barPad
            anchors.top: parent.top
            anchors.topMargin: Theme.barPad
            spacing: Theme.space3

            Repeater {
                model: [
                    { g: "\uf11b", tip: "игровой режим", on: root.gameMode, act: "game" },
                    { g: "\uf111", tip: "запись экрана", on: root.recording, act: "rec" },
                    { g: "\uf011", tip: "питание", on: false, act: "power" },
                    { g: "\uf009", tip: "Hub", on: false, act: "hub" },
                    { g: "\uf1eb", tip: "сеть", on: false, act: "net" },
                    { g: "\uf03e", tip: "обои", on: false, act: "wall" },
                    { g: "\uf002", tip: "поиск", on: root.panelMode === "search", act: "search" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 30
                    height: 28
                    radius: Theme.radius
                    color: modelData.on
                        ? Theme.alpha(Theme.accent, 0.14)
                        : (ctlMouse.containsMouse ? Theme.hoverStrong : Theme.fill)
                    border.width: 1
                    border.color: modelData.on ? Theme.alpha(Theme.accent, 0.5) : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.g
                        color: modelData.on ? Theme.accent
                            : (ctlMouse.containsMouse ? Theme.barText : Theme.barDim)
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(16)
                        scale: ctlMouse.containsMouse ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        id: ctlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.showTip(modelData.tip, ctlMouse)
                        onExited: Theme.tooltipShown = false
                        onClicked: {
                            if (modelData.act === "game")
                                root.toggleGameMode()
                            else if (modelData.act === "rec")
                                root.toggleRecording()
                            else if (modelData.act === "power")
                                root.openPower()
                            else if (modelData.act === "hub")
                                root.openHub()
                            else if (modelData.act === "net")
                                root.openNetwork()
                            else if (modelData.act === "wall")
                                root.openWallpapers()
                            else if (modelData.act === "search")
                                root.openPanel("search")
                        }
                    }
                }
            }
        }

        // ── МЕДИА ──
        Column {
            visible: root.panelMode === "media"
            anchors.left: parent.left
            anchors.leftMargin: Theme.barPad
            anchors.top: parent.top
            anchors.topMargin: Theme.barPad
            spacing: Theme.space3

            Row {
                spacing: Theme.space3

                // обложка трека: монохром, скруглённая
                Item {
                    width: 64
                    height: 64
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: root.player ? (root.player.trackArtUrl || "") : ""
                        sourceSize: Qt.size(128, 128)
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: coverImg
                        visible: coverImg.status === Image.Ready
                        saturation: -1.0
                        brightness: 0.06
                        maskEnabled: true
                        maskSource: coverMaskP
                    }
                    Rectangle {
                        id: coverMaskP
                        anchors.fill: parent
                        radius: Theme.radius
                        color: "white"
                        visible: false
                        layer.enabled: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: coverImg.status !== Image.Ready
                        text: "\uf001"
                        color: Theme.barFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(22)
                    }
                }

                Column {
                    spacing: Theme.space2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: 340
                        elide: Text.ElideRight
                        text: root.track.length > 0 ? root.track : "ничего не играет"
                        color: Theme.barText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(14)
                    }
                    Row {
                        spacing: Theme.space4
                        Text {
                            text: "\uf048"
                            color: Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(18)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.previous() }
                        }
                        Text {
                            text: root.playing ? "\uf04c" : "\uf04b"
                            color: root.playing ? Theme.accent : Theme.barFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(20)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.togglePlaying() }
                        }
                        Text {
                            text: "\uf051"
                            color: Theme.barDim
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(18)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.next() }
                        }
                    }
                    Text {
                        text: "открыть плеер  →"
                        color: Theme.barDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mediaPanelProc.running = true }
                    }
                }
            }
        }

        // ── ПОИСК ──
        Column {
            visible: root.panelMode === "search"
            anchors.fill: parent
            anchors.margins: Theme.barPad
            spacing: Theme.space2

            // строка ввода
            Rectangle {
                width: parent.width
                height: 34
                radius: Theme.radius
                color: Theme.fill
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.borderAccent : Theme.border

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    clip: true
                    onTextChanged: root.setSearchQuery(text)
                    Keys.onEscapePressed: {
                        if (text !== "") { text = ""; root.setSearchQuery("") }
                        else root.closePanel()
                    }
                    Keys.onUpPressed: root.moveSearch(-1)
                    Keys.onDownPressed: root.moveSearch(1)
                    Keys.onReturnPressed: root.runSearch()
                    Keys.onEnterPressed: root.runSearch()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "поиск: приложение, страница Hub, действие…"
                        visible: searchInput.text === ""
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(14)
                    }
                }
            }

            // результаты
            Column {
                width: parent.width
                spacing: 2
                Repeater {
                    model: root.searchResults
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 32
                        radius: Theme.radius
                        color: index === root.searchIndex ? Theme.active
                            : (resMouse.containsMouse ? Theme.hover : "transparent")
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.space2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.space2
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon || ""
                                color: index === root.searchIndex ? Theme.accent : Theme.textDim
                                font.family: modelData.kind === "app" ? Theme.iconFont : Theme.iconFont
                                font.pixelSize: Theme.fontSize(14)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: index === root.searchIndex ? Theme.text : Theme.barText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.kind === "page" ? "страница"
                                    : (modelData.kind === "action" ? "действие" : "приложение")
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTiny
                            }
                        }
                        MouseArea {
                            id: resMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.searchIndex = index
                            onClicked: { root.searchIndex = index; root.runSearch() }
                        }
                    }
                }
            }
        }

        // ── УВЕДОМЛЕНИЯ ──
        Column {
            visible: root.panelMode === "notifs"
            anchors.fill: parent
            anchors.margins: Theme.barPad
            spacing: Theme.space2

            Row {
                width: parent.width
                spacing: Theme.space3
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "УВЕДОМЛЕНИЯ"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    font.letterSpacing: 2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotifModel.items.length
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    font.bold: true
                }
                Item { width: 1; height: 1 }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotifModel.dnd ? "DND ВКЛ" : "DND"
                    color: NotifModel.dnd ? Theme.danger : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotifModel.toggleDnd() }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "очистить"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotifModel.clear() }
                }
            }

            Text {
                visible: NotifModel.items.length === 0
                text: NotifModel.dnd ? "режим «не беспокоить»" : "уведомлений нет"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
            }

            Column {
                width: parent.width
                spacing: Theme.space1
                Repeater {
                    model: NotifModel.items
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool expanded: NotifModel.expandedId === modelData.id
                        width: parent.width
                        height: expanded ? Math.min(120, bodyText.implicitHeight + 46) : 40
                        radius: Theme.radius
                        color: expanded ? Theme.fill : (notifMouse.containsMouse ? Theme.hover : "transparent")
                        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.space2
                            anchors.rightMargin: Theme.space2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Row {
                                width: parent.width
                                spacing: Theme.space2
                                Text {
                                    text: modelData.app
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                }
                                Text {
                                    width: parent.width - 120
                                    elide: Text.ElideRight
                                    text: modelData.summary
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.bold: true
                                }
                            }
                            Text {
                                id: bodyText
                                width: parent.width
                                visible: expanded
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                text: modelData.body
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                            }
                        }
                        MouseArea {
                            id: notifMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: function(m) {
                                if (m.button === Qt.MiddleButton) NotifModel.dismiss(modelData.id)
                                else NotifModel.toggleExpand(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

}
