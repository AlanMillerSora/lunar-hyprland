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
    property string aiStatus: "проверяю…"

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
                        anchors.margins: 14
                        spacing: 10
                        Text {
                            text: "Lunar AI"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Локальный ассистент на Ollama. Если не установлен — открой терминал и поставь."
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(13)
                            wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: root.aiStatus
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "проверить"
                                color: aiMouse.containsMouse ? Theme.accent : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                                MouseArea {
                                    id: aiMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ollamaProc.running = true
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: Theme.radius
                            color: termMouse.containsMouse
                                ? Theme.alpha(Theme.accent, 0.16)
                                : Theme.alpha(Theme.accent, 0.08)
                            border.color: Theme.borderAccent
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "открыть терминал"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                            MouseArea {
                                id: termMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    termProc.command = ["hyprctl", "dispatch", "exec", "kitty"]
                                    termProc.running = true
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

    Process {
        id: ollamaProc
        running: false
        command: ["bash", "-c",
            "if command -v ollama >/dev/null 2>&1; then " +
            "n=$(ollama list 2>/dev/null | tail -n +2 | grep -c .); " +
            "echo \"Ollama: моделей — ${n:-0}\"; else echo 'Ollama не установлен'; fi"]
        stdout: StdioCollector { onStreamFinished: root.aiStatus = text.trim() }
    }

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
        ollamaProc.running = true
    }

    Process {
        id: notesLoadProc
        running: false
        stdout: StdioCollector { onStreamFinished: notesArea.text = text }
    }
}
