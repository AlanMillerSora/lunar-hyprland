pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    // ── палитра ──────────────────────────────────────────────
    // Цвета приходят из ~/.cache/lunar/palette.json (генератор
    // eclipse-palette.py, пресеты lunar/graphite/steel). Если файла нет —
    // работают прежние значения риса: шелл не зависит от генератора.
    property var palette: ({})

    // hex → color; понимаю и #RRGGBBAA (палитра пишет альфу в конце),
    // потому что Qt в такой строке ждёт #AARRGGBB и перепутает каналы
    function hexColor(h, fallback) {
        if (typeof h !== "string" || h.length < 7)
            return fallback
        var r = parseInt(h.substr(1, 2), 16) / 255
        var g = parseInt(h.substr(3, 2), 16) / 255
        var b = parseInt(h.substr(5, 2), 16) / 255
        var a = h.length >= 9 ? parseInt(h.substr(7, 2), 16) / 255 : 1
        return Qt.rgba(r, g, b, a)
    }

    // холодный уголь вместо чистого чёрного: мягче на глаз, но всё ещё монохром.
    // Базовая альфа ниже единицы — поверх стекла Hyprland панели «дышат»,
    // а ползунок прозрачности по-прежнему множит её сверху (L43).
    readonly property color _bgBase: hexColor(palette.bg, Qt.rgba(8 / 255, 9 / 255, 13 / 255, 1))
    readonly property color _bgPanelBase: hexColor(palette.bgPanel, Qt.rgba(12 / 255, 14 / 255, 19 / 255, 1))
    readonly property color _bgCardBase: hexColor(palette.bgCard, Qt.rgba(18 / 255, 21 / 255, 27 / 255, 1))
    readonly property color _barPillBase: hexColor(palette.barPill, Qt.rgba(12 / 255, 14 / 255, 19 / 255, 1))
    property color bg: Qt.rgba(_bgBase.r, _bgBase.g, _bgBase.b, 0.72 * interfaceOpacity)
    property color bgPanel: Qt.rgba(_bgPanelBase.r, _bgPanelBase.g, _bgPanelBase.b, 0.78 * interfaceOpacity)
    property color bgCard: Qt.rgba(_bgCardBase.r, _bgCardBase.g, _bgCardBase.b, 0.62 * interfaceOpacity)

    // рамки — не линии, а намёк: белый на малых альфах (раньше был #1e1e1e)
    property color border: hexColor(palette.border, Qt.rgba(1, 1, 1, 0.08))
    property color borderAccent: hexColor(palette.borderAccent, Qt.rgba(1, 1, 1, 0.16))

    property color text: hexColor(palette.text, "#e8ecf2")
    property color textDim: hexColor(palette.textDim, "#98a1ac")
    property color textFaint: hexColor(palette.textFaint, "#5b636d")

    property color accent: hexColor(palette.accent, "#e8edf4")
    property color accent2: hexColor(palette.accent2, "#e8edf4")
    property color danger: hexColor(palette.danger, "#ff003c")
    property color ok: hexColor(palette.ok, "#00ff9c")

    property color trackBg: hexColor(palette.bgTrack, "#181b21")

    // ── панель-бар: чуть мягче и холоднее общего текста (правил отдельно,
    //    чтобы не выцветал текст оверлеев) ──
    property color barText: hexColor(palette.barText, "#d5dce4")
    property color barDim: hexColor(palette.barDim, "#a6aeb9")
    property color barFaint: hexColor(palette.barFaint, "#5b636d")
    property color barPill: Qt.rgba(_barPillBase.r, _barPillBase.g, _barPillBase.b, 1.0 * interfaceOpacity)

    // ── токены «ритма» интерфейса (Hub и панели) ──
    property color hover: Qt.rgba(accent.r, accent.g, accent.b, 0.07)        // наведение: строки, карточки
    property color hoverStrong: Qt.rgba(accent.r, accent.g, accent.b, 0.10)  // наведение: кнопки, чипы
    property color active: Qt.rgba(accent.r, accent.g, accent.b, 0.14)       // выбранное/включённое
    property color fill: Qt.rgba(text.r, text.g, text.b, 0.04)               // покой (фон карточек/строк)

    // палитру переписывает генератор; watchChanges подхватит на лету
    property FileView paletteFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/lunar/palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                var t = text()
                theme.palette = (t && t.trim() !== "") ? JSON.parse(t) : ({})
            } catch (e) {
                console.warn("[Theme] палитра не прочитана: " + e)
                theme.palette = ({})
            }
        }
    }

    // Раньше стояло "JetBrains Mono" — такого семейства в системе нет
    // (ставится только JetBrainsMono Nerd Font), и Qt молча подставлял
    // Noto Sans Mono. Беру Iosevka NFM: узкая, тонкая, кириллица полная,
    // есть все веса. Иконки остаются на JetBrainsMono NF.
    property string fontFamily: "Iosevka Nerd Font Mono"
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

    // плеер: окно открыто и активная страница. Живёт в Theme, потому что
    // оверлей разбит на две поверхности (подложка LunarPlayer + карточка
    // LunarPlayerCard) и им нужен общий маленький стейт.
    property bool playerOpen: false
    property int playerPage: 0

    // Радиусы: мелкое — 8, среднее — 10, крупные поверхности (Hub, сайдбары) — 12
    property int radius: 8
    property int radiusM: 10
    property int radiusL: 12

    // ── ритм интерфейса ──────────────────────────────────────────
    // Всё, что раньше было «магическими числами» по файлам, свожу сюда:
    // отступы, высоты строк, шкала текста, геометрия панели. Меняем тут —
    // меняется весь рис разом (этап «воздух»).
    property int space1: 4
    property int space2: 8
    property int space3: 12
    property int space4: 16
    property int space5: 24
    property int space6: 32

    property int rowHCompact: 34
    property int rowH: 42
    property int rowHComfy: 48
    property int headerH: 44

    property int fontTiny: 11
    property int fontSmall: 12
    property int fontBody: 14
    property int fontTitle: 22
    property int fontClock: 16

    // панель-острова (этап 1): высота плашки, зазоры, поля, отступ внутри
    property int barH: 36
    property int barMargin: 8
    property int barPad: 12
    property int barRadius: 8

    // мягкая реакция на наведение — масштаб глифа, без переверстки
    property real hoverGrow: 1.25

    // сколько значков трея видно в панели (остальные — в списке «+N»)
    property int trayVisible: 2

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
            property int trayVisible: 2
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

    // зажимаю значение в диапазон — для адаптивных размеров окна
    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }
}
