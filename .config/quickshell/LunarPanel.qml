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
    implicitHeight: 42
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
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
    readonly property color pillBg: Theme.bg
    readonly property color pillHover: Theme.alpha(Theme.accent, 0.08)
    readonly property color pillBorder: Theme.border

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
        command: ["bash", "-c",
            "hyprctl -j status 2>/dev/null | grep -q '\"configProvider\": \"lua\"' && echo lua || echo legacy"]
        stdout: StdioCollector { onStreamFinished: root.luaMode = (text.trim() === "lua") }
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
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: sysProc.running = true
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
    readonly property var player: {
        var ps = Mpris.players.values
        for (var i = 0; i < ps.length; i++)
            if (ps[i].isPlaying)
                return ps[i]
        return ps.length > 0 ? ps[0] : null
    }
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string track: player
        ? ((player.trackTitle || "") + (player.trackArtist ? "  —  " + player.trackArtist : ""))
        : ""

    property int mqPos: 0
    onTrackChanged: mqPos = 0

    Timer {
        interval: 180
        running: root.playing && root.track.length > 0
        repeat: true
        onTriggered: root.mqPos = (root.mqPos + 1) % (root.track.length + 6)
    }

    // len — сколько символов показать (по ширине поля «сейчас играет»)
    function marqueeText(len) {
        if (!root.track)
            return ""
        if (!isFinite(len) || len < 4)
            len = 4
        if (len > 240)
            len = 240
        if (!root.playing)
            return root.track.length > len ? root.track.substring(0, len - 1) + "…" : root.track
        var s = root.track + "      "
        var o = root.mqPos % s.length
        var big = ""
        while (big.length < o + len + 1)
            big += s
        return big.substring(o, o + len)
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
    Process { id: powerProc; running: false }

    Process { id: pavuProc; running: false }
    function openMixer() {
        pavuProc.command = ["bash", "-c", "setsid pavucontrol >/dev/null 2>&1 &"]
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

    Process { id: trayPanelProc; running: false }
    function openTrayPanel() {
        trayPanelProc.command = ["bash", "-c", "qs ipc call tray toggle"]
        trayPanelProc.running = true
    }

    // icon у SNI бывает: путь, file:///image:// или имя темы — приводим к Image source.
    // Важно: если иконки нет в теме, image://icon отдаёт заглушку, поэтому
    // сначала проверяем hasThemeIcon и иначе возвращаем "" (в UI будет точка).
    function trayIconSource(item) {
        if (!item) return ""
        var ic = item.icon || ""
        if (ic.indexOf("file://") === 0 || ic.indexOf("qrc:") === 0) return ic
        if (ic.indexOf("image://icon/") === 0) {
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
    property string gpuTemp: ""
    property bool gameMode: false
    property string powerProfile: ""
    property bool recording: false
    readonly property int focusedPhase:
        (root.focusedWs && root.focusedWs.id > 0) ? root.focusedWs.id : 0

    Process {
        id: statusProc
        running: false
        command: ["bash", "-c", "~/.config/hypr/scripts/eclipse-status.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/)
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
                        root.gpuLoad = v
                    } else if (k === "gput") {
                        root.gpuTemp = v
                    } else if (k === "gm") {
                        root.gameMode = (v === "1")
                    } else if (k === "pp") {
                        root.powerProfile = v
                    } else if (k === "rec") {
                        root.recording = (v === "1")
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500
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

    Process { id: statusProcAction; running: false }
    Process {
        id: mediaPanelProc
        running: false
        command: ["qs", "ipc", "call", "media", "toggle"]
    }

    function openNetwork() {
        statusProcAction.command = ["bash", "-c",
            "qs ipc call hub open; sleep 0.15; qs ipc call hub nav 4"]
        statusProcAction.running = true
    }

    function switchLayout() {
        if (kbDevice.length === 0)
            return
        statusProcAction.command = ["bash", "-c",
            "hyprctl switchxkblayout '" + kbDevice + "' next"]
        statusProcAction.running = true
    }

    function toggleDnd() {
        statusProcAction.command = ["bash", "-c", "makoctl mode -t do-not-disturb"]
        statusProcAction.running = true
    }

    function toggleGameMode() {
        statusProcAction.command = ["bash", "-c",
            "~/.config/hypr/scripts/eclipse-gamemode.sh toggle"]
        statusProcAction.running = true
    }

    function cyclePower() {
        statusProcAction.command = ["bash", "-c",
            "p=$(powerprofilesctl get); case \"$p\" in performance) n=balanced;; power-saver) n=performance;; *) n=power-saver;; esac; powerprofilesctl set \"$n\""]
        statusProcAction.running = true
    }

    function toggleRecording() {
        statusProcAction.command = ["bash", "-c",
            "~/.config/hypr/scripts/eclipse-record.sh toggle"]
        statusProcAction.running = true
    }

    // ───────────────────────────── layout ─────────────────────────────
    // Две части бара: слева «LUNAR + фазы столов», справа — блок от конца
    // столов до правого края. Часы в правом блоке держатся ровно по
    // центру экрана, телеметрия — у правого края. Секции разделены 1px (Sep).
    component Sep: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        Layout.leftMargin: 5
        Layout.rightMargin: 5
        color: Theme.border
    }

    // подсветка интерактивной секции при наведении
    component HoverBg: Rectangle {
        anchors.fill: parent
        radius: 4
        color: Theme.alpha(Theme.accent, 0.07)
        opacity: hh.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        HoverHandler { id: hh }
    }

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
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 32
        radius: Theme.radiusL
        color: root.pillBg
        border.color: root.pillBorder
        border.width: 1
        width: leftLayout.implicitWidth + 28

        RowLayout {
            id: leftLayout
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 0

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
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    font.letterSpacing: 1.5
                }
            }

            Sep {}

            // ── рабочие столы: 9 фаз ──
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: wsRow.implicitWidth
                implicitHeight: 26

                HoverBg {}

                // тонкая «орбита» за фазами — связывает индикаторы в цикл
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.alpha(Theme.accent, 0.10)
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
        anchors.left: leftBar.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 32
        radius: Theme.radiusL
        color: root.pillBg
        border.color: root.pillBorder
        border.width: 1
        clip: true

        // ── телеметрия и управление: прижаты к правому краю ──
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            // ── сеть: скорость + иконка подключения (клик — сети в Hub) ──
            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 10
                implicitWidth: netRow.implicitWidth
                implicitHeight: 26

                HoverBg {}

                Row {
                    id: netRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: 6

                    // стрелка и число — отдельно: число в поле фикс. ширины
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰁅"
                        color: Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fm15.advanceWidth("00.0K")
                        text: root.netFmt(root.netDown)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰁝"
                        color: Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fm15.advanceWidth("00.0K")
                        text: root.netFmt(root.netUp)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(fmIcon17.advanceWidth("󰈀"), fmIcon17.advanceWidth("\uf1eb"))
                        text: root.netKind === "eth" ? "󰈀" : "\uf1eb"
                        color: root.netKind === "off" ? Theme.textFaint : Theme.text
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

            Sep {}

            // ── действия: Game Mode / питание / запись ──
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: actionRow.implicitWidth
                implicitHeight: 26
                HoverBg {}
                Row {
                    id: actionRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: 8

                    // Game Mode (клик — переключить)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf11b"
                        color: root.gameMode ? Theme.danger : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(17)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleGameMode()
                        }
                    }

                    // профиль питания (клик — переключить performance/balanced/save)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fm13.advanceWidth("PERF")
                        text: root.powerProfile === "performance"
                            ? "PERF"
                            : (root.powerProfile === "power-saver" ? "SAVE" : "BAL")
                        color: root.powerProfile === "performance" ? Theme.accent : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(13)
                        font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cyclePower()
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Theme.border
                        anchors.verticalCenter: parent.verticalCenter
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
                            color: root.recording ? Theme.danger : Theme.textDim
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

            Sep {}

            // ── статистика: CPU / RAM / °C / GPU ──
            Row {
                id: statsRow
                Layout.alignment: Qt.AlignVCenter
                height: 26
                spacing: 7

                // каждое поле — фиксированной ширины, цифры не дёргают строку
                Text {
                    width: fm14.advanceWidth("CPU 100%")
                    text: "CPU " + root.padNum(root.cpuPct < 0 ? "--" : root.cpuPct + "%", 4)
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    width: fm14.advanceWidth("RAM 100%")
                    text: "RAM " + root.padNum(root.ramPct < 0 ? "--" : root.ramPct + "%", 4)
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                // температура — вместе с CPU/RAM
                Text {
                    visible: root.tempC > 0
                    width: fm14.advanceWidth("58°C")
                    text: root.padNum(root.tempC + "°C", 4)
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                // GPU: загрузка и температура
                Text {
                    visible: root.gpuLoad !== ""
                    width: fm14.advanceWidth("GPU 100% 100°C")
                    text: "GPU " + root.padNum(root.gpuLoad + "%", 4)
                        + " " + root.padNum(root.gpuTemp !== "" ? root.gpuTemp + "°C" : "--", 5)
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // ── трей: место под 3 значка зарезервировано всегда ──
            Sep {}

            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.trayMax * 20 + Math.max(0, root.trayMax - 1) * 9
                implicitHeight: 26

                HoverBg { visible: SystemTray.items.values.length > 0 }

                Row {
                    id: trayRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    spacing: 9

                    Repeater {
                        model: SystemTray.items.values.slice(0, root.trayMax)

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
                                color: Theme.textFaint
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
                                    } else if (m.button === Qt.RightButton || modelData.onlyMenu) {
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
                        visible: SystemTray.items.values.length > root.trayMax
                        width: moreText.implicitWidth + 12
                        height: 22
                        radius: Theme.radius
                        anchors.verticalCenter: parent.verticalCenter
                        color: moreMouse.containsMouse ? Theme.alpha(Theme.accent, 0.12) : "transparent"
                        border.width: 1
                        border.color: moreMouse.containsMouse ? Theme.accent : Theme.borderAccent

                        Text {
                            id: moreText
                            anchors.centerIn: parent
                            text: "+" + (SystemTray.items.values.length - root.trayMax)
                            color: moreMouse.containsMouse ? Theme.accent : Theme.textDim
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
                implicitWidth: rightRow.implicitWidth
                implicitHeight: 26
                HoverBg {}
                Row {
                    id: rightRow
                    anchors.centerIn: parent
                    height: 26
                    spacing: 9

                    // раскладка (клик — переключить)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: fm14.advanceWidth("EN")
                        text: root.kbLayout
                        color: Theme.text
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
                            ? Theme.textFaint
                            : (root.notifCount > 0 ? Theme.text : Theme.textDim)
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

                    Rectangle {
                        width: 1
                        height: 16
                        color: Theme.border
                        anchors.verticalCenter: parent.verticalCenter
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
                                color: root.muted ? Theme.textFaint : Theme.text
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(19)
                                height: 26
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                width: fm14.advanceWidth("100%")
                                text: root.muted ? "mute" : Math.round(root.vol * 100) + "%"
                                color: Theme.textDim
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
    // ── часы: жёстко по центру экрана ──
    Item {
        id: clockBox
        width: clockRow.implicitWidth
        height: 26
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: clockRow
            anchors.centerIn: parent
            height: 26
            spacing: 10

            Row {
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                spacing: 0

                Text {
                    id: clockLabel
                    text: root.clockText.substring(0, 2)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(15)
                    font.bold: true
                    font.letterSpacing: 1
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    id: clockColon
                    text: ":"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(15)
                    font.bold: true
                    font.letterSpacing: 1
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    opacity: root.colonOn ? 1.0 : 0.15
                    Behavior on opacity { NumberAnimation { duration: 480; easing.type: Easing.InOutSine } }
                }
                Text {
                    id: clockMin
                    text: root.clockText.substring(3)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(15)
                    font.bold: true
                    font.letterSpacing: 1
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                width: 1
                height: 16
                color: Theme.border
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: dayLabel
                text: root.dayText + " " + root.dateText
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
                height: 26
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // медиа «сейчас играет»: пусто — тонкая линия, играет — столбики cava
    // (1/3 ширины) слева и бегущая строка с названием трека (2/3) справа.
    // Лежит внутри правого блока, не задевая столы и часы.
    Item {
        id: mediaBox
        anchors.verticalCenter: parent.verticalCenter
        height: 26
        // внутри правого блока, с отступом от столов и от часов
        x: rightBar.x + 18
        width: Math.max(0, clockBox.x - 18 - x)
        readonly property bool active: root.mediaActive
        readonly property real vizW: width / 3
        readonly property real titleW: Math.max(0, width - vizW - 12)
        readonly property real mqCharW: fm12.advanceWidth("0") > 0 ? fm12.advanceWidth("0") : 8
        readonly property int mqChars:
            Math.max(4, Math.floor((titleW - 18 - 8) / mqCharW))

        // холостой ход — линия
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.accent, 0.18)
            visible: !mediaBox.active
        }

        // играет — столбики cava + название
        Row {
            visible: mediaBox.active
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            spacing: 12

            // столбики — треть ширины
            Row {
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                spacing: 2

                Repeater {
                    model: root.barCount

                    delegate: Item {
                        required property int index
                        width: Math.max(1, (mediaBox.vizW - (root.barCount - 1) * 2) / root.barCount)
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

            // название трека — две трети
            Row {
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                spacing: 8

                Text {
                    id: noteIcon
                    width: 18
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.playing ? "\uf04c" : "\uf04b"
                    color: root.playing ? Theme.accent : Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(13)
                }

                Text {
                    width: Math.max(0, mediaBox.titleW - noteIcon.width - 8)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    clip: true
                    text: root.marqueeText(mediaBox.mqChars)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaPanelProc.running = true   // попап «сейчас играет»
        }
    }
}
