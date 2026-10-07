import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import "SettingsPages"
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarHub — настройки/лаунчер оверлей-карточкой (как у 43PR).
//  Раньше был обычным FloatingWindow: Hyprland сам блюрил и тянул
//  его за края. Теперь — PanelWindow слоя Overlay: прозрачный фон
//  во весь экран + mask, а «окно» — карточка, которую тащу за
//  верхний грип, ресайзю с SUPER за края/углы и прилипаю по позициям
//  (центр/верх/низ/бок). Геометрия (snap,x,y,w,h) переживает
//  рестарт в ~/.config/lunar/hub-state.json. Фон темнит наша
//  LunarBackdrop (слой Bottom) — Hub лишь пишет флаг в Theme.setModal.
//  IPC: qs ipc call hub toggle|open|close|nav N  (0..8)
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lunar-hub"
    // клавиатуру беру только пока открыт (по требованию) — поиск и Esc
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // кликабельно только когда открыт; mask по подложке — модалка
    mask: Region { item: root.showing ? backdrop : null }

    property bool showing: false

    // Пока Hub открыт, снимаю у Hyprland бинды SUPER+ЛКМ/ПКМ: иначе они
    // съедают событие и QML не видит ресайз карточки за край/угол. Клавиши
    // не трогаю — хоткеи остаются живыми. Функция — в hyprland.lua.
    Process { id: hubMouseOff; command: ["hyprctl", "eval", "lunar_hub_mouse(false)"] }
    Process { id: hubMouseOn;  command: ["hyprctl", "eval", "lunar_hub_mouse(true)"] }
    // страховка: если Quickshell перезапустили с открытым Hub — вернуть бинды
    Component.onCompleted: hubMouseOn.running = true

    // агент/плеер и Hub взаимоисключающие: открылся Hub — гашу их
    // (через Theme.activeOverlay, в одном процессе — плавно)
    onShowingChanged: {
        if (showing) {
            Theme.activeOverlay = "hub"
            Theme.setModal("hub", true)
            hubMouseOff.running = true
        } else {
            Theme.setModal("hub", false)
            dragging = false
            hubMouseOn.running = true
        }
    }
    Connections {
        target: Theme
        function onActiveOverlayChanged() {
            if (Theme.activeOverlay !== "hub" && root.showing) root.closePanel()
        }
    }

    function openPanel() {
        showing = true
        Qt.callLater(function() {
            if (root.showing)
                cardContent.forceActiveFocus()
        })
    }
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
        // снап — удобно дёргать из тестов/скриптов
        function snapTop(): void { root.snapTop() }
        function snapBottom(): void { root.snapBottom() }
        function snapLeft(): void { root.snapLeft() }
        function snapRight(): void { root.snapRight() }
        function snapCenter(): void { root.snapCenter() }
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
        { name: "Launch",     icon: "󰆍", page: "LaunchPage" },
        { name: "System",     icon: "󰒓", page: "SystemPage" },
        { name: "Devices",    icon: "󰍹", page: "DevicesPage" },
        { name: "Network",    icon: "󰖩", page: "NetworkPage" },
        { name: "Interface",  icon: "󰣖", page: "InterfacePage" },
        { name: "Games",      icon: "󰊖", page: "GamesPage" },
        { name: "Dev",        icon: "󰅴", page: "DevPage" },
        { name: "Update",     icon: "󰑐", page: "UpdatePage" },
        { name: "Media",      icon: "󰈰", page: "MediaPage" }
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
        { name: "Game Mode — вкл/выкл", icon: "󰊖",
          run: function() { root.runShell("~/.config/hypr/scripts/eclipse-gamemode.sh toggle") } },
        { name: "Запись экрана — старт/стоп", icon: "󰝥",
          run: function() { root.runShell("~/.config/hypr/scripts/eclipse-record.sh toggle") } },
        { name: "Микшер (pavucontrol)", icon: "󰕾",
          run: function() { root.runShell("setsid pavucontrol >/dev/null 2>&1 &") } },
        { name: "Живые обои — вкл/выкл", icon: "󰋩",
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

    // ════════════════════════════════════════════════════════════════
    //  Карточка: геометрия, drag, snap, ресайз, персист
    //  (механика — по образцу SettingsWindow у 43PR, переписана под рис)
    // ════════════════════════════════════════════════════════════════
    property real cardMargin: 40
    property real dragMargin: 8
    property bool dragging: false
    property int minCardW: 760
    property int minCardH: 500

    property real cardHeightCenter: root.height > 0
        ? Math.min(640, root.height - cardMargin * 2) : 640
    property real cardHeightSnapped: cardHeightCenter * 0.6
    property real cardHeight: 640
    property real cardY: root.height > 0 ? (root.height - cardHeight) / 2 : 0

    property real cardWidthCenter: root.width > 0
        ? Math.min(980, root.width - cardMargin * 2) : 980
    property real cardWidthSnapped: cardWidthCenter * 0.85
    property real cardHeightSideSnapped: cardHeightCenter * 1.4
    property real cardWidth: 980
    property real cardX: root.width > 0 ? (root.width - cardWidth) / 2 : 0

    property string snapPosition: "center"
    property real freeX: 0
    property real freeY: 0
    property real freeW: 0
    property real freeH: 0
    property bool stateReady: false

    readonly property string statePath: Quickshell.env("HOME") + "/.config/lunar/hub-state.json"

    function saveState() {
        if (!root.stateReady) return
        stateFile.setText(JSON.stringify({
            snap: root.snapPosition,
            x: root.freeX,
            y: root.freeY,
            w: root.freeW,
            h: root.freeH
        }))
    }

    function clampX(v) {
        return Math.max(dragMargin, Math.min(root.width - cardWidth - dragMargin, v))
    }

    function clampY(v) {
        return Math.max(dragMargin, Math.min(root.height - cardHeight - dragMargin, v))
    }

    function applySnap(pos) {
        if (root.width <= 0 || root.height <= 0) return
        switch (pos) {
        case "top":
            cardWidth = cardWidthCenter
            cardHeight = cardHeightSnapped
            cardX = (root.width - cardWidth) / 2
            cardY = cardMargin
            break
        case "bottom":
            cardWidth = cardWidthCenter
            cardHeight = cardHeightSnapped
            cardX = (root.width - cardWidth) / 2
            cardY = root.height - cardHeight - cardMargin
            break
        case "left":
            cardWidth = cardWidthSnapped
            cardHeight = Math.min(cardHeightSideSnapped, root.height - cardMargin * 2)
            cardX = cardMargin
            cardY = (root.height - cardHeight) / 2
            break
        case "right":
            cardWidth = cardWidthSnapped
            cardHeight = Math.min(cardHeightSideSnapped, root.height - cardMargin * 2)
            cardX = root.width - cardWidth - cardMargin
            cardY = (root.height - cardHeight) / 2
            break
        case "free":
            cardWidth = Math.max(root.minCardW,
                Math.min(freeW > 0 ? freeW : cardWidthCenter, root.width - 2 * dragMargin))
            cardHeight = Math.max(root.minCardH,
                Math.min(freeH > 0 ? freeH : cardHeightCenter, root.height - 2 * dragMargin))
            cardX = clampX(freeX)
            cardY = clampY(freeY)
            break
        default: // center
            cardHeight = cardHeightCenter
            cardWidth = cardWidthCenter
            cardY = (root.height - cardHeight) / 2
            cardX = (root.width - cardWidth) / 2
        }
    }

    function snapTo(pos) {
        root.snapPosition = pos
        root.applySnap(pos)
        root.saveState()
    }

    function snapTop()    { snapTo("top") }
    function snapBottom() { snapTo("bottom") }
    function snapLeft()   { snapTo("left") }
    function snapRight()  { snapTo("right") }
    function snapCenter() { snapTo("center") }

    // конец перетаскивания: фиксирую свободную позицию и запоминаю
    function finishDrag() {
        if (!root.dragging) return
        root.dragging = false
        root.snapPosition = "free"
        root.freeX = root.cardX
        root.freeY = root.cardY
        root.freeW = root.cardWidth
        root.freeH = root.cardHeight
        root.saveState()
    }

    // конец ресайза за край/угол — то же, что drag, но размер уже задан
    function finishResize() {
        if (!root.dragging) return
        root.dragging = false
        root.snapPosition = "free"
        root.freeX = root.cardX
        root.freeY = root.cardY
        root.freeW = root.cardWidth
        root.freeH = root.cardHeight
        root.saveState()
    }

    onWidthChanged: if (width > 0 && height > 0) applySnap(snapPosition)
    onHeightChanged: if (width > 0 && height > 0) applySnap(snapPosition)

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                if (["center", "top", "bottom", "left", "right", "free"].indexOf(s.snap) >= 0) {
                    if (typeof s.x === "number") root.freeX = s.x
                    if (typeof s.y === "number") root.freeY = s.y
                    if (typeof s.w === "number") root.freeW = s.w
                    if (typeof s.h === "number") root.freeH = s.h
                    root.snapPosition = s.snap
                    root.applySnap(s.snap)
                }
            } catch (e) {
                console.warn("hub: could not read saved state:", e)
            }
            root.stateReady = true
        }
        onLoadFailed: root.stateReady = true
    }

    // ── подложка: ловит клик «мимо» и Esc ──
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"
        focus: root.showing
        Keys.onEscapePressed: root.closePanel()

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    // ── карточка Hub ──
    Rectangle {
        id: card
        x: root.cardX
        y: root.cardY
        width: root.cardWidth
        height: root.cardHeight
        radius: Theme.radiusL
        color: Theme.barPill
        border.width: 1
        border.color: Theme.arch ? Theme.hairAccent : Theme.hair

        opacity: root.showing ? 1 : 0
        visible: opacity > 0

        Behavior on x {
            enabled: !root.dragging && root.showing
            NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
        }
        Behavior on y {
            enabled: !root.dragging && root.showing
            NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
        }
        Behavior on width {
            enabled: !root.dragging
            NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
        }
        Behavior on height {
            enabled: !root.dragging
            NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
        }

        // -------------------------
        // Содержимое (бывшая карточка — теперь внутри оверлей-окна)
        // -------------------------
        Item {
            id: cardContent
            anchors.fill: parent
            focus: true

            // клавиатура: Esc закрывает
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
                    // ширина сайдбара едет за карточкой: на минимуме — 180,
                    // на широкой — до 240, но не больше 16% ширины
                    width: Theme.clamp(parent.width * 0.16, 180, 240)
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

        // ── верхний грип: тащу карточку, двойной клик — центр ──
        Item {
            id: positionHandle
            width: 220
            height: 22
            z: 120
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            anchors.topMargin: -3

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0
                property real startX: 0
                property real startY: 0
                property bool moved: false

                onPressed: function(mouse) {
                    var p = dragArea.mapToItem(backdrop, mouse.x, mouse.y)
                    pressX = p.x
                    pressY = p.y
                    startX = root.cardX
                    startY = root.cardY
                    moved = false
                    root.dragging = true
                }
                onPositionChanged: function(mouse) {
                    if (!root.dragging) return
                    var p = dragArea.mapToItem(backdrop, mouse.x, mouse.y)
                    moved = true
                    root.cardX = root.clampX(startX + (p.x - pressX))
                    root.cardY = root.clampY(startY + (p.y - pressY))
                }
                onReleased: {
                    if (!root.dragging) return
                    if (moved) root.finishDrag()
                    else root.dragging = false
                }
                onCanceled: {
                    if (!root.dragging) return
                    if (moved) root.finishDrag()
                    else root.dragging = false
                }
                onDoubleClicked: root.snapCenter()
            }

            Row {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: "◀"
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    color: Theme.textDim
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: root.snapLeft() }
                }
                Text {
                    text: "▲"
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.textDim
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: root.snapTop() }
                }
                Text {
                    text: "●"
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.textDim
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: root.snapCenter() }
                }
                Text {
                    text: "▼"
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.textDim
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: root.snapBottom() }
                }
                Text {
                    text: "▶"
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    color: Theme.textDim
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: root.snapRight() }
                }
            }
        }

        // ── ресайз за края и углы (битовая маска edges) ──
        //  Раньше Hub был обычным окном и тянулся за края с SUPER (resize_on_border).
        //  Возвращаю то же: ресайз стартует только при зажатом SUPER (Meta). Без SUPER
        //  отпускаю событие — клик/скролл уходят содержимому, край ничего не ловит.
        component ResizeHandle: MouseArea {
            id: rh
            property int edges: 0
            z: 100
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: (rh.edges === 1 || rh.edges === 2) ? Qt.SizeHorCursor
                       : (rh.edges === 4 || rh.edges === 8) ? Qt.SizeVerCursor
                       : (rh.edges === 5 || rh.edges === 10) ? Qt.SizeFDiagCursor
                       : Qt.SizeBDiagCursor

            property real pressX: 0
            property real pressY: 0
            property real startX: 0
            property real startY: 0
            property real startW: 0
            property real startH: 0

            onPressed: function(mouse) {
                if (!(mouse.modifiers & Qt.MetaModifier)) {
                    mouse.accepted = false
                    return
                }
                var p = rh.mapToItem(backdrop, mouse.x, mouse.y)
                pressX = p.x
                pressY = p.y
                startX = root.cardX
                startY = root.cardY
                startW = root.cardWidth
                startH = root.cardHeight
                root.dragging = true
            }
            onPositionChanged: function(mouse) {
                if (!root.dragging) return
                var p = rh.mapToItem(backdrop, mouse.x, mouse.y)
                var dx = p.x - pressX
                var dy = p.y - pressY
                var x = startX, y = startY, w = startW, h = startH
                if (rh.edges & 1) { x = startX + dx; w = startW - dx }
                if (rh.edges & 2) { w = startW + dx }
                if (rh.edges & 4) { y = startY + dy; h = startH - dy }
                if (rh.edges & 8) { h = startH + dy }
                if (w < root.minCardW) {
                    if (rh.edges & 1) x = startX + startW - root.minCardW
                    w = root.minCardW
                }
                if (h < root.minCardH) {
                    if (rh.edges & 4) y = startY + startH - root.minCardH
                    h = root.minCardH
                }
                if (x < root.dragMargin) { w += x - root.dragMargin; x = root.dragMargin }
                if (y < root.dragMargin) { h += y - root.dragMargin; y = root.dragMargin }
                if (x + w > root.width - root.dragMargin) w = root.width - root.dragMargin - x
                if (y + h > root.height - root.dragMargin) h = root.height - root.dragMargin - y
                root.cardX = x
                root.cardY = y
                root.cardWidth = w
                root.cardHeight = h
            }
            onReleased: root.finishResize()
            onCanceled: root.finishResize()
        }

        ResizeHandle {
            edges: 1; width: 6
            anchors { left: parent.left; leftMargin: -3; top: parent.top; topMargin: 12; bottom: parent.bottom; bottomMargin: 12 }
        }
        ResizeHandle {
            edges: 2; width: 6
            anchors { right: parent.right; rightMargin: -3; top: parent.top; topMargin: 12; bottom: parent.bottom; bottomMargin: 12 }
        }
        ResizeHandle {
            edges: 4; height: 6
            anchors { top: parent.top; topMargin: -3; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
        }
        ResizeHandle {
            edges: 8; height: 6
            anchors { bottom: parent.bottom; bottomMargin: -3; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
        }
        ResizeHandle {
            edges: 5; width: 14; height: 14
            anchors { left: parent.left; leftMargin: -5; top: parent.top; topMargin: -5 }
        }
        ResizeHandle {
            edges: 6; width: 14; height: 14
            anchors { right: parent.right; rightMargin: -5; top: parent.top; topMargin: -5 }
        }
        ResizeHandle {
            edges: 9; width: 14; height: 14
            anchors { left: parent.left; leftMargin: -5; bottom: parent.bottom; bottomMargin: -5 }
        }
        ResizeHandle {
            edges: 10; width: 14; height: 14
            anchors { right: parent.right; rightMargin: -5; bottom: parent.bottom; bottomMargin: -5 }
        }
    }
}
