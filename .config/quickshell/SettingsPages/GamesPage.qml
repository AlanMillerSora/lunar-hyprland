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
            height: 38
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
                    ? Theme.alpha(Theme.accent, 0.08)
                    : Theme.alpha(Theme.text, 0.025)
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
                        root.closePanel()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: gameModel.games.length === 0
                text: gameModel.loaded ? "игр не найдено" : "ищу игры…"
                color: Theme.textFaint
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

    Process { id: launchProc; running: false }

    QtObject {
        id: gameModel
        property var games: []
        property var allGames: []
        property bool loaded: false

        Component.onCompleted: load()

        function load() {
            proc.command = ["python3", "-c", `
import json, os, glob
apps = []
for base in ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]:
    for f in sorted(glob.glob(base + "/*.desktop")):
        entry = {}
        cur = None
        try:
            with open(f, "r", encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    line = line.strip()
                    if line.startswith("[") and line.endswith("]"):
                        cur = line[1:-1]
                    elif "=" in line and cur == "Desktop Entry":
                        k, v = line.split("=", 1)
                        entry.setdefault(k, v)
        except Exception:
            continue
        cats = entry.get("Categories", "")
        if "Game" not in cats.split(";"):
            continue
        if entry.get("NoDisplay") == "true" or not entry.get("Name"):
            continue
        ex = entry.get("Exec", "")
        for token in ["%f", "%F", "%u", "%U", "%i", "%c", "%k"]:
            ex = ex.replace(token, "")
        apps.append({"id": os.path.splitext(os.path.basename(f))[0],
                     "name": entry["Name"], "exec": ex.strip(),
                     "icon": entry.get("Icon", "")})
print(json.dumps(apps))
`]
            proc.running = true
        }

        function update() {
            var f = search.text.toLowerCase()
            games = allGames.filter(function(g) {
                return f === "" || (g.name + " " + g.id).toLowerCase().includes(f)
            })
        }

        function launch(g) {
            launchProc.command = ["bash", "-c", "exec " + g.exec]
            launchProc.running = true
        }
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    gameModel.allGames = JSON.parse(text)
                    gameModel.loaded = true
                    gameModel.update()
                } catch (e) {
                    gameModel.loaded = true
                }
            }
        }
    }
}
