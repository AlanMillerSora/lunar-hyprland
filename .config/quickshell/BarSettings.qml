pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ════════════════════════════════════════════════════════════════
//  BarSettings — персистентные настройки бара: состав, порядок и
//  видимость ячеек по зонам (левая / центр / правая) плюс число
//  значков трея. Живут в ~/.config/lunar/bar.json (FileView +
//  JsonAdapter). Вид (морф панели, токены) — по-прежнему в Theme,
//  состояния острова — в BarState; здесь только «что и в каком
//  порядке рисуем». Дефолт = текущий порядок, чтобы обновление
//  ничего не сдвигало.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: bar

    // ── каталог ячеек: id, зона, человекочитаемое имя. locked —
    //    ячейку нельзя скрыть (часы задают центровку строки). ──
    readonly property var catalog: [
        { id: "workspaces", zone: "left",   name: "Фазы столов" },
        { id: "perf",       zone: "left",   name: "PERF" },
        { id: "media",      zone: "center", name: "Медиа · полоса" },
        { id: "clock",      zone: "center", name: "Часы и дата", locked: true },
        { id: "network",    zone: "center", name: "Сеть ↓" },
        { id: "weather",    zone: "center", name: "Погода" },
        { id: "game",       zone: "right",  name: "Game Mode" },
        { id: "layout",     zone: "right",  name: "Раскладка" },
        { id: "tray",       zone: "right",  name: "Трей" },
        { id: "notifs",     zone: "right",  name: "Уведомления" },
        { id: "volume",     zone: "right",  name: "Звук" },
        { id: "system",     zone: "right",  name: "Ресурсы CPU·RAM·GPU" }
    ]

    // ── флаги состояния файла: как в Theme.uiState — не затираем
    //    битый файл дефолтами и не гоним запись на эхо от загрузки ──
    property bool ready: false
    property bool loading: false
    property bool writeBlocked: false
    property bool internal: false
    property bool pendingWrite: false

    // число значков трея в баре (arch: до 3 видимых, лишние — «+N»)
    property int trayVisible: 3

    // ── горячие зоны у краёв бара → сайдбары по ховеру ──
    //   hotZone: включать ли ховер-раскрытие;
    //   revealIn: сколько держать курсор на краю до раскрытия (мс);
    //   revealOut: сколько держать после ухода до закрытия (мс).
    property bool hotZone: true
    property int revealIn: 220
    property int revealOut: 600

    // ── метаданные ячеек ──
    function meta(id) {
        for (var i = 0; i < catalog.length; i++)
            if (catalog[i].id === id)
                return catalog[i]
        return null
    }
    function nameOf(id) { var m = meta(id); return m ? m.name : id }
    function isLocked(id) { var m = meta(id); return !!(m && m.locked) }

    // ── копия списка ячеек в обычный JS-массив (адаптер отдаёт
    //    QVariantList — так с ним безопасно работать) ──
    function copyList(v) {
        var out = []
        if (v)
            for (var i = 0; i < v.length; i++) {
                var it = v[i]
                if (it && typeof it === "object")
                    out.push({ id: String(it.id), visible: it.visible !== false })
                else
                    out.push({ id: String(it), visible: true })
            }
        return out
    }

    // дефолтный порядок зоны = порядок каталога
    function defaults(zone) {
        var out = []
        for (var i = 0; i < catalog.length; i++)
            if (catalog[i].zone === zone)
                out.push({ id: catalog[i].id, visible: true })
        return out
    }

    // привести список к каталогу: выкинуть неизвестные id и дубли,
    // дописать появившиеся новые ячейки в конец; locked всегда видимы
    function sanitize(zone, raw) {
        var def = defaults(zone)
        var known = {}
        for (var i = 0; i < def.length; i++)
            known[def[i].id] = true
        var seen = {}
        var out = []
        var src = copyList(raw)
        for (var j = 0; j < src.length; j++) {
            var id = src[j].id
            if (!known[id] || seen[id])
                continue
            seen[id] = true
            out.push({ id: id, visible: bar.isLocked(id) ? true : src[j].visible })
        }
        for (var k = 0; k < def.length; k++)
            if (!seen[def[k].id])
                out.push({ id: def[k].id, visible: true })
        return out
    }

    function sameList(a, b) {
        if (a.length !== b.length)
            return false
        for (var i = 0; i < a.length; i++)
            if (a[i].id !== b[i].id
                || (a[i].visible !== false) !== (b[i].visible !== false))
                return false
        return true
    }

    function getItems(zone) {
        if (zone === "left") return adapter.left
        if (zone === "center") return adapter.center
        return adapter.right
    }
    function setItems(zone, v) {
        // правка пользователя/нормализация: битый файл больше не держим —
        // следующая запись восстановит bar.json из текущего состояния
        writeBlocked = false
        if (zone === "left") adapter.left = v
        else if (zone === "center") adapter.center = v
        else adapter.right = v
    }

    function adoptZone(zone) {
        if (writeBlocked || internal)
            return
        var cur = copyList(getItems(zone))
        var norm = sanitize(zone, cur)
        if (!sameList(cur, norm)) {
            bar.internal = true
            setItems(zone, norm)
            bar.internal = false
        }
    }
    function adoptAll() {
        adoptZone("left")
        adoptZone("center")
        adoptZone("right")
    }

    // ── текущие списки (реактивные): всё для UI ──
    readonly property var left: adapter.left
    readonly property var center: adapter.center
    readonly property var right: adapter.right

    function filterVisible(v) {
        var src = copyList(v)
        var out = []
        for (var i = 0; i < src.length; i++)
            if (src[i].visible)
                out.push(src[i])
        return out
    }
    function listFor(zone) {
        if (zone === "left") return bar.left
        if (zone === "center") return bar.center
        return bar.right
    }
    // ── только видимые, в порядке отрисовки: для зон бара ──
    readonly property var leftVisible: filterVisible(adapter.left)
    readonly property var centerVisible: filterVisible(adapter.center)
    readonly property var rightVisible: filterVisible(adapter.right)

    // ── правки из UI ──
    function move(zone, id, dir) {
        var list = copyList(getItems(zone))
        var i = -1
        for (var k = 0; k < list.length; k++)
            if (list[k].id === id) { i = k; break }
        if (i < 0)
            return
        var j = i + dir
        if (j < 0 || j >= list.length)
            return
        var t = list[i]
        list[i] = list[j]
        list[j] = t
        setItems(zone, list)
    }

    function toggle(zone, id) {
        if (isLocked(id))
            return
        var list = copyList(getItems(zone))
        for (var k = 0; k < list.length; k++)
            if (list[k].id === id) {
                list[k] = { id: id, visible: !list[k].visible }
                break
            }
        setItems(zone, list)
    }

    function resetZone(zone) { setItems(zone, defaults(zone)) }
    function resetAll() {
        bar.internal = true
        setItems("left", defaults("left"))
        setItems("center", defaults("center"))
        setItems("right", defaults("right"))
        bar.internal = false
        bar.trayVisible = 3
        bar.hotZone = true
        bar.revealIn = 220
        bar.revealOut = 600
    }

    onTrayVisibleChanged: if (!internal) adapter.trayVisible = trayVisible
    onHotZoneChanged: if (!internal) adapter.hotZone = hotZone
    onRevealInChanged: if (!internal) adapter.revealIn = revealIn
    onRevealOutChanged: if (!internal) adapter.revealOut = revealOut

    // досылаю нормализованное состояние, если правка adapter'а пришлась
    // на загрузку файла (watch-перезагрузка не всегда даёт onLoaded)
    function flush() {
        if (ready && !writeBlocked && pendingWrite) {
            pendingWrite = false
            file.writeAdapter()
        }
    }
    property Timer flushTimer: Timer {
        interval: 80
        onTriggered: bar.flush()
    }

    // ── файл настроек ──
    property FileView state: FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/lunar/bar.json"
        watchChanges: true
        atomicWrites: true

        onFileChanged: { bar.loading = true; reload() }

        onAdapterUpdated: {
            if (bar.writeBlocked)
                return
            if (bar.ready && !bar.loading) {
                bar.pendingWrite = false
                writeAdapter()
            } else {
                bar.pendingWrite = true
                bar.flushTimer.restart()
            }
        }

        onLoaded: {
            bar.loading = false
            var raw = file.text()
            var healthy = true
            if (raw && raw.trim() !== "") {
                try {
                    JSON.parse(raw)
                } catch (e) {
                    healthy = false
                }
            }
            if (!healthy) {
                bar.writeBlocked = true
                bar.ready = true
                console.warn("[BarSettings] bar.json повреждён — не перезаписываю, копия .bak")
                Quickshell.execDetached(["cp", "-f", file.path, file.path + ".bak"])
                return
            }
            bar.ready = true
            bar.writeBlocked = false
            bar.adoptAll()
            if (bar.pendingWrite && !bar.writeBlocked) {
                bar.pendingWrite = false
                writeAdapter()
            }
        }

        onLoadFailed: (error) => {
            bar.loading = false
            if (error === FileViewError.FileNotFound) {
                // файла ещё нет — наливаю дефолты (текущий порядок) и сохраняю
                bar.ready = true
                bar.internal = true
                adapter.left = bar.defaults("left")
                adapter.center = bar.defaults("center")
                adapter.right = bar.defaults("right")
                bar.internal = false
                bar.pendingWrite = false
                writeAdapter()
            } else {
                bar.writeBlocked = true
                bar.ready = true
                console.warn("[BarSettings] bar.json не прочитан: " + FileViewError.toString(error))
                Quickshell.execDetached(["cp", "-f", file.path, file.path + ".bak"])
            }
        }

        JsonAdapter {
            id: adapter
            property var left: bar.defaults("left")
            property var center: bar.defaults("center")
            property var right: bar.defaults("right")
            property int trayVisible: 3
            property bool hotZone: true
            property int revealIn: 220
            property int revealOut: 600

            onLeftChanged: bar.adoptZone("left")
            onCenterChanged: bar.adoptZone("center")
            onRightChanged: bar.adoptZone("right")
            onTrayVisibleChanged: {
                if (bar.internal)
                    return
                bar.internal = true
                bar.trayVisible = trayVisible
                bar.internal = false
            }
            onHotZoneChanged: {
                if (bar.internal)
                    return
                bar.internal = true
                bar.hotZone = hotZone
                bar.internal = false
            }
            onRevealInChanged: {
                if (bar.internal)
                    return
                bar.internal = true
                bar.revealIn = revealIn
                bar.internal = false
            }
            onRevealOutChanged: {
                if (bar.internal)
                    return
                bar.internal = true
                bar.revealOut = revealOut
                bar.internal = false
            }
        }
    }
}
