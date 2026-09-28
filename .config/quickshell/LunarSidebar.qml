import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: root

    anchors { top: true; left: true; bottom: true }
    implicitWidth: 560
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "lunar-sidebar"
    // клавиатуру берём только когда панель выдвинута (нужна для заметок)
    WlrLayershell.keyboardFocus: root.collapsed ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

    property bool collapsed: true
    property int tabIndex: 0
    // заметки: true, если пользователь уже правил текст до/во время загрузки файла —
    // тогда загрузка не должна затирать его правку (TOCTOU при старте)
    property bool notesDirty: false
    // L24: панель, открытая по IPC, не должна сама спрятаться через 600 мс
    property bool pinned: false

    function openPanel() { collapsed = false }
    function closePanel() { collapsed = true }
    function toggle() { collapsed = !collapsed }

    onCollapsedChanged: {
        if (!collapsed) {
            sysStats.running = true
            sysStatsTimer.restart()
            if (!pinned && !stripHover.hovered && !contentHover.hovered) hideTimer.restart()
        }
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void {
            if (root.collapsed) { root.pinned = true; root.openPanel() }
            else { root.pinned = false; root.closePanel() }
        }
        function open(): void { root.pinned = true; root.openPanel() }
        function close(): void { root.pinned = false; root.closePanel() }
        function tab(idx: int): void { root.tabIndex = Math.max(0, Math.min(1, idx)) }
    }

    mask: Region {
        item: collapsed ? hoverStrip : contentBox
    }

    Item {
        id: hoverStrip
        anchors.top: parent.top
        anchors.topMargin: 46
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 22

        HoverHandler {
            id: stripHover
            onHoveredChanged: {
                if (hovered) root.openPanel()
                else if (!contentHover.hovered) hideTimer.restart()
            }
        }
    }

    Rectangle {
        id: contentBox
        anchors.top: parent.top
        anchors.topMargin: 46
        anchors.bottom: parent.bottom
        width: 540
        // при скрытии уводим панель целиком за край (раньше оставалась видимая полоска)
        x: collapsed ? -(width + 4) : 0
        color: Theme.bg
        radius: Theme.radiusM
        border.color: Theme.border
        border.width: collapsed ? 0 : 1

        // острые HUD-скобки по углам — единый стиль с Hub
        HudCorners {
            color: Theme.accent
            size: 16
            thickness: 1
            margin: 8
        }

        Behavior on x {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: contentHover
            onHoveredChanged: {
                if (hovered) root.openPanel()
                else if (!stripHover.hovered) hideTimer.restart()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            RowLayout {
                spacing: 8
                Text {
                    text: "LUNAR"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(17)
                    font.bold: true
                    font.letterSpacing: 3
                }
                Item { Layout.fillWidth: true }

                // закрыть панель
                Rectangle {
                    width: 28
                    height: 22
                    radius: Theme.radius
                    color: closeMouse.containsMouse ? Theme.hoverStrong : "transparent"
                    border.width: closeMouse.containsMouse ? 1 : 0
                    border.color: Theme.borderAccent

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(14)
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePanel()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                RowLayout {
                    id: leftTabRow
                    anchors.fill: parent
                    spacing: 4
                    Repeater {
                        id: leftTabRep
                        model: ["чат", "заметки"]
                        delegate: Rectangle {
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            height: 36
                            radius: Theme.radius
                            color: tabIndex === index
                                ? Theme.active
                                : (tabMouse.containsMouse ? Theme.hover : "transparent")
                            border.color: tabIndex === index ? Theme.borderAccent : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: tabIndex === index
                                    ? Theme.accent
                                    : (tabMouse.containsMouse ? Theme.text : Theme.textDim)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tabIndex = index
                            }
                        }
                    }
                }

                // плавный индикатор активной вкладки
                Rectangle {
                    readonly property var active: leftTabRep.count > 0 ? leftTabRep.itemAt(root.tabIndex) : null
                    visible: active !== null
                    x: active ? active.x : 0
                    y: leftTabRow.height - 2
                    width: active ? active.width : 0
                    height: 2
                    radius: 1
                    color: Theme.accent
                    Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabIndex

                Rectangle {
                    color: Theme.bgCard
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "OPENCODE"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(14)
                                font.bold: true
                                font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: chat.busy ? "думает…" : "агент"
                                color: chat.busy ? Theme.accent : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                            }
                        }

                        // история чата (ListView + reuseItems: длинный стрим
                        // не пересоздаёт все делегаты на каждый чанк)
                        ListView {
                            id: chatList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            model: chat.messages
                            reuseItems: true
                            cacheBuffer: 400
                            boundsBehavior: Flickable.StopAtBounds
                            onCountChanged: positionViewAtEnd()

                            delegate: Rectangle {
                                required property var modelData
                                width: chatList.width
                                height: msgText.implicitHeight + 16
                                radius: Theme.radius
                                color: modelData.role === "user"
                                    ? Theme.active
                                    : Theme.fill
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
                            height: 40
                            radius: Theme.radius
                            color: Theme.bg
                            border.width: 1
                            border.color: chatInput.activeFocus ? Theme.borderAccent : Theme.border

                            TextInput {
                                id: chatInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                                clip: true
                                selectByMouse: true
                                onAccepted: chat.send(text)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "спроси что-нибудь…"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    visible: chatInput.text === "" && !chatInput.activeFocus
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: Theme.radius
                                color: sendMouse.containsMouse
                                    ? Theme.active
                                    : Theme.hoverStrong
                                border.color: Theme.borderAccent
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: chat.busy ? "СТОП" : "ОТПРАВИТЬ"
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
                                    onClicked: chat.busy ? chat.stop() : chat.send(chatInput.text)
                                }
                            }

                            // новая сессия (сбросить контекст)
                            Rectangle {
                                Layout.preferredWidth: 40
                                height: 36
                                radius: Theme.radius
                                color: newMouse.containsMouse ? Theme.alpha(Theme.danger, 0.12) : "transparent"
                                border.width: 1
                                border.color: newMouse.containsMouse ? Theme.danger : Theme.border
                                Text {
                                    anchors.centerIn: parent
                                    text: "＋"
                                    color: newMouse.containsMouse ? Theme.danger : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(14)
                                }
                                MouseArea {
                                    id: newMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: chat.newSession()
                                }
                            }

                            // открыть полноценный opencode в терминале
                            Rectangle {
                                Layout.preferredWidth: 40
                                height: 36
                                radius: Theme.radius
                                color: tuiMouse.containsMouse ? Theme.active : "transparent"
                                border.width: 1
                                border.color: tuiMouse.containsMouse ? Theme.accent : Theme.border
                                Text {
                                    anchors.centerIn: parent
                                    text: "▣"
                                    color: tuiMouse.containsMouse ? Theme.accent : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(14)
                                }
                                MouseArea {
                                    id: tuiMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: chat.openTui()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: chat.status
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    color: Theme.bgCard
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "заметки"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "сохранить"
                                color: saveMouse.containsMouse ? Theme.accent : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                                MouseArea {
                                    id: saveMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notesFile.setText(notesArea.text)
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radius
                            TextArea {
                                id: notesArea
                                anchors.fill: parent
                                anchors.margins: 8
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                                wrapMode: TextArea.WordWrap
                                clip: true
                                selectByMouse: true
                                // L23: фокус не захватываем открытием по наведению —
                                // только явным кликом (activeFocusOnPress по умолчанию)
                                background: Rectangle { color: "transparent" }
                                onTextChanged: {
                                    root.notesDirty = true
                                    notesSaveTimer.restart()
                                }
                            }

                            Text {
                                anchors.fill: parent
                                anchors.margins: 8
                                visible: notesArea.text.length === 0
                                text: "пиши здесь — сохраняется само"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            Text {
                text: sysStats.text
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(12)
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 600
        onTriggered: {
            if (!root.pinned && !stripHover.hovered && !contentHover.hovered) root.closePanel()
        }
    }

    Timer {
        id: notesSaveTimer
        interval: 800
        onTriggered: notesFile.setText(notesArea.text)
    }

    Process { id: termProc; running: false }

    // ═══════════════ OpenCode-чат (агент в сайдбаре) ═══════════════
    // Вызов: opencode run --format json "<сообщение>" — стримит JSON-события,
    // из них берём текстовые части ответа. Контекст держим в сессии
    // (--continue), пока пользователь не сбросит (＋).
    QtObject {
        id: chat
        property var messages: []
        property bool busy: false
        property string status: "готов"
        property string sessionId: ""
        // C4/H10: сообщение, ждущее завершения текущего запуска — не теряем
        property string queued: ""

        // Витрина чата ограничена: и по числу сообщений, и по суммарной
        // длине — длинный стрим не растит память бесконечно. Контекст
        // агента живёт в сессии OpenCode (--session), а не здесь.
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
            if (chatInput) chatInput.text = ""
            dispatch(text)
        }

        // H10: без shell — argv-массив, поэтому кавычки/апострофы в тексте
        // не ломают команду. C4: если процесс занят — ставим в очередь.
        function dispatch(text) {
            if (text === "") return
            if (chatProc.running) { queued = text; return }
            var args = ["opencode", "run", "--format", "json"]
            if (sessionId !== "") { args.push("--session", sessionId) }
            args.push("--", text)
            chatProc.command = args
            chatProc.running = true
            chatWatchdog.restart()
        }

        function appendAssistant(chunk) {
            if (messages.length === 0) return
            var m = messages.slice()
            m[m.length - 1] = { role: "assistant", text: m[m.length - 1].text + chunk }
            messages = capHistory(m)
        }

        function newSession() {
            // H9: гасим текущий запуск, иначе он снова запишет ID удалённой сессии
            chatProc.running = false
            chatWatchdog.stop()
            queued = ""
            busy = false
            status = "новая сессия"
            if (sessionId !== "") {
                sessionsProc.command = ["opencode", "session", "delete", sessionId]
                sessionsProc.running = true
            }
            sessionId = ""
            messages = []
        }

        function openTui() {
            termProc.command = ["bash", "-c",
                "hyprctl dispatch 'hl.dsp.exec_cmd(\"kitty -e opencode\")'"]
            termProc.running = true
        }

        function stop() {
            // running=false теперь завершает сам opencode (без bash-обёртки)
            chatProc.running = false
            chatWatchdog.stop()
            queued = ""
            busy = false
            status = "остановлено"
        }
    }

    Timer {
        id: chatWatchdog
        interval: 600000        // 10 мин: дольше агент уже не отвечает — не висим вечно
        repeat: false
        onTriggered: chat.stop()
    }

    Process {
        id: chatProc
        running: false
        onExited: (exitCode) => {
            chatWatchdog.stop()
            chat.busy = false
            if (exitCode === 0) {
                chat.status = "готов"
            } else {
                var e = (chatErr.text || "").trim()
                chat.status = e !== "" ? e.split("\n").pop() : ("ошибка " + exitCode)
            }
            if (chat.queued !== "") {
                var p = chat.queued
                chat.queued = ""
                chat.busy = true
                chat.status = "opencode работает…"
                chat.dispatch(p)
            }
        }
        stderr: StdioCollector { id: chatErr }
        stdout: SplitParser {
            onRead: function(line) {
                if (!line) return
                try {
                    var ev = JSON.parse(line)
                    if (ev.type === "text" && ev.part && ev.part.text !== undefined)
                        chat.appendAssistant(ev.part.text)
                    if (ev.sessionID) chat.sessionId = ev.sessionID
                } catch (e) { /* не-JSON строки игнорируем */ }
            }
        }
    }

    Process { id: sessionsProc; running: false }

    // заметки: пишем файлом напрямую (без bash/heredoc) и атомарно
    FileView {
        id: notesFile
        path: Quickshell.env("HOME") + "/.cache/lunar_notes.txt"
        blockLoading: true
        atomicWrites: true
        // файла может ещё не быть — это не ошибка
        printErrors: false
        onLoaded: {
            if (root.notesDirty) return
            notesArea.text = text()
            root.notesDirty = false
            notesSaveTimer.stop()
        }
    }

    Process {
        id: sysStats
        // interval>0 обязателен: в новом процессе cpu_percent() иначе всегда 0
        command: ["python3", "-c", "import psutil; print(f'CPU {int(psutil.cpu_percent(interval=0.3))}%  RAM {int(psutil.virtual_memory().percent)}%')"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") sysStats.text = text.trim()
        }
        stderr: StdioCollector {}
        property string text: "CPU --%  RAM --%"
    }
    Timer {
        id: sysStatsTimer
        interval: 3000
        running: !root.collapsed
        repeat: true
        onTriggered: sysStats.running = true
    }

    Component.onCompleted: notesFile.reload()
}
