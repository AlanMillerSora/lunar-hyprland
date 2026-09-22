import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LaunchPage — лаунчер Hub: список приложений с поиском.
//  Список читается из .desktop (в т.ч. flatpak), обновляется сам
//  (таймер + при фокусе поиска + кнопка), чтобы удалённые/новые
//  приложения появлялись без перезапуска шелла.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── заголовок ───────────────────────────────────────────
        Row {
            Layout.fillWidth: true
            height: 36
            spacing: 12

            Text {
                text: "LAUNCH"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: appModel.allApps.length
                    ? (appModel.apps.length + " из " + appModel.allApps.length)
                    : "сканирую…"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        // ── поиск + обновить ────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: Theme.radius
                color: Theme.bgCard
                border.color: search.activeFocus ? Theme.borderAccent : Theme.border
                border.width: 1

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    clip: true
                    focus: true
                    onTextChanged: appModel.update()
                    onAccepted: appModel.launchFirst()
                    onActiveFocusChanged: if (activeFocus) appModel.load()

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "поиск приложений (несколько слов — через пробел)"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        visible: search.text === ""
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 42
                radius: Theme.radius
                color: refreshMouse.containsMouse
                    ? Theme.alpha(Theme.accent, 0.10)
                    : Theme.alpha(Theme.text, 0.025)
                border.width: 1
                border.color: refreshMouse.containsMouse ? Theme.borderAccent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "ОБНОВИТЬ"
                    color: refreshMouse.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appModel.load()
                }
            }
        }

        // ── сетка приложений ────────────────────────────────────
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 140
            cellHeight: 104
            clip: true
            model: appModel.apps
            currentIndex: 0

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: 132
                height: 96
                radius: Theme.radius
                color: index === grid.currentIndex
                    ? Theme.alpha(Theme.accent, 0.12)
                    : (mouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : Theme.alpha(Theme.text, 0.025))
                border.color: index === grid.currentIndex ? Theme.accent : Theme.border
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 46
                        height: 46
                        radius: Theme.radius
                        color: Theme.alpha(Theme.accent, 0.08)
                        border.color: Theme.borderAccent
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        Image {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            source: modelData.icon
                                ? Quickshell.iconPath(modelData.icon, true)
                                : ""
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: appModel.initials(modelData.name)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    Text {
                        text: modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        width: 120
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: grid.currentIndex = index
                    onClicked: {
                        appModel.launch(modelData)
                        root.closePanel()
                    }
                }
            }

            Keys.onLeftPressed:  currentIndex = Math.max(0, currentIndex - 1)
            Keys.onRightPressed: currentIndex = Math.min(count - 1, currentIndex + 1)
            Keys.onUpPressed:    currentIndex = Math.max(0, currentIndex - Math.floor(width / cellWidth))
            Keys.onDownPressed:  currentIndex = Math.min(count - 1, currentIndex + Math.floor(width / cellWidth))
            Keys.onReturnPressed: appModel.launchAt(currentIndex)

            Text {
                anchors.centerIn: parent
                visible: appModel.apps.length === 0
                text: appModel.allApps.length === 0 ? "ищу приложения…" : "ничего не найдено"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }

    Process { id: launchProc; running: false }

    QtObject {
        id: appModel
        property string filter: ""
        property var apps: []
        property var allApps: []

        Component.onCompleted: load()
        onFilterChanged: update()

        function initials(name) {
            if (!name) return "?"
            var parts = name.trim().split(/\s+/)
            if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
        }

        function load() {
            proc.command = ["python3", "-c", `
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
            var hay = (name + " " + (app.generic || "") + " " + (app.keywords || "") + " " + app.id).toLowerCase()
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
                grid.currentIndex = 0
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
                grid.currentIndex = 0
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
            grid.currentIndex = 0
        }

        function launch(app) {
            var cmd = app.terminal ? ("kitty -e " + app.exec) : app.exec
            launchProc.command = ["bash", "-c", "exec " + cmd]
            launchProc.running = true
        }

        function launchAt(idx) {
            if (idx >= 0 && idx < apps.length) {
                launch(apps[idx])
                root.closePanel()
            }
        }

        function launchFirst() {
            launchAt(0)
        }
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    appModel.allApps = JSON.parse(text)
                    appModel.update()
                } catch (e) {}
            }
        }
    }

    // список приложений обновляем сами (поставил/удалил — увидел)
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: appModel.load()
    }
}
