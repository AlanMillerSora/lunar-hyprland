import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarClipboard — модальное окно истории буфера (cliphist).
//  Открывается по SUPER + V:  qs ipc call clipboard toggle
//  Поиск, ↑↓ навигация, ENTER — копировать, DEL — удалить, ESC — закрыть.
//  Обычное окно (FloatingWindow): тянется за края, скругление/блюр — Hyprland.
// ════════════════════════════════════════════════════════════════
FloatingWindow {
    id: root

    title: "Lunar Clipboard"
    // фон даёт окно, скругление/блюр — правило Hyprland по заголовку
    color: Theme.bgPanel
    visible: root.showing
    implicitWidth: 720
    implicitHeight: 600
    minimumSize: Qt.size(360, 280)

    property bool showing: false
    property var items: []          // все записи: [{ id, preview }]
    property string query: ""
    property int selectedIndex: 0
    property string toolError: ""   // cliphist/wl-copy недоступны или команда упала

    readonly property var filtered: {
        var q = root.query.toLowerCase()
        if (!q)
            return root.items
        var out = []
        for (var i = 0; i < root.items.length; i++) {
            if (root.items[i].preview.toLowerCase().indexOf(q) >= 0)
                out.push(root.items[i])
        }
        return out
    }

    function openPanel() {
        root.selectedIndex = 0
        root.toolError = ""
        searchInput.text = ""
        root.query = ""
        list.positionViewAtBeginning()   // прокрутка не «залипает» с прошлого раза (L47)
        root.refresh()
        root.showing = true
        focusTimer.restart()
    }

    // фокус в поиск после появления окна: SUPER+V сразу пишет в строку
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: searchInput.forceActiveFocus()
    }

    function closePanel() { root.showing = false }
    function toggle() { root.showing ? root.closePanel() : root.openPanel() }

    function refresh() {
        listProc.running = false
        listProc.running = true
    }

    function move(delta) {
        if (root.filtered.length === 0)
            return
        var i = root.selectedIndex + delta
        if (i < 0)
            i = root.filtered.length - 1
        if (i >= root.filtered.length)
            i = 0
        root.selectedIndex = i
        list.positionViewAtIndex(i, ListView.Contain)
    }

    function activate() {
        var l = root.filtered
        if (root.selectedIndex < 0 || root.selectedIndex >= l.length)
            return
        root.copyEntry(l[root.selectedIndex].id)
    }

    function copyEntry(id) {
        // id из cliphist — только цифры; проверяем и заодно не даём
        // подставить что-то в shell (L45/C5-стиль)
        if (!/^\d+$/.test("" + id))
            return
        root.toolError = ""
        copyProc.command = ["bash", "-c",
            "command -v cliphist >/dev/null 2>&1 || exit 127; "
            + "command -v wl-copy >/dev/null 2>&1 || exit 128; "
            + "cliphist decode " + id + " | wl-copy"]
        copyProc.running = false
        copyProc.running = true
    }

    function removeSelected() {
        var l = root.filtered
        if (root.selectedIndex < 0 || root.selectedIndex >= l.length)
            return
        var id = "" + l[root.selectedIndex].id
        if (!/^\d+$/.test(id))
            return
        root.toolError = ""
        delProc.command = ["bash", "-c", "cliphist list | grep -P '^" + id + "\\t' | cliphist delete"]
        delProc.running = false
        delProc.running = true
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    // содержимое — прямо в окне: фон/рамку/радиус даёт FloatingWindow и
    // правило Hyprland; Esc и клавиатуру вешаю на предмет во весь экран
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closePanel()

        HudCorners {
            color: Theme.accent
            size: 18
            thickness: 1
            margin: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: Theme.space3

            // ── шапка ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3

                Text {
                    text: "CLIPBOARD"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(Theme.fontPanelTitle)
                    font.bold: true
                    font.letterSpacing: 4
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.filtered.length + " / " + root.items.length
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            // ── поиск ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                color: Theme.bgCard
                radius: Theme.radiusM
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.borderAccent : Theme.border

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontTiny
                    color: Theme.textDim
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: Theme.space3
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    selectionColor: Theme.accent
                    selectedTextColor: "#000000"
                    clip: true
                    focus: root.showing

                    onTextChanged: {
                        root.query = text
                        root.selectedIndex = 0
                    }

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Escape) {
                            root.closePanel()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers === Qt.NoModifier)) {
                            root.move(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers === Qt.NoModifier)) {
                            root.move(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Delete) {
                            root.removeSelected()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    anchors.left: searchInput.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: "поиск по буферу обмена…"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }
            }

            // ── список ──
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filtered

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: list.width
                        height: Theme.rowHCompact
                        radius: Theme.radiusM
                        color: root.selectedIndex === index
                            ? Theme.active
                            : (rowMouse.containsMouse ? Theme.hover : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space3
                            anchors.rightMargin: Theme.space3
                            spacing: Theme.space3

                            Text {
                                text: String(index + 1).padStart(2, "0")
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(10)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.preview
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTiny
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.copyEntry(modelData.id)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filtered.length === 0
                    text: root.toolError !== ""
                        ? root.toolError
                        : (root.items.length === 0
                            ? "буфер обмена пуст"
                            : "ничего не найдено")
                    color: root.toolError !== "" ? Theme.danger : Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.toolError !== "" && root.items.length > 0
                text: root.toolError
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(10)
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            Text {
                Layout.fillWidth: true
                text: "↑↓ выбрать   ENTER копировать   DEL удалить   ESC закрыть"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMicro
            }
        }
    }

    // ───────────────────────────── процессы ────────────────────────────
    Process {
        id: listProc
        running: false
        // без head -200: список не обрезается, счётчик «N / M» честный (M61).
        // Проверяем наличие cliphist и читаем stderr (M62).
        command: ["bash", "-c",
            "command -v cliphist >/dev/null 2>&1 || { echo cliphist-not-installed >&2; exit 127; }; "
            + "cliphist list"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                var lines = ("" + listOut.text).split("\n")
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (line === "")
                        continue
                    var tab = line.indexOf("\t")
                    var id = tab > 0 ? line.substring(0, tab) : ""
                    if (tab > 0 && /^\d+$/.test(id)) {
                        var preview = line.substring(tab + 1)
                        out.push({ id: id, preview: preview.length ? preview : "(пусто)" })
                    } else if (out.length > 0) {
                        // продолжение многострочного превью (L46)
                        out[out.length - 1].preview += "\n" + line
                    }
                }
                root.items = out
                if (root.selectedIndex >= out.length)
                    root.selectedIndex = 0
                list.positionViewAtBeginning()   // новый список — с начала (L47)
                if (out.length > 0)
                    root.toolError = ""
            }
        }
        stderr: StdioCollector { id: listErr }
        onExited: (code) => {
            if (code === 127) {
                root.toolError = "cliphist не установлен"
            } else if (code !== 0) {
                root.toolError = (listErr.text || "").trim()
                    || ("cliphist недоступен (код " + code + ")")
            }
        }
    }

    Process {
        id: copyProc
        running: false
        stderr: StdioCollector { id: copyErr }
        onExited: (code) => {
            if (code === 0) {
                root.closePanel()
            } else if (code === 127) {
                root.toolError = "cliphist не установлен"
            } else if (code === 128) {
                root.toolError = "wl-copy не установлен"
            } else {
                root.toolError = (copyErr.text || "").trim()
                    || ("не удалось скопировать (код " + code + ")")
            }
        }
    }

    Process {
        id: delProc
        running: false
        stderr: StdioCollector { id: delErr }
        onExited: (code) => {
            if (code !== 0)
                root.toolError = (delErr.text || "").trim()
                    || ("не удалось удалить запись (код " + code + ")")
            root.refresh()
        }
    }
}
