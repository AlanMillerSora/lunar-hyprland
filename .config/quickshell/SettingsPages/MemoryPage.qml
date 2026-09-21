import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  MemoryPage — раздел MEMORY: индикатор заполнения памяти
//  (RAM/SWAP, живые значения из /proc/meminfo) плюс очистка системы.
//  Кнопка «ОЧИСТИТЬ» запускает eclipse-cleanup.sh через pkexec.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    readonly property string scriptPath: (Quickshell.env("HOME") || "/home/sora")
        + "/.config/hypr/scripts/eclipse-cleanup.sh"

    // ── память (в килобайтах) ──
    property real memTotal: 0
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0

    readonly property real memPct: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real swapPct: swapTotal > 0 ? swapUsed / swapTotal : 0

    function gb(kb) { return (kb / 1048576).toFixed(1) }

    function applyMem(t) {
        var lines = t.split("\n")
        var v = {}
        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split(":")
            if (p.length === 2)
                v[p[0].trim()] = parseFloat(p[1].trim()) || 0
        }
        var total = v["MemTotal"] || 0
        var avail = v["MemAvailable"] || 0
        page.memTotal = total
        page.memUsed = Math.max(0, total - avail)
        var st = v["SwapTotal"] || 0
        var sf = v["SwapFree"] || 0
        page.swapTotal = st
        page.swapUsed = Math.max(0, st - sf)
    }

    // ── очистка ──
    property bool running: false
    property string status: ""
    property string logText: ""
    property var enabled: ({})

    readonly property var options: [
        { key: "orphans",  flag: "--orphans",  label: "Пакеты-сироты", on: true },
        { key: "pkgcache", flag: "--pkgcache", label: "Кэш пакетов", on: true },
        { key: "pkgall",   flag: "--pkgcache-all", label: "Весь кэш пакетов (агрессивно)", on: false },
        { key: "journal",  flag: "--journal",  label: "Журнал systemd", on: true },
        { key: "tmpfiles", flag: "--tmpfiles", label: "Временные файлы", on: true },
        { key: "yay",      flag: "--yay",      label: "Кэш сборок yay", on: true },
        { key: "thumbs",   flag: "--thumbs",   label: "Эскизы и шрифты", on: true },
        { key: "browser",  flag: "--browser",  label: "Кэш браузеров", on: false }
    ]

    Component.onCompleted: {
        var e = {}
        for (var i = 0; i < options.length; i++)
            e[options[i].key] = options[i].on
        enabled = e
        memProc.running = true
    }

    function isOn(key) { return enabled[key] === true }

    function toggleOption(key) {
        var e = Object.assign({}, enabled)
        e[key] = !e[key]
        enabled = e
    }

    function buildFlags() {
        var f = []
        for (var i = 0; i < options.length; i++)
            if (enabled[options[i].key])
                f.push(options[i].flag)
        return f.join(" ")
    }

    function start(dry) {
        if (running)
            return
        var flags = buildFlags()
        if (flags.length === 0) {
            status = "Ничего не выбрано"
            return
        }
        if (dry)
            flags += " --dry-run"
        logText = ""
        status = dry ? "Сухой прогон (без удаления)…" : "Очистка… введи пароль в окне polkit"
        running = true
        cleanProc.command = ["bash", "-c",
            "pkexec '" + scriptPath + "' " + flags + " 2>&1"]
        cleanProc.running = true
    }

    function startTerminal() {
        var flags = buildFlags()
        if (flags.length === 0) {
            status = "Ничего не выбрано"
            return
        }
        terminalProc.command = ["bash", "-c",
            "setsid kitty --hold -e sudo '" + scriptPath + "' " + flags + " >/dev/null 2>&1 &"]
        terminalProc.running = true
        status = "Открыл терминал — пароль вводится там"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.rightMargin: 36
        spacing: 8

        Text {
            text: "MEMORY"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.letterSpacing: 3
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        // ── индикатор заполнения памяти ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            color: Theme.bgCard
            radius: Theme.radius
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "RAM"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: page.gb(page.memUsed) + " / " + page.gb(page.memTotal) + " GB"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                    Text {
                        text: Math.round(page.memPct * 100) + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                // сама «забитость»
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10
                    radius: 5
                    color: Theme.trackBg
                    border.width: 1
                    border.color: Theme.border

                    Rectangle {
                        width: parent.width * page.memPct
                        height: parent.height
                        radius: 5
                        color: page.memPct > 0.9 ? Theme.danger : Theme.accent
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "SWAP"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Theme.trackBg
                        Rectangle {
                            width: parent.width * page.swapPct
                            height: parent.height
                            radius: 3
                            color: Theme.textDim
                        }
                    }
                    Text {
                        text: page.swapTotal > 0
                            ? page.gb(page.swapUsed) + " / " + page.gb(page.swapTotal) + " GB"
                            : "нет swap"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                    }
                }
            }
        }

        // ── заголовок очистки ──
        Text {
            Layout.fillWidth: true
            text: "ОЧИСТКА СИСТЕМЫ — ненужные пакеты, старые кэши и логи"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        // ── опции в две колонки ──
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 4

            Repeater {
                model: page.options

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: Theme.radius
                    color: page.isOn(modelData.key)
                        ? Theme.alpha(Theme.accent, 0.06)
                        : "transparent"
                    border.width: 1
                    border.color: optMouse.containsMouse ? Theme.borderAccent : Theme.border

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: page.isOn(modelData.key)
                                ? Theme.alpha(Theme.accent, 0.15)
                                : "transparent"
                            border.width: 1
                            border.color: page.isOn(modelData.key)
                                ? Theme.accent
                                : Theme.textFaint

                            Text {
                                anchors.centerIn: parent
                                visible: page.isOn(modelData.key)
                                text: "\uf00c"
                                color: Theme.accent
                                font.family: Theme.iconFont
                                font.pixelSize: 8
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: page.isOn(modelData.key) ? Theme.text : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        id: optMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.toggleOption(modelData.key)
                    }
                }
            }
        }

        // ── кнопки ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radius
                color: page.running
                    ? Theme.alpha(Theme.accent, 0.05)
                    : (runMouse.containsMouse ? Theme.alpha(Theme.accent, 0.16) : Theme.alpha(Theme.accent, 0.10))
                border.width: 1
                border.color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: page.running ? "РАБОТАЮ…" : "ОЧИСТИТЬ"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 2
                }

                MouseArea {
                    id: runMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !page.running
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.start(false)
                }
            }

            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 38
                radius: Theme.radius
                color: dryMouse.containsMouse ? Theme.alpha(Theme.text, 0.06) : "transparent"
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "СУХОЙ ПРОГОН"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                MouseArea {
                    id: dryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !page.running
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.start(true)
                }
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 38
                radius: Theme.radius
                color: termMouse.containsMouse ? Theme.alpha(Theme.text, 0.06) : "transparent"
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "В ТЕРМИНАЛЕ"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                MouseArea {
                    id: termMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.startTerminal()
                }
            }
        }

        // ── отчёт ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 60
            color: Theme.bgCard
            radius: Theme.radius
            border.width: 1
            border.color: Theme.border

            Flickable {
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                contentWidth: width
                contentHeight: logItem.implicitHeight

                Text {
                    id: logItem
                    width: parent.width
                    text: page.logText.length > 0
                        ? page.logText
                        : "отчёт об очистке появится здесь…"
                    color: page.logText.length > 0 ? Theme.text : Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.status
            visible: page.status.length > 0
            color: page.running ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 9
        }
    }

    // ── живые данные о памяти ──
    Process {
        id: memProc
        running: false
        command: ["bash", "-c",
            "grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: page.applyMem(text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: memProc.running = true
    }

    Process {
        id: cleanProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: page.logText = text
        }
        onExited: {
            page.running = false
            page.status = "Готово"
        }
    }

    Process {
        id: terminalProc
        running: false
    }
}
