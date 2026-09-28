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
    property string lastRaw: ""      // сырой JSON прошлого УСПЕШНОГО скана
    property string scanError: ""    // диагностика сканера (пусто = всё хорошо)
    property bool scanPending: false // обновление запрошено, пока шёл скан

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
        // не теряем запрос: если скан уже идёт — повторим сразу после него (M55)
        if (proc.running) {
            scanPending = true
            return
        }
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
        // flatpak-id может содержать заглавные: приводим, как в score() (L44)
        if (app.id.toLowerCase().indexOf(q) >= 0) return 5
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
        var argv = app.execArgs
        if (!argv || argv.length === 0)
            return
        // argv уже разобран по спецификации desktop-entry (см. python-скан) —
        // никакого `bash -c` и field-codes: shell-инъекция невозможна (C5).
        // execDetached не следит за процессом, поэтому быстрый второй запуск
        // ничего не «проглатывает» (H28).
        var cmd = app.terminal ? ["kitty", "-e"].concat(argv) : argv
        Quickshell.execDetached(cmd)
        launched()
    }

    onFilterChanged: update()

    property Process proc: Process {
        running: false
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: {
                var text = scanOut.text
                if (!text || text.trim() === "")
                    return
                if (text === appModel.lastRaw)
                    return
                var parsed
                try {
                    parsed = JSON.parse(text)
                } catch (e) {
                    // lastRaw НЕ трогаем: иначе следующий такой же вывод
                    // считался бы «уже разобранным» (H29)
                    appModel.scanError = "не удалось разобрать список приложений"
                    console.warn("[AppModel] " + appModel.scanError)
                    return
                }
                if (!Array.isArray(parsed)) {
                    appModel.scanError = "сканер вернул не список"
                    return
                }
                appModel.allApps = parsed
                appModel.lastRaw = text
                appModel.scanError = ""
                appModel.update()
            }
        }
        stderr: StdioCollector { id: scanErr }
        onExited: (code) => {
            if (code !== 0 && appModel.scanError === "") {
                appModel.scanError = (scanErr.text || "").trim()
                    || ("индексатор приложений вышел с кодом " + code)
                console.warn("[AppModel] " + appModel.scanError)
            } else if (code === 0 && appModel.scanError === ""
                       && (scanOut.text || "").trim() === "") {
                appModel.scanError = "не удалось проиндексировать приложения"
                console.warn("[AppModel] " + appModel.scanError)
            }
            if (appModel.scanPending) {
                appModel.scanPending = false
                Qt.callLater(function() { appModel.load() })
            }
        }
        command: ["python3", "-c", `
import json, os, glob, re, shlex, shutil

bases = [
    os.path.expanduser("~/.local/share/applications"),
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
]

# field-codes desktop-entry (%% — литерал процента, снимаем отдельно)
FIELDS = re.compile(r"%[fFuUdDnNickvm]")


def locale_suffixes():
    loc = os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
    loc = loc.split(".")[0].split("@")[0]
    if not loc or loc in ("C", "POSIX"):
        return []
    out = ["[" + loc + "]"]
    if "_" in loc:
        out.append("[" + loc.split("_")[0] + "]")
    return out


LANG_SUFFIXES = locale_suffixes()
CURRENT_DESKTOP = set((os.environ.get("XDG_CURRENT_DESKTOP") or "").split(":"))


def localized(entry, key):
    for sfx in LANG_SUFFIXES:
        v = entry.get(key + sfx)
        if v:
            return v
    return entry.get(key, "")


def shown_in(val):
    for d in (val or "").split(";"):
        if d and d in CURRENT_DESKTOP:
            return True
    return False


def parse_exec(ex):
    ex = ex.replace("%%", "lunar_pct_marker")
    try:
        argv = shlex.split(ex, posix=True)
    except ValueError:
        argv = ex.split()
    out = []
    for a in argv:
        a = FIELDS.sub("", a).replace("lunar_pct_marker", "%")
        if a:
            out.append(a)
    return out


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
        name = localized(e, "Name")
        if not name or "avahi" in name.lower():
            continue
        # TryExec: если бинарника нет — запись заведомо нерабочая (M54)
        te = e.get("TryExec")
        if te and not (shutil.which(te) or (os.path.isabs(te) and os.access(te, os.X_OK))):
            continue
        only = e.get("OnlyShowIn")
        if CURRENT_DESKTOP and only and not shown_in(only):
            continue
        notin = e.get("NotShowIn")
        if CURRENT_DESKTOP and notin and shown_in(notin):
            continue
        aid = os.path.splitext(os.path.basename(f))[0]
        if aid in seen:
            continue
        seen.add(aid)
        argv = parse_exec(e.get("Exec", ""))
        if not argv:
            continue
        apps.append({
            "id": aid.lower(),
            "name": name,
            "generic": localized(e, "GenericName"),
            "keywords": localized(e, "Keywords").replace(";", " "),
            "execArgs": argv,
            "icon": e.get("Icon", ""),
            "terminal": e.get("Terminal") == "true",
        })
apps.sort(key=lambda a: a["name"].lower())
print(json.dumps(apps))
`]
    }

    // список приложений обновляем сами (поставил/удалил — увидел).
    // Раньше — раз в минуту (постоянный CPU и пробуждение из idle, M55);
    // теперь редко, а кнопка «ОБНОВИТЬ» на странице Launch делает это вручную.
    property Timer refreshTimer: Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: appModel.load()
    }
}
