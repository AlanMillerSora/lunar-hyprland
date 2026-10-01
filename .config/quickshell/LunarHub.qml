
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import "SettingsPages"

// ════════════════════════════════════════════════════════════════
//  LunarHub — настройки/лаунчер обычным окном (FloatingWindow).
//  Hyprland сам даёт тянуть за края, двигать, блюрит (окно
//  полупрозрачное) и скругляет — правило в hyprland.lua по
//  заголовку «Lunar Hub». Раньше был layer-оверлей с затемнением
//  и закрытием по клику мимо; обычное окно честнее и не гоняет
//  лишний блюр слоя. IPC: qs ipc call hub toggle|open|close|nav N
// ════════════════════════════════════════════════════════════════
FloatingWindow {
    id: root

    title: "Lunar Hub"
    color: Theme.bgPanel          // полупрозрачный фон — его и блюрит Hyprland
    visible: root.showing
    implicitWidth: 1320
    implicitHeight: 820
    minimumSize: Qt.size(820, 560)

    property bool showing: false

    // агент и Hub взаимоисключающие: открылся Hub — гашу агента
    // (через Theme.activeOverlay, в одном процессе — плавно)
    onShowingChanged: if (showing) Theme.activeOverlay = "hub"
    Connections {
        target: Theme
        function onActiveOverlayChanged() {
            if (Theme.activeOverlay !== "hub" && root.showing) root.closePanel()
        }
    }

    function openPanel() { showing = true }
    function closePanel() {
        showing = false
        // L29: сбрасываем поиск, чтобы при следующем открытии поле было пустым
        if (query !== "") {
            query = ""
            results = []
            resultIndex = 0
        }
        if (hubSearch)
            hubSearch.text = ""
    }
    function toggle() { showing = !showing }

    // Bind a Hyprland key to this, e.g. in hyprland.conf:
    //   bind = SUPER, S, exec, qs ipc call hub toggle
    IpcHandler {
        target: "hub"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
        function nav(idx: int): void { root.selectPage(idx) }
    }

    // -------------------------
    // PipeWire (for volume)
    // -------------------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    property var sink: Pipewire.defaultAudioSink
    property real pwVolume: (sink && sink.audio) ? sink.audio.volume : 0
    property bool pwMuted: (sink && sink.audio) ? sink.audio.muted : false

    // -------------------------
    // Nav model
    // -------------------------
    property var navItems: [
        { name: "Launch",     icon: "\uf120", page: "LaunchPage" },
        { name: "System",     icon: "󰒓", page: "SystemPage" },
        { name: "Devices",    icon: "\uf108", page: "DevicesPage" },
        { name: "Network",    icon: "\uf1eb", page: "NetworkPage" },
        { name: "Interface",  icon: "\uf085", page: "InterfacePage" },
        { name: "Games",      icon: "\uf11b", page: "GamesPage" },
        { name: "Dev",        icon: "\uf121", page: "DevPage" },
        { name: "Update",     icon: "\uf021", page: "UpdatePage" }
    ]

    property int selectedIndex: 0

    // H: кэш страниц. Создаю страницу при первом заходе и держу живой —
    // переключение вкладок не пересобирает QML и не убивает её Process
    // (System/Network/Monitors и т.д. стартуют один раз). Спящие страницы
    // не рисуются и гасят свои таймеры по visible. Индекс 0 — сразу.
    property var visitedPages: [true]

    function ensurePage(i) {
        if (i < 0 || i >= root.navItems.length || root.visitedPages[i] === true)
            return
        var v = root.visitedPages.slice()
        v[i] = true
        root.visitedPages = v
    }

    function selectPage(i) {
        i = Math.max(0, Math.min(root.navItems.length - 1, i))
        root.selectedIndex = i
        root.ensurePage(i)
    }

    // -------------------------
    // Глобальный поиск (поле внизу сайдбара)
    // -------------------------
    property string query: ""
    property var results: []
    property int resultIndex: 0
    // H38: предрассчитанные поисковые строки приложений
    // (не склеиваем name/generic/keywords/id на каждый введённый символ)
    property var appHay: []

    property var searchActions: [
        { name: "Game Mode — вкл/выкл", icon: "\uf11b",
          run: function() { root.runShell("~/.config/hypr/scripts/eclipse-gamemode.sh toggle") } },
        { name: "Запись экрана — старт/стоп", icon: "\uf111",
          run: function() { root.runShell("~/.config/hypr/scripts/eclipse-record.sh toggle") } },
        { name: "Микшер (pavucontrol)", icon: "\uf028",
          run: function() { root.runShell("setsid pavucontrol >/dev/null 2>&1 &") } },
        { name: "Живые обои — вкл/выкл", icon: "\uf03e",
          run: function() { Theme.wallpaperLive = !Theme.wallpaperLive } }
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
            root.rebuildAppHay()
            if (root.query.trim() !== "")
                root.applyQuery(root.query)
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
        var apps = AppModel.allApps
        if (root.appHay.length !== apps.length)
            root.rebuildAppHay()
        var hits = []
        for (var j = 0; j < apps.length; j++) {
            var ap = apps[j]
            var r2 = root.matchRank(q, ap.name)
            if (r2 < 0) r2 = root.matchRank(q, root.appHay[j])
            if (r2 >= 0) hits.push({ kind: "app", rank: r2, label: ap.name, app: ap })
        }
        hits.sort(function(x, y) { return x.rank - y.rank })
        out = out.concat(hits.slice(0, 8))
        out.sort(function(x, y) { return x.rank - y.rank })
        return out.slice(0, 12)
    }

    function rebuildAppHay() {
        var apps = AppModel.allApps
        var h = []
        for (var i = 0; i < apps.length; i++) {
            var ap = apps[i]
            h.push(((ap.name || "") + " " + (ap.generic || "") + " " + (ap.keywords || "")
                + " " + (ap.id || "")).toLowerCase())
        }
        root.appHay = h
    }

    function applyQuery(q) {
        root.results = root.search(q)
        root.resultIndex = 0
    }

    // H38: debounce — не гоняем поиск по всем приложениям на каждый символ
    Timer {
        id: searchDebounce
        interval: 120
        repeat: false
        onTriggered: root.applyQuery(root.query)
    }

    function setQuery(q) {
        root.query = q
        searchDebounce.restart()
    }

    function moveResult(d) {
        if (root.results.length === 0) return
        root.resultIndex = (root.resultIndex + d + root.results.length) % root.results.length
    }

    function activateIndex(i) {
        if (i < 0 || i >= root.results.length) return
        var r = root.results[i]
        if (r.kind === "page")
            root.selectPage(r.pageIndex)
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
    // Содержимое (бывшая карточка — поднял её прямо в окно)
    // -------------------------
    Item {
        anchors.fill: parent
        focus: true

        // клавиатура обычного окна: Esc закрывает, стрелки/Enter — по поиску
        Keys.onEscapePressed: {
            if (hubSearch.text !== "") {
                hubSearch.text = ""
                root.query = ""
                root.results = []
                root.resultIndex = 0
            } else {
                root.closePanel()
            }
        }
        Keys.onUpPressed: root.moveResult(-1)
        Keys.onDownPressed: root.moveResult(1)
        Keys.onReturnPressed: {
            // H38: если debounce ещё не сработал — досчитываю сразу
            if (searchDebounce.running) {
                searchDebounce.stop()
                root.applyQuery(root.query)
            }
            root.activateResult()
        }
        Keys.onPressed: (e) => {
            // H14: цифры остаются обычным вводом; быстрый выбор — по Ctrl+1…9
            if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9
                && (e.modifiers & Qt.ControlModifier)) {
                root.activateIndex(e.key - Qt.Key_1)
                e.accepted = true
            }
        }

        // приглушённые HUD-скобки: намёк на кибер-рамку, не спорящий с контентом
        Rectangle {
            width: 40; height: 2; color: Theme.alpha(Theme.accent, 0.35)
            anchors { top: parent.top; left: parent.left; margins: 14 }
        }

        Rectangle {
            width: 2; height: 40; color: Theme.alpha(Theme.accent, 0.35)
            anchors { top: parent.top; left: parent.left; margins: 14 }
        }

        Rectangle {
            width: 40; height: 2; color: Theme.alpha(Theme.accent, 0.35)
            anchors { bottom: parent.bottom; right: parent.right; margins: 14 }
        }

        Rectangle {
            width: 2; height: 40; color: Theme.alpha(Theme.accent, 0.35)
            anchors { bottom: parent.bottom; right: parent.right; margins: 14 }
        }

        Row {
                anchors.fill: parent
                anchors.margins: Theme.space6
                spacing: Theme.space6

                // ---------------- Sidebar ----------------
                Item {
                    // ширина сайдбара едет за окном: на минимуме (820) — 180,
                    // на широком — до 240, но не больше 16% ширины
                    width: Theme.clamp(root.width * 0.16, 180, 240)
                    height: parent.height
                    Column {
                        id: sidebar
                        width: parent.width
                        height: parent.height
                        spacing: Theme.space5

                        Text {
                            text: "SETTINGS"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitle
                            font.bold: true
                            font.letterSpacing: 4
                        }

                        // ---------------- Nav buttons ----------------
                        // H15: на низких экранах (800p) список не влезает — прокручиваем
                        Flickable {
                            id: navFlick
                            width: parent.width
                            height: Math.max(0, sidebar.height - y - hubSearchBox.height - 12)
                            contentWidth: width
                            contentHeight: navColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            // H15: прокрутка колесом (только вертикаль)
                            WheelHandler {
                                onWheel: function(event) {
                                    if (event.angleDelta.y === 0)
                                        return
                                    navFlick.contentY = Math.max(0,
                                        Math.min(navFlick.contentHeight - navFlick.height,
                                            navFlick.contentY - event.angleDelta.y))
                                    event.accepted = true
                                }
                            }

                            Column {
                            id: navColumn
                            width: navFlick.width
                            spacing: 4

                            Repeater {
                                model: root.navItems

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    width: sidebar.width
                                    height: Theme.rowH
                                    radius: Theme.radiusM

                                    color: root.selectedIndex === index
                                        ? Theme.active
                                        : (navMouse.containsMouse ? Theme.hover : "transparent")

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
                                        id: navMouse
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        anchors.fill: parent
                                        onClicked: root.selectPage(index)
                                    }
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
                        height: Theme.rowH
                        radius: Theme.radiusM
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
                            Keys.onReturnPressed: {
                                // H38: если debounce ещё не сработал — досчитываем сразу
                                if (searchDebounce.running) {
                                    searchDebounce.stop()
                                    root.applyQuery(root.query)
                                }
                                root.activateResult()
                            }
                            Keys.onPressed: (e) => {
                                // H14: цифры остаются обычным вводом; быстрый выбор — по Ctrl+1…9
                                if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9
                                    && (e.modifiers & Qt.ControlModifier)) {
                                    root.activateIndex(e.key - Qt.Key_1)
                                    e.accepted = true
                                }
                            }
                        }
                    }
                }

                // ---------------- Page content ----------------
                Item {
                    width: parent.width - sidebar.width - Theme.space6
                    height: parent.height
                    clip: true

                    // H: страницы в кэше. Каждая создаётся один раз (при первом
                    // заходе) и живёт до конца сессии — поэтому переходы мгновенные,
                    // а её Process не убиваются SIGKILL посреди долгой операции.
                    // Живая, но не текущая страница = invisible: таймеры-поллинг
                    // (Network/Bluetooth/Memory/System) спят по page.visible.
                    Repeater {
                        model: root.navItems

                        delegate: Loader {
                            required property var modelData
                            required property int index

                            anchors.fill: parent
                            active: root.visitedPages[index] === true
                            source: active ? "SettingsPages/" + modelData.page + ".qml" : ""

                            // видимость — текущая страница, пока Hub открыт
                            onItemChanged: if (item)
                                item.visible = Qt.binding(function() {
                                    return index === root.selectedIndex && root.showing
                                })
                        }
                    }

                    // результаты поиска — поверх контента
                    Rectangle {
                        id: searchOverlay
                        anchors.fill: parent
                        visible: root.query.trim() !== ""
                        color: Theme.alpha(Theme.bgPanel, 0.97)
                        radius: Theme.radiusL
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
                                    radius: Theme.radius
                                    color: index === root.resultIndex
                                        ? Theme.active
                                        : (rowMouse.containsMouse ? Theme.hover : "transparent")

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


