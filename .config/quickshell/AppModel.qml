pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ════════════════════════════════════════════════════════════════
//  AppModel — единый индекс приложений (.desktop, в т.ч. flatpak).
//  Используется и командным поиском Hub, и страницей Launch.
//  Обновляется сам (таймер), чтобы новые/удалённые приложения
//  появлялись без перезапуска шелла.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: appModel

    property var allApps: []
    property var apps: []
    property string filter: ""

    // приложение запущено — Hub может закрыться
    signal launched()

    Component.onCompleted: load()

    function initials(name) {
        if (!name) return "?"
        var parts = ("" + name).trim().split(/\s+/)
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
    }

    function load() {
        if (!proc.running)
            proc.running = true
    }

    // нечёткий поиск: буквы запроса по порядку + бонус за начало строки
    function fuzzy(needle, hay) {
        if (needle === "") return 0
        var hi = 0, score = 0, streak = 0
        for (var i = 0; i < needle.length; i++) {
            var idx = hay.indexOf(needle[i], hi)
            if (idx < 0) return -1
            streak = idx === hi ? streak + 1 : 0
            score += 2 + streak * 3 - Math.min(idx - hi, 12) * 0.15
            hi = idx + 1
        }
        return score
    }

    function score(app, tokens) {
        var name = app.name.toLowerCase()
        var hay = (name + " " + (app.generic || "") + " " + (app.keywords || "")
            + " " + app.id).toLowerCase()
        var total = 0
        for (var i = 0; i < tokens.length; i++) {
            var s = fuzzy(tokens[i], hay)
            if (s < 0) return -1
            total += s
        }
        if (tokens.length && name.indexOf(tokens[0]) === 0) total += 25
        if (tokens.length && name.indexOf(tokens.join("")) >= 0) total += 15
        return total
    }

    // ранг совпадения по подстроке (меньше — лучше), -1 если нет
    function substrRank(app, q) {
        var name = app.name.toLowerCase()
        var idx = name.indexOf(q)
        if (idx === 0) return 0
        if (idx > 0) return name[idx - 1] === " " ? 1 : 1.5
        if ((app.generic || "").toLowerCase().indexOf(q) >= 0) return 3
        if ((app.keywords || "").toLowerCase().indexOf(q) >= 0) return 4
        if (app.id.indexOf(q) >= 0) return 5
        return -1
    }

    function update() {
        var f = filter.trim().toLowerCase()
        if (f === "") {
            apps = allApps
            return
        }
        var tokens = f.split(/\s+/)

        // 1) точные совпадения (подстрока) — приоритет
        var exact = []
        for (var i = 0; i < allApps.length; i++) {
            var rank = 0, ok = true
            for (var t = 0; t < tokens.length; t++) {
                var r = substrRank(allApps[i], tokens[t])
                if (r < 0) { ok = false; break }
                rank += r
            }
            if (ok) exact.push({ app: allApps[i], r: rank })
        }
        if (exact.length > 0) {
            exact.sort(function(a, b) {
                return a.r !== b.r ? a.r - b.r : a.app.name.localeCompare(b.app.name)
            })
            apps = exact.map(function(x) { return x.app })
            return
        }

        // 2) нечёткий поиск — если точных нет
        var scored = []
        for (var j = 0; j < allApps.length; j++) {
            var s = score(allApps[j], tokens)
            if (s >= 0) scored.push({ app: allApps[j], s: s })
        }
        scored.sort(function(a, b) { return b.s - a.s })
        apps = scored.slice(0, 24).map(function(x) { return x.app })
    }

    function launch(app) {
        if (!app) return
        var cmd = app.terminal ? ("kitty -e " + app.exec) : app.exec
        launchProc.command = ["bash", "-c", "exec " + cmd]
        launchProc.running = true
        launched()
    }

    onFilterChanged: update()

    property Process proc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    appModel.allApps = JSON.parse(text)
                    appModel.update()
                } catch (e) {}
            }
        }
        command: ["python3", "-c", `
import json, os, glob

bases = [
    os.path.expanduser("~/.local/share/applications"),
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
]
DROPS = ["%f", "%F", "%u", "%U", "%i", "%c", "%k", "%d", "%D", "%n", "%N", "%v", "%m"]


def parse(path):
    entry = {}
    cur = None
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                line = line.rstrip("\\n")
                if line.startswith("[") and line.endswith("]"):
                    cur = line[1:-1]
                elif "=" in line and cur == "Desktop Entry":
                    k, v = line.split("=", 1)
                    entry.setdefault(k, v)
    except Exception:
        return None
    return entry


apps = []
seen = set()
for base in bases:
    for f in sorted(glob.glob(base + "/*.desktop")):
        e = parse(f)
        if not e:
            continue
        if e.get("Type", "Application") != "Application":
            continue
        if e.get("NoDisplay") == "true" or e.get("Hidden") == "true":
            continue
        name = e.get("Name[ru]") or e.get("Name")
        if not name or "avahi" in name.lower():
            continue
        aid = os.path.splitext(os.path.basename(f))[0]
        if aid in seen:
            continue
        seen.add(aid)
        ex = e.get("Exec", "")
        for token in DROPS:
            ex = ex.replace(token, "")
        apps.append({
            "id": aid,
            "name": name,
            "generic": e.get("GenericName[ru]") or e.get("GenericName", ""),
            "keywords": (e.get("Keywords[ru]") or e.get("Keywords", "")).replace(";", " "),
            "exec": ex.strip(),
            "icon": e.get("Icon", ""),
            "terminal": e.get("Terminal") == "true",
        })
apps.sort(key=lambda a: a["name"].lower())
print(json.dumps(apps))
`]
    }

    property Process launchProc: Process { running: false }

    // список приложений обновляем сами (поставил/удалил — увидел)
    property Timer refreshTimer: Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: appModel.load()
    }
}
