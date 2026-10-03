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
    // заметки: true, если я уже правил текст до/во время загрузки файла —
    // тогда загрузка не должна затирать правку (TOCTOU при старте)
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
            if (tabIndex === 0) api.refresh()
            if (!pinned && !stripHover.hovered && !contentHover.hovered) hideTimer.restart()
        }
    }

    onTabIndexChanged: if (tabIndex === 0) api.refresh()

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
            anchors.margins: Theme.space5
            spacing: Theme.space4

            RowLayout {
                spacing: Theme.space2
                Text {
                    text: "LUNAR"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(Theme.fontPanelTitle)
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
                        font.pixelSize: Theme.fontSize(15)
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
                Layout.preferredHeight: Theme.rowHCompact

                RowLayout {
                    id: leftTabRow
                    anchors.fill: parent
                    spacing: Theme.space1
                    Repeater {
                        id: leftTabRep
                        model: ["api-limit", "заметки"]
                        delegate: Rectangle {
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            height: Theme.rowHCompact
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
                                font.pixelSize: Theme.fontSize(14)
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

                // ═══ api-limit: расход лимитов OpenCode Go ═══
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bgCard
                    radius: Theme.radius
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        spacing: Theme.space3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "API-LIMIT"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(15)
                                font.bold: true
                                font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: api.ok ? (api.lead !== "" ? api.lead : "нет данных") : api.status
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                                elide: Text.ElideRight
                                Layout.maximumWidth: 320
                            }
                        }

                        // три HUD-полосы: 5 часов / неделя / месяц
                        Repeater {
                            model: [
                                { label: "5 ЧАСОВ", value: api.h5, limit: api.h5lim },
                                { label: "НЕДЕЛЯ", value: api.wk, limit: api.wklim },
                                { label: "МЕСЯЦ", value: api.mo, limit: api.molim }
                            ]
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 5

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        text: modelData.label
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                        font.letterSpacing: 1
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: api.money(modelData.value) + " / "
                                            + (modelData.limit > 0 ? api.money(modelData.limit) : "∞")
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                    }
                                    Text {
                                        text: modelData.limit > 0
                                            ? api.pctLabel(modelData.value, modelData.limit)
                                            : "∞"
                                        color: api.pct(modelData.value, modelData.limit) > 80
                                            ? Theme.danger
                                            : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 8
                                    radius: 3
                                    color: Theme.trackBg
                                    border.color: Theme.border
                                    border.width: 1
                                    Rectangle {
                                        readonly property real ratio: modelData.limit > 0
                                            ? Math.max(0, Math.min(1, modelData.value / modelData.limit))
                                            : 0
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 1
                                        width: (parent.width - 2) * ratio
                                        radius: 2
                                        color: (ratio * 100) > 80 ? Theme.danger : Theme.accent
                                        Behavior on width {
                                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
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
                            text: "МОДЕЛИ · локально"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(13)
                            font.bold: true
                            font.letterSpacing: 2
                        }

                        // разбивка по моделям (локальная история): доля в расходе
                        Repeater {
                            model: api.models
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        text: modelData.id
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: api.money(modelData.usd)
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 4
                                        radius: 2
                                        color: Theme.trackBg
                                        Rectangle {
                                            readonly property real ratio: api.modelsTotal > 0
                                                ? Math.max(0, Math.min(1, modelData.usd / api.modelsTotal))
                                                : 0
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: parent.height
                                            width: parent.width * ratio
                                            radius: 2
                                            color: Theme.accent
                                            Behavior on width {
                                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                            }
                                        }
                                    }
                                    Text {
                                        text: "in " + api.fmtTokens(modelData.tin)
                                            + "  out " + api.fmtTokens(modelData.tout)
                                            + "  cache " + api.fmtTokens(modelData.cache)
                                        color: Theme.textFaint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: api.status
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // ═══ заметки ═══
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bgCard
                    radius: Theme.radius
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        spacing: Theme.space2
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "заметки"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(14)
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "сохранить"
                                color: saveMouse.containsMouse ? Theme.accent : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
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
                                anchors.margins: Theme.space2
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(14)
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
                                anchors.margins: Theme.space2
                                visible: notesArea.text.length === 0
                                text: "пиши здесь — сохраняется само"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(14)
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
                font.pixelSize: Theme.fontSize(13)
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

    // ═══════════════ api-limit: расход лимитов OpenCode Go ═══════════════
    // Проценты окон (5ч/неделя/месяц) беру из официального usage-API Go,
    // доллары оцениваю от лимита ведущей модели; разбивку по моделям беру
    // из локальной БД. Данные собирает eclipse-api-limit.sh, ключ не хранит.
    QtObject {
        id: api
        property bool ok: false
        property string source: "local"
        property string lead: ""
        property real h5: 0
        property real wk: 0
        property real mo: 0
        property real molim: 60
        property var models: []
        property string status: "загрузка…"

        // лимиты окон выводятся из месячного лимита ведущей модели
        readonly property real h5lim: molim * 0.2
        readonly property real wklim: molim * 0.5

        // сумма локального расхода — для долей в разбивке по моделям
        readonly property real modelsTotal: {
            var t = 0
            for (var i = 0; i < models.length; i++)
                t += models[i].usd
            return t
        }

        function money(v) {
            return "$" + Number(v || 0).toFixed(2)
        }

        function pct(v, lim) {
            if (!(lim > 0)) return 0
            return Math.round((v / lim) * 100)
        }

        function pctLabel(v, lim) {
            return Math.min(999, pct(v, lim)) + "%"
        }

        function fmtTokens(n) {
            n = Number(n || 0)
            if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
            if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
            if (n >= 1e3) return Math.round(n / 1e3) + "K"
            return "" + Math.round(n)
        }

        function refresh() {
            if (apiProc.running) return
            models = []
            ok = false
            status = "загрузка…"
            apiProc.running = true
        }

        // строки сборщика: key=value и "M id usd lim tin tout cache"
        function parseLine(line) {
            if (!line) return
            if (line.charAt(0) === "M") {
                var p = line.split(" ")
                if (p.length >= 7) {
                    var arr = models.slice()
                    arr.push({
                        id: p[1],
                        usd: Number(p[2]),
                        lim: Number(p[3]),
                        tin: Number(p[4]),
                        tout: Number(p[5]),
                        cache: Number(p[6])
                    })
                    models = arr
                }
                return
            }
            var i = line.indexOf("=")
            if (i < 0) return
            var k = line.slice(0, i)
            var v = line.slice(i + 1)
            if (k === "lead") lead = v
            else if (k === "source") source = v
            else if (k === "h5") h5 = Number(v)
            else if (k === "wk") wk = Number(v)
            else if (k === "mo") mo = Number(v)
            else if (k === "molim") molim = Number(v)
            else if (k === "ok") ok = (v === "1")
        }
    }

    Process {
        id: apiProc
        running: false
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/eclipse-api-limit.sh"]
        onExited: (exitCode) => {
            if (exitCode !== 0) { api.status = "ошибка " + exitCode; return }
            if (api.lead === "") { api.status = "нет данных"; return }
            api.status = (api.source === "api" ? "официальные" : "локальные") + " · обновлено"
        }
        stderr: StdioCollector {}
        stdout: SplitParser {
            onRead: function(line) { api.parseLine(line) }
        }
    }

    Timer {
        id: apiTimer
        interval: 60000
        repeat: true
        running: !root.collapsed && root.tabIndex === 0
        onTriggered: api.refresh()
    }

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

    Component.onCompleted: {
        notesFile.reload()
        api.refresh()
    }
}
