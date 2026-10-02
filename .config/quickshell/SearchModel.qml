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
        if (done)
            done()
    }
}
