import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
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
    property int memPct: -1
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
        var memTotal = 0, memAvail = 0, swapTotal = 0, swapFree = 0, temp = -1
        for (i = 0; i < lines.length; i++) {
            var l = lines[i]
            if (l.indexOf("MemTotal:") === 0)
                memTotal = parseInt(l.split(/\s+/)[1])
            else if (l.indexOf("MemAvailable:") === 0)
                memAvail = parseInt(l.split(/\s+/)[1])
            else if (l.indexOf("SwapTotal:") === 0)
                swapTotal = parseInt(l.split(/\s+/)[1])
            else if (l.indexOf("SwapFree:") === 0)
                swapFree = parseInt(l.split(/\s+/)[1])
            else if (/^\d+$/.test(l.trim()))
                temp = Math.round(parseInt(l.trim()) / 1000)
        }
        if (memTotal > 0)
            root.ramPct = Math.round(100 * (memTotal - memAvail) / memTotal)
        // память «в целом» = RAM + swap
        var allTotal = memTotal + swapTotal
        if (allTotal > 0)
            root.memPct = Math.round(100 * ((memTotal - memAvail) + (swapTotal - swapFree)) / allTotal)
        if (temp > 0)
            root.tempC = temp
    }

    Process {
        id: sysProc
        running: false
        command: ["bash", "-c",
            "head -1 /proc/stat; " +
            "grep -E '^MemTotal:|^MemAvailable:|^SwapTotal:|^SwapFree:' /proc/meminfo; " +
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
    readonly property var dayNames: [
        "воскресенье", "понедельник", "вторник", "среда",
        "четверг", "пятница", "суббота"
    ]
    property string clockText: Qt.formatTime(new Date(), "HH:mm")
    property string dayText: dayNames[new Date().getDay()]

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            root.clockText = Qt.formatTime(now, "HH:mm")
            root.dayText = root.dayNames[now.getDay()]
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
    Process { id: powerProc; running: false }
    function openPower() {
        powerProc.command = ["bash", "-c", "pgrep -x wlogout >/dev/null || setsid wlogout >/dev/null 2>&1 &"]
        powerProc.running = true
    }

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

    // ───────────────────────────── layout ─────────────────────────────
    Item {
        anchors.fill: parent

        // ── LEFT pill: workspaces ──
        Rectangle {
            id: leftPill
            anchors.left: parent.left
            anchors.leftMargin: 8
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
                    model: 8

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
            height: 34
            radius: Theme.radiusL
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            width: Math.max(clockLabel.implicitWidth, dayLabel.implicitWidth) + 30

            Column {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    id: clockLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.clockText
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(15)
                    font.bold: true
                    font.letterSpacing: 1
                }

                Text {
                    id: dayLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dayText
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(8)
                    font.letterSpacing: 1
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
                    font.pixelSize: Theme.fontSize(12)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: "RAM " + (root.ramPct < 0 ? "--" : root.ramPct + "%")
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                // температура — вместе с CPU/RAM, до индикаторов памяти
                Text {
                    visible: root.tempC > 0
                    text: root.tempC + "°C"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                // индикатор заполнения RAM
                Rectangle {
                    width: 40
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.trackBg
                    border.width: 1
                    border.color: Theme.border

                    Rectangle {
                        width: parent.width * (root.ramPct < 0 ? 0 : Math.min(1, root.ramPct / 100))
                        height: parent.height
                        radius: 3
                        color: root.ramPct > 90 ? Theme.danger : Theme.accent
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
                }
                // память «в целом» (RAM + swap)
                Text {
                    text: "MEM " + (root.memPct < 0 ? "--" : root.memPct + "%")
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                }
                Rectangle {
                    width: 40
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.trackBg
                    border.width: 1
                    border.color: Theme.border

                    Rectangle {
                        width: parent.width * (root.memPct < 0 ? 0 : Math.min(1, root.memPct / 100))
                        height: parent.height
                        radius: 3
                        color: root.memPct > 90 ? Theme.danger : Theme.accent2
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
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
                    font.pixelSize: Theme.fontSize(12)

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
                                root.player.togglePlaying()
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
                            font.pixelSize: Theme.fontSize(16)
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: root.muted ? "mute" : Math.round(root.vol * 100) + "%"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
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

                // power
                Text {
                    text: "\uf011"
                    color: Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(17)
                    height: 26
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: root.openPower()
                    }
                }
            }
        }
    }
}
