pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    property color bg: Qt.rgba(0, 0, 0, 0.85 * interfaceOpacity)
    // панель и карточки тоже реагируют на ползунок прозрачности (L43)
    property color bgPanel: Qt.rgba(5 / 255, 5 / 255, 5 / 255, interfaceOpacity)
    property color bgCard: Qt.rgba(13 / 255, 13 / 255, 13 / 255, interfaceOpacity)
    property color border: "#1e1e1e"
    property color borderAccent: "#2a2a2a"

    property color text: "#ffffff"
    property color textDim: "#888888"
    property color textFaint: "#4a4a4a"

    property color accent: "#ffffff"
    property color accent2: "#ffffff"
    property color danger: "#ff003c"
    property color ok: "#00ff9c"

    property color trackBg: "#161616"

    // ── токены «ритма» интерфейса (Hub и панели) ──
    property color hover: Qt.rgba(accent.r, accent.g, accent.b, 0.06)        // наведение: строки, карточки
    property color hoverStrong: Qt.rgba(accent.r, accent.g, accent.b, 0.08)  // наведение: кнопки, чипы
    property color active: Qt.rgba(accent.r, accent.g, accent.b, 0.12)       // выбранное/включённое
    property color fill: Qt.rgba(text.r, text.g, text.b, 0.03)               // покой (фон карточек/строк)

    property string fontFamily: "JetBrains Mono"
    property string iconFont: "JetBrainsMono Nerd Font"

    property real interfaceOpacity: 1.0
    property real fontScale: 1.0

    // живые обои (QML-сцена): false — «лёгкий режим» без звёзд/метеоров/пыли
    property bool wallpaperLive: true

    // Производительность: единственный облегчённый режим (см. eclipse-perf.sh
    // и LunarWallpaper). Пресеты NORMAL/OPTIMIZE убраны.

    // Блюр (Hub → Interface): size 0..12 и число проходов.
    //   -1 = пользователь ещё не трогал — рулит облегчённый пресет
    // (eclipse-perf.sh). Как только выставлено — значение переживает
    // hyprctl reload и перезапуск шелла: ползунок главнее пресета.
    property int blurSize: -1
    property int blurPasses: 3

    // попап громкости открыт — центральный OSD не показываем (без дубля)
    property bool volumePopupOpen: false

    // Единый радиус системы — как у карточки Hub
    property int radius: 6
    property int radiusM: 6
    property int radiusL: 6

    // сколько значков трея видно в панели (остальные — в списке «+N»)
    property int trayVisible: 3

    // тултип панели: панель выставляет, LunarTooltip показывает
    property bool tooltipShown: false
    property string tooltipText: ""
    property real tooltipX: 0

    property int animFast: 120
    property int animMed: 220
    property int animSlow: 380

    // активный модальный оверлей ("hub" | "agent"): открытие одного
    // закрывает другой, плавно и в одном процессе (без внешнего qs ipc)
    property string activeOverlay: ""

    // ─────────── персистентность UI-настроек ───────────
    // Прозрачность интерфейса, масштаб шрифта и число значков трея
    // сохраняются между перезапусками Quickshell.
    property bool uiReady: false        // первичная загрузка файла завершена
    property bool uiLoading: false      // идёт загрузка/перезагрузка (защита от эха, L42)
    property bool uiInternal: false     // изменение пришло из файла, а не от пользователя
    property bool uiWriteBlocked: false // файл битый — не затираем его дефолтами (M73)
    property bool uiPersistPending: false // UI-правка ждёт окончания загрузки
    property string uiError: ""         // диагностика чтения настроек

    // пометить изменение как пользовательское и запланировать запись
    function markUI() {
        uiWriteBlocked = false
        uiPersistPending = true
    }

    property FileView uiState: FileView {
        id: uiFile
        path: Quickshell.statePath("lunar-ui.json")
        watchChanges: true
        atomicWrites: true

        onFileChanged: { theme.uiLoading = true; reload() }
        onAdapterUpdated: {
            if (theme.uiReady && !theme.uiLoading && !theme.uiWriteBlocked) {
                theme.uiPersistPending = false
                writeAdapter()
            }
        }
        onLoaded: {
            theme.uiLoading = false
            // адаптер о битом JSON молчит и оставляет дефолты, поэтому
            // проверяем содержимое сами и не затираем файл (M73)
            var raw = uiFile.text()
            var healthy = true
            if (raw && raw.trim() !== "") {
                try {
                    JSON.parse(raw)
                } catch (e) {
                    healthy = false
                }
            }
            if (!healthy) {
                theme.uiError = "настройки не прочитаны: повреждён JSON"
                console.warn("[Theme] " + theme.uiError + " — файл сохранён в .bak, дефолты не записываются")
                theme.uiWriteBlocked = true
                theme.uiReady = true
                Quickshell.execDetached(["cp", "-f", theme.uiState.path,
                                         theme.uiState.path + ".bak"])
                return
            }
            theme.uiReady = true
            theme.uiError = ""
            // правка, пришедшая во время загрузки, станет финальным значением
            if (theme.uiPersistPending) {
                theme.uiPersistPending = false
                writeAdapter()
            }
        }
        onLoadFailed: (error) => {
            theme.uiLoading = false
            if (error === FileViewError.FileNotFound) {
                // файла ещё нет — создаём с текущими значениями
                theme.uiReady = true
                writeAdapter()
            } else {
                // битый/нечитаемый файл: сохраняем копию и не затираем
                // его дефолтами молча — ошибка видна в Theme.uiError (M73)
                theme.uiError = "настройки не прочитаны: " + FileViewError.toString(error)
                console.warn("[Theme] " + theme.uiError + " — файл сохранён в .bak, дефолты не записываются")
                theme.uiWriteBlocked = true
                theme.uiReady = true
                Quickshell.execDetached(["cp", "-f", theme.uiState.path,
                                         theme.uiState.path + ".bak"])
            }
        }

        JsonAdapter {
            id: uiAdapter
            property real interfaceOpacity: 1.0
            property real fontScale: 1.0
            property int trayVisible: 3
            property bool wallpaperLive: true
            property int blurSize: -1
            property int blurPasses: 3

            // файл → UI (в uiInternal, чтобы не писать назад прочитанное)
            onInterfaceOpacityChanged: { theme.uiInternal = true; theme.interfaceOpacity = interfaceOpacity; theme.uiInternal = false }
            onFontScaleChanged: { theme.uiInternal = true; theme.fontScale = fontScale; theme.uiInternal = false }
            onTrayVisibleChanged: { theme.uiInternal = true; theme.trayVisible = trayVisible; theme.uiInternal = false }
            onWallpaperLiveChanged: { theme.uiInternal = true; theme.wallpaperLive = wallpaperLive; theme.uiInternal = false }
            onBlurSizeChanged: { theme.uiInternal = true; theme.blurSize = blurSize; theme.uiInternal = false }
            onBlurPassesChanged: { theme.uiInternal = true; theme.blurPasses = blurPasses; theme.uiInternal = false }
        }
    }

    // UI → файл. Пишем только настоящие действия пользователя: загрузка
    // из файла идёт через uiInternal и сюда не попадает (H27, L42).
    onInterfaceOpacityChanged: if (!uiInternal) { markUI(); uiAdapter.interfaceOpacity = interfaceOpacity }
    onFontScaleChanged: if (!uiInternal) { markUI(); uiAdapter.fontScale = fontScale }
    onTrayVisibleChanged: if (!uiInternal) { markUI(); uiAdapter.trayVisible = trayVisible }
    onWallpaperLiveChanged: if (!uiInternal) { markUI(); uiAdapter.wallpaperLive = wallpaperLive }
    onBlurSizeChanged: {
        if (!uiInternal) { markUI(); uiAdapter.blurSize = blurSize }
        blurApply.restart()
    }
    onBlurPassesChanged: {
        if (!uiInternal) { markUI(); uiAdapter.blurPasses = blurPasses }
        blurApply.restart()
    }

    // Ползунок блюра: применяем с задержкой — size и passes могут прийти
    // по очереди (загрузка сохранённого состояния, перетаскивание).
    property Timer blurApply: Timer {
        id: blurApply
        interval: 60
        onTriggered: theme.applyBlur()
    }

    // Применить текущий блюр к Hyprland (ползунок Hub → Interface).
    // size = 0 выключает блюр. Если пользователь ещё не выставлял
    // значение (blurSize < 0) — не трогаем, рулит пресет.
    function applyBlur() {
        if (blurSize < 0)
            return
        var size = Math.max(0, Math.min(12, blurSize))
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({decoration = {blur = {enabled = " + (size > 0)
            + ", size = " + size + ", passes = " + Math.max(1, blurPasses) + "}}})"])
    }

    // Выставить и запомнить блюр (ползунок Hub → Interface). Пресет
    // Пресеты NORMAL/OPTIMIZE убраны: пресет сюда не пишет — иначе он
    // затирал бы выбор пользователя.
    // Сам вызов hyprctl делает blurApply (см. выше).
    function setBlur(size, passes) {
        blurSize = size
        blurPasses = passes
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function fontSize(base) {
        return Math.round(base * fontScale)
    }
}
