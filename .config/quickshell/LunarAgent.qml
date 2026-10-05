import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarAgent — оверлей-агент OpenCode по SUPER+A (как Spotlight).
//  Работает под профилем OpenCode `lunar` (свой промпт и память).
//  Перед отправкой подмешиваю справку: память агента + контекст
//  системы (активное окно, стол, Game Mode). Вопрос в историю идёт
//  без справки. Агент может ПРЕДЛОЖИТЬ действие блоком lunar-action —
//  оверлей выполняет его только по кнопке, без шелла (argv) и лишь из
//  whitelist программ: hyprctl / qs ipc call / скрипты eclipse-*.sh (только
//  известные подкоманды — карта lunarScripts).
//  Обычное окно (FloatingWindow), скругление/блюр — Hyprland. С Hub взаимоисключающий.
// ════════════════════════════════════════════════════════════════
FloatingWindow {
    id: root

    title: "Lunar Agent"
    // фон даёт окно, скругление/блюр — правило Hyprland по заголовку
    color: Theme.surfacePanel
    visible: root.showing
    implicitWidth: 1320
    implicitHeight: 768
    minimumSize: Qt.size(360, 280)

    property bool showing: false
    readonly property string ctxScript: Quickshell.env("HOME") + "/.config/hypr/scripts/eclipse-agent-context.sh"

    function openPanel() { showing = true }
    function closePanel() {
        // закрыл — гашу незавершённый ответ, чтобы не висел процесс
        if (agent.busy) agent.stop()
        agent.pendingAction = ""
        agentInput.text = ""
        showing = false
    }
    function toggle() { if (showing) closePanel(); else openPanel() }

    // агент и Hub взаимоисключающие: открылся агент — гашу Hub.
    // Через общий флаг Theme, а не внешний qs ipc: переключение в одном
    // процессе, без задержки на старт процесса и без наложения затемнений.
    onShowingChanged: {
        if (showing) {
            Theme.activeOverlay = "agent"
            agentFocus.restart()
        }
    }
    Connections {
        target: Theme
        function onActiveOverlayChanged() {
            if (Theme.activeOverlay !== "agent" && root.showing) root.closePanel()
        }
    }

    IpcHandler {
        target: "agent"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
        // отправить вопрос извне (тесты/автоматизация)
        function ask(text: string): void { root.openPanel(); agent.send(text) }
    }

    // содержимое — прямо в окне: фон/рамку/радиус даёт FloatingWindow и
    // правило Hyprland; Esc и клавиатуру вешаю на предмет во весь экран
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closePanel()

        HudNodes { inset: 6; size: 4 }
        HudCorners {
            color: Theme.accent
            size: 18
            thickness: 1
            margin: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: Theme.space3

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2
                Text {
                    text: "AGENT"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(Theme.fontPanelTitle)
                    font.bold: true
                    font.letterSpacing: 3
                }
                Text {
                    text: "opencode · lunar"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                }
                // переключатель контекста системы (память подмешивается всегда)
                Text {
                    text: "ctx"
                    color: agent.contextOn ? Theme.accent : Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.letterSpacing: 1
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: agent.contextOn = !agent.contextOn
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: agent.busy ? "думает…" : "готов"
                    color: agent.busy ? Theme.accent : Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            // история ответа
            ListView {
                id: agentList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.space2
                model: agent.messages
                reuseItems: true
                cacheBuffer: 400
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: positionViewAtEnd()

                delegate: Rectangle {
                    required property var modelData
                    width: agentList.width
                    height: msgText.implicitHeight + Theme.space4
                    radius: Theme.radiusM
                    color: modelData.role === "user" ? Theme.active
                         : (modelData.role === "system" ? "transparent" : Theme.fill)

                    Text {
                        id: msgText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        text: modelData.text
                        color: modelData.role === "user" ? Theme.text
                             : (modelData.role === "system" ? Theme.textFaint : Theme.textDim)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }
            }

            // предложенное агентом действие — выполняется только по кнопке
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                visible: agent.pendingAction !== ""
                radius: Theme.radiusL
                color: Theme.bg
                border.width: 1
                border.color: Theme.borderAccent

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space3
                    spacing: Theme.space2

                    Text {
                        text: "▸"
                        color: Theme.danger
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(14)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: agent.pendingAction
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        // показываю команду целиком, как простой текст: нельзя
                        // обрезать/спрятать HTML-разметкой
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.preferredWidth: 118
                        Layout.preferredHeight: 26
                        radius: Theme.radiusM
                        color: runMouse.containsMouse ? Theme.active : Theme.hoverStrong
                        border.width: 1
                        border.color: Theme.danger
                        Text {
                            anchors.centerIn: parent
                            text: "ВЫПОЛНИТЬ"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.letterSpacing: 1
                        }
                        MouseArea {
                            id: runMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: agent.runAction()
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: Theme.radiusM
                        color: cancelMouse.containsMouse ? Theme.hover : "transparent"
                        border.width: 1
                        border.color: Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(12)
                        }
                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: agent.pendingAction = ""
                        }
                    }
                }
            }

            // строка ввода
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusM
                color: Theme.bg
                border.width: 1
                border.color: agentInput.activeFocus ? Theme.borderAccent : Theme.border

                TextInput {
                    id: agentInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    clip: true
                    selectByMouse: true
                    onAccepted: agent.send(text)
                    Keys.onEscapePressed: root.closePanel()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "спроси что-нибудь…"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(13)
                        visible: agentInput.text === ""
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: Theme.radiusM
                    color: sendMouse.containsMouse ? Theme.active : Theme.hoverStrong
                    border.color: Theme.borderAccent
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: agent.busy ? "СТОП" : "ОТПРАВИТЬ"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        font.letterSpacing: 1
                    }
                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: agent.busy ? agent.stop() : agent.send(agentInput.text)
                    }
                }

                // новая сессия (сбросить контекст диалога)
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 38
                    radius: Theme.radiusM
                    color: newMouse.containsMouse ? Theme.alpha(Theme.danger, 0.12) : "transparent"
                    border.width: 1
                    border.color: newMouse.containsMouse ? Theme.danger : Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "＋"
                        color: newMouse.containsMouse ? Theme.danger : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(15)
                    }
                    MouseArea {
                        id: newMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: agent.newSession()
                    }
                }

                // открыть полноценный opencode в терминале
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 38
                    radius: Theme.radiusM
                    color: tuiMouse.containsMouse ? Theme.active : "transparent"
                    border.width: 1
                    border.color: tuiMouse.containsMouse ? Theme.accent : Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "▣"
                        color: tuiMouse.containsMouse ? Theme.accent : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(15)
                    }
                    MouseArea {
                        id: tuiMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: agent.openTui()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: agent.status
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(10)
                elide: Text.ElideRight
            }
        }
    }

    // ставим фокус в поле ввода после появления слоя
    Timer {
        id: agentFocus
        interval: 60
        onTriggered: agentInput.forceActiveFocus()
    }

    // ═══════════════ логика агента ═══════════════
    QtObject {
        id: agent
        property var messages: []
        property bool busy: false
        property bool contextOn: true
        property string status: "готов"
        property string sessionId: ""
        // вопрос, ждущий сборки справки (контекст + память)
        property string pendingText: ""
        // предложенное агентом действие (ждёт подтверждения)
        property string pendingAction: ""
        // последняя выполненная команда — для возврата результата агенту
        property string lastAction: ""
        // вывод «читающей» команды (буфер/скриншот/статус) не гоню в облако
        property bool lastSensitive: false

        // витрина ограничена: длинный стрим не растит память бесконечно,
        // контекст диалога живёт в сессии OpenCode (--session)
        readonly property int maxMessages: 200
        readonly property int maxChars: 180000

        function capHistory(m) {
            if (m.length > maxMessages)
                m = m.slice(m.length - maxMessages)
            var n = 0, i
            for (i = 0; i < m.length; i++)
                n += m[i].text.length
            var start = 0
            while (n > maxChars && (m.length - start) > 1) {
                n -= m[start].text.length
                start++
            }
            if (start > 0)
                m = m.slice(start)
            return m
        }

        function send(text) {
            if (text.trim() === "" || busy) return
            pendingAction = ""
            messages = capHistory(messages.concat([
                { role: "user", text: text },
                { role: "assistant", text: "" }
            ]))
            busy = true
            status = "собираю справку…"
            if (agentInput) agentInput.text = ""
            pendingText = text
            ctxProc.command = ["bash", root.ctxScript, contextOn ? "1" : "0"]
            ctxProc.running = true
        }

        // вызывается, когда справка собрана: склеиваю её с вопросом
        function submit() {
            if (pendingText === "") return
            var ctx = (ctxOut.text || "").trim()
            var full = pendingText
            if (ctx !== "")
                full = "Справка (память и контекст системы, не часть вопроса):\n"
                     + ctx + "\n\nВопрос: " + pendingText
            pendingText = ""
            status = "opencode работает…"
            dispatch(full)
        }

        // opencode подвешивается, когда stdout — не tty, поэтому гоняем его
        // в псевдо-терминале через `script`; текст вопроса квотим вручную
        function shQuote(s) {
            return "'" + String(s).replace(/'/g, "'\\''") + "'"
        }

        function dispatch(text) {
            if (text === "") return
            var cmd = "opencode run --format json --agent lunar"
            if (sessionId !== "") cmd += " --session " + shQuote(sessionId)
            cmd += " -- " + shQuote(text)
            agentProc.command = ["script", "-qefc", cmd, "/dev/null"]
            agentProc.running = true
            agentWatchdog.restart()
        }

        function appendAssistant(chunk) {
            if (messages.length === 0) return
            var m = messages.slice()
            m[m.length - 1] = { role: "assistant", text: m[m.length - 1].text + chunk }
            messages = capHistory(m)
            extractAction()
        }

        // вырезаю из ответа блок ```lunar-action … ``` в предложенное действие
        function extractAction() {
            if (messages.length === 0) return
            var m = messages.slice()
            var i = m.length - 1
            var text = m[i].text
            var re = /```lunar-action\s*\n([\s\S]*?)```/
            var match = text.match(re)
            if (!match) return
            var cmd = (match[1] || "").trim()
            text = text.replace(re, "").replace(/\n{3,}/g, "\n\n").replace(/\s+$/, "")
            m[i] = { role: "assistant", text: text }
            messages = m
            if (cmd !== "") pendingAction = cmd
        }

        // Разбор команды в argv БЕЗ шелла. Возвращает null, если есть
        // подозрительные символы (цепочки/подстановки/редиректы) или
        // незакрытая кавычка — тогда действие отклоняется.
        function splitArgv(cmd) {
            var c = String(cmd)
            if (/[;&|<>`$\n\r]/.test(c)) return null
            // скрытые/управляющие Unicode (bidi, zero-width) — чтобы нельзя
            // было показать в карточке одно, а выполнить другое
            if (/[\u200B-\u200F\u202A-\u202E\u2066-\u2069\u00AD\uFEFF\u0000-\u0008]/.test(c))
                return null
            var argv = [], cur = "", quote = ""
            for (var i = 0; i < c.length; i++) {
                var ch = c[i]
                if (quote !== "") {
                    if (ch === quote) quote = ""
                    else cur += ch
                } else if (ch === "'" || ch === '"') {
                    quote = ch
                } else if (ch === " " || ch === "\t") {
                    if (cur !== "") { argv.push(cur); cur = "" }
                } else {
                    cur += ch
                }
            }
            if (quote !== "") return null
            if (cur !== "") argv.push(cur)
            return argv.length ? argv : null
        }

        function expandHome(p) {
            if (p.indexOf("~/") === 0)
                return Quickshell.env("HOME") + p.substring(1)
            return p
        }

        // whitelist по argv: hyprctl / qs ipc call <наша цель> / наши скрипты /
        // простые системные утилиты / systemctl --user (ограниченно)
        // скрипты риса: разрешаю только известные подкоманды, а не любые
        // аргументы — так поверхность агента не шире, чем реально нужное
        readonly property var lunarScripts: ({
            "eclipse-status.sh": [],
            "eclipse-perf.sh": [],
            "eclipse-backup.sh": [],
            "eclipse-cleanup.sh": [],
            "eclipse-api-limit.sh": [],
            "eclipse-agent-context.sh": [],
            "eclipse-transparency.sh": [],
            "eclipse-mono-icons.sh": [],
            "eclipse-update.sh": ["--check", "--news"],
            "eclipse-record.sh": ["toggle", "start", "stop", "status", "probe"],
            "eclipse-gamemode.sh": ["toggle", "on", "off"],
            "eclipse-zapret.sh": ["update", "tune", "toggle", "status", "restart", "on", "off"],
            "eclipse-zapret-tg.sh": ["toggle", "status", "open", "restart", "link", "on", "off"],
            "eclipse-vencord.sh": ["update", "status", "patch", "unpatch", "repair"],
            "eclipse-media.sh": ["play-pause", "previous", "next"],
            "eclipse-avatar.sh": ["pick"],
            "eclipse-launch.sh": ["firefox"]
        })
        readonly property var qsTargets: ["hub", "sidebar", "rsidebar", "clipboard",
            "tray", "power", "overview"]
        readonly property var simpleTools: ["wpctl", "playerctl",
            "grim", "slurp", "wl-copy", "wl-paste", "notify-send",
            "checkupdates", "df", "free", "uptime", "nvidia-smi", "lscpu",
            "lsblk", "sensors", "uname"]
        // pactl разрешаю только чтением/регулировкой: load-module/unload-module
        // грузят код в PipeWire-демон — это лишняя поверхность для агента.
        readonly property var pactlSafe: ["get-sink-volume", "get-source-volume",
            "get-sink-mute", "get-source-mute", "set-sink-volume",
            "set-source-volume", "set-sink-mute", "set-source-mute",
            "list", "stat", "info"]
        readonly property var systemctlRead: ["status", "is-active", "is-enabled",
            "show", "list-units", "list-unit-files", "cat"]
        // у hyprctl разрешаю только чтение + eval/dispatch с безопасной Lua
        // строго чтение: reload/notify/rollinglog убраны (мутация/дамп лога/фишинг)
        readonly property var hyprRead: ["clients", "monitors", "workspaces",
            "activewindow", "activeworkspace", "layers", "binds", "version",
            "configerrors", "getoption", "devices", "cursorpos", "systeminfo"]
        readonly property var systemctlMutate: ["start", "stop", "restart",
            "enable", "disable"]

        function isTool(prog, name) {
            return prog === name || prog === "/usr/bin/" + name
                || prog === "/bin/" + name || prog === "/usr/local/bin/" + name
        }
        function isLunarUnit(u) {
            return /^lunar-[A-Za-z0-9_.@-]+\.service$/.test(u || "")
        }
        // eval/dispatch: ТОЛЬКО явный список диспетчеров, ровно один вызов,
        // аргументы — простые литералы. Никаких вложенных вызовов, конкатенации
        // (..), индексации ([]), os/io/exec_*: иначе через hyprctl eval
        // агент уходил в произвольное исполнение (exec_raw, _G["o".."s"]).
        readonly property var safeDispatchers: [
            "focus", "layout", "submap",
            "window.move", "window.close", "window.fullscreen", "window.float",
            "window.pseudo", "window.pin", "window.cycle_next", "window.swap",
            "window.center", "window.resize", "window.alter_zorder", "window.tag",
            "workspace.toggle_special", "workspace.change_id", "workspace.rename",
            "group.toggle", "group.lock_active", "group.active",
            "cursor.move", "cursor.move_to_corner"
        ]
        function safeLua(s) {
            var t = String(s).trim()
            if (t.length === 0 || t.length > 300) return false
            if (/[\u200B-\u200F\u202A-\u202E]/.test(t)) return false
            var m = t.match(/^hl\.dispatch\(hl\.dsp\.([a-z_]+(?:\.[a-z_]+)*)\(([^()]*)\)\)$/)
                 || t.match(/^hl\.dsp\.([a-z_]+(?:\.[a-z_]+)*)\(([^()]*)\)$/)
            if (!m) return false
            if (safeDispatchers.indexOf(m[1]) === -1) return false
            var args = m[2]
            if (args.indexOf("..") !== -1) return false
            // аргументы: числа, строки, ключи, скобки объекта; без ()[];`$\
            return /^[A-Za-z0-9_\-\=\"'{}\s,.:]*$/.test(args)
        }

        function allowedArgv(argv) {
            if (!argv || argv.length === 0) return false
            var prog = expandHome(argv[0])
            if (isTool(prog, "hyprctl")) {
                var sub = argv[1] || ""
                if (hyprRead.indexOf(sub) !== -1) return true
                if (sub === "eval" || sub === "dispatch")
                    return safeLua(argv.slice(2).join(" "))
                return false
            }
            if (isTool(prog, "qs")) {
                if (argv[1] !== "ipc" || argv[2] !== "call") return false
                return qsTargets.indexOf(argv[3]) !== -1
            }
            if (isTool(prog, "systemctl")) {
                if (argv[1] !== "--user") return false
                var verb = argv[2] || ""
                // чтение: без юнита или только lunar-*
                if (systemctlRead.indexOf(verb) !== -1)
                    return argv.length === 3 || (argv.length === 4 && isLunarUnit(argv[3]))
                // мутации: ровно один юнит, только lunar-*
                if (systemctlMutate.indexOf(verb) !== -1)
                    return argv.length === 4 && isLunarUnit(argv[3])
                return false
            }
            if (isTool(prog, "pactl")) {
                return pactlSafe.indexOf(argv[1] || "") !== -1
            }
            for (var i = 0; i < simpleTools.length; i++)
                if (isTool(prog, simpleTools[i])) return true
            var dir = Quickshell.env("HOME") + "/.config/hypr/scripts/"
            if (prog.indexOf(dir) === 0) {
                var f = prog.substring(dir.length)
                if (!/^eclipse-[A-Za-z0-9_-]+\.sh$/.test(f))
                    return false
                var subs = lunarScripts[f]
                if (subs === undefined)
                    return false
                if (argv.length === 1)
                    return subs.length === 0
                if (argv.length === 2)
                    return subs.indexOf(argv[1]) !== -1
                return false
            }
            return false
        }

        function systemMsg(t) {
            messages = capHistory(messages.concat([{ role: "system", text: t }]))
        }

        function runAction() {
            var cmd = pendingAction
            if (cmd === "") return
            pendingAction = ""
            var argv = splitArgv(cmd)
            if (!argv || !allowedArgv(argv)) {
                status = "действие не разрешено"
                systemMsg("✕ не разрешено: " + cmd)
                return
            }
            argv[0] = expandHome(argv[0])
            var base = argv[0].substring(argv[0].lastIndexOf("/") + 1)
            lastSensitive = ["wl-paste", "grim", "systemctl"].indexOf(base) !== -1
            lastAction = cmd
            systemMsg("▶ " + cmd)
            actionProc.command = argv
            actionProc.running = true
            actionWatchdog.restart()
        }

        function actionDone() {
            actionWatchdog.stop()
            var out = ((actionOut.text || "") + (actionErr2.text || "")).trim()
            if (out.length > 2000) out = out.slice(0, 2000) + "…"
            systemMsg(out !== "" ? out : "готово")
            status = "готов"
            followUp(out)
        }

        // возвращаю агенту результат действия, чтобы он прокомментировал.
        // Только если оверлей открыт и не занят; в историю — лишь ответ
        // ассистента (без служебной строки-вопроса).
        function followUp(out) {
            if (!root.showing || busy || lastAction === "") return
            // чувствительный вывод (буфер/скриншот/статус) в облако не шлю
            if (lastSensitive) return
            var prompt = "Я выполнил действие:\n" + lastAction
                + "\n\nВывод:\n" + (out !== "" ? out : "(пусто)")
                + "\n\nПрокомментируй кратко и предложи следующий шаг, если это уместно."
            messages = capHistory(messages.concat([{ role: "assistant", text: "" }]))
            busy = true
            status = "opencode работает…"
            dispatch(prompt)
        }

        function newSession() {
            ctxProc.running = false
            pendingText = ""
            pendingAction = ""
            agentProc.running = false
            agentWatchdog.stop()
            busy = false
            status = "новая сессия"
            if (sessionId !== "") {
                agentSessions.command = ["opencode", "session", "delete", sessionId]
                agentSessions.running = true
            }
            sessionId = ""
            messages = []
        }

        function openTui() {
            agentTerm.command = ["bash", "-c",
                "hyprctl dispatch 'hl.dsp.exec_cmd(\"kitty -e opencode\")'"]
            agentTerm.running = true
        }

        function stop() {
            ctxProc.running = false
            pendingText = ""
            agentProc.running = false
            agentWatchdog.stop()
            busy = false
            status = "остановлено"
        }
    }

    Timer {
        id: agentWatchdog
        interval: 600000        // 10 мин: дольше агент уже не отвечает — не висим вечно
        repeat: false
        onTriggered: agent.stop()
    }

    // справка: память агента + контекст системы (скрипт)
    Process {
        id: ctxProc
        running: false
        onExited: (exitCode) => agent.submit()
        stdout: StdioCollector { id: ctxOut }
        stderr: StdioCollector {}
    }

    Process {
        id: agentProc
        running: false
        // рабочая папка агента = папка памяти: запись разрешена только здесь,
        // а попытки писать в проект упираются в external_directory
        workingDirectory: Quickshell.env("HOME") + "/.local/state/lunar"
        onExited: (exitCode) => {
            agentWatchdog.stop()
            agent.busy = false
            if (exitCode === 0) {
                agent.status = "готов"
            } else {
                var e = (agentErr.text || "").trim()
                agent.status = e !== "" ? e.split("\n").pop() : ("ошибка " + exitCode)
            }
        }
        stderr: StdioCollector { id: agentErr }
        stdout: SplitParser {
            onRead: function(line) {
                if (!line) return
                line = line.replace(/\r/g, "")
                try {
                    var ev = JSON.parse(line)
                    if (ev.type === "text" && ev.part && ev.part.text !== undefined)
                        agent.appendAssistant(ev.part.text)
                    if (ev.sessionID) agent.sessionId = ev.sessionID
                } catch (e) { /* не-JSON строки игнорируем */ }
            }
        }
    }

    // выполнение подтверждённого действия
    Process {
        id: actionProc
        running: false
        onExited: (exitCode) => agent.actionDone()
        stdout: StdioCollector { id: actionOut }
        stderr: StdioCollector { id: actionErr2 }
    }
    // предохранитель: команда вроде `nvidia-smi -l 1` не должна подвешивать агента
    Timer {
        id: actionWatchdog
        interval: 15000
        onTriggered: {
            if (actionProc.running) {
                actionProc.running = false
                agent.systemMsg("⏱ действие остановлено по таймауту")
                agent.status = "готов"
            }
        }
    }

    Process { id: agentTerm; running: false }
    Process { id: agentSessions; running: false }
}
