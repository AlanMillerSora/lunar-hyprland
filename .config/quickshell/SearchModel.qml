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
        { name: "Update",     icon: "\uf021" }
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
            "printf %s \"$1\" | wl-copy && notify-send -a lunar \"Калькулятор\" \"$2\"",
            "--", t, "= " + t + " — в буфере"]
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
          run: function() { Theme.wallpaperLive = !Theme.wallpaperLive } }
    ]

    // H38: предрассчитанные поисковые строки приложений
    property var appHay: []

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
            if (r2 >= 0) hits.push({ kind: "app", rank: r2, label: ap.name, app: ap })
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
        if (done)
            done()
    }
}
