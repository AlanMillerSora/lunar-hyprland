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
//  Lunar top bar — монохромный HUD (скруглённые "таблетки")
//    слева   : рабочие столы 01–08 + CPU/RAM/темп
//    центр   : часы
//    справа  : mpris-маркиза, громкость, питание
//  Панель резервирует место (exclusiveZone), окна не заходят под неё.
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

    function marqueeText() {
        if (!root.track)
            return ""
        if (!root.playing)
            return root.track.length > 30 ? root.track.substring(0, 30) + "…" : root.track
        var s = root.track + "      "
        var doubled = s + s
        var o = root.mqPos % s.length
        return doubled.substring(o, o + 30)
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
    property real netDown: 0            // МБ/с приём
    property real netUp: 0              // МБ/с передача
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

    // ── скорость сети (МБ/с) из /proc/net/dev ─────────────────
    // Скрипт считает дельту по суммарному трафику всех интерфейсов
    // (кроме lo) за интервал и печатает "down up" в МБ/с.
    Process {
        id: netProc
        running: false
        command: ["python3", "-c", `
import time, os
def read():
    rx = tx = 0
    with open("/proc/net/dev") as f:
        for line in f.readlines()[2:]:
            name, data = line.split(":", 1)
            if name.strip() == "lo":
                continue
            parts = data.split()
            rx += int(parts[0]); tx += int(parts[8])
    return rx, tx
r1, t1 = read()
time.sleep(1.0)
r2, t2 = read()
print(f"{(r2-r1)/1048576:.2f} {(t2-t1)/1048576:.2f}")
`]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(/\s+/)
                if (p.length >= 2) {
                    root.netDown = parseFloat(p[0]) || 0
                    root.netUp = parseFloat(p[1]) || 0
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: if (!netProc.running) netProc.running = true
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
    Item {
        anchors.fill: parent

        // ── LOGO pill: марка + фаза активного стола ──
        Rectangle {
            id: logoPill
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusL
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            width: logoRow.implicitWidth + 18

            Row {
                id: logoRow
                anchors.centerIn: parent
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
        }

        // ── LEFT pill: workspaces ──
        Rectangle {
            id: leftPill
            anchors.left: logoPill.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusL
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            width: leftRow.implicitWidth + 18

            // тонкая «орбита» за фазами — связывает индикаторы в цикл
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                height: 1
                color: Theme.alpha(Theme.accent, 0.10)
            }

            Row {
                id: leftRow
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

                        width: 28
                        height: 26
                        color: "transparent"

                        // тонкое кольцо-выделение активного стола
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: 12
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.alpha(Theme.accent, 0.55)
                            visible: wsPill.isFocused
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

                // статистика системы переехала в правый бок (statsPill)
            }
        }

        // ── CENTER pill: clock ──
        Rectangle {
            id: centerPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusL
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            width: clockRow.implicitWidth + 30

            Row {
                id: clockRow
                anchors.centerIn: parent
                height: 26
                spacing: 10

                Text {
                    id: clockLabel
                    text: root.clockText
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(15)
                    font.bold: true
                    font.letterSpacing: 1
                    height: 26
                    verticalAlignment: Text.AlignVCenter
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

        // ── STATUS pill: сеть / раскладка / уведомления ──
        Rectangle {
            id: statusPill
            anchors.right: actionPill.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusL
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            width: statusRow.implicitWidth + 18

            Row {
                id: statusRow
                anchors.centerIn: parent
                height: 26
                spacing: 8

                // сеть (клик — список сетей в Hub)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.netKind === "eth" ? "󰈀" : "\uf1eb"
                    color: root.netKind === "off" ? Theme.textFaint : Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(17)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openNetwork()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.netKind === "wifi"
                    text: root.netSignal + "%"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                }

                // скорость сети (показываем, когда есть трафик)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.netDown > 0.05 || root.netUp > 0.05
                    text: "󰁅 " + root.netDown.toFixed(1) + "  󰁝 " + root.netUp.toFixed(1)
                    color: Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(11)
                }

                Rectangle {
                    width: 1
                    height: 16
                    color: Theme.border
                    anchors.verticalCenter: parent.verticalCenter
                }

                // раскладка (клик — переключить)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
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

                Rectangle {
                    width: 1
                    height: 16
                    color: Theme.border
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 1
                    height: 16
                    color: Theme.border
                    anchors.verticalCenter: parent.verticalCenter
                }

                // уведомления / «не беспокоить» (клик — переключить)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
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
                    visible: root.notifCount > 0
                    text: root.notifCount
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    font.bold: true
                }
            }
        }

        // ── ACTION pill: Game Mode + запись экрана ──
        Rectangle {
            id: actionPill
            anchors.right: statsPill.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusL
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            width: actionRow.implicitWidth + 18

            Row {
                id: actionRow
                anchors.centerIn: parent
                height: 26
                spacing: 10

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

                // запись экрана — с явной подписью, чтобы было понятно
                Rectangle {
                    width: recLabel.implicitWidth + 20
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
                        text: root.recording ? "■ СТОП" : "● ЗАПИСЬ"
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

        // ── RIGHT-STATS pill: CPU / RAM / MEM / °C (переехало из левого бока) ──
        Rectangle {
            id: statsPill
            anchors.right: rightPill.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusL
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            width: statsRow.implicitWidth + 18

            Row {
                id: statsRow
                anchors.centerIn: parent
                height: 26
                spacing: 14

                Text {
                    text: "CPU " + (root.cpuPct < 0 ? "--" : root.cpuPct + "%")
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: "RAM " + (root.ramPct < 0 ? "--" : root.ramPct + "%")
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                // температура — вместе с CPU/RAM, до индикаторов памяти
                Text {
                    visible: root.tempC > 0
                    text: root.tempC + "°C"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                // GPU: загрузка и температура
                Text {
                    visible: root.gpuLoad !== ""
                    text: "GPU " + root.gpuLoad + "%"
                        + (root.gpuTemp !== "" ? " " + root.gpuTemp + "°C" : "")
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // ── RIGHT pill: mpris + volume + power ──
        Rectangle {
            id: rightPill
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusL
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            width: rightRow.implicitWidth + 20

            Row {
                id: rightRow
                anchors.centerIn: parent
                height: 26
                spacing: 10

                // mpris marquee
                Text {
                    visible: root.track.length > 0
                    width: visible ? 240 : 0
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    clip: true
                    text: "♪  " + root.marqueeText()
                    color: root.playing ? Theme.text : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: function (mouse) {
                            if (!root.player)
                                return
                            if (mouse.button === Qt.RightButton)
                                root.player.next()
                            else if (mouse.button === Qt.MiddleButton)
                                root.player.previous()
                            else
                                mediaPanelProc.running = true   // ЛКМ — попап «сейчас играет»
                        }
                    }
                }

                // ── системный трей: до 3 значков, остальные — в списке ──
                Rectangle {
                    visible: SystemTray.items.values.length > 0
                    width: 1
                    height: 16
                    color: Theme.border
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    visible: SystemTray.items.values.length > 0
                    width: visible ? trayRow.implicitWidth : 0
                    height: 26

                    Row {
                        id: trayRow
                        anchors.centerIn: parent
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
