import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  DevPage — раздел «Разработка» в Hub.
//  Сам находит git-репозитории в домашних каталогах проектов и
//  показывает ветку, изменения и последний коммит.
//  Кнопка GIT открывает панель: ветки, коммит, diff, pull, push.
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

        width: 64
        height: 32
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
            font.pixelSize: 10
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

    // ── состояние git-панели ───────────────────────────────────
    property var gitProject: null
    property bool gitOpen: false
    property var gitBranches: []
    property string gitOut: ""
    property string commitMsg: ""

    function shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function openGit(p) {
        gitProject = p
        gitOpen = true
        commitMsg = ""
        gitOut = "загрузка…"
        gitBranches = []
        refreshGit()
    }

    function refreshGit() {
        if (!gitProject)
            return
        gitProc.action = "refresh"
        gitProc.command = ["bash", "-c",
            "cd " + shq(gitProject.path) + " && " +
            "echo '###BRANCHES###' && git for-each-ref --format='%(refname:short)|%(HEAD)' refs/heads && " +
            "echo '###STATUS###' && git status --short && " +
            "echo '###DIFF###' && git diff --stat 2>&1"]
        gitProc.running = true
    }

    function gitRun(action, cmd) {
        if (!gitProject)
            return
        gitProc.action = action
        gitProc.command = ["bash", "-c", "cd " + shq(gitProject.path) + " && " + cmd + " 2>&1"]
        gitProc.running = true
    }

    function switchBranch(branch) {
        gitRun("switch", "git checkout " + shq(branch))
    }

    function commitChanges() {
        if (commitMsg.trim() === "")
            return
        gitRun("commit", "git add -A && git commit -m " + shq(commitMsg))
    }

    function gitPull() {
        gitRun("pull", "GIT_TERMINAL_PROMPT=0 git pull")
    }

    function gitPush() {
        gitRun("push", "GIT_TERMINAL_PROMPT=0 git push")
    }

    function gitDiff() {
        gitRun("diff", "git --no-pager diff")
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
            height: 38
            spacing: 8

            Repeater {
                model: [
                    { label: "VS CODE",  action: "code" },
                    { label: "ТЕРМИНАЛ", action: "term" },
                    { label: "ОБНОВИТЬ", action: "refresh" }
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: 122
                    height: 38
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
                        font.pixelSize: 11
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
                                width: 190
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
                        label: "GIT"
                        action: "git"
                        projPath: modelData.path
                        onTriggered: (act, path) => page.openGit(modelData)
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

    // ── git-панель ─────────────────────────────────────────────
    Rectangle {
        id: gitOverlay

        anchors.fill: parent
        visible: page.gitOpen
        z: 10
        radius: Theme.radius
        color: Theme.bgPanel
        border.width: 1
        border.color: Theme.accent

        // перехват кликов по фону
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // заголовок
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: page.gitProject ? page.gitProject.name : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.letterSpacing: 2
                }

                Text {
                    Layout.fillWidth: true
                    text: page.gitProject ? page.gitProject.path : ""
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                }

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Theme.radius
                    color: closeMouse.containsMouse
                        ? Theme.alpha(Theme.danger, 0.15)
                        : "transparent"
                    border.width: 1
                    border.color: closeMouse.containsMouse
                        ? Theme.danger
                        : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: closeMouse.containsMouse
                            ? Theme.danger
                            : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.gitOpen = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            // ветки
            Text {
                text: "ВЕТКИ"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 2
            }

            Flow {
                id: branchFlow
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(implicitHeight, 78)
                spacing: 6

                Repeater {
                    model: page.gitBranches

                    delegate: Rectangle {
                        required property var modelData

                        width: branchLabel.implicitWidth + 20
                        height: 30
                        radius: Theme.radius

                        color: modelData.current
                            ? Theme.alpha(Theme.accent, 0.14)
                            : Theme.alpha(Theme.text, 0.03)

                        border.width: 1
                        border.color: modelData.current
                            ? Theme.accent
                            : Theme.border

                        Text {
                            id: branchLabel
                            anchors.centerIn: parent
                            text: (modelData.current ? "● " : "") + modelData.name
                            color: modelData.current ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !modelData.current
                            onClicked: page.switchBranch(modelData.name)
                        }
                    }
                }
            }

            // коммит
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Theme.radius
                    color: Theme.bgCard
                    border.width: 1
                    border.color: msgInput.activeFocus ? Theme.borderAccent : Theme.border

                    TextInput {
                        id: msgInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        clip: true
                        focus: page.gitOpen
                        onTextChanged: page.commitMsg = text
                        Keys.onEscapePressed: page.gitOpen = false
                        Keys.onReturnPressed: page.commitChanges()

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "сообщение коммита…"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            visible: msgInput.text === ""
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 36
                    radius: Theme.radius
                    color: commitMouse.containsMouse
                        ? Theme.alpha(Theme.accent, 0.14)
                        : "transparent"
                    border.width: 1
                    border.color: commitMouse.containsMouse
                        ? Theme.accent
                        : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "COMMIT"
                        color: commitMouse.containsMouse ? Theme.accent : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        id: commitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.commitChanges()
                    }
                }
            }

            // действия
            Row {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { label: "DIFF",     action: "diff" },
                        { label: "PULL",     action: "pull" },
                        { label: "PUSH",     action: "push" },
                        { label: "ОБНОВИТЬ", action: "refresh" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width: 100
                        height: 34
                        radius: Theme.radius

                        color: actMouse.containsMouse
                            ? Theme.alpha(Theme.accent, 0.10)
                            : "transparent"

                        border.width: 1
                        border.color: actMouse.containsMouse
                            ? Theme.borderAccent
                            : Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: actMouse.containsMouse ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }

                        MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (modelData.action === "diff")
                                    page.gitDiff()
                                else if (modelData.action === "pull")
                                    page.gitPull()
                                else if (modelData.action === "push")
                                    page.gitPush()
                                else
                                    page.refreshGit()
                            }
                        }
                    }
                }
            }

            // вывод git
            Text {
                text: "ВЫВОД"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 2
            }

            Flickable {
                id: outScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: gitOutText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    onWheel: function(event) {
                        var d = event.angleDelta.y
                        if (d !== 0) {
                            outScroll.contentY = Math.max(0, Math.min(
                                outScroll.contentHeight - outScroll.height,
                                outScroll.contentY - d))
                        }
                        event.accepted = true
                    }
                }

                Text {
                    id: gitOutText
                    width: outScroll.width
                    text: page.gitOut === "" ? "—" : page.gitOut
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.NoWrap
                }
            }
        }
    }

    Process { id: actionProc; running: false }

    Process {
        id: gitProc
        running: false
        property string action: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var t = text

                if (gitProc.action === "refresh") {
                    var parts = t.split(/###BRANCHES###\n|###STATUS###\n|###DIFF###\n/)
                    var branches = []
                    ;(parts[1] || "").trim().split("\n").forEach(function(l) {
                        l = l.trim()
                        if (l === "") return
                        var i = l.indexOf("|")
                        var name = i >= 0 ? l.slice(0, i) : l
                        var cur = i >= 0 ? l.slice(i + 1).trim() === "*" : false
                        branches.push({ name: name, current: cur })
                    })
                    page.gitBranches = branches

                    var status = (parts[2] || "").trim()
                    var diff = (parts[3] || "").trim()
                    page.gitOut = status === "" && diff === ""
                        ? "рабочее дерево чистое"
                        : (status + (diff ? "\n\n" + diff : ""))
                } else {
                    page.gitOut = t.trim() === "" ? "готово" : t.trim()
                }
            }
        }

        onExited: {
            if (["commit", "switch", "pull", "push"].indexOf(gitProc.action) >= 0) {
                page.refreshGit()
                projectModel.load()
            }
        }
    }

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
