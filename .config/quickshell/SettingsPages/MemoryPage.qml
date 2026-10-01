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

    // L31: без хардкода домашней папки — берём HOME из окружения
    readonly property string scriptPath: (Quickshell.env("HOME") || "")
        + "/.config/hypr/scripts/eclipse-cleanup.sh"

    // ── память (в килобайтах) ──
    property real memTotal: 0
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0

    readonly property real memPct: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real swapPct: swapTotal > 0 ? swapUsed / swapTotal : 0
    // память «в целом» = RAM + swap
    readonly property real memAllPct: (memTotal + swapTotal) > 0
        ? (memUsed + swapUsed) / (memTotal + swapTotal)
        : 0

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
    // M42: не даём запускать очистку в терминале пачкой
    property bool terminalBusy: false
    property string status: ""
    property string logText: ""
    // M44: переименовано из `enabled` — не затеняет Item.enabled
    property var opts: ({})

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
        opts = e
        memProc.running = true
    }

    function isOn(key) { return opts[key] === true }

    function toggleOption(key) {
        var e = Object.assign({}, opts)
        e[key] = !e[key]
        opts = e
    }

    function buildFlags() {
        var f = []
        for (var i = 0; i < options.length; i++)
            if (opts[options[i].key])
                f.push(options[i].flag)
        return f
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
            flags.push("--dry-run")
        logText = ""
        status = dry ? "Сухой прогон (без удаления)…" : "Очистка… введи пароль в окне polkit"
        running = true
        // L31: путь и флаги — аргументами, без shell
        cleanProc.command = ["pkexec", scriptPath].concat(flags)
        cleanProc.running = true
    }

    function startTerminal() {
        // M42: защита от повторных запусков
        if (terminalBusy)
            return
        var flags = buildFlags()
        if (flags.length === 0) {
            status = "Ничего не выбрано"
            return
        }
        // L31: argv без shell
        terminalProc.command = ["setsid", "kitty", "--hold", "-e", "sudo", scriptPath].concat(flags)
        terminalProc.running = true
        terminalBusy = true
        terminalCooldown.restart()
        status = "Открыл терминал — пароль вводится там"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.rightMargin: 36
        spacing: Theme.space2

        Text {
            text: "MEMORY"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitle
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
            Layout.preferredHeight: 112
            color: Theme.fill
            radius: Theme.radius

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space3
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "RAM"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: page.gb(page.memUsed) + " / " + page.gb(page.memTotal) + " GB"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                    }
                    Text {
                        text: Math.round(page.memPct * 100) + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                    }
                }

                // сама «забитость»
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10
                    radius: 5
                    color: Theme.trackBg

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
                        text: "MEM"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: Theme.radius
                        color: Theme.trackBg
                        Rectangle {
                            width: parent.width * page.memAllPct
                            height: parent.height
                            radius: Theme.radius
                            color: page.memAllPct > 0.9 ? Theme.danger : Theme.accent2
                            Behavior on width { NumberAnimation { duration: 200 } }
                        }
                    }
                    Text {
                        text: Math.round(page.memAllPct * 100) + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        font.bold: true
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
                        radius: Theme.radius
                        color: Theme.trackBg
                        Rectangle {
                            width: parent.width * page.swapPct
                            height: parent.height
                            radius: Theme.radius
                            color: Theme.textDim
                            Behavior on width { NumberAnimation { duration: 200 } }
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
            font.pixelSize: Theme.fontTiny
        }

        // ── опции в две колонки ──
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.space2
            rowSpacing: Theme.space1

            Repeater {
                model: page.options

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: Theme.radius
                    color: page.isOn(modelData.key)
                        ? Theme.active
                        : Theme.fill

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space2

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
                            font.pixelSize: Theme.fontTiny
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
            spacing: Theme.space2

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.rowHCompact
                radius: Theme.radius
                color: page.running
                    ? Theme.hover
                    : (runMouse.containsMouse ? Theme.active : Theme.active)
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
                Layout.preferredHeight: Theme.rowHCompact
                radius: Theme.radius
                color: dryMouse.containsMouse ? Theme.alpha(Theme.text, 0.06) : "transparent"
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "СУХОЙ ПРОГОН"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
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
                Layout.preferredHeight: Theme.rowHCompact
                radius: Theme.radius
                color: termMouse.containsMouse ? Theme.alpha(Theme.text, 0.06) : "transparent"
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "В ТЕРМИНАЛЕ"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }

                MouseArea {
                    id: termMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !page.terminalBusy
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
            color: Theme.fill
            radius: Theme.radius

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.space3
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
                    font.pixelSize: Theme.fontTiny
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
        // X1: пока Hub закрыт, страницы не видно — живой поллинг не нужен
        running: page.visible
        repeat: true
        onTriggered: memProc.running = true
    }

    // M42: остывание кнопки «В ТЕРМИНАЛЕ» (процесс отцеплен, running не помогает)
    Timer {
        id: terminalCooldown
        interval: 3000
        repeat: false
        onTriggered: page.terminalBusy = false
    }

    Process {
        id: cleanProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: page.logText = text
        }
        stderr: StdioCollector {
            onStreamFinished: page.logText = (page.logText + "\n" + text).trim()
        }
        // M43: отмена/ошибка polkit — не «Готово»
        onExited: (exitCode) => {
            page.running = false
            if (exitCode === 0)
                page.status = "Готово"
            else if (exitCode === 126 || exitCode === 127)
                page.status = "Отменено: аутентификация не пройдена"
            else
                page.status = "Завершено с кодом " + exitCode
        }
    }

    Process {
        id: terminalProc
        running: false
    }
}
