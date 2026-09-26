
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import "SettingsPages"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only actually grab input/paint when open - mirrors the OSD's mask trick
    // so the window is a no-op on the compositor while closed.
    mask: Region {
        item: root.showing ? backdrop : null
    }

    property bool showing: false

    function openPanel() { showing = true }
    function closePanel() { showing = false }
    function toggle() { showing = !showing }

    // Bind a Hyprland key to this, e.g. in hyprland.conf:
    //   bind = SUPER, S, exec, qs ipc call hub toggle
    IpcHandler {
        target: "hub"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
        function nav(idx: int): void { root.selectedIndex = Math.max(0, Math.min(root.navItems.length - 1, idx)) }
    }

    // -------------------------
    // PipeWire (for volume)
    // -------------------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    property var sink: Pipewire.defaultAudioSink
    property real pwVolume: (sink && sink.audio) ? sink.audio.volume : 0
    property bool pwMuted: (sink && sink.audio) ? sink.audio.muted : false

    // -------------------------
    // Backdrop (click-outside-to-close)
    // -------------------------
    Rectangle {
        id: backdrop
        anchors.fill: parent
        // затемнение/блюр только пока открыто
        color: root.showing ? Theme.alpha(Theme.bgPanel, 0.45) : "transparent"

        focus: root.showing
        Keys.onEscapePressed: root.closePanel()

        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    // -------------------------
    // Nav model
    // -------------------------
    property var navItems: [
        { name: "Launch",     icon: "\uf120", page: "LaunchPage" },
        { name: "System",     icon: "󰒓", page: "SystemPage" },
        { name: "Sound",      icon: "\uf028", page: "SoundPage" },
        { name: "Monitors",   icon: "\uf108", page: "MonitorsPage" },
        { name: "Network",    icon: "\uf1eb", page: "NetworkPage" },
        { name: "Bluetooth",  icon: "󰂯", page: "BluetoothPage" },
        { name: "Interface",  icon: "\uf085", page: "InterfacePage" },
        { name: "Memory",     icon: "󰍛", page: "MemoryPage" },
        { name: "Games",      icon: "\uf11b", page: "GamesPage" },
        { name: "Dev",        icon: "\uf121", page: "DevPage" },
        { name: "Wallpapers", icon: "\uf03e", page: "WallpapersPage" },
        { name: "Update",     icon: "\uf021", page: "UpdatePage" }
    ]

    property int selectedIndex: 0

    // -------------------------
    // Глобальный поиск (поле внизу сайдбара)
    // -------------------------
    property string query: ""
    property var results: []
    property int resultIndex: 0

    property var searchActions: [
        { name: "Game Mode — вкл/выкл", icon: "\uf11b",
          run: function() { root.runShell("~/.config/hypr/scripts/eclipse-gamemode.sh toggle") } },
        { name: "Запись экрана — старт/стоп", icon: "\uf111",
          run: function() { root.runShell("~/.config/hypr/scripts/eclipse-record.sh toggle") } },
        { name: "Микшер (pavucontrol)", icon: "\uf028",
          run: function() { root.runShell("setsid pavucontrol >/dev/null 2>&1 &") } },
        { name: "Живые обои — вкл/выкл", icon: "\uf03e",
          run: function() { Theme.wallpaperLive = !Theme.wallpaperLive } },
        { name: "Оптимизация (OPTIMIZE) — вкл/выкл", icon: "\uf0e7",
          run: function() { Theme.optimizeMode = !Theme.optimizeMode } }
    ]

    Process { id: actionProc; running: false }

    function runShell(cmd) {
        actionProc.command = ["bash", "-c", cmd]
        actionProc.running = true
    }

    // приложение запущено (из поиска или Launch) — закрыть Hub
    Connections {
        target: AppModel
        function onLaunched() { root.closePanel() }
        // список приложений подгрузился/обновился — досчитываем выдачу
        function onAllAppsChanged() {
            if (root.query.trim() !== "")
                root.results = root.search(root.query)
        }
    }

    function matchRank(q, hay) {
        hay = ("" + hay).toLowerCase()
        var i = hay.indexOf(q)
        if (i === 0) return 0
        if (i > 0) return hay.charAt(i - 1) === " " ? 1 : 2
        var hi = 0, gaps = 0
        for (var k = 0; k < q.length; k++) {
            var idx = hay.indexOf(q.charAt(k), hi)
            if (idx < 0) return -1
            gaps += idx - hi
            hi = idx + 1
        }
        return 6 + gaps * 0.2
    }

    function search(q) {
        q = ("" + q).trim().toLowerCase()
        if (q === "") return []
        var out = []
        for (var i = 0; i < navItems.length; i++) {
            var r = root.matchRank(q, navItems[i].name)
            if (r >= 0)
                out.push({ kind: "page", rank: r - 1, label: navItems[i].name,
                           icon: navItems[i].icon, pageIndex: i })
        }
        for (var a = 0; a < searchActions.length; a++) {
            var ra = root.matchRank(q, searchActions[a].name)
            if (ra >= 0)
                out.push({ kind: "action", rank: ra - 1, label: searchActions[a].name,
                           icon: searchActions[a].icon, act: a })
        }
        var hits = []
        for (var j = 0; j < AppModel.allApps.length; j++) {
            var ap = AppModel.allApps[j]
            var hay = (ap.name + " " + (ap.generic || "") + " " + (ap.keywords || "")
                + " " + ap.id).toLowerCase()
            var r2 = root.matchRank(q, ap.name)
            if (r2 < 0) r2 = root.matchRank(q, hay)
            if (r2 >= 0) hits.push({ kind: "app", rank: r2, label: ap.name, app: ap })
        }
        hits.sort(function(x, y) { return x.rank - y.rank })
        out = out.concat(hits.slice(0, 8))
        out.sort(function(x, y) { return x.rank - y.rank })
        return out.slice(0, 12)
    }

    function setQuery(q) {
        root.query = q
        root.results = root.search(q)
        root.resultIndex = 0
    }

    function moveResult(d) {
        if (root.results.length === 0) return
        root.resultIndex = (root.resultIndex + d + root.results.length) % root.results.length
    }

    function activateIndex(i) {
        if (i < 0 || i >= root.results.length) return
        var r = root.results[i]
        if (r.kind === "page")
            root.selectedIndex = r.pageIndex
        else if (r.kind === "action")
            root.searchActions[r.act].run()
        else if (r.kind === "app")
            AppModel.launch(r.app)
        if (hubSearch)
            hubSearch.text = ""
        root.query = ""
        root.results = []
        root.resultIndex = 0
    }

    function activateResult() { root.activateIndex(root.resultIndex) }

    // -------------------------
    // Card
    // -------------------------
    PerspectivePanel {
        id: card
        anchors.centerIn: parent
        width: Math.min(1320, root.width - 80)
        height: Math.min(768, root.height - 80)
        open: root.showing

        MouseArea {
            cursorShape: Qt.PointingHandCursor
            // swallow clicks so they don't fall through to the backdrop
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 6
            border.color: Theme.accent
            border.width: 1

            // faint corner glow accents, cyberpunk HUD style
            Rectangle {
                width: 40; height: 2; color: Theme.accent2
                anchors { top: parent.top; left: parent.left; margins: 14 }
            }

            Rectangle {
                width: 2; height: 40; color: Theme.accent2
                anchors { top: parent.top; left: parent.left; margins: 14 }
            }

            Rectangle {
                width: 40; height: 2; color: Theme.accent2
                anchors { bottom: parent.bottom; right: parent.right; margins: 14 }
            }

            Rectangle {
                width: 2; height: 40; color: Theme.accent2
                anchors { bottom: parent.bottom; right: parent.right; margins: 14 }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 28

                // ---------------- Sidebar ----------------
                Item {
                    width: 158
                    height: parent.height
                    Column {
                        id: sidebar
                        width: 158
                        height: parent.height
                        spacing: 22

                        Text {
                            text: "SETTINGS"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            font.bold: true
                            font.letterSpacing: 4
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.border
                        }

                        // ---------------- Nav buttons ----------------
                        Column {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.navItems

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    width: sidebar.width
                                    height: 42
                                    radius: Theme.radius

                                    color: root.selectedIndex === index
                                        ? Theme.alpha(Theme.accent, 0.12)
                                        : "transparent"

                                    border.width: root.selectedIndex === index ? 1 : 0
                                    border.color: Theme.accent

                                    Rectangle {
                                        visible: root.selectedIndex === index
                                        width: 3
                                        height: parent.height - 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        color: Theme.accent2
                                    }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        spacing: 12

                                        Text {
                                            text: modelData.icon
                                            font.family: Theme.iconFont
                                            font.pixelSize: 15
                                            color: root.selectedIndex === index
                                                ? Theme.accent
                                                : Theme.textDim
                                        }

                                        Text {
                                            text: modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            color: root.selectedIndex === index
                                                ? Theme.text
                                                : Theme.textDim
                                        }
                                    }

                                    MouseArea {
                                        cursorShape: Qt.PointingHandCursor
                                        anchors.fill: parent
                                        onClicked: root.selectedIndex = index
                                    }
                                }
                            }
                        }
                    }
                    // поиск (глобальный) — внизу сайдбара
                    Rectangle {
                        id: hubSearchBox
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 38
                        radius: Theme.radius
                        color: Theme.bgCard
                        border.width: 1
                        border.color: hubSearch.activeFocus ? Theme.borderAccent : Theme.border

                        TextInput {
                            id: hubSearch
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "поиск по Hub…"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                visible: hubSearch.text === ""
                            }

                            onTextChanged: root.setQuery(text)
                            Keys.onEscapePressed: {
                                if (text !== "")
                                    text = ""
                                else
                                    root.closePanel()
                            }
                            Keys.onUpPressed: root.moveResult(-1)
                            Keys.onDownPressed: root.moveResult(1)
                            Keys.onReturnPressed: root.activateResult()
                            Keys.onPressed: (e) => {
                                if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                                    root.activateIndex(e.key - Qt.Key_1)
                                    e.accepted = true
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height
                    color: Theme.border
                }

                // ---------------- Page content ----------------
                Item {
                    width: parent.width - sidebar.width - 57
                    height: parent.height
                    clip: true

                    Loader {
                        id: pageLoader
                        anchors.fill: parent
                        source: "SettingsPages/" + root.navItems[root.selectedIndex].page + ".qml"

                        opacity: 0
                        Component.onCompleted: opacity = 1
                        onSourceChanged: fadeIn.restart()

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animMed
                            }
                        }

                        SequentialAnimation {
                            id: fadeIn

                            PropertyAction {
                                target: pageLoader
                                property: "opacity"
                                value: 0
                            }

                            NumberAnimation {
                                target: pageLoader
                                property: "opacity"
                                to: 1
                                duration: Theme.animMed
                            }
                        }
                    }

                    // результаты поиска — поверх контента
                    Rectangle {
                        id: searchOverlay
                        anchors.fill: parent
                        visible: root.query.trim() !== ""
                        color: Theme.alpha(Theme.bgPanel, 0.97)
                        radius: 6
                        border.color: Theme.border
                        border.width: 1
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            visible: root.results.length === 0
                            text: "ничего не найдено"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 3

                            Repeater {
                                model: root.results

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    height: 30
                                    radius: 4
                                    color: index === root.resultIndex
                                        ? Theme.alpha(Theme.accent, 0.12)
                                        : (rowMouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent")

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        height: 30
                                        spacing: 10

                                        Text {
                                            width: 14
                                            text: index < 9 ? (index + 1) : ""
                                            color: Theme.textFaint
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            width: 18
                                            visible: modelData.kind !== "app"
                                            text: modelData.icon || ""
                                            color: index === root.resultIndex ? Theme.accent : Theme.textDim
                                            font.family: Theme.iconFont
                                            font.pixelSize: 14
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Image {
                                            width: 18
                                            height: 18
                                            visible: modelData.kind === "app"
                                                && source != "" && status === Image.Ready
                                            source: modelData.kind === "app" && modelData.app.icon
                                                ? Quickshell.iconPath(modelData.app.icon, true) : ""
                                            sourceSize: Qt.size(36, 36)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.label
                                            color: index === root.resultIndex ? Theme.text : Theme.textDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.kind === "page" ? "страница"
                                                : (modelData.kind === "action" ? "действие" : "приложение")
                                            color: Theme.textFaint
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.resultIndex = index
                                        onClicked: root.activateIndex(index)
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


