import QtQuick
import Quickshell.Io
import "../"
import "../widgets/shared"

Item {
    id: page

    property string homeDir: ""
    property string hostname: "..."
    property string uptime: "..."
    property string os: "..."
    property string cpu: "Loading..."
    property string gpu: "Loading..."
    property string gpuTemp: "—"
    property string memory: "Loading..."
    property string ramSpeed: "Loading..."
    property int updateCount: -1
    property string updateList: ""
    property string updateError: ""

    property real cpuUsage: 0
    property real gpuUsage: 0
    property real memoryUsage: 0

    property string cpuTemp: "—"

    property var cpuHistory: []
    property var gpuHistory: []
    property var memoryHistory: []

    property var cpuPrev: null

    property int hardwareLabelSize: 13
    property int hardwareTextSize: 13
    property string mono: Theme.fontFamily
    property int rightMargin: 36

    property string currentTime: ""

    function updateGraph(value, type) {
        value = parseFloat(value)
        if (isNaN(value)) return

        value = Math.max(0, Math.min(100, value))

        var history

        if (type === "cpu")
            history = cpuHistory.slice()
        else if (type === "gpu")
            history = gpuHistory.slice()
        else
            history = memoryHistory.slice()

        history.push(value)

        if (history.length > 60)
            history.shift()

        if (type === "cpu") {
            cpuUsage = value
            cpuHistory = history
            cpuGraph.requestPaint()
        } else if (type === "gpu") {
            gpuUsage = value
            gpuHistory = history
            gpuGraph.requestPaint()
        } else {
            memoryUsage = value
            memoryHistory = history
            memoryGraph.requestPaint()
        }
    }

    function updateCpu(value) {
        updateGraph(value, "cpu")
    }

    function updateGpu(value) {
        updateGraph(value, "gpu")
    }

    function updateMemory(value) {
        updateGraph(value, "memory")
    }

    function updateCpuFromStat(value) {
        var p = value.trim().split(/\s+/)
        if (p.length < 5) return

        var user = Number(p[1])
        var nice = Number(p[2])
        var system = Number(p[3])
        var idle = Number(p[4])
        var iowait = Number(p[5] || 0)
        var irq = Number(p[6] || 0)
        var softirq = Number(p[7] || 0)
        var steal = Number(p[8] || 0)

        var idleTime = idle + iowait
        var total = user + nice + system + idle + iowait + irq + softirq + steal

        if (cpuPrev !== null) {
            var totalDelta = total - cpuPrev.total
            var idleDelta = idleTime - cpuPrev.idle

            if (totalDelta > 0)
                updateCpu(100 * (1 - idleDelta / totalDelta))
        }

        cpuPrev = {
            total: total,
            idle: idleTime
        }
    }

    function updateMemoryFromStat(value) {
        var total = 0
        var available = 0
        var lines = value.trim().split("\n")

        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].trim().split(/\s+/)

            if (parts[0] === "MemTotal:")
                total = Number(parts[1])

            else if (parts[0] === "MemAvailable:")
                available = Number(parts[1])
        }

        if (total <= 0) return

        var used = total - available
        var usage = (used / total) * 100

        updateMemory(usage)

        function formatMemory(kb) {
            var gb = kb / 1024 / 1024

            if (gb >= 1)
                return gb.toFixed(1) + " GiB"

            return Math.round(kb / 1024) + " MiB"
        }

        page.memory =
            formatMemory(used) +
            " / " +
            formatMemory(total)
    }

    function updateTemp(value) {
        value = parseFloat(value.trim())

        cpuTemp = isNaN(value)
            ? "—"
            : Math.round(value) + "°C"
    }

    function updateGpuTemp(value) {
        var v = parseFloat(String(value).trim())

        gpuTemp = isNaN(v)
            ? "—"
            : Math.round(v) + "°C"
    }

    function updateClock() {
        page.currentTime = Qt.formatTime(new Date(), "HH:mm:ss")
    }

    // проверка обновлений (checkupdates из pacman-contrib, иначе pacman -Qu)
    // M39: пустой вывод ≠ «система актуальна» — различаем «не проверено» и ошибку проверки
    Process {
        id: pUpdates
        running: false

        command: ["bash", "-c",
            "if command -v checkupdates >/dev/null 2>&1; then " +
            "out=$(checkupdates 2>/dev/null); rc=$?; " +
            "if [ $rc -ne 0 ] && [ $rc -ne 2 ]; then exit 9; fi; " +
            "printf '%s' \"$out\"; " +
            "else " +
            "out=$(pacman -Qu 2>/dev/null); rc=$?; " +
            "if [ $rc -ne 0 ] && [ $rc -ne 1 ]; then exit 9; fi; " +
            "printf '%s' \"$out\"; " +
            "fi"]

        stdout: StdioCollector { id: updOut }

        onExited: (exitCode) => {
            // команда нормализует код: 0 — проверка удалась (пусто = обновлений нет);
            // 9 — ошибка (нет сети, занята БД pacman и т.п.)
            if (exitCode !== 0) {
                page.updateError = "не удалось проверить (код " + exitCode + ")"
                page.updateCount = -1
                page.updateList = ""
                return
            }
            page.updateError = ""
            var t = (updOut.text || "").trim()
            var lines = t === "" ? [] : t.split("\n")
            page.updateCount = lines.length
            page.updateList = lines.slice(0, 12).join("\n")
        }
    }

    Process {
        id: pHome

        command: ["sh", "-c", "printf '%s' \"$HOME\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: page.homeDir = text.trim()
        }
    }

    Process {
        id: pHost

        command: [
            "sh",
            "-c",
            "hostnamectl --static 2>/dev/null || cat /etc/hostname"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.hostname = text.trim()
        }
    }

    Process {
        id: pUptime

        command: ["uptime", "-p"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: page.uptime = text.trim()
        }
    }

    Process {
        id: pOs

        command: [
            "sh",
            "-c",
            "grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.os = text.trim()
        }
    }

    Process {
        id: pCpu

        command: [
            "sh",
            "-c",
            "awk -F: '/model name/ {gsub(/^ +/, \"\", $2); print $2; exit}' /proc/cpuinfo"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.cpu = text.trim()
        }
    }

    Process {
        id: pCpuUsage

        command: ["sh", "-c", "head -1 /proc/stat"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: page.updateCpuFromStat(text)
        }
    }

    Process {
        id: pCpuTemp

        command: [
            "sh",
            "-c",
            // hwmon напрямую (k10temp/zenpower/coretemp): быстро, без sensors;
            // если датчика нет — откат на sensors
            "for h in /sys/class/hwmon/hwmon*; do " +
            "n=$(cat \"$h/name\" 2>/dev/null); " +
            "case \"$n\" in k10temp|zenpower|coretemp) " +
            "v=$(cat \"$h/temp1_input\" 2>/dev/null); " +
            "[ -n \"$v\" ] && { echo $((v / 1000)); exit 0; }; ;; esac; done; " +
            "sensors 2>/dev/null | awk '/Package id 0:|Tctl:|Tdie:/ {for(i=1;i<=NF;i++) if($i ~ /\\+?[0-9]+(\\.[0-9]+)?°C/) {gsub(/[+°C]/, \"\", $i); print $i; exit}}'"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.updateTemp(text)
        }
    }

    Process {
        id: pGpu

        command: [
            "sh",
            "-c",
            "lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | sed -E 's/.*: //; s/ \\(rev.*\\)//' | head -1"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                page.gpu = text.trim()

                if (!page.gpu)
                    page.gpu = "Unknown"
            }
        }
    }

    Process {
        id: pGpuUsage

        command: [
            "sh",
            "-c",
            // NVIDIA: nvidia-smi; AMD/Intel: sysfs. Как в панели (eclipse-status.sh).
            "if command -v nvidia-smi >/dev/null 2>&1; then " +
            "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1; " +
            "else cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1; fi"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.updateGpu(text)
        }
    }

    Process {
        id: pGpuTemp

        command: [
            "sh",
            "-c",
            // NVIDIA: nvidia-smi; AMD/Intel: sysfs (миллиградусы → градусы)
            "if command -v nvidia-smi >/dev/null 2>&1; then " +
            "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1; " +
            "else v=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); " +
            "[ -n \"$v\" ] && echo $((v / 1000)); fi"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.updateGpuTemp(text)
        }
    }

    Process {
        id: pMemory

        command: [
            "sh",
            "-c",
            "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.updateMemoryFromStat(text)
        }
    }

    Process {
        id: pRamSpeed

        command: [
            "sudo",
            "-n",
            "/usr/bin/dmidecode",
            "-t",
            "memory"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                var speed = ""

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()

                    if (line.indexOf("Configured Memory Speed:") === 0) {
                        var parts = line.split(/\s+/)

                        if (parts.length >= 5 &&
                            /^[0-9]+$/.test(parts[3])) {
                            speed = parts[3] + " " + parts[4]
                            break
                        }
                    }
                }

                if (!speed) {
                    for (var j = 0; j < lines.length; j++) {
                        var line2 = lines[j].trim()

                        if (line2.indexOf("Speed:") === 0) {
                            var parts2 = line2.split(/\s+/)

                            if (parts2.length >= 3 &&
                                /^[0-9]+$/.test(parts2[1])) {
                                speed = parts2[1] + " " + parts2[2]
                                break
                            }
                        }
                    }
                }

                page.ramSpeed = speed || "Unknown"
            }
        }
    }

    Timer {
        interval: 1000
        // X1: пока Hub закрыт, страницу не видно — поллинг не нужен
        running: page.visible
        repeat: true

        onTriggered: {
            page.updateClock()
            pCpuUsage.running = true
            pCpuTemp.running = true
            pGpuUsage.running = true
            pGpuTemp.running = true
        }
    }

    Timer {
        interval: 1000
        running: page.visible
        repeat: true

        onTriggered: {
            pMemory.running = true
        }
    }

    Timer {
        interval: 5000
        running: page.visible
        repeat: true

        onTriggered: {
            pUptime.running = true
        }
    }

    Component.onCompleted: {
        page.updateClock()
        pRamSpeed.running = true
        pUpdates.running = true
    }

    Flickable {
        id: scrollArea

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            id: wheelHandler

            onWheel: function(event) {
                var delta = event.angleDelta.y

                // L33: не перехватываем горизонтальную прокрутку
                if (delta === 0)
                    return

                scrollArea.contentY = Math.max(
                    0,
                    Math.min(
                        scrollArea.contentHeight - scrollArea.height,
                        scrollArea.contentY - delta
                    )
                )

                event.accepted = true
            }
        }

        Column {
            id: contentColumn

            anchors {
                left: parent.left
                right: parent.right
                rightMargin: page.rightMargin
            }

            spacing: Theme.space5

            Text {
                text: "SYSTEM"
                color: Theme.text
                font.family: page.mono
                font.pixelSize: Theme.fontTitle
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Row {
                width: parent.width
                height: 150
                spacing: Theme.space5

                Item {
                    width: 150
                    height: 150

                    Image {
                        anchors.centerIn: parent
                        source: page.homeDir
                            ? "file://" + page.homeDir + "/.config/avatars/avatar.png"
                            : ""

                        width: 140
                        height: 140

                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        asynchronous: true
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space4

                    Column {
                        spacing: 3

                        SectionHeader { icon: "󰒋"; text: "HOSTNAME"; textColor: Theme.accent; size: Theme.fontTiny; bold: false }

                        Text {
                            text: page.hostname
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                        }
                    }

                    Column {
                        spacing: 3

                        SectionHeader { icon: "󰣇"; text: "OS"; textColor: Theme.accent; size: Theme.fontTiny; bold: false }

                        Text {
                            text: page.os
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            elide: Text.ElideRight
                            width: 500
                        }
                    }

                    Column {
                        spacing: 3

                        SectionHeader { icon: "󰔛"; text: "UPTIME"; textColor: Theme.accent; size: Theme.fontTiny; bold: false }

                        Text {
                            text: page.uptime
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.space3

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.space5

                    SectionHeader {
                        id: cpuHeader
                        icon: "󰍛"
                        text: "CPU"
                        textColor: Theme.accent
                        size: page.hardwareLabelSize
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: cpuValue

                        text: page.cpu
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: page.hardwareTextSize
                        elide: Text.ElideLeft

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "USAGE  " + Math.round(page.cpuUsage) + "%"
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: Theme.fontSmall

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "TEMP  " + page.cpuTemp
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: Theme.fontSmall

                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    width: parent.width
                    height: 60

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.fill
                    }

                    Repeater {
                        model: [0.25, 0.5, 0.75]

                        Rectangle {
                            x: 0
                            y: parent.height * modelData
                            width: parent.width
                            height: 1
                            color: Theme.border
                            opacity: 0.35
                        }
                    }

                    Canvas {
                        id: cpuGraph

                        anchors.fill: parent
                        anchors.margins: 6

                        onPaint: page.drawGraph(
                            getContext("2d"),
                            page.cpuHistory
                        )
                    }

                    Text {
                        text: "100%"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: Theme.fontNano
                    }

                    Text {
                        text: "0%"
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: Theme.fontNano
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.space3

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.space5

                    SectionHeader {
                        id: gpuHeader
                        icon: "󰢮"
                        text: "GPU"
                        textColor: Theme.accent
                        size: page.hardwareLabelSize
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: gpuValue

                        text: page.gpu
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: page.hardwareTextSize
                        elide: Text.ElideLeft

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "USAGE  " + Math.round(page.gpuUsage) + "%"
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: Theme.fontSmall

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "TEMP  " + page.gpuTemp
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: Theme.fontSmall

                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    width: parent.width
                    height: 60

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.fill
                    }

                    Repeater {
                        model: [0.25, 0.5, 0.75]

                        Rectangle {
                            y: parent.height * modelData
                            width: parent.width
                            height: 1
                            color: Theme.border
                            opacity: 0.35
                        }
                    }

                    Canvas {
                        id: gpuGraph

                        anchors.fill: parent
                        anchors.margins: 6

                        onPaint: page.drawGraph(
                            getContext("2d"),
                            page.gpuHistory
                        )
                    }

                    Text {
                        text: "100%"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: Theme.fontNano
                    }

                    Text {
                        text: "0%"
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: Theme.fontNano
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.space3

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.space5

                    SectionHeader {
                        id: memoryHeader
                        icon: "󰘚"
                        text: "RAM"
                        textColor: Theme.accent
                        size: page.hardwareLabelSize
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "SPEED  " + page.ramSpeed
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: Theme.fontSmall

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: memoryValue

                        text: page.memory
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: page.hardwareTextSize
                        elide: Text.ElideLeft

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "USAGE  " + Math.round(page.memoryUsage) + "%"
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: Theme.fontSmall

                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    width: parent.width
                    height: 60

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.fill
                    }

                    Repeater {
                        model: [0.25, 0.5, 0.75]

                        Rectangle {
                            y: parent.height * modelData
                            width: parent.width
                            height: 1
                            color: Theme.border
                            opacity: 0.35
                        }
                    }

                    Canvas {
                        id: memoryGraph

                        anchors.fill: parent
                        anchors.margins: 6

                        onPaint: page.drawGraph(
                            getContext("2d"),
                            page.memoryHistory
                        )
                    }

                    Text {
                        text: "100%"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: Theme.fontNano
                    }

                    Text {
                        text: "0%"
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: Theme.fontNano
                    }
                }
            }

            // ── обновления системы ─────────────────────────────
            Column {
                width: parent.width
                spacing: Theme.space3

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.space5

                    SectionHeader {
                        icon: "󰚰"
                        text: "ОБНОВЛЕНИЯ"
                        textColor: Theme.accent
                        size: page.hardwareLabelSize
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: page.updateError !== ""
                            ? page.updateError
                            : (page.updateCount < 0
                                ? "не проверялось"
                                : (page.updateCount === 0
                                    ? "система актуальна"
                                    : page.updateCount + " пакетов"))
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: Theme.fontSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    visible: page.updateList !== ""
                    text: page.updateList
                    color: Theme.textDim
                    font.family: page.mono
                    font.pixelSize: Theme.fontTiny
                    lineHeight: 1.3
                }

                Row {
                    spacing: Theme.space2

                    ActionButton {
                        label: "ПРОВЕРИТЬ"
                        width: 142
                        height: Theme.rowHCompact
                        fontSize: Theme.fontSmall
                        onClicked: pUpdates.running = true
                    }
                }

                Text {
                    width: parent.width
                    text: "обновление и чтение новостей — в разделе «Обновление»"
                    color: Theme.textFaint
                    font.family: page.mono
                    font.pixelSize: Theme.fontTiny
                }
            }
        }
    }

    Text {
        id: clock

        anchors {
            top: parent.top
            right: parent.right
            rightMargin: page.rightMargin
        }

        text: page.currentTime
        color: Theme.text
        font.family: page.mono
        font.pixelSize: Theme.fontSize(18)
        font.letterSpacing: 1
    }

    function drawGraph(ctx, history) {
        ctx.clearRect(
            0,
            0,
            ctx.canvas.width,
            ctx.canvas.height
        )

        var w = ctx.canvas.width
        var h = ctx.canvas.height

        if (history.length < 2)
            return

        var step = w / (history.length - 1)

        // Filled area
        ctx.beginPath()
        ctx.moveTo(0, h)

        for (var i = 0; i < history.length; i++) {
            ctx.lineTo(
                i * step,
                h - history[i] / 100 * h
            )
        }

        ctx.lineTo(w, h)
        ctx.closePath()

        ctx.fillStyle = Qt.rgba(
            Theme.accent.r,
            Theme.accent.g,
            Theme.accent.b,
            0.10
        )

        ctx.fill()

        // Line
        ctx.beginPath()

        for (var j = 0; j < history.length; j++) {
            var x = j * step
            var y = h - history[j] / 100 * h

            if (j)
                ctx.lineTo(x, y)
            else
                ctx.moveTo(x, y)
        }

        ctx.strokeStyle = Theme.accent
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()
    }
}
