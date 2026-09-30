import QtQuick
import Quickshell.Io
import "../"

// ════════════════════════════════════════════════════════════════
//  UpdatePage — обновление системы с буфером, чтением новостей
//  Arch (переведённых) и откатом. Логика — eclipse-update.sh.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    property int rightMargin: 36
    property string log: ""
    property bool busy: false

    // состояние буфера/обновлений
    property string newestAge: "—"
    property string pending: "—"
    property string newsText: ""
    property var newsItems: []
    property bool newsLoaded: false
    // разбор новостей агентом
    property bool agentBusy: false
    property string agentText: ""
    // идёт проверка (pCheck/pNews) — для отдачи кнопке
    property bool checking: false

    component ActionButton: Rectangle {
        property string label: ""
        property bool accent: false
        property bool enabledBtn: true
        signal clicked()

        width: Math.max(120, btnText.implicitWidth + 34)
        height: 36
        radius: Theme.radius
        color: !enabledBtn ? Theme.fill
             : btnArea.containsMouse ? Theme.active
             : "transparent"
        border.width: 1
        border.color: !enabledBtn ? Theme.border
                    : (btnArea.containsMouse || accent) ? Theme.accent : Theme.border

        Text {
            id: btnText
            anchors.centerIn: parent
            text: label
            color: !enabledBtn ? Theme.textFaint
                 : (btnArea.containsMouse || parent.accent) ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabledBtn ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: enabledBtn
            onClicked: parent.clicked()
        }
    }

    // ── проверка состояния ────────────────────────────────────
    Process {
        id: pCheck
        command: ["bash", "-c",
            "$HOME/.config/hypr/scripts/eclipse-update.sh --check 2>&1"]
        onRunningChanged: page.checking = pCheck.running || pNews.running
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                page.log = t
                var age = t.match(/(\d+)\s*дн\./)
                if (age) page.newestAge = (age[1] === "999") ? "нет данных" : (age[1] + " дн.")
                var pk = t.match(/пакетов к обновлению:\s*(\S+)/)
                if (pk) page.pending = pk[1]
            }
        }
    }

    // ── новости (переведённые) ────────────────────────────────
    Process {
        id: pNews
        command: ["bash", "-c",
            "$HOME/.config/hypr/scripts/eclipse-update.sh --news 2>&1"]
        onRunningChanged: page.checking = pCheck.running || pNews.running
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                page.newsText = t
                // разбираем блоки "── дата ── / RU: … / EN: …"
                var items = []
                var lines = t.split("\n")
                var cur = null
                for (var i = 0; i < lines.length; i++) {
                    var L = lines[i]
                    var m = L.match(/^──\s*(\S+)\s*──/)
                    if (m) { cur = { date: m[1], ru: "", en: "" }; items.push(cur); continue }
                    if (!cur) continue
                    if (L.indexOf("RU:") === 0) cur.ru = L.substring(3).trim()
                    else if (L.indexOf("EN:") === 0) cur.en = L.substring(3).trim()
                }
                page.newsItems = items
                page.newsLoaded = true
            }
        }
    }

    // ── действия в терминале (sudo интерактивный) ─────────────
    Process {
        id: pAction
        onRunningChanged: page.busy = running
        onExited: { page.busy = false; pCheck.running = true }
    }

    // ── разбор новостей агентом (opencode под pty) ─────────────
    Process {
        id: pAgent
        onRunningChanged: page.agentBusy = running
        stdout: StdioCollector {
            onStreamFinished: page.agentText = text.trim()
        }
    }
    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }
    function runAgentNews() {
        if (pAgent.running) return
        var lines = []
        for (var i = 0; i < page.newsItems.length; i++)
            lines.push("- " + page.newsItems[i].date + ": " + page.newsItems[i].en)
        if (lines.length === 0) return
        var prompt = "Свежие новости Arch Linux (EN). Переведи на русский кратко и по делу, "
            + "выдели, на что важно обратить внимание перед обновлением (ручное вмешательство, "
            + "ломающие изменения, безопасность). Если критичного нет — так и скажи.\n\n"
            + lines.join("\n")
        page.agentText = ""
        // opencode подвешивается без tty — гоняю через script (как в оверлее)
        pAgent.command = ["script", "-qefc",
            "opencode run --agent lunar -- " + shQuote(prompt), "/dev/null"]
        pAgent.running = true
    }

    // L39: раньше был kitty --hold → busy висел, пока пользователь сам не
    // закроет окно, хотя команда давно завершилась. Держим окно только при
    // ошибке (чтобы прочитать вывод), при успехе kitty закрывается сам.
    function termCommand(script) {
        return ["kitty", "-e", "bash", "-c",
            script + "; rc=$?; if [ $rc -ne 0 ]; then " +
            "echo; echo \"код возврата: $rc\"; " +
            "read -r -p 'Enter — закрыть…' _ </dev/tty; fi"]
    }

    function runUpdate() {
        // L39: не подменяем команду у работающего процесса
        if (pAction.running)
            return
        pAction.command = termCommand(
            "$HOME/.config/hypr/scripts/eclipse-update.sh --now")
        pAction.running = true
    }

    function runUpdateBuffered() {
        if (pAction.running)
            return
        pAction.command = termCommand(
            "$HOME/.config/hypr/scripts/eclipse-update.sh")
        pAction.running = true
    }

    // кэш pacman (2 версии), журнал (≤200 МБ), сироты под подтверждение
    function runClean() {
        if (pAction.running)
            return
        pAction.command = termCommand(
            "$HOME/.config/hypr/scripts/eclipse-update.sh --clean")
        pAction.running = true
    }

    function showRollback() {
        // предпросмотр снимков timeshift (без реального отката)
        if (pAction.running)
            return
        pAction.command = termCommand(
            "if command -v timeshift >/dev/null 2>&1; then " +
            "echo 'Снимки timeshift:'; sudo timeshift --list; " +
            "echo; echo 'Откат: sudo timeshift --restore --snapshot <имя>'; " +
            "else echo 'timeshift не установлен (см. get-deps.sh)'; fi; " +
            "read -r -p 'Enter — закрыть…' _ </dev/tty")
        pAction.running = true
    }

    Component.onCompleted: {
        pCheck.running = true
        pNews.running = true
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: function(event) {
                var d = event.angleDelta.y
                if (d !== 0)
                    flick.contentY = Math.max(0, Math.min(
                        flick.contentHeight - flick.height, flick.contentY - d))
                event.accepted = true
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.rightMargin
            spacing: 18

            Text {
                text: "ОБНОВЛЕНИЕ"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ── состояние ──
            Column {
                width: parent.width
                spacing: 10

                Row {
                    spacing: 24
                    Text {
                        text: "свежие новости: " + page.newestAge
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        text: "буфер: 2 дн."
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        text: "пакетов: " + page.pending
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Row {
                    spacing: 8

                    ActionButton {
                        label: page.busy ? "РАБОТАЮ…" : "ОБНОВИТЬ"
                        accent: true
                        enabledBtn: !page.busy
                        onClicked: page.runUpdateBuffered()
                    }
                    ActionButton {
                        label: "ОБНОВИТЬ СРАЗУ"
                        enabledBtn: !page.busy
                        onClicked: page.runUpdate()
                    }
                    ActionButton {
                        label: "ОТКАТ"
                        enabledBtn: !page.busy
                        onClicked: page.showRollback()
                    }
                    ActionButton {
                        label: page.checking ? "ПРОВЕРЯЮ…" : "ПРОВЕРИТЬ"
                        enabledBtn: !page.busy && !page.checking
                        onClicked: { page.checking = true; pCheck.running = true; pNews.running = true }
                    }
                    ActionButton {
                        label: page.agentBusy ? "АГЕНТ ДУМАЕТ…" : "РАЗБОР АГЕНТОМ"
                        enabledBtn: !page.busy && !page.agentBusy && page.newsItems.length > 0
                        onClicked: page.runAgentNews()
                    }
                    ActionButton {
                        label: "ПОЧИСТИТЬ"
                        enabledBtn: !page.busy
                        onClicked: page.runClean()
                    }
                }

                Text {
                    visible: page.log !== ""
                    width: parent.width
                    text: page.log
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ── новости (переведённые) ──
            Text {
                text: "НОВОСТИ ARCH (ПЕРЕВОД)"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 2
            }

            // ── разбор новостей агентом: перевод и на что обратить внимание ──
            Rectangle {
                width: col.width
                visible: page.agentBusy || page.agentText !== ""
                height: agentCol.implicitHeight + 24
                radius: Theme.radius
                color: Theme.bgCard
                border.width: 1
                border.color: Theme.accent

                Column {
                    id: agentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: page.agentBusy ? "АГЕНТ РАЗБИРАЕТ…" : "РАЗБОР ОТ АГЕНТА"
                        color: page.agentBusy ? Theme.textFaint : Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                    }
                    Text {
                        width: parent.width
                        visible: page.agentText !== ""
                        text: page.agentText
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }

            Repeater {
                model: page.newsItems

                delegate: Rectangle {
                    required property var modelData
                    width: col.width
                    height: newsCol.implicitHeight + 24
                    radius: Theme.radius
                    color: Theme.fill
                    border.width: 1
                    border.color: Theme.border

                    Column {
                        id: newsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 6

                        Text {
                            text: modelData.date
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }
                        Text {
                            width: parent.width
                            text: modelData.ru
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            text: modelData.en
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            Text {
                visible: page.newsItems.length === 0
                text: page.newsLoaded
                    ? "новости не загрузились (проверь сеть) — нажми ПРОВЕРИТЬ"
                    : "новости загружаются…"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
}
