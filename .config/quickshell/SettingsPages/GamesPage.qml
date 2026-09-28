import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  GamesPage — список установленных игр (desktop-записи с
//  Categories=Game). Ловит Steam/Lutris/Heroic и т.п.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    // контейнер (Hub) может закрыться по этому сигналу — без хрупкой
    // ссылки root.closePanel() через цепочку контекстов Loader (M77)
    signal closeRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Row {
            Layout.fillWidth: true
            height: 36
            Text {
                text: "GAMES"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        Rectangle {
            Layout.fillWidth: true
            height: 42
            radius: Theme.radius
            color: Theme.bgCard
            border.color: search.activeFocus ? Theme.borderAccent : Theme.border
            border.width: 1

            TextInput {
                id: search
                anchors.fill: parent
                anchors.margins: 10
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                clip: true
                focus: true
                onTextChanged: gameModel.update()

                Text {
                    anchors.fill: parent
                    text: "поиск игры"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    visible: search.text === "" && !search.activeFocus
                }
            }
        }

        // строки: иконка + название + запуск
        ListView {
            id: gameList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: gameModel.games

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: gameList.width
                height: 52
                radius: Theme.radius
                color: rowMouse.containsMouse
                    ? Theme.hoverStrong
                    : Theme.fill
                border.width: 1
                border.color: rowMouse.containsMouse ? Theme.borderAccent : Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 12

                    Image {
                        id: gIcon
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        sourceSize: Qt.size(56, 56)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        source: modelData.icon
                            ? Quickshell.iconPath(modelData.icon, true)
                            : ""
                        visible: status === Image.Ready
                    }

                    Text {
                        visible: gIcon.status !== Image.Ready
                        text: "\uf11b"
                        color: Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "ЗАПУСТИТЬ"
                        color: rowMouse.containsMouse ? Theme.accent : Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        gameModel.launch(modelData)
                        page.closeRequested()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: gameModel.games.length === 0
                text: gameModel.loaded
                    ? (gameModel.loadError !== "" ? gameModel.loadError : "игр не найдено")
                    : "ищу игры…"
                color: gameModel.loadError !== "" ? Theme.danger : Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        Text {
            text: gameModel.games.length + " игр"
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: 9
        }
    }

    QtObject {
        id: gameModel
        property var games: []
        property var allGames: []
        property bool loaded: false
        property string loadError: ""

        Component.onCompleted: load()

        function load() {
            // перезапуск, даже если скан уже идёт
            proc.running = false
            proc.running = true
        }

        function update() {
            var f = search.text.toLowerCase()
            games = allGames.filter(function(g) {
                return f === "" || (g.name + " " + g.id).toLowerCase().includes(f)
            })
        }

        function launch(g) {
            if (!g) return
            // общий безопасный лаунчер AppModel: argv без shell (C5), без
            // «проглоченного» второго запуска (H28); его launched закрывает Hub
            AppModel.launch(g)
        }
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            id: gameOut
            onStreamFinished: {
                var text = gameOut.text
                if (!text || text.trim() === "")
                    return
                var parsed
                try {
                    parsed = JSON.parse(text)
                } catch (e) {
                    gameModel.loadError = "не удалось разобрать список игр"
                    return
                }
                if (!Array.isArray(parsed)) {
                    gameModel.loadError = "сканер вернул не список"
                    return
                }
                gameModel.allGames = parsed
                gameModel.loadError = ""
                gameModel.loaded = true
                gameModel.update()
            }
        }
        stderr: StdioCollector { id: gameErr }
        onExited: (code) => {
            if (code !== 0 && gameModel.loadError === "")
                gameModel.loadError = (gameErr.text || "").trim()
                    || ("сканер игр вышел с кодом " + code)
            gameModel.loaded = true
        }
        command: ["python3", "-c", `
import json, os, glob, re, shlex, shutil

bases = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]
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
        entry = parse(f)
        if not entry:
            continue
        if entry.get("Type", "Application") != "Application":
            continue
        if "Game" not in entry.get("Categories", "").split(";"):
            continue
        if entry.get("NoDisplay") == "true" or entry.get("Hidden") == "true":
            continue
        name = localized(entry, "Name")
        if not name:
            continue
        te = entry.get("TryExec")
        if te and not (shutil.which(te) or (os.path.isabs(te) and os.access(te, os.X_OK))):
            continue
        only = entry.get("OnlyShowIn")
        if CURRENT_DESKTOP and only and not shown_in(only):
            continue
        notin = entry.get("NotShowIn")
        if CURRENT_DESKTOP and notin and shown_in(notin):
            continue
        aid = os.path.splitext(os.path.basename(f))[0]
        if aid in seen:
            continue
        seen.add(aid)
        argv = parse_exec(entry.get("Exec", ""))
        if not argv:
            continue
        apps.append({
            "id": aid.lower(),
            "name": name,
            "execArgs": argv,
            "icon": entry.get("Icon", ""),
            "terminal": entry.get("Terminal") == "true",
        })
apps.sort(key=lambda a: a["name"].lower())
print(json.dumps(apps))
`]
    }
}
