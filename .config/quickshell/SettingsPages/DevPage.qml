import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  DevPage — раздел «Разработка» в Hub.
//  Сам находит git-репозитории в домашних каталогах проектов и
//  показывает ветку, изменения и последний коммит. Кнопки: открыть
//  в VS Code, открыть терминал в проекте, сделать git pull.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    // ── кнопка строки проекта ──────────────────────────────────
    component RowButton: Rectangle {
        id: btn

        property string label: ""
        property string action: ""
        property string projPath: ""

        signal triggered(string act, string path)

        width: 58
        height: 28
        radius: Theme.radius

        color: btnMouse.containsMouse
            ? Theme.alpha(Theme.accent, 0.12)
            : "transparent"

        border.width: 1
        border.color: btnMouse.containsMouse
            ? Theme.accent
            : Theme.border

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btnMouse.containsMouse
                ? Theme.accent
                : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.letterSpacing: 1
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered(btn.action, btn.projPath)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── шапка ──────────────────────────────────────────────
        Row {
            Layout.fillWidth: true
            height: 36
            spacing: 12

            Text {
                text: "DEVELOPMENT"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: projectModel.loaded
                    ? projectModel.projects.length + " проектов"
                    : "поиск…"
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

        // ── быстрые действия ───────────────────────────────────
        Row {
            Layout.fillWidth: true
            height: 34
            spacing: 8

            Repeater {
                model: [
                    { label: "VS CODE",  action: "code" },
                    { label: "ТЕРМИНАЛ", action: "term" },
                    { label: "ОБНОВИТЬ", action: "refresh" }
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: 110
                    height: 34
                    radius: Theme.radius

                    color: quickMouse.containsMouse
                        ? Theme.alpha(Theme.accent, 0.08)
                        : Theme.alpha(Theme.text, 0.025)

                    border.width: 1
                    border.color: quickMouse.containsMouse
                        ? Theme.borderAccent
                        : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: quickMouse.containsMouse
                            ? Theme.accent
                            : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        id: quickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (modelData.action === "code")
                                projectModel.openCode(Quickshell.env("HOME"))
                            else if (modelData.action === "term")
                                projectModel.openTerm(Quickshell.env("HOME"))
                            else
                                projectModel.load()
                        }
                    }
                }
            }
        }

        // ── список проектов ────────────────────────────────────
        ListView {
            id: projectList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: projectModel.projects

            delegate: Rectangle {
                required property var modelData

                width: projectList.width
                height: 58
                radius: Theme.radius

                color: rowMouse.containsMouse
                    ? Theme.alpha(Theme.accent, 0.08)
                    : Theme.alpha(Theme.text, 0.025)

                border.width: 1
                border.color: rowMouse.containsMouse
                    ? Theme.borderAccent
                    : Theme.border

                // клик по пустому месту строки — открыть проект в VS Code
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: projectModel.openCode(modelData.path)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // монограмма проекта
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: Theme.radius
                        color: Theme.alpha(Theme.accent, 0.08)
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: projectModel.initials(modelData.name)
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    // название + ветка + последний коммит
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: 8

                            Text {
                                text: "\uf126 " + (modelData.branch || "—")
                                color: Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: 9
                            }

                            Text {
                                text: modelData.dirty > 0
                                    ? "● " + modelData.dirty + " изм."
                                    : "чисто"
                                color: modelData.dirty > 0
                                    ? Theme.accent
                                    : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }

                            Text {
                                width: 210
                                text: modelData.last || ""
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }
                    }

                    RowButton {
                        label: "CODE"
                        action: "code"
                        projPath: modelData.path
                        onTriggered: (act, path) => projectModel.openCode(path)
                    }

                    RowButton {
                        label: "TERM"
                        action: "term"
                        projPath: modelData.path
                        onTriggered: (act, path) => projectModel.openTerm(path)
                    }

                    RowButton {
                        label: "PULL"
                        action: "pull"
                        projPath: modelData.path
                        onTriggered: (act, path) => projectModel.gitPull(path)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: projectModel.projects.length === 0
                text: projectModel.loaded
                    ? "проектов не найдено"
                    : "ищу проекты…"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }

    Process { id: actionProc; running: false }

    QtObject {
        id: projectModel
        property var projects: []
        property bool loaded: false

        Component.onCompleted: load()

        function initials(name) {
            if (!name) return "?"
            var parts = name.trim().split(/\s+/)
            if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
        }

        function load() {
            scanProc.command = ["python3", "-c", `
import json, os, glob, subprocess

roots = [
    "~/Projects", "~/projects", "~/dev", "~/code",
    "~/src", "~/work", "~/rice", "~/git",
]
seen = set()
projects = []


def git(path, *args):
    try:
        r = subprocess.run(["git", "-C", path, *args],
                           capture_output=True, text=True, timeout=5)
        return r.stdout.strip()
    except Exception:
        return ""


def add(path):
    path = os.path.realpath(path)
    if path in seen or not os.path.isdir(os.path.join(path, ".git")):
        return
    seen.add(path)
    st = git(path, "status", "--porcelain")
    dirty = len([l for l in st.splitlines() if l.strip()])
    projects.append({
        "name": os.path.basename(path),
        "path": path,
        "branch": git(path, "rev-parse", "--abbrev-ref", "HEAD"),
        "dirty": dirty,
        "last": git(path, "log", "-1", "--pretty=%s"),
    })


for r in roots:
    r = os.path.expanduser(r)
    if os.path.isdir(r):
        add(r)  # сам корень может быть репозиторием
        for sub in sorted(glob.glob(os.path.join(r, "*"))):
            add(sub)

# заодно репозитории первого уровня прямо в домашнем каталоге
for g in sorted(glob.glob(os.path.expanduser("~/*/.git"))):
    add(os.path.dirname(g))

projects.sort(key=lambda p: p["name"].lower())
print(json.dumps(projects))
`]
            scanProc.running = true
        }

        function openCode(path) {
            actionProc.command = ["code", path]
            actionProc.running = true
        }

        function openTerm(path) {
            actionProc.command = ["kitty", "-d", path]
            actionProc.running = true
        }

        function gitPull(path) {
            actionProc.command = ["kitty", "--hold", "-d", path, "-e", "git", "pull"]
            actionProc.running = true
        }
    }

    Process {
        id: scanProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    projectModel.projects = JSON.parse(text)
                } catch (e) {
                    projectModel.projects = []
                }
                projectModel.loaded = true
            }
        }
    }
}
