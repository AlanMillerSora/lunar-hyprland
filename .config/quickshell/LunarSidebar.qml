import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: root

    anchors { top: true; left: true; bottom: true }
    implicitWidth: 380
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool collapsed: true
    property int tabIndex: 0

    function show() { collapsed = false }
    function hide() { collapsed = true }
    function toggle() { collapsed = !collapsed }

    onCollapsedChanged: {
        if (!collapsed && !stripHover.hovered && !contentHover.hovered) hideTimer.restart()
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void { root.toggle() }
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
                if (hovered) root.show()
                else if (!contentHover.hovered) hideTimer.restart()
            }
        }
    }

    Rectangle {
        id: contentBox
        anchors.top: parent.top
        anchors.topMargin: 46
        anchors.bottom: parent.bottom
        width: 360
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
                if (hovered) root.show()
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
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 3
                }
                Item { Layout.fillWidth: true }
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
                        height: 28
                        radius: Theme.radius
                        color: tabIndex === index ? Theme.alpha(Theme.accent, 0.12) : "transparent"
                        border.color: tabIndex === index ? Theme.borderAccent : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: tabIndex === index ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
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
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "ИИ-ассистент пока не подключён. Откройте терминал для работы с Ollama или другим провайдером."
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
                        Item { Layout.fillHeight: true }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: Theme.radius
                            color: Theme.alpha(Theme.accent, 0.08)
                            border.color: Theme.borderAccent
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "открыть терминал"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                            MouseArea {
                                anchors.fill: parent
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
                            Text {
                                text: "буфер обмена"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                            Item { Layout.fillWidth: true }
                            MouseArea {
                                width: 30
                                height: 18
                                onClicked: clipModel.load()
                                Text {
                                    anchors.centerIn: parent
                                    text: "↻"
                                    color: Theme.textDim
                                    font.family: Theme.iconFont
                                    font.pixelSize: 10
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
                                height: 32
                                radius: Theme.radius
                                color: mouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: modelData.preview
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        clipSelectProc.command = ["bash", "-c", "cliphist decode " + modelData.id + " | wl-copy"]
                                        clipSelectProc.running = true
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
                        Text {
                            text: "заметки"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
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
                                font.pixelSize: 10
                                wrapMode: TextArea.WordWrap
                                background: Rectangle { color: "transparent" }
                                onTextChanged: notesSaveTimer.restart()
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
                font.pixelSize: 9
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 600
        onTriggered: {
            if (!stripHover.hovered && !contentHover.hovered) root.hide()
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
    Process { id: clipSelectProc; running: false }
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
