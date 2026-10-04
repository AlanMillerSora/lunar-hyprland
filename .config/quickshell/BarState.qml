pragma Singleton
import QtQuick

// ════════════════════════════════════════════════════════════════
//  BarState — состояния острова бара: какой режим открыт, пульсовый он
//  или ручной, сколько держать до авто-закрытия и где курсор. Вид
//  (морф, размеры, контент) живёт в LunarPanel и реагирует на изменения.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: bar

    property string mode: ""            // "" | control | media | search | notifs | sys | weather
    readonly property bool expanded: mode !== ""
    // приоритеты: кто открыл (ручной клик важнее пульса) и сколько держать
    property bool isPulse: false
    property int holdMs: 0
    // пока курсор на баре или панели — остров «пришпилен», таймер не закрывает
    property bool barHovered: false
    property bool panelHovered: false
    readonly property bool pinned: barHovered || panelHovered
    // игра: пульсовые острова не всплывают (синхронизируется из LunarPanel)
    property bool gameMode: false

    // ── пузырь в полосе бара: погода/медиа.
    // Клик по ячейке теперь раскрывает САМУ плашку вниз (режимы
    // weather/media), поэтому отдельного «пузыря в полке» больше нет.
    // Оставляю эти имена как алиасы на режим — чтобы хоткеи/IPC и старые
    // вызовы работали как раньше, но вели к морфу, а не к боковому пузырю.
    property string bubble: ""
    // экранные координаты ячейки-источника — исторические, больше не нужны
    property real bubbleX: 0
    property real bubbleY: 0
    // legacy: открыть погоду/медиа как режим-морф плашки
    function openBubble(name, x, y) {
        bar.openPanel(name)
    }
    function toggleBubble(name, x, y) {
        bar.togglePanel(name)
    }
    function closeBubble() {}

    property Timer holdTimer: Timer {
        repeat: false
        onTriggered: if (!bar.pinned) bar.deactivate()
    }
    // Пульсы событий (звук/трек/уведомления) открывают нужный остров сами.
    // holdMs>0 — авто-закрытие (пока курсор не на баре/панели — hover-pin).
    function activate(name, ms) {
        if (name === "") { bar.deactivate(); return }
        if ((ms || 0) > 0 && bar.gameMode)
            return
        // тот же остров уже открыт: пульсовый продлеваю, ручной — не трогаю
        if (bar.mode === name) {
            if (bar.isPulse) {
                bar.holdMs = ms || 0
                bar.restartHold()
            }
            return
        }
        // другой остров открыт вручную — клик пользователя важнее пульса
        if (bar.expanded && !bar.isPulse)
            return
        bar.isPulse = true
        bar.holdMs = ms || 0
        bar.mode = name
        bar.restartHold()
    }
    function restartHold() {
        holdTimer.stop()
        if (bar.holdMs > 0 && !bar.pinned) {
            holdTimer.interval = bar.holdMs
            holdTimer.restart()
        }
    }
    function deactivate() {
        holdTimer.stop()
        bar.holdMs = 0
        bar.isPulse = false
        bar.mode = ""
    }
    // ручное открытие — высокий приоритет, без авто-закрытия
    function openPanel(name) { bar.holdMs = 0; bar.isPulse = false; bar.mode = name }
    function closePanel() { bar.deactivate() }
    function togglePanel(name) {
        if (bar.mode === name) { bar.deactivate(); return }
        bar.openPanel(name)
    }
    onPinnedChanged: {
        if (bar.pinned)
            holdTimer.stop()
        else if (bar.holdMs > 0)
            bar.restartHold()
    }
}
