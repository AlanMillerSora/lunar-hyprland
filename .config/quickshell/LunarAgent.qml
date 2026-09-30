import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarAgent — оверлей-агент OpenCode по SUPER+A (как Spotlight).
//  Скрытый слой не рендерится (mask = null): в покое нагрузки ноль.
//  Вопрос уходит в `opencode run --format json`; ответ стримится
//  событиями и дописывается в историю. Контекст держу в сессии
//  (--session), пока не сброшу (＋). С Hub взаимоисключающий.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "lunar-agent"

    // окно — no-op, пока закрыто (как Hub)
    mask: Region { item: root.showing ? backdrop : null }

    property bool showing: false

    function openPanel() { showing = true }
    function closePanel() {
        // закрыл — гашу незавершённый ответ, чтобы не висел процесс
        if (agent.busy) agent.stop()
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
    }

    // клик по фону / Esc — закрыть
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: root.showing ? Theme.alpha(Theme.bgPanel, 0.62) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animMed } }
        focus: root.showing
        Keys.onEscapePressed: root.closePanel()

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closePanel()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(1320, parent.width - 80)
        height: Math.min(768, parent.height - 80)
        radius: Theme.radius
        color: Theme.bgPanel
        border.color: Theme.border
        border.width: 1
        // карточка живёт, пока видна: mask=null гасит только ввод,
        // а отрисовка идёт всегда (см. AGENTS про фон оверлея)
        visible: root.showing || opacity > 0
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.90
        Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack } }

        // клик по карточке не закрывает оверлей
        MouseArea { anchors.fill: parent }

        HudCorners {
            color: Theme.accent
            size: 18
            thickness: 1
            margin: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "AGENT"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(17)
                    font.bold: true
                    font.letterSpacing: 3
                }
                Text {
                    text: "opencode"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(11)
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
                spacing: 8
                model: agent.messages
                reuseItems: true
                cacheBuffer: 400
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: positionViewAtEnd()

                delegate: Rectangle {
                    required property var modelData
                    width: agentList.width
                    height: msgText.implicitHeight + 16
                    radius: Theme.radius
                    color: modelData.role === "user" ? Theme.active : Theme.fill
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        id: msgText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        text: modelData.text
                        color: modelData.role === "user" ? Theme.text : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }
            }

            // строка ввода
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radius
                color: Theme.bg
                border.width: 1
                border.color: agentInput.activeFocus ? Theme.borderAccent : Theme.border

                TextInput {
                    id: agentInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
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
                    radius: Theme.radius
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

                // новая сессия (сбросить контекст)
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 38
                    radius: Theme.radius
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
                    radius: Theme.radius
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
        property string status: "готов"
        property string sessionId: ""
        // сообщение, ждущее завершения текущего запуска — не теряем
        property string queued: ""

        // витрина ограничена: длинный стрим не растит память бесконечно,
        // контекст агента живёт в сессии OpenCode (--session)
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
            messages = capHistory(messages.concat([
                { role: "user", text: text },
                { role: "assistant", text: "" }
            ]))
            busy = true
            status = "opencode работает…"
            if (agentInput) agentInput.text = ""
            dispatch(text)
        }

        // argv-массив (без shell): кавычки/апострофы в тексте не ломают команду
        function dispatch(text) {
            if (text === "") return
            if (agentProc.running) { queued = text; return }
            var args = ["opencode", "run", "--format", "json"]
            if (sessionId !== "") { args.push("--session", sessionId) }
            args.push("--", text)
            agentProc.command = args
            agentProc.running = true
            agentWatchdog.restart()
        }

        function appendAssistant(chunk) {
            if (messages.length === 0) return
            var m = messages.slice()
            m[m.length - 1] = { role: "assistant", text: m[m.length - 1].text + chunk }
            messages = capHistory(m)
        }

        function newSession() {
            agentProc.running = false
            agentWatchdog.stop()
            queued = ""
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
            agentProc.running = false
            agentWatchdog.stop()
            queued = ""
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

    Process {
        id: agentProc
        running: false
        onExited: (exitCode) => {
            agentWatchdog.stop()
            agent.busy = false
            if (exitCode === 0) {
                agent.status = "готов"
            } else {
                var e = (agentErr.text || "").trim()
                agent.status = e !== "" ? e.split("\n").pop() : ("ошибка " + exitCode)
            }
            if (agent.queued !== "") {
                var p = agent.queued
                agent.queued = ""
                agent.busy = true
                agent.status = "opencode работает…"
                agent.dispatch(p)
            }
        }
        stderr: StdioCollector { id: agentErr }
        stdout: SplitParser {
            onRead: function(line) {
                if (!line) return
                try {
                    var ev = JSON.parse(line)
                    if (ev.type === "text" && ev.part && ev.part.text !== undefined)
                        agent.appendAssistant(ev.part.text)
                    if (ev.sessionID) agent.sessionId = ev.sessionID
                } catch (e) { /* не-JSON строки игнорируем */ }
            }
        }
    }

    Process { id: agentTerm; running: false }
    Process { id: agentSessions; running: false }
}
