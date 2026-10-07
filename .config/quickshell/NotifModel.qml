pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// ════════════════════════════════════════════════════════════════
//  NotifModel — единственный владелец уведомлений риса. Держу здесь
//  сам демон (Quickshell.Services.Notifications, D-Bus
//  org.freedesktop.Notifications), историю, DND и настройки, чтобы
//  и панель бара (PanelNotifs), и тост-оверлей (LunarNotifications),
//  и сайдбар читали один источник. mako больше не нужен.
//
//  Раньше модель парсила вывод makoctl; теперь это живой NotificationServer:
//  тост показывает LunarNotifications по trackedNotifications, а здесь
//  собираю единый список «активные + история» для панели бара.
//
//  Хранение:
//    ~/.config/quickshell/state/notifications-state.json — DND/размер/позиция
//    ~/.cache/lunar/notifications.json                  — история (до 100)
// ════════════════════════════════════════════════════════════════
QtObject {
    id: nm

    // ── демон: D-Bus-имя занимаю я, а не mako ──────────────────
    property NotificationServer server: NotificationServer {
        id: server
        // переживаю перезагрузку конфига Quickshell — активные не теряются
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: (n) => nm.onNotification(n)
    }

    // Содержимое модели меняется — пересобираю список для панели. Именно
    // valuesChanged модели (сам объект trackedNotifications не меняется),
    // иначе счётчик активных в баре залипал бы на нуле.
    property Connections trackedConn: Connections {
        target: nm.server.trackedNotifications
        function onValuesChanged() { nm.rebuild() }
    }

    // активные (то, что показывает тост) — удобный алиас для UI
    readonly property var tracked: server.trackedNotifications

    property var items: []        // единый список для панели бара
    property var history: []      // история: свежие впереди
    property bool dnd: false
    property int menuSize: 100    // масштаб оверлея, 60..200
    property string pos: "tr"     // угол: tr | br | tl | bl
    property int maxHistory: 100
    property var expandedId: -1   // развёрнутое в панели бара
    property int count: 0         // активные (значок колокольчика в баре)

    property bool stateReady: false
    property bool historyReady: false
    property int hidSeq: 0        // раздаю отрицательные id истории

    // ── id истории ─────────────────────────────────────────────
    function nextHid() { nm.hidSeq -= 1; return nm.hidSeq }

    function urgencyName(u) {
        if (u === NotificationUrgency.Critical) return "critical"
        if (u === NotificationUrgency.Low) return "low"
        return "normal"
    }

    // ── пришло уведомление ─────────────────────────────────────
    // DND глушит обычные, но критичные (и аварийные) всё равно показываю —
    // иначе важное молча теряется. transient (OSD приложений) в историю не
    // кладу, но тост показываю.
    function onNotification(n) {
        n.tracked = !(nm.dnd && n.urgency !== NotificationUrgency.Critical)

        if (n.transient)
            return

        var img = (n.image && String(n.image).indexOf("image://") !== 0)
            ? String(n.image) : ""
        nm.history.unshift({
            hid: nm.nextHid(),
            summary: n.summary || "",
            body: n.body || "",
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            image: img,
            urgency: nm.urgencyName(n.urgency),
            time: Date.now()
        })
        if (nm.history.length > nm.maxHistory)
            nm.history = nm.history.slice(0, nm.maxHistory)
        else
            nm.history = nm.history.slice()   // переприсваиваю — биндинги живы
        nm.rebuild()
        nm.historyTimer.restart()
    }

    // ── сборка списка для панели: активные сверху, затем история ──
    function rebuild() {
        var out = []
        var av = nm.server.trackedNotifications ? nm.server.trackedNotifications.values : []
        for (var i = 0; i < av.length; i++) {
            var n = av[i]
            out.push({
                id: n.id,
                app: n.appName || "",
                summary: n.summary || "",
                body: n.body || "",
                icon: n.appIcon || "",
                image: (n.image && String(n.image).indexOf("image://") !== 0) ? String(n.image) : "",
                urgency: nm.urgencyName(n.urgency),
                group: "active",
                time: 0
            })
        }
        for (var j = 0; j < nm.history.length; j++) {
            var h = nm.history[j]
            out.push({
                id: h.hid,
                app: h.appName || "",
                summary: h.summary || "",
                body: h.body || "",
                icon: h.appIcon || "",
                image: h.image || "",
                urgency: h.urgency || "normal",
                group: "history",
                time: h.time || 0
            })
        }
        nm.items = out
        nm.count = av.length
        nm.saveStatus()
    }

    // совместимость с прежним вызовом NotifModel.load()
    function load() { nm.rebuild() }

    function toggleExpand(id) {
        nm.expandedId = (nm.expandedId === id) ? -1 : id
    }

    // ── удаление ───────────────────────────────────────────────
    // id >= 0 — активное (dismiss у демона), id < 0 — запись истории.
    function dismiss(id) {
        if (id >= 0) {
            var av = nm.server.trackedNotifications.values
            for (var i = 0; i < av.length; i++) {
                if (av[i].id === id) { av[i].dismiss(); break }
            }
        } else {
            for (var j = 0; j < nm.history.length; j++) {
                if (nm.history[j].hid === id) { nm.history.splice(j, 1); break }
            }
            nm.history = nm.history.slice()
            nm.historyTimer.restart()
        }
        if (nm.expandedId === id) nm.expandedId = -1
        nm.rebuild()
    }

    // ── очистка: история + активные (как прежний «очистить») ────
    function clear() {
        nm.history = []
        nm.expandedId = -1
        var av = nm.server.trackedNotifications.values.slice()
        for (var i = 0; i < av.length; i++)
            av[i].dismiss()
        nm.rebuild()
        nm.historyTimer.restart()
    }

    function toggleDnd() {
        nm.setDnd(!nm.dnd)
    }

    // явная установка (Game Mode гасит/возвращает DND детерминированно)
    function setDnd(v) {
        if (nm.dnd === v) return
        nm.dnd = v
        nm.stateTimer.restart()
        nm.saveStatus()
    }

    // статус для shell-скриптов (eclipse-status.sh / контекст агента):
    // крошечный файл, чтобы не поднимать IPC ради двух чисел.
    function saveStatus() {
        if (!nm.statusReady) return
        nm.statusFile.setText("dnd=" + (nm.dnd ? 1 : 0) + "\ncount=" + nm.count + "\n")
    }

    property FileView statusFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/lunar/notif-status"
        printErrors: false
        onLoaded: { nm.statusReady = true; nm.saveStatus() }
        onLoadFailed: { nm.statusReady = true; nm.saveStatus() }
    }

    property bool statusReady: false

    function copy(summary, body) {
        var s = String(summary || "")
        var b = String(body || "")
        Quickshell.execDetached(["wl-copy", b !== "" ? s + "\n" + b : s])
    }

    function setSize(v) {
        nm.menuSize = Math.max(60, Math.min(200, Math.round(v)))
        nm.stateTimer.restart()
    }

    function setPos(p) {
        nm.pos = p
        nm.stateTimer.restart()
    }

    function cyclePos() {
        var order = ["tr", "br", "bl", "tl"]
        var i = order.indexOf(nm.pos)
        nm.setPos(order[(i + 1) % order.length])
    }

    // ── сохранение состояния (DND/размер/позиция) ───────────────
    property Timer stateTimer: Timer {
        interval: 300
        onTriggered: nm.saveState()
    }

    function saveState() {
        if (!nm.stateReady) return
        nm.stateFile.setText(JSON.stringify({
            dnd: nm.dnd,
            menuSize: nm.menuSize,
            pos: nm.pos
        }))
    }

    property FileView stateFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/state/notifications-state.json"
        printErrors: false
        onLoaded: {
            try {
                var s = JSON.parse(text())
                if (typeof s.dnd === "boolean") nm.dnd = s.dnd
                if (typeof s.menuSize === "number")
                    nm.menuSize = Math.max(60, Math.min(200, Math.round(s.menuSize)))
                if (typeof s.pos === "string" && s.pos !== "") nm.pos = s.pos
            } catch (e) {
                console.warn("[NotifModel] состояние не прочитано: " + e)
            }
            nm.stateReady = true
        }
        onLoadFailed: nm.stateReady = true
    }

    // ── история на диск ────────────────────────────────────────
    property Timer historyTimer: Timer {
        interval: 400
        onTriggered: nm.saveHistory()
    }

    function saveHistory() {
        if (!nm.historyReady) return
        var out = []
        for (var i = 0; i < nm.history.length; i++) {
            var e = nm.history[i]
            out.push({
                summary: e.summary,
                body: e.body,
                appName: e.appName,
                appIcon: e.appIcon,
                image: e.image,
                urgency: e.urgency,
                time: e.time
            })
        }
        nm.historyFile.setText(JSON.stringify(out))
    }

    property FileView historyFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/lunar/notifications.json"
        printErrors: false
        onLoaded: {
            try {
                var arr = JSON.parse(text())
                if (Array.isArray(arr) && nm.history.length === 0) {
                    nm.history = arr
                    // раздаю отрицательные id заново (после перезапуска)
                    nm.hidSeq = 0
                    for (var i = 0; i < nm.history.length; i++)
                        nm.history[i].hid = nm.nextHid()
                }
            } catch (e) {
                console.warn("[NotifModel] история не прочитана: " + e)
            }
            nm.historyReady = true
            nm.rebuild()
        }
        onLoadFailed: nm.historyReady = true
    }
}
