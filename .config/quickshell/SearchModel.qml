pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ════════════════════════════════════════════════════════════════
//  SearchModel — общий поиск риса: приложения + страницы Hub + действия.
//  Перенёс из LunarHub, чтобы искать прямо из бара (панель «поиск»).
//  Страницы Hub не рисую сам — только открываю Hub на нужной вкладке.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: sm

    // страницы Hub (порядок = nav в LunarHub)
    readonly property var navItems: [
        { name: "Launch",     icon: "\uf120" },
        { name: "System",     icon: "󰒓" },
        { name: "Devices",    icon: "\uf108" },
        { name: "Network",    icon: "\uf1eb" },
        { name: "Interface",  icon: "\uf085" },
        { name: "Games",      icon: "\uf11b" },
        { name: "Dev",        icon: "\uf121" },
        { name: "Update",     icon: "\uf021" },
        { name: "Media",      icon: "\uf302" }
    ]

    property Process p: Process { running: false }
    function runShell(cmd) {
        sm.p.command = ["bash", "-c", cmd]
        sm.p.running = true
    }

    // Копирую текст в буфер: ответ передаю позиционным аргументом ($1),
    // а не склеиваю в тело команды — иначе выражение с кавычками ломает shell.
    // Заодно рапортую mako, что ответ ушёл в буфер (панель-то закрывается).
    property Process cp: Process { running: false }
    function copyText(t) {
        t = "" + t
        sm.cp.command = ["bash", "-c",
            "printf %s \"$1\" | wl-copy && notify-send -a lunar \"$2\" \"$3\"",
            "--", t, "Калькулятор", "= " + t + " — в буфере"]
        sm.cp.running = true
    }
    // эмодзи копирую тем же путём, но с другой подписью
    function copyEmoji(t) {
        t = "" + t
        sm.cp.command = ["bash", "-c",
            "printf %s \"$1\" | wl-copy && notify-send -a lunar \"$2\" \"$3\"",
            "--", t, "Эмодзи", t + " — в буфере"]
        sm.cp.running = true
    }

    // Простой калькулятор: разбираю выражение сам (рекурсивный спуск),
    // без eval — считаю только цифры и операторы + - * / % ^ и скобки.
    function calcEval(src) {
        var s = ("" + src).replace(/\s+/g, "")
        var i = 0
        function peek() { return s.charAt(i) }
        function next() { return s.charAt(i++) }
        // число (целое/дробное, точка) — возвращаю NaN, если числа нет
        function number() {
            var start = i
            while (i < s.length && /[0-9.]/.test(s.charAt(i))) i++
            if (start === i) return NaN
            return parseFloat(s.slice(start, i))
        }
        // множитель: унарный минус, скобки или число
        function factor() {
            if (peek() === "+") { next(); return factor() }
            if (peek() === "-") { next(); return -factor() }
            if (peek() === "(") {
                next()
                var v = expr()
                if (next() !== ")") return NaN
                return v
            }
            return number()
        }
        // степень (правоассоциативно)
        function power() {
            var base = factor()
            if (peek() === "^") { next(); return Math.pow(base, power()) }
            return base
        }
        // произведение/деление/остаток
        function term() {
            var v = power()
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                var op = next()
                var rhs = power()
                if (op === "*") v = v * rhs
                else if (op === "/") v = rhs === 0 ? NaN : v / rhs
                else v = rhs === 0 ? NaN : v % rhs
            }
            return v
        }
        // сумма/разность
        function expr() {
            var v = term()
            while (peek() === "+" || peek() === "-") {
                var op = next()
                var rhs = term()
                v = op === "+" ? v + rhs : v - rhs
            }
            return v
        }
        var res = expr()
        if (i !== s.length) return NaN   // остались лишние символы — не выражение
        if (!isFinite(res)) return NaN
        // убираю хвостовые нули у дробных, long-хвост округляю
        if (Math.abs(res) < 1e15) res = Math.round(res * 1e10) / 1e10
        return res
    }

    // Похоже ли на выражение и есть ли что считать
    function calcAnswer(q) {
        var s = ("" + q).trim()
        if (s.length < 2) return null
        if (!/^[0-9+\-*/(). %^]+$/.test(s)) return null
        if (!/[0-9]/.test(s)) return null
        if (!/[+\-*/%^]/.test(s)) return null
        var v = sm.calcEval(s)
        if (isNaN(v)) return null
        return "" + v
    }

    property var searchActions: [
        { name: "Game Mode — вкл/выкл", icon: "\uf11b",
          run: function() { sm.runShell("~/.config/hypr/scripts/eclipse-gamemode.sh toggle") } },
        { name: "Запись экрана — старт/стоп", icon: "\uf111",
          run: function() { sm.runShell("~/.config/hypr/scripts/eclipse-record.sh toggle") } },
        { name: "Микшер (pavucontrol)", icon: "\uf028",
          run: function() { sm.runShell("setsid pavucontrol >/dev/null 2>&1 &") } },
        { name: "Обои — подбор", icon: "\uf03e",
          run: function() { sm.runShell("qs ipc call wallpapers toggle") } },
        { name: "Живые обои — вкл/выкл", icon: "\uf03e",
          run: function() { Theme.wallpaperLive = !Theme.wallpaperLive } },
        { name: "История буфера (cliphist)", icon: "\uf0ea",
          run: function() { sm.runShell("qs ipc call clipboard open") } },
        { name: "Медиа — мои файлы", icon: "\uf302",
          run: function() { sm.openHubPage(8) } }
    ]

    // H38: предрассчитанные поисковые строки приложений
    property var appHay: []

    // ── URL: открыть ссылку из поиска ──
    function urlOf(q) {
        var s = ("" + q).trim()
        if (/^https?:\/\/\S+$/i.test(s)) return s
        if (/^www\.\S+\.\S+$/i.test(s)) return "https://" + s
        // «слово.tld» с известным доменом и без пробелов
        if (/^[a-z0-9-]+(\.[a-z0-9-]+)+(\/\S*)?$/i.test(s)
                && /\.(com|org|net|ru|io|dev|me|app|ai|edu|gov|xyz|cc|gg|tv|info|site|online|store|tech)$/i.test(s.split("/")[0]))
            return "https://" + s
        return ""
    }
    function openUrl(u) {
        Quickshell.execDetached(["xdg-open", u])
    }

    // ── Конверсия единиц: «10 km to mi», «100 c to f» ──
    function unitAnswer(q) {
        var m = ("" + q).trim().toLowerCase()
            .match(/^(-?\d+(?:[.,]\d+)?)\s*([a-z°]+)\s*(?:to|in|в|->|=>)\s*([a-z°]+)$/)
        if (!m) return null
        var v = parseFloat(m[1].replace(",", "."))
        if (isNaN(v)) return null
        var from = m[2], to = m[3]
        // категории: множитель к базовой единице
        var table = {
            "km":   { cat: "len",  f: 1000 },
            "m":    { cat: "len",  f: 1 },
            "cm":   { cat: "len",  f: 0.01 },
            "mm":   { cat: "len",  f: 0.001 },
            "mi":   { cat: "len",  f: 1609.344 },
            "миля": { cat: "len",  f: 1609.344 },
            "миль": { cat: "len",  f: 1609.344 },
            "ft":   { cat: "len",  f: 0.3048 },
            "in":   { cat: "len",  f: 0.0254 },
            "miles":{ cat: "len",  f: 1609.344 },
            "кг":   { cat: "mass", f: 1 },
            "kg":   { cat: "mass", f: 1 },
            "г":    { cat: "mass", f: 0.001 },
            "g":    { cat: "mass", f: 0.001 },
            "т":    { cat: "mass", f: 1000 },
            "lb":   { cat: "mass", f: 0.45359237 },
            "lbs":  { cat: "mass", f: 0.45359237 },
            "фунт": { cat: "mass", f: 0.45359237 },
            "oz":   { cat: "mass", f: 0.028349523125 },
            "l":    { cat: "vol",  f: 1 },
            "л":    { cat: "vol",  f: 1 },
            "ml":   { cat: "vol",  f: 0.001 },
            "мл":   { cat: "vol",  f: 0.001 },
            "gal":  { cat: "vol",  f: 3.785411784 },
            "gb":   { cat: "data", f: 1e9 },
            "mb":   { cat: "data", f: 1e6 },
            "kb":   { cat: "data", f: 1e3 },
            "gib":  { cat: "data", f: 1073741824 },
            "mib":  { cat: "data", f: 1048576 },
            "kib":  { cat: "data", f: 1024 }
        }
        // температуры — отдельно (не линейные множители)
        var temp = { "c": 1, "°c": 1, "f": 1, "°f": 1, "k": 1, "к": 1, "ц": 1 }
        if (temp[from] && temp[to]) {
            var cel = from === "f" || from === "°f" ? (v - 32) * 5 / 9
                : (from === "k" || from === "к") ? v - 273.15 : v
            var res = to === "f" || to === "°f" ? cel * 9 / 5 + 32
                : (to === "k" || to === "к") ? cel + 273.15 : cel
            return sm.fmtNum(res)
        }
        if (!table[from] || !table[to]) return null
        if (table[from].cat !== table[to].cat) return null
        return sm.fmtNum(v * table[from].f / table[to].f)
    }

    function fmtNum(x) {
        if (Math.abs(x) < 1e15) x = Math.round(x * 1e6) / 1e6
        return "" + x
    }

    // ── Эмодзи: компактный словарь частых (имя → знак) ──
    readonly property var emojiMap: [
        { k: "fire огонь", e: "🔥" }, { k: "heart сердце", e: "❤️" },
        { k: "smile улыбка", e: "🙂" }, { k: "laugh смех", e: "😂" },
        { k: "wink подмиг", e: "😉" }, { k: "cool круто", e: "😎" },
        { k: "think думаю", e: "🤔" }, { k: "cry плачу", e: "😢" },
        { k: "angry злой", e: "😠" }, { k: "shock шок", e: "😱" },
        { k: "sleep сон", e: "😴" }, { k: "love любовь", e: "😍" },
        { k: "kiss поцелуй", e: "😘" }, { k: "party вечеринка", e: "🥳" },
        { k: "ok ок", e: "👌" }, { k: "thumbs палец", e: "👍" },
        { k: "clap хлопаю", e: "👏" }, { k: "wave привет", e: "👋" },
        { k: "pray молюсь", e: "🙏" }, { k: "muscle сила", e: "💪" },
        { k: "eyes глаза", e: "👀" }, { k: "brain мозг", e: "🧠" },
        { k: "rocket ракета", e: "🚀" }, { k: "star звезда", e: "⭐" },
        { k: "boom взрыв", e: "💥" }, { k: "sparkles блеск", e: "✨" },
        { k: "check галочка", e: "✅" }, { k: "cross крест", e: "❌" },
        { k: "warning предупреждение", e: "⚠️" }, { k: "question вопрос", e: "❓" },
        { k: "skull череп", e: "💀" }, { k: "ghost призрак", e: "👻" },
        { k: "moon луна", e: "🌙" }, { k: "sun солнце", e: "☀️" },
        { k: "cloud облако", e: "☁️" }, { k: "rain дождь", e: "🌧️" },
        { k: "snow снег", e: "❄️" }, { k: "zap молния", e: "⚡" },
        { k: "cat кот", e: "🐱" }, { k: "dog собака", e: "🐶" },
        { k: "fox лиса", e: "🦊" }, { k: "wolf волк", e: "🐺" },
        { k: "penguin пингвин", e: "🐧" }, { k: "coffee кофе", e: "☕" },
        { k: "beer пиво", e: "🍺" }, { k: "pizza пицца", e: "🍕" },
        { k: "cake торт", e: "🎂" }, { k: "gift подарок", e: "🎁" },
        { k: "music музыка", e: "🎵" }, { k: "guitar гитара", e: "🎸" },
        { k: "game игра", e: "🎮" }, { k: "book книга", e: "📖" },
        { k: "code код", e: "💻" }, { k: "gear шестерня", e: "⚙️" },
        { k: "wrench гаечный", e: "🔧" }, { k: "hammer молоток", e: "🔨" },
        { k: "key ключ", e: "🔑" }, { k: "lock замок", e: "🔒" },
        { k: "bell колокол", e: "🔔" }, { k: "hourglass время", e: "⏳" },
        { k: "clock часы", e: "🕐" }, { k: "calendar календарь", e: "📅" },
        { k: "mail почта", e: "✉️" }, { k: "phone телефон", e: "📱" },
        { k: "camera камера", e: "📷" }, { k: "video видео", e: "🎬" },
        { k: "trash мусор", e: "🗑️" }, { k: "save сохранить", e: "💾" },
        { k: "eyes2 очи", e: "👁️" }, { k: "100 сто", e: "💯" }
    ]
    function emojiHit(q) {
        var s = ("" + q).trim().toLowerCase()
        if (s.length < 2) return null
        // точный эмодзи-ввод уже (сам знак)
        for (var i = 0; i < sm.emojiMap.length; i++) {
            var keys = sm.emojiMap[i].k.split(" ")
            for (var j = 0; j < keys.length; j++) {
                if (keys[j] === s)
                    return { k: keys[0], e: sm.emojiMap[i].e }
            }
        }
        return null
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

    function rebuildAppHay() {
        var apps = AppModel.allApps
        var h = []
        for (var i = 0; i < apps.length; i++) {
            var ap = apps[i]
            h.push(((ap.name || "") + " " + (ap.generic || "") + " " + (ap.keywords || "")
                + " " + (ap.id || "")).toLowerCase())
        }
        sm.appHay = h
    }

    function search(q) {
        q = ("" + q).trim().toLowerCase()
        if (q === "") return []
        var out = []
        // Калькулятор — первым: если запрос считаю выражением, ставлю его впереди.
        var ans = sm.calcAnswer(q)
        if (ans !== null)
            out.push({ kind: "calc", rank: -1000, label: "= " + ans,
                       icon: "\uf1ec", text: ans })
        // Ссылка: похоже на URL — открыть.
        var url = sm.urlOf(q)
        if (url !== "")
            out.push({ kind: "url", rank: -990, label: "Открыть " + url,
                       icon: "\uf0c1", url: url })
        // Конверсия единиц: «10 km to mi».
        var unit = sm.unitAnswer(q)
        if (unit !== null)
            out.push({ kind: "unit", rank: -980, label: "= " + unit,
                       icon: "\uf1ec", text: unit })
        // Эмодзи: точное имя — копировать знак.
        var em = sm.emojiHit(q)
        if (em !== null)
            out.push({ kind: "emoji", rank: -970, label: em.e + "  " + em.k,
                       icon: "", text: em.e })
        for (var i = 0; i < sm.navItems.length; i++) {
            var r = sm.matchRank(q, sm.navItems[i].name)
            if (r >= 0)
                out.push({ kind: "page", rank: r - 1, label: sm.navItems[i].name,
                           icon: sm.navItems[i].icon, pageIndex: i })
        }
        for (var a = 0; a < sm.searchActions.length; a++) {
            var ra = sm.matchRank(q, sm.searchActions[a].name)
            if (ra >= 0)
                out.push({ kind: "action", rank: ra - 1, label: sm.searchActions[a].name,
                           icon: sm.searchActions[a].icon, act: a })
        }
        var apps = AppModel.allApps
        if (sm.appHay.length !== apps.length)
            sm.rebuildAppHay()
        var hits = []
        for (var j = 0; j < apps.length; j++) {
            var ap = apps[j]
            var r2 = sm.matchRank(q, ap.name)
            if (r2 < 0) r2 = sm.matchRank(q, sm.appHay[j])
            if (r2 >= 0) hits.push({ kind: "app", rank: r2, label: ap.name, app: ap,
                icon: ap.icon || "",
                image: (ap.icon && Quickshell.hasThemeIcon(ap.icon)) ? Quickshell.iconPath(ap.icon, true) : "" })
        }
        hits.sort(function(x, y) { return x.rank - y.rank })
        out = out.concat(hits.slice(0, 8))
        out.sort(function(x, y) { return x.rank - y.rank })
        return out.slice(0, 12)
    }

    function openHubPage(i) {
        sm.runShell("qs ipc call hub open; sleep 0.15; qs ipc call hub nav " + i)
    }

    // выполнить результат; после — закрыть панель (если передали колбэк)
    function activate(r, done) {
        if (!r)
            return
        if (r.kind === "page")
            sm.openHubPage(r.pageIndex)
        else if (r.kind === "action")
            sm.searchActions[r.act].run()
        else if (r.kind === "app")
            AppModel.launch(r.app)
        else if (r.kind === "calc")
            sm.copyText(r.text)
        else if (r.kind === "unit")
            sm.copyText(r.text)
        else if (r.kind === "emoji")
            sm.copyEmoji(r.text)
        else if (r.kind === "url")
            sm.openUrl(r.url)
        if (done)
            done()
    }
}
