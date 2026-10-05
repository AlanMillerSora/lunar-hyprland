
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import "SettingsPages"
import "widgets/shared"

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
    // arch: фон окна — тот же тон, что у плашки бара (palette.barPill):
    // меняются обои → Hub меняет цвет вместе с баром. Окно и так блюрится
    // и скругляется Hyprland'ом.
    color: Theme.barPill
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
        { name: "Update",     icon: "\uf021", page: "UpdatePage" },
        { name: "Media",      icon: "\uf008", page: "MediaPage" }
    ]

    property int selectedIndex: 0

    // H: кэш страниц — LRU на pageCacheLimit (текущая + недавние).
    // Раньше страница жила до конца сессии, и все девять держали свои
    // Process/модели (сотни МБ). Теперь живыми остаются только последние
    // три: при заходе на четвёртую самую старую выгружаю (снимаю
    // visitedPages) — её Process и таймеры останавливаются, память
    // возвращается. Повторный заход поднимает страницу заново
    // (ensurePage/selectPage), переключение при этом не ломается.
    property int pageCacheLimit: 3
    property var pageOrder: [0]
    property var visitedPages: [true]

    function touchPage(i) {
        var o = root.pageOrder.slice()
        var at = o.indexOf(i)
        if (at !== -1)
            o.splice(at, 1)
        o.unshift(i)
        var v = root.visitedPages.slice()
        while (o.length > root.pageCacheLimit) {
            var old = o.pop()
            v[old] = false
        }
        v[i] = true
        root.pageOrder = o
        root.visitedPages = v
    }

    function ensurePage(i) {
        if (i < 0 || i >= root.navItems.length)
            return
        root.touchPage(i)
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

        // клавиатура обычного окна: Esc закрывает
        Keys.onEscapePressed: root.closePanel()

        // architect: линия по всей длине верхней кромки
        Rectangle {
            visible: Theme.arch
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: Theme.lineThick
            color: Theme.hairAccent
        }
        // architect: линия по нижней кромке
        Rectangle {
            visible: Theme.arch
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Theme.line
            color: Theme.hairAccent
        }

        // architect: визиры в полях (диагональные засечки убрал — Hub и без них
        // держит «чертёж»: скобки HudFrame + узлы + внутренняя линия)
        HudCrosshairs { inset: 14; arm: 7 }
        HudNodes { inset: 7; size: 5 }
        HudInnerFrame { variant: 3 }

        // HUD-скобки (единый компонент; раньше были инлайном)
        HudFrame {
            always: true
            color: Theme.accent
            size: 40
            thickness: 2
            inset: 14
            strength: 0.35
        }

        Row {
                anchors.fill: parent
                anchors.margins: Theme.space6
                anchors.bottomMargin: Theme.space6
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

                        Rectangle {
                            visible: Theme.arch
                            width: 30
                            height: Theme.lineThick
                            color: Theme.hairAccent
                        }

                        // ---------------- Nav buttons ----------------
                        // H15: на низких экранах (800p) список не влезает — прокручиваем
                        Flickable {
                            id: navFlick
                            width: parent.width
                            height: Math.max(0, sidebar.height - y)
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
                            spacing: Theme.space1

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
                                        spacing: Theme.space3

                                        Text {
                                            text: modelData.icon
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.fontSize(15)
                                            color: root.selectedIndex === index
                                                ? Theme.accent
                                                : Theme.textDim
                                        }

                                        Text {
                                            text: modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontBody
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
                }

                // ---------------- Page content ----------------
                Item {
                    width: parent.width - sidebar.width - Theme.space6
                    height: parent.height
                    clip: true

                    // architect: разделитель между навигацией и контентом
                    Rectangle {
                        visible: Theme.arch
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        anchors.leftMargin: -Theme.space3
                        width: Theme.line
                        color: Theme.hair
                    }

                    // H: страницы в кэше — LRU (см. pageCacheLimit выше).
                    // Живыми держу не больше трёх: давние выгружаю, их Process
                    // останавливаются. Переходы всё равно мгновенные (живой
                    // набор), а долгие операции с выгруженной страницы уже не
                    // нужны. Живая, но не текущая страница = invisible: таймеры-
                    // поллинг (Network/Bluetooth/Memory/System) спят по page.visible.
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

                }
            }

        }
}
