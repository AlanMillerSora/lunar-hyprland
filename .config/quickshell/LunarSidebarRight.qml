import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarSidebarRight — правая панель: уведомления (mako),
//  «сейчас играет» (mpris) и календарь. Выезжает от правого края
//  по наведению. IPC:  qs ipc call rsidebar toggle|open|close
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; right: true; bottom: true }
    implicitWidth: 560
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.collapsed ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

    property bool collapsed: true
    property int tabIndex: 0

    function openPanel() { collapsed = false; notif.load(); recModel.load(); recStatusProc.running = true }
    function closePanel() { collapsed = true }
    function toggle() { collapsed = !collapsed }

    onCollapsedChanged: {
        if (!collapsed && !stripHover.hovered && !contentHover.hovered)
            hideTimer.restart()
    }

    IpcHandler {
        target: "rsidebar"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
        function tab(idx: int): void { root.tabIndex = Math.max(0, Math.min(3, idx)) }
    }

    mask: Region {
        item: collapsed ? hoverStrip : contentBox
    }

    // полоска у правого края — триггер выезда
    Item {
        id: hoverStrip
        anchors.top: parent.top
        anchors.topMargin: 46
        anchors.bottom: parent.bottom
        anchors.right: parent.right
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
        width: 530
        // уезжает за правый край целиком
        x: root.collapsed ? (root.width + 4) : (root.width - width)
        color: Theme.bg
        radius: Theme.radiusM
        border.color: Theme.border
        border.width: collapsed ? 0 : 1

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
            spacing: 14

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

            // ── вкладки ──
            RowLayout {
                spacing: 4
                Repeater {
                    model: ["уведомления", "музыка", "календарь", "запись"]
                    delegate: Rectangle {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        height: 36
                        radius: Theme.radius
                        color: root.tabIndex === index
                            ? Theme.alpha(Theme.accent, 0.12)
                            : (tabMouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent")
                        border.color: root.tabIndex === index ? Theme.borderAccent : "transparent"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: root.tabIndex === index
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
                            onClicked: root.tabIndex = index
                        }
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.tabIndex

                // ═══════════ уведомления ═══════════
                Rectangle {
                    color: Theme.bgCard
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "уведомления"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                            Text {
                                text: notif.items.length
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                            Item { Layout.fillWidth: true }

                            // DND
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 26
                                radius: Theme.radius
                                color: notif.dnd ? Theme.alpha(Theme.danger, 0.15) : "transparent"
                                border.width: notif.dnd ? 1 : 0
                                border.color: Theme.danger
                                Text {
                                    anchors.centerIn: parent
                                    text: notif.dnd ? "\uf1f6" : "\uf0f3"
                                    color: notif.dnd ? Theme.danger : Theme.textDim
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.fontSize(14)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notif.toggleDnd()
                                }
                            }

                            // очистить всё
                            Rectangle {
                                Layout.preferredWidth: 82
                                Layout.preferredHeight: 26
                                radius: Theme.radius
                                color: clearMouse.containsMouse ? Theme.alpha(Theme.danger, 0.12) : "transparent"
                                border.width: clearMouse.containsMouse ? 1 : 0
                                border.color: Theme.danger
                                Text {
                                    anchors.centerIn: parent
                                    text: "очистить"
                                    color: clearMouse.containsMouse ? Theme.danger : Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                }
                                MouseArea {
                                    id: clearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notif.clear()
                                }
                            }
                        }

                        ListView {
                            id: notifList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 6
                            model: notif.items

                            delegate: Rectangle {
                                required property var modelData
                                width: notifList.width
                                height: bodyCol.implicitHeight + 16
                                radius: Theme.radius
                                color: itemMouse.containsMouse
                                    ? Theme.alpha(Theme.accent, 0.06)
                                    : "transparent"
                                border.width: 1
                                border.color: Theme.border

                                Column {
                                    id: bodyCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: modelData.app
                                        color: Theme.textFaint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.summary
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(14)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        visible: modelData.body.length > 0
                                        text: modelData.body
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notif.dismiss(modelData.id)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: notif.items.length === 0
                            text: notif.dnd ? "режим «не беспокоить»" : "уведомлений нет"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // ═══════════ сейчас играет ═══════════
                Rectangle {
                    color: Theme.bgCard
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        Text {
                            text: "сейчас играет"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(13)
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "\uf001"
                            color: root.player ? Theme.accent : Theme.textFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(52)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.player && root.player.trackTitle
                                ? root.player.trackTitle : "ничего не играет"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(18)
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.player && root.player.trackArtist
                            text: root.player ? (root.player.trackArtist || "") : ""
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        // прогресс
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            visible: root.player && root.player.length > 0

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.trackBg
                                Rectangle {
                                    width: parent.width * (root.player && root.player.length > 0
                                        ? Math.min(1, root.player.position / root.player.length) : 0)
                                    height: parent.height
                                    radius: 2
                                    color: Theme.accent
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 22

                            Text {
                                text: "\uf048"
                                color: root.player && root.player.canGoPrevious ? Theme.text : Theme.textFaint
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(23)
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.previous()
                                }
                            }
                            Text {
                                text: (root.player && root.player.isPlaying) ? "\uf04c" : "\uf04b"
                                color: Theme.text
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(29)
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.togglePlaying()
                                }
                            }
                            Text {
                                text: "\uf051"
                                color: root.player && root.player.canGoNext ? Theme.text : Theme.textFaint
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(23)
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.next()
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // ═══════════ календарь (прокручивается) ═══════════
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
                            Layout.fillWidth: true
                            text: root.todayText
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                        }

                        Flickable {
                            id: monthFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: monthsColumn.height
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: monthsColumn
                                width: monthFlick.width
                                spacing: 18

                                Repeater {
                                    model: root.months

                                    delegate: Column {
                                        required property var modelData
                                        width: monthsColumn.width
                                        spacing: 6

                                        Text {
                                            width: parent.width
                                            text: modelData.title
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize(15)
                                            font.bold: true
                                            font.letterSpacing: 1
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 0
                                            Repeater {
                                                model: ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]
                                                Text {
                                                    required property string modelData
                                                    width: 58
                                                    text: modelData
                                                    color: Theme.textFaint
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSize(12)
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                        }

                                        Grid {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            columns: 7
                                            spacing: 0
                                            Repeater {
                                                model: modelData.cells
                                                Rectangle {
                                                    required property var modelData
                                                    width: 58
                                                    height: 34
                                                    radius: Theme.radius
                                                    color: modelData.today
                                                        ? Theme.alpha(Theme.accent, 0.14) : "transparent"
                                                    border.width: modelData.today ? 1 : 0
                                                    border.color: Theme.borderAccent
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.day > 0 ? modelData.day : ""
                                                        color: modelData.day === 0
                                                            ? "transparent"
                                                            : (modelData.today ? Theme.accent : Theme.text)
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Theme.fontSize(13)
                                                        font.bold: modelData.today
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════ запись экрана ═══════════
                Rectangle {
                    color: Theme.bgCard
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "запись экрана"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 30
                                radius: Theme.radius
                                color: root.recording
                                    ? Theme.alpha(Theme.danger, 0.16)
                                    : Theme.alpha(Theme.accent, 0.10)
                                border.width: 1
                                border.color: root.recording ? Theme.danger : Theme.borderAccent

                                Text {
                                    anchors.centerIn: parent
                                    text: root.recording ? "■ СТОП" : "● ЗАПИСЬ"
                                    color: root.recording ? Theme.danger : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: recModel.toggle()
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 30
                                radius: Theme.radius
                                color: recRefreshMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                                border.width: recRefreshMouse.containsMouse ? 1 : 0
                                border.color: Theme.borderAccent
                                Text {
                                    anchors.centerIn: parent
                                    text: "↻"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(14)
                                }
                                MouseArea {
                                    id: recRefreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: recModel.load()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.recording
                            text: "● идёт запись…"
                            color: Theme.danger
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                        }

                        ListView {
                            id: recList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 6
                            model: recModel.items

                            delegate: Rectangle {
                                required property var modelData
                                width: recList.width
                                height: 54
                                radius: Theme.radius
                                color: recMouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent"
                                border.width: 1
                                border.color: Theme.border

                                MouseArea {
                                    id: recMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: recModel.open(modelData.path)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        text: "\uf03d"
                                        color: Theme.accent
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.fontSize(16)
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize(12)
                                            elide: Text.ElideMiddle
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.fmtSize(modelData.size) + "  ·  " + root.fmtDate(modelData.mtime)
                                            color: Theme.textFaint
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize(10)
                                        }
                                    }

                                    Text {
                                        text: "\uf04b"
                                        color: playMouse.containsMouse ? Theme.accent : Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.fontSize(13)
                                        MouseArea {
                                            id: playMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: recModel.open(modelData.path)
                                        }
                                    }
                                    Text {
                                        text: "\uf1f8"
                                        color: delMouse.containsMouse ? Theme.danger : Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.fontSize(12)
                                        MouseArea {
                                            id: delMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: recModel.remove(modelData.path)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: recModel.items.length === 0
                            text: "записей нет"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "открыть папку записей"
                            color: folderMouse.containsMouse ? Theme.accent : Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            horizontalAlignment: Text.AlignHCenter
                            MouseArea {
                                id: folderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: recModel.openFolder()
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

    // ─────────────────────────── данные ───────────────────────────
    readonly property var player: {
        var ps = Mpris.players.values
        for (var i = 0; i < ps.length; i++)
            if (ps[i].isPlaying)
                return ps[i]
        return ps.length > 0 ? ps[0] : null
    }

    readonly property var monthNames: [
        "январь", "февраль", "март", "апрель", "май", "июнь",
        "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"
    ]

    readonly property string todayText: {
        var d = new Date()
        return d.getDate() + "." + ("0" + (d.getMonth() + 1)).slice(-2) + "." + d.getFullYear()
    }

    // 18 месяцев вперёд — список прокручивается
    readonly property var months: {
        var out = []
        var now = new Date()
        for (var i = 0; i < 18; i++) {
            var first = new Date(now.getFullYear(), now.getMonth() + i, 1)
            var y = first.getFullYear(), m = first.getMonth()
            var startDow = (new Date(y, m, 1).getDay() + 6) % 7
            var days = new Date(y, m + 1, 0).getDate()
            var cells = []
            for (var k = 0; k < startDow; k++)
                cells.push({ day: 0, today: false })
            for (var dd = 1; dd <= days; dd++)
                cells.push({ day: dd, today: (i === 0 && dd === now.getDate()) })
            out.push({ title: monthNames[m] + " " + y, cells: cells })
        }
        return out
    }

    Timer {
        id: hideTimer
        interval: 600
        onTriggered: {
            if (!stripHover.hovered && !contentHover.hovered)
                root.closePanel()
        }
    }

    // обновление списка уведомлений, пока панель открыта
    Timer {
        interval: 2500
        repeat: true
        running: !root.collapsed
        onTriggered: notif.load()
    }

    QtObject {
        id: notif
        property var items: []
        property bool dnd: false

        function load() {
            listProc.running = true
            modeProc.running = true
        }

        function dismiss(id) {
            actionProc.command = ["bash", "-c", "makoctl dismiss -n " + id]
            actionProc.running = true
        }

        function clear() {
            actionProc.command = ["bash", "-c", "makoctl dismiss --all"]
            actionProc.running = true
        }

        function toggleDnd() {
            actionProc.command = ["bash", "-c", "makoctl mode -t do-not-disturb"]
            actionProc.running = true
        }
    }

    Process {
        id: listProc
        running: false
        command: ["bash", "-c", "makoctl list -j 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text)
                    var out = []
                    for (var i = 0; i < arr.length; i++) {
                        var n = arr[i]
                        out.push({
                            id: n.id,
                            app: n.app_name || "",
                            summary: n.summary || "",
                            body: (n.body || "").replace(/\n/g, " ")
                        })
                    }
                    notif.items = out
                } catch (e) {
                    notif.items = []
                }
            }
        }
    }

    Process {
        id: modeProc
        running: false
        command: ["bash", "-c", "makoctl mode 2>/dev/null | grep -q '^do-not-disturb$' && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: notif.dnd = (text.trim() === "1")
        }
    }

    Process {
        id: actionProc
        running: false
        onExited: {
            notif.load()
            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 250
        onTriggered: notif.load()
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

    // ─────────────────── запись экрана ───────────────────
    property bool recording: false

    function fmtSize(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB"
        return Math.max(1, Math.round(b / 1048576)) + " MB"
    }

    function fmtDate(ts) {
        var d = new Date(ts * 1000)
        return ("0" + d.getDate()).slice(-2) + "." + ("0" + (d.getMonth() + 1)).slice(-2)
            + " " + ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
    }

    QtObject {
        id: recModel
        property var items: []

        function load() { recListProc.running = true }

        function toggle() {
            recActionProc.command = ["bash", "-c",
                "~/.config/hypr/scripts/eclipse-record.sh toggle"]
            recActionProc.running = true
        }

        function open(p) {
            recActionProc.command = ["bash", "-c", "setsid mpv '" + p + "' >/dev/null 2>&1 &"]
            recActionProc.running = true
        }

        function remove(p) {
            recActionProc.command = ["bash", "-c", "rm -f '" + p + "'"]
            recActionProc.running = true
        }

        function openFolder() {
            recActionProc.command = ["bash", "-c", "setsid xdg-open ~/Videos >/dev/null 2>&1 &"]
            recActionProc.running = true
        }
    }

    Process {
        id: recListProc
        running: false
        command: ["python3", "-c", `
import json, os, glob
d = os.path.expanduser("~/Videos")
out = []
for f in sorted(glob.glob(d + "/*.mp4"), key=os.path.getmtime, reverse=True):
    st = os.stat(f)
    out.append({"path": f, "name": os.path.basename(f),
                "size": st.st_size, "mtime": int(st.st_mtime)})
print(json.dumps(out[:200]))
`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    recModel.items = JSON.parse(text)
                } catch (e) {
                    recModel.items = []
                }
            }
        }
    }

    Process {
        id: recActionProc
        running: false
        onExited: {
            recModel.load()
            recStatusProc.running = true
        }
    }

    Process {
        id: recStatusProc
        running: false
        command: ["bash", "-c", "pgrep -x wf-recorder >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: root.recording = (text.trim() === "1")
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: !root.collapsed
        onTriggered: recStatusProc.running = true
    }

    Component.onCompleted: {
        notif.load()
        recModel.load()
        recStatusProc.running = true
    }
}
