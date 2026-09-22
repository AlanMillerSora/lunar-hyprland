import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarClipboard — модальный оверлей истории буфера (cliphist).
//  Открывается по SUPER + V:  qs ipc call clipboard toggle
//  Поиск, ↑↓ навигация, ENTER — копировать, DEL — удалить, ESC — закрыть.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    // Пока окно скрыто — клавиатуру не трогаем; когда открыто — забираем,
    // чтобы сразу работал ввод в поиске.
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Без маски поверхность перехватывала бы клики на весь экран даже закрытой.
    mask: Region {
        item: root.showing ? backdrop : null
    }

    property bool showing: false
    property var items: []          // все записи: [{ id, preview }]
    property string query: ""
    property int selectedIndex: 0

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
        searchInput.text = ""
        root.query = ""
        root.refresh()
        root.showing = true
        searchInput.forceActiveFocus()
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
        copyProc.command = ["bash", "-c", "cliphist decode " + id + " | wl-copy"]
        copyProc.running = true
        root.closePanel()
    }

    function removeSelected() {
        var l = root.filtered
        if (root.selectedIndex < 0 || root.selectedIndex >= l.length)
            return
        var id = l[root.selectedIndex].id
        delProc.command = ["bash", "-c", "cliphist list | grep -P '^" + id + "\\t' | cliphist delete"]
        delProc.running = true
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    // ─────────────────── затемнение фона + клик мимо = закрыть ─────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    // ───────────────────────────── карточка ────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(720, root.width - 80)
        height: Math.min(600, root.height - 120)
        color: Theme.bgPanel
        radius: Theme.radius
        border.color: Theme.accent
        border.width: 1

        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }

        // клики по карточке не проваливаются на backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        HudCorners {
            color: Theme.accent
            size: 18
            thickness: 1
            margin: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12

            // ── шапка ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "CLIPBOARD"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    font.letterSpacing: 4
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.filtered.length + " / " + root.items.length
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
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
                radius: Theme.radius
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.borderAccent : Theme.border

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                    color: Theme.textDim
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
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
                    font.pixelSize: 12
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
                        height: 40
                        radius: Theme.radius
                        color: root.selectedIndex === index
                            ? Theme.alpha(Theme.accent, 0.12)
                            : (rowMouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent")
                        border.width: root.selectedIndex === index ? 1 : 0
                        border.color: Theme.borderAccent

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: String(index + 1).padStart(2, "0")
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.preview
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
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
                    text: root.items.length === 0
                        ? "буфер обмена пуст"
                        : "ничего не найдено"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
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
                font.pixelSize: 9
            }
        }
    }

    // ───────────────────────────── процессы ────────────────────────────
    Process {
        id: listProc
        running: false
        command: ["bash", "-c", "cliphist list 2>/dev/null | head -200"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (!line.length)
                        continue
                    var tab = line.indexOf("\t")
                    if (tab < 0)
                        continue
                    var id = line.substring(0, tab).trim()
                    var preview = line.substring(tab + 1)
                    if (!preview.length)
                        preview = "(пусто)"
                    out.push({ id: id, preview: preview })
                }
                root.items = out
                if (root.selectedIndex >= out.length)
                    root.selectedIndex = 0
            }
        }
    }

    Process { id: copyProc; running: false }
    Process {
        id: delProc
        running: false
        onExited: root.refresh()
    }
}
