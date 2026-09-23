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
    // клавиатуру берём только когда панель выдвинута (нужна для заметок)
    WlrLayershell.keyboardFocus: root.collapsed ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

    property bool collapsed: true
    property int tabIndex: 0

    function openPanel() { collapsed = false }
    function closePanel() { collapsed = true }
    function toggle() { collapsed = !collapsed }

    onCollapsedChanged: {
        if (!collapsed && !stripHover.hovered && !contentHover.hovered) hideTimer.restart()
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
        function tab(idx: int): void { root.tabIndex = Math.max(0, Math.min(2, idx)) }
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
                    color: closeMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent"
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

            RowLayout {
                spacing: 4
                Repeater {
                    model: ["чат", "буфер", "заметки"]
                    delegate: Rectangle {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        height: 36
                        radius: Theme.radius
                        color: tabIndex === index
                            ? Theme.alpha(Theme.accent, 0.12)
                            : (tabMouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent")
                        border.color: tabIndex === index ? Theme.borderAccent : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: tabIndex === index
                                ? Theme.accent
                                : (tabMouse.containsMouse ? Theme.text : Theme.textDim)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(13)
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
                        anchors.margins: 10
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

                        // история чата
                        Flickable {
                            id: chatFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: chatCol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                            Column {
                                id: chatCol
                                width: chatFlick.width
                                spacing: 8

                                Repeater {
                                    model: chat.messages

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: chatCol.width
                                        height: msgText.implicitHeight + 16
                                        radius: Theme.radius
                                        color: modelData.role === "user"
                                            ? Theme.alpha(Theme.accent, 0.10)
                                            : Theme.alpha(Theme.text, 0.03)
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
                                    ? Theme.alpha(Theme.accent, 0.16)
                                    : Theme.alpha(Theme.accent, 0.08)
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
                                color: tuiMouse.containsMouse ? Theme.alpha(Theme.accent, 0.12) : "transparent"
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
                        anchors.margins: 10
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "буфер обмена"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                            Item { Layout.fillWidth: true }

                            // очистить всю историю
                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 26
                                radius: Theme.radius
                                color: wipeMouse.containsMouse ? Theme.alpha(Theme.danger, 0.12) : "transparent"
                                border.width: wipeMouse.containsMouse ? 1 : 0
                                border.color: Theme.danger

                                Text {
                                    anchors.centerIn: parent
                                    text: "очистить"
                                    color: wipeMouse.containsMouse ? Theme.danger : Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                }
                                MouseArea {
                                    id: wipeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wipeProc.command = ["bash", "-c", "cliphist wipe"]
                                        wipeProc.running = true
                                    }
                                }
                            }

                            // обновить список
                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 26
                                radius: Theme.radius
                                color: refreshMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                                border.width: refreshMouse.containsMouse ? 1 : 0
                                border.color: Theme.borderAccent

                                Text {
                                    anchors.centerIn: parent
                                    text: "↻"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                }
                                MouseArea {
                                    id: refreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clipModel.load()
                                }
                            }
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: clipModel.items
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 42
                                radius: Theme.radius
                                color: mouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: modelData.preview
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function (m) {
                                        if (m.button === Qt.RightButton) {
                                            clipDeleteProc.command = ["bash", "-c",
                                                "cliphist list | grep -P '^" + modelData.id + "\\t' | cliphist delete"]
                                            clipDeleteProc.running = true
                                        } else {
                                            clipSelectProc.command = ["bash", "-c",
                                                "cliphist decode " + modelData.id + " | wl-copy"]
                                            clipSelectProc.running = true
                                        }
                                    }
                                }
                            }
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
                        anchors.margins: 10
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
                                    onClicked: notesSaveTimer.triggered()
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
                                focus: root.tabIndex === 2 && !root.collapsed
                                background: Rectangle { color: "transparent" }
                                onTextChanged: notesSaveTimer.restart()
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
            if (!stripHover.hovered && !contentHover.hovered) root.closePanel()
        }
    }

    Timer {
        id: notesSaveTimer
        interval: 800
        onTriggered: {
            notesSaveProc.command = ["bash", "-c", "cat > ~/.cache/lunar_notes.txt <<'EOF'\n" + notesArea.text.replace(/\\/g, "\\\\").replace(/'/g, "'\\''") + "\nEOF"]
            notesSaveProc.running = true
        }
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

        function send(text) {
            if (text.trim() === "" || busy) return
            messages = messages.concat([{ role: "user", text: text }])
            messages = messages.concat([{ role: "assistant", text: "" }])
            busy = true
            status = "opencode работает…"
            if (chatInput) chatInput.text = ""

            var args = "opencode run --format json "
            if (sessionId !== "") args += "--session " + sessionId + " "
            chatProc.command = ["bash", "-c",
                args + "-- " + JSON.stringify(text).replace(/^"|"$/g, "'\\''")]
            chatProc.running = true
        }

        function appendAssistant(chunk) {
            var m = messages.slice()
            if (m.length === 0) return
            m[m.length - 1] = { role: "assistant", text: m[m.length - 1].text + chunk }
            messages = m
        }

        function newSession() {
            if (sessionId !== "") {
                sessionsProc.command = ["opencode", "session", "delete", sessionId]
                sessionsProc.running = true
            }
            sessionId = ""
            messages = []
            status = "новая сессия"
        }

        function openTui() {
            termProc.command = ["bash", "-c",
                "hyprctl dispatch 'hl.dsp.exec_cmd(\"kitty -e opencode\")'"]
            termProc.running = true
        }

        function stop() {
            chatProc.running = false
            busy = false
            status = "остановлено"
        }
    }

    Process {
        id: chatProc
        running: false
        onExited: {
            chat.busy = false
            chat.status = "готов"
        }
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
    Process {
        id: clipSelectProc
        running: false
        onExited: clipModel.load()
    }
    Process {
        id: clipDeleteProc
        running: false
        onExited: clipModel.load()
    }
    Process {
        id: wipeProc
        running: false
        onExited: clipModel.load()
    }
    Process { id: notesSaveProc; running: false }

    QtObject {
        id: clipModel
        property var items: []
        Component.onCompleted: load()
        function load() {
            clipProc.command = ["bash", "-c", "cliphist list | head -40"]
            clipProc.running = true
        }
    }

    Process {
        id: clipProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue
                    var idx = line.indexOf("\t")
                    if (idx < 0) idx = line.indexOf("  ")
                    var id = idx >= 0 ? line.substring(0, idx).trim() : line
                    var preview = idx >= 0 ? line.substring(idx + 1).trim() : ""
                    if (preview.length > 80) preview = preview.substring(0, 80) + "…"
                    out.push({ id: id, preview: preview })
                }
                clipModel.items = out
            }
        }
    }

    Process {
        id: sysStats
        command: ["python3", "-c", "import psutil; print(f'CPU {int(psutil.cpu_percent())}%  RAM {int(psutil.virtual_memory().percent)}%')"]
        running: true
        stdout: StdioCollector { onStreamFinished: sysStats.text = text.trim() }
        property string text: "CPU --%  RAM --%"
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: sysStats.running = true
    }

    Component.onCompleted: {
        notesLoadProc.command = ["bash", "-c", "cat ~/.cache/lunar_notes.txt 2>/dev/null || true"]
        notesLoadProc.running = true
    }

    Process {
        id: notesLoadProc
        running: false
        stdout: StdioCollector { onStreamFinished: notesArea.text = text }
    }
}
