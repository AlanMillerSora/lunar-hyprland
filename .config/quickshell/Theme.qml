pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    // ── палитра ──────────────────────────────────────────────
    // Цвета приходят из ~/.cache/lunar/palette.json (генератор
    // eclipse-palette.py, пресеты lunar/steel/photo). Если файла нет —
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
    property color bgPanel: Qt.rgba(_bgPanelBase.r, _bgPanelBase.g, _bgPanelBase.b, 0.80 * interfaceOpacity)
    property color bgCard: Qt.rgba(_bgCardBase.r, _bgCardBase.g, _bgCardBase.b, 0.62 * interfaceOpacity)

    // рамки — не линии, а намёк: белый на малых альфах (раньше был #1e1e1e)
    property color border: hexColor(palette.border, Qt.rgba(1, 1, 1, 0.08))
    property color borderAccent: hexColor(palette.borderAccent, Qt.rgba(1, 1, 1, 0.16))

    property color text: hexColor(palette.text, "#e8ecf2")
    property color textDim: hexColor(palette.textDim, "#98a1ac")
    property color textFaint: hexColor(palette.textFaint, "#7b838d")

    property color accent: hexColor(palette.accent, "#e8edf4")
    property color accent2: hexColor(palette.accent2, "#e8edf4")
    property color danger: hexColor(palette.danger, "#ff003c")
    property color ok: hexColor(palette.ok, "#e8edf4")   // без зелёного: «ок» — светлый

    property color trackBg: hexColor(palette.bgTrack, "#181b21")

    // ── панель-бар: чуть мягче и холоднее общего текста (правил отдельно,
    //    чтобы не выцветал текст оверлеев) ──
    readonly property color barText: hexColor(palette.barText, "#d5dce4")
    readonly property color barDim: hexColor(palette.barDim, "#a6aeb9")
    readonly property color barFaint: hexColor(palette.barFaint, "#7b838d")
    // тон как у окна Hub (Theme.alpha(surfaceSolid, 0.80)); альфу бара держу
    // на уровне Hub и панелей (bgPanel 0.80) — стекло читается одинаково
    readonly property color barPill: Qt.rgba(_barPillBase.r, _barPillBase.g, _barPillBase.b, (arch ? 0.90 : 0.80) * interfaceOpacity)
    // наведённое состояние поверхности (сайдбары/Hub): тот же тон, чуть светлее.
    // Производная от палитры — меняются обои, меняется и он.
    readonly property color barPillHover: Qt.rgba(
        Math.min(1, _barPillBase.r + 0.045),
        Math.min(1, _barPillBase.g + 0.045),
        Math.min(1, _barPillBase.b + 0.045),
        (arch ? 0.93 : 0.88) * interfaceOpacity)

    // ── arch-слой «островов»: подложки в НЕЙТРАЛИ (тон обоев/окна ~#171A1B),
    //    чтобы бар читался единым тоном с системой, а не «стальным» тёмным.
    //    Акцент здесь только у активного состояния (surfaceActive).
    readonly property color surface: Qt.rgba(23 / 255, 26 / 255, 27 / 255, 0.80)
    readonly property color surfaceSolid: Qt.rgba(23 / 255, 26 / 255, 27 / 255, 1)
    readonly property color surfaceHover: Qt.rgba(30 / 255, 34 / 255, 35 / 255, 0.94)
    readonly property color surfaceActive: Qt.rgba(text.r, text.g, text.b, 0.10)

    // ── семантические поверхности (T20) ──────────────────────────
    // Компонент читает роль, а не сырой токен палитры. Значения — ровно
    // те, что стоят в прежних токенах, поэтому визуал не съезжает:
    //   surfacePanel — подложка панелей/оверлеев (бывш. bgPanel);
    //   surfaceCard  — подложка карточек/контролов (бывш. surface).
    // surfaceHover/surfaceActive/surfaceSolid уже семантические — оставляю.
    readonly property color surfacePanel: bgPanel
    readonly property color surfaceCard: surface

    readonly property color border2: Qt.rgba(text.r, text.g, text.b, 0.10)
    // непрозрачный цвет фона — для текста поверх акцента (выделение и т.п.);
    // Theme.bg полупрозрачен и на плашке выделения читался бы неровно
    property color onAccent: _bgBase

    // ── токены «ритма» интерфейса (Hub и панели) ──
    property color hover: Qt.rgba(accent.r, accent.g, accent.b, 0.07)        // наведение: строки, карточки
    property color hoverStrong: Qt.rgba(accent.r, accent.g, accent.b, 0.10)  // наведение: кнопки, чипы
    property color active: Qt.rgba(accent.r, accent.g, accent.b, 0.14)       // выбранное/включённое
    property color activeBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.5)  // рамка выбранного
    property color fill: Qt.rgba(text.r, text.g, text.b, 0.04)               // покой (фон карточек/строк)
    // подсветка ячейки бара на наведении: в architect её нет (плоский носитель)
    readonly property color cellHoverBg: arch ? "transparent" : hoverStrong
    // линия-разделитель в сайдбарах: в architect — акцентная волосинка
    readonly property color dividerLine: arch ? hairAccent : border

    // ── карточки панелей: подложка чуть контрастнее строк + рамка ──
    property color cardBg: Qt.rgba(text.r, text.g, text.b, 0.055)

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
                // синхронизирую «стоит фото» с фактическим файлом
                theme.photoActive = (theme.palette.preset === "photo")
            } catch (e) {
                console.warn("[Theme] палитра не прочитана: " + e)
                theme.palette = ({})
            }
        }
    }

    // Roboto Mono: ровный машинописный моно, кириллица полная, все веса.
    // Семейство ставлю без «Nerd», иконки отдельно — JetBrainsMono NF,
    // так у 43PR и так надёжнее: Qt не подставляет чужой шрифт.
    property string fontFamily: "Roboto Mono"
    property string iconFont: "JetBrainsMono Nerd Font"

    property real interfaceOpacity: 1.0
    property real fontScale: 1.0

    // ── стиль-профиль (форма/мотив), ортогонален палитре ──
    // classic   — текущий вид риса;
    // architect — острее углы, технические линии, HUD-рамка.
    property string style: "classic"
    readonly property bool arch: style === "architect"

    // технические волосяные линии
    readonly property int line: 1
    readonly property int lineThick: 2
    readonly property color hair: Qt.rgba(text.r, text.g, text.b, 0.20)
    readonly property color hairFaint: Qt.rgba(text.r, text.g, text.b, 0.10)
    readonly property color hairAccent: Qt.rgba(accent.r, accent.g, accent.b, 0.62)

    // HUD-рамка (скобки/насечки)
    readonly property int hudCornerSize: 14
    readonly property int hudCornerThickness: 1
    readonly property int hudCornerInset: 8
    readonly property real hudCornerOpacity: 0.35
    readonly property int hudTickGap: 6
    readonly property int hudTickH: 4

    // ── производные токены профиля ───────────────────────────────
    // Рендер не выбирает «arch или нет» сам: все ветвления профиля
    // собраны здесь, компоненты читают готовое значение.
    // скобки HUD: "[ X ]" в architect, "X" в classic
    readonly property string hudBracketOpen: arch ? "[ " : ""
    readonly property string hudBracketClose: arch ? " ]" : ""
    function hudBracket(s) { return hudBracketOpen + s + hudBracketClose }
    // HUD-скобки по углам: в architect крупнее и толще
    function hudCornerSizeFor(sz) { return arch ? sz * 1.4 : sz }
    function hudCornerThicknessFor(th) { return arch ? Math.max(2, th * 1.5) : th }

    // живые обои (QML-сцена): false — «лёгкий режим» без звёзд/метеоров/пыли
    property bool wallpaperLive: true

    // обои: "scene" — живая сцена затмения (фаза по столу), "image" — обычная картинка
    property string wallpaperMode: "scene"
    property string wallpaperPath: ""

    // авто-палитра из картинки обоев (наш «matugen»): считаю при смене обоев,
    // на «сцене» возвращаю пресет, который стоял до фотопалитры
    property bool wallpaperAuto: true
    // стоит ли сейчас именно фотопалитра. Держу синхронно: файл palette.json
    // читается асинхронно, и по нему можно не успеть вернуть пресет
    property bool photoActive: false

    // Считаю не на каждый кадр листания — вызов дорогой (ImageMagick), — а
    // когда выбор замер: дебаунс живёт в окне подбора обоев. Два прогона
    // разом не пускаю: пока считает — держу следующий интерес в очереди.
    property bool paletteBusy: false
    property string palettePending: ""

    property Process paletteProc: Process {
        id: paletteProc
        running: false
        onExited: (exitCode) => {
            theme.paletteBusy = false
            // приложения читают палитру сами: kitty — по USR1, mako — reload
            Quickshell.execDetached(["bash", "-c",
                "pidof kitty >/dev/null && kill -USR1 $(pidof kitty); makoctl reload 2>/dev/null; true"])
            if (theme.palettePending !== "") {
                var next = theme.palettePending
                theme.palettePending = ""
                theme.runPalette(next)
            }
        }
    }

    // kind: "photo:<путь>" — палитра из картинки; иначе — пресет до фотопалитры
    function runPalette(kind) {
        if (kind === "")
            return
        if (paletteBusy) {
            palettePending = kind
            return
        }
        var cmd
        if (kind.indexOf("photo:") === 0) {
            var p = kind.substring(6)
            var q = "'" + p.replace(/'/g, "'\\''") + "'"
            cmd = ["bash", "-c",
                "$HOME/.config/hypr/scripts/eclipse-palette.py --from-image " + q + " --apply >/dev/null"]
            photoActive = true
        } else if (kind.indexOf("preset:") === 0) {
            // ручной пресет из Hub: имя — только из букв/цифр/дефиса
            var pn = kind.substring(7)
            if (!/^[a-zA-Z0-9_-]+$/.test(pn))
                return
            cmd = ["bash", "-c",
                "$HOME/.config/hypr/scripts/eclipse-palette.py --preset " + pn + " --apply >/dev/null"]
            photoActive = false
        } else if (kind === "restore") {
            cmd = ["bash", "-c",
                "$HOME/.config/hypr/scripts/eclipse-palette.py --restore-preset --apply >/dev/null"]
            photoActive = false
        } else {
            return
        }
        paletteBusy = true
        paletteProc.command = cmd
        paletteProc.running = true
    }

    // из обоев — только если авто включено и режим действительно «картинка»
    // (иначе отложенный дебаунс вернёт фото уже на «сцене»)
    function applyPhotoPalette(path) {
        if (wallpaperAuto && wallpaperMode === "image" && path !== "")
            runPalette("photo:" + path)
    }

    // снимаю фотопалитру, если она стоит; иначе не трогаю ручной пресет.
    // Гейт по photoActive (а не по palette.json) — файл читается асинхронно,
    // и на этом была гонка; АВТО·ВЫКЛ тоже не мешает вернуть пресет
    function restoreScenePalette() {
        if (photoActive)
            runPalette("restore")
    }

    // ручной пресет из Hub (lunar/steel/photo) — через ту же очередь,
    // что и фото, чтобы прогоны не писали палитру одновременно
    function setPreset(name) {
        if (name !== "")
            runPalette("preset:" + name)
    }

    // Производительность: единственный облегчённый режим (см. eclipse-perf.sh
    // и LunarWallpaper). Пресеты NORMAL/OPTIMIZE убраны.

    // Блюр (Hub → Interface): size 0..12 и число проходов.
    //   -1 = пользователь ещё не трогал — рулит облегчённый пресет
    // (eclipse-perf.sh). Как только выставлено — значение переживает
    // hyprctl reload и перезапуск шелла: ползунок главнее пресета.
    property int blurSize: -1
    property int blurPasses: 3

    // попап громкости убран — звук живёт в панели бара (инлайн) и в Hub.

    // плеер: окно открыто и активная страница. Живёт в Theme, потому что
    // оверлей разбит на две поверхности (подложка LunarPlayer + карточка
    // LunarPlayerCard) и им нужен общий маленький стейт.
    property bool playerOpen: false
    property int playerPage: 0

    // Радиусы: мелкое — 12, среднее — 14, крупные поверхности (Hub, сайдбары) — 18.
    // classic смягчён (этап «форма»): мягкие крупные углы как у 43PR,
    // arch оставляю острым — профиль не трогаю.
    property int radius: arch ? 2 : 12
    property int radiusM: arch ? 3 : 14
    property int radiusL: arch ? 4 : 18
    // мелочь подэлементов: точки, пилюли, полоски-индикаторы. Точные
    // значения и без профиля: это геометрия самого элемента, а не поверхности,
    // поэтому arch её не заостряет — иначе поедут пиксели.
    property int radiusHair: 1   // волосинка: 2-3px полоски, разделители
    property int radiusDot: 2    // точки и мелкие пилюли 4-5px
    property int radiusChip: 3   // чипы/точки 5-8px
    property int radiusTile: 4   // мелкие плитки/иконки

    // ── ритм интерфейса ──────────────────────────────────────────
    // Всё, что раньше было «магическими числами» по файлам, свожу сюда:
    // отступы, высоты строк, шкала текста, геометрия панели. Меняем тут —
    // меняется весь рис разом (этап «воздух»).
    // «воздух» (B4): шаг отступов поднят на ступень, чтобы интерфейс дышал.
    property int space1: 5
    property int space2: 10
    property int space3: 14
    property int space4: 22
    property int space5: 30
    property int space6: 36

    property int rowHCompact: 42
    property int rowH: 46
    property int rowHComfy: 54
    property int headerH: 50

    // Все ступени — через fontSize(): тогда fontScale двигает шкалу целиком,
    // а не наполовину (раньше семантические токены были константами).
    // B4: кегль поднят на 1-2 пункта — тело читаемее, заголовки заметнее.
    property int fontTiny: fontSize(12)
    property int fontSmall: fontSize(13)
    property int fontBody: fontSize(15)
    property int fontPanelTitle: fontSize(18)
    property int fontTitle: fontSize(26)
    property int fontClock: fontSize(18)

    // Микро-шкала значений/иконок и поле карточки — чтобы панели не сыпали
    // «магическими» числами (всё считается от fontScale).
    property int fontMicro: fontSize(10)
    property int fontNano: fontSize(9)   // самые мелкие подписи-служебки
    property int fontBig: fontSize(26)
    property int fontHero: fontSize(38)
    property int iconXL: fontSize(32)
    property int cardPad: 22

    // панель-острова (этап 1): высота плашки, зазоры, поля, отступ внутри.
    // arch-стиль: тонкая полоса, контент без «плашек».
    property int barH: arch ? 40 : 38
    property int barMargin: arch ? 0 : 5
    // верхний отступ бара (воздух сверху), отдельно от бокового
    property int barTop: arch ? 8 : 6
    property int barPad: 18
    property int barRadius: arch ? 3 : 12
    // внешняя кромка плашки бара: в architect — прямоугольник без рамки
    readonly property int barOuterRadius: arch ? 0 : barRadius
    readonly property int barOuterBorder: arch ? 0 : 1
    // высота содержимого ячейки бара (иконки/текст внутри плашки)
    property int barCellH: 34
    // разделитель между ячейками бара: в architect — выше и акцентный
    readonly property real barDividerHFactor: arch ? 0.62 : 0.5
    readonly property int barDividerRadius: arch ? 0 : 1
    readonly property color barDividerColor: arch ? hairAccent : alpha(barText, 0.12)
    // высоты строк панелей: поле поиска и строка «пульта»
    property int panelFieldH: 50
    property int panelRowH: 40
    property int sparkH: 28

    // панель-остров (этап 2): шапка, строки, ширины режимов
    property int panelHeaderH: 50
    property int panelWSearch: 620
    property int panelWNotifs: 580
    // «подгонка под режим»: у каждого пузыря своя ширина
    property int panelWMedia: 640
    property int panelWSys: 700
    property int panelWAudio: 520
    // панель поиска раскрывается шире строки — отдельная «широкая» ширина
    property int panelWSearchWide: 900
    // высота панелей-модалок (поиск/уведомления) до полного раскрытия
    property int panelHSearch: 520
    property int panelHNotifs: 420
    property int radiusS: arch ? 0 : 8

    // SectionHeader: в architect — скобки и отступ, в classic — просто подпись
    readonly property int sectionHeaderPad: arch ? 6 : 0
    function sectionHeaderMinH(sz) { return arch ? sz + 2 : 0 }

    // мягкая реакция на наведение — масштаб глифа, без переверстки
    property real hoverGrow: 1.25

    // сколько значков трея видно в панели (остальные — в списке «+N»).
    // Это настройка бара — живёт в BarSettings (bar.json), здесь только
    // чтение, чтобы старый код не менялся.
    readonly property int trayVisible: BarSettings.trayVisible

    // задержка появления тултипов (мс) — чтобы не мигали при проходе курсора
    property int tooltipDelay: 600

    // легаси-шкала: теперь это алиасы единого anim (тот же характер и
    // уважение тумблера animationsEnabled). Новые анимации — через Anim.
    property int animFast: theme.anim.fastEffects
    property int animMed: theme.anim.defaultEffects
    property int animSlow: theme.anim.slowEffects
    // единое движение: одна кривая на весь рис (задаю здесь, чтобы потом
    // менять характер анимаций в одном месте)
    readonly property int easeOut: Easing.OutCubic

    // ── expressive-моушен (порт Material-3 Expressive / Caelestia) ──
    // spatial — движение и размер (лёгкий перелёт в конце), effects —
    // прозрачность/цвет. Характер анимаций меняю в одном месте; durations
    // в мс, кривые — точки для Easing.BezierSpline.
    property bool animationsEnabled: true
    property real animScale: 1.0
    // Тон раскрытия барных островов (по мотивам ArchEclipse): одна настройка
    // решает, какой кривой раскрывается плашка. Имена — для UI, значения —
    // токены Anim. "expressive" — наш текущий характер (перелёт), "standard"
    // — сдержанный, "emphasized" — долгий выразительный.
    property string islandStyle: "expressive"
    // Индекс типа в Anim.Type (0..13). Theme — синглтон без QML-контекста,
    // поэтому Anim тут не виден; задаю числом: Standard=1,
    // Emphasized=5, DefaultSpatial=9 (см. enum в widgets/shared/Anim.qml).
    readonly property int islandAnimType: {
        if (theme.islandStyle === "standard")
            return 1
        if (theme.islandStyle === "emphasized")
            return 5
        return 9
    }
    // токены острова: та же плашка, что бар, но чуть мягче под раскрытие
    readonly property int islandRadius: theme.barRadius
    readonly property color islandSurface: theme.barPill
    readonly property color islandSurfaceHover: theme.hoverStrong
    readonly property QtObject anim: QtObject {
        readonly property real scale: theme.animationsEnabled ? theme.animScale : 0
        // стандартные
        readonly property int small: Math.round(150 * scale)
        readonly property int normal: Math.round(250 * scale)
        readonly property int large: Math.round(400 * scale)
        readonly property int extraLarge: Math.round(600 * scale)
        // expressive: spatial (с перелётом) и effects (без).
        // effects-длительности сверил с 43PR (их animFast/animMed/animSlow
        // 120/220/380) — тот же мягкий заход, что и кривая easeOut в Hyprland.
        readonly property int fastSpatial: Math.round(250 * scale)
        readonly property int defaultSpatial: Math.round(350 * scale)
        readonly property int slowSpatial: Math.round(500 * scale)
        readonly property int fastEffects: Math.round(120 * scale)
        readonly property int defaultEffects: Math.round(220 * scale)
        readonly property int slowEffects: Math.round(380 * scale)
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        readonly property var emphasized: [0.05, 0, 0.1333, 0.06, 0.1667, 0.4, 0.2083, 0.82, 0.25, 1, 1, 1]
        readonly property var expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property var expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property var expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property var expressiveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
        readonly property var expressiveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property var expressiveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    }

    // активный модальный оверлей ("hub" | "agent"): открытие одного
    // закрывает другой, плавно и в одном процессе (без внешнего qs ipc)
    property string activeOverlay: ""

    // Крупные модалки (Hub/Player/Clipboard/Power/Agent/Wallpapers) отмечаются
    // здесь, пока открыты, — по этому флагу LunarBackdrop плавно затемняет фон
    // рабочего стола (dim-подложка как у 43PR). Держу множеством, а не строкой
    // activeOverlay: модалки взаимоисключающие, но подложка должна жить, пока
    // открыта любая, и не лезть в их логику закрытия. Мелкие поверхности
    // (бар, сайдбары, OSD, попапы) сюда не пишут — фон они не затемняют.
    property var openModals: ({})
    readonly property bool backdropOn: {
        for (var k in openModals)
            if (openModals[k])
                return true
        return false
    }
    function setModal(name, isOpen) {
        var next = {}
        for (var k in openModals)
            if (openModals[k] && k !== name)
                next[k] = true
        if (isOpen)
            next[name] = true
        openModals = next
    }

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
            property bool wallpaperLive: true
            property string wallpaperMode: "scene"
            property string wallpaperPath: ""
            property bool wallpaperAuto: true
            property int blurSize: -1
            property int blurPasses: 3
            property string islandStyle: "expressive"
            property string style: "classic"

            // файл → UI (в uiInternal, чтобы не писать назад прочитанное)
            onInterfaceOpacityChanged: { theme.uiInternal = true; theme.interfaceOpacity = interfaceOpacity; theme.uiInternal = false }
            onFontScaleChanged: { theme.uiInternal = true; theme.fontScale = fontScale; theme.uiInternal = false }
            onWallpaperLiveChanged: { theme.uiInternal = true; theme.wallpaperLive = wallpaperLive; theme.uiInternal = false }
            onWallpaperModeChanged: { theme.uiInternal = true; theme.wallpaperMode = wallpaperMode; theme.uiInternal = false }
            onWallpaperPathChanged: { theme.uiInternal = true; theme.wallpaperPath = wallpaperPath; theme.uiInternal = false }
            onWallpaperAutoChanged: { theme.uiInternal = true; theme.wallpaperAuto = wallpaperAuto; theme.uiInternal = false }
            onBlurSizeChanged: { theme.uiInternal = true; theme.blurSize = blurSize; theme.uiInternal = false }
            onBlurPassesChanged: { theme.uiInternal = true; theme.blurPasses = blurPasses; theme.uiInternal = false }
            onIslandStyleChanged: { theme.uiInternal = true; theme.islandStyle = islandStyle; theme.uiInternal = false }
            onStyleChanged: { theme.uiInternal = true; theme.style = style; theme.uiInternal = false }
        }
    }

    // UI → файл. Пишем только настоящие действия пользователя: загрузка
    // из файла идёт через uiInternal и сюда не попадает (H27, L42).
    onInterfaceOpacityChanged: if (!uiInternal) { markUI(); uiAdapter.interfaceOpacity = interfaceOpacity }
    onFontScaleChanged: if (!uiInternal) { markUI(); uiAdapter.fontScale = fontScale }
    onWallpaperLiveChanged: if (!uiInternal) { markUI(); uiAdapter.wallpaperLive = wallpaperLive }
    onWallpaperModeChanged: {
        if (!uiInternal) { markUI(); uiAdapter.wallpaperMode = wallpaperMode }
        // вернулся на сцену — снимаю фотопалитру и возвращаю прежний пресет
        if (!uiInternal && wallpaperMode === "scene")
            restoreScenePalette()
    }
    onWallpaperPathChanged: if (!uiInternal) { markUI(); uiAdapter.wallpaperPath = wallpaperPath }
    onWallpaperAutoChanged: if (!uiInternal) { markUI(); uiAdapter.wallpaperAuto = wallpaperAuto }
    onBlurSizeChanged: {
        if (!uiInternal) { markUI(); uiAdapter.blurSize = blurSize }
        blurApply.restart()
    }
    onBlurPassesChanged: {
        if (!uiInternal) { markUI(); uiAdapter.blurPasses = blurPasses }
        blurApply.restart()
    }
    onIslandStyleChanged: if (!uiInternal) { markUI(); uiAdapter.islandStyle = islandStyle }
    onStyleChanged: if (!uiInternal) { markUI(); uiAdapter.style = style }

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
