import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../widgets/shared"
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  DevPage — раздел «Разработка» в Hub.
//  Сам находит git-репозитории в домашних каталогах проектов и
//  показывает ветку, изменения и последний коммит.
//  Кнопка GIT открывает панель: ветки, коммит, diff, pull, push.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    // Hub держит страницу в кэше (не пересоздаёт при переходе вкладок),
    // поэтому репозитории пересканирую сам при возврате. До первой загрузки
    // не дёргаю — её делает Component.onCompleted у projectModel.
    onVisibleChanged: if (visible && projectModel.loaded) projectModel.load()

    // ── состояние git-панели ───────────────────────────────────
    property var gitProject: null
    property bool gitOpen: false
    property var gitBranches: []
    property string gitOut: ""
    property string commitMsg: ""
    // H21: очередь git-действий — один Process не должен терять команды
    property var gitQueue: []
    // L37-подобно: повторный refresh, если он пришёл во время работы
    property bool gitRefreshAgain: false

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
        // H21: у refresh — отдельный Process, он не мешает действиям
        if (gitProc.running) {
            gitRefreshAgain = true
            return
        }
        gitRefreshAgain = false
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
        var job = { action: action, cmd: cmd, path: gitProject.path }
        // H21: действие уже идёт — ставим в очередь, а не переписываем команду
        if (gitActionProc.running) {
            var q = gitQueue.slice()
            q.push(job)
            gitQueue = q
            return
        }
        startGitJob(job)
    }

    function startGitJob(job) {
        gitActionProc.action = job.action
        gitActionProc.command = ["bash", "-c",
            "cd " + shq(job.path) + " && " + job.cmd + " 2>&1"]
        gitActionProc.running = true
    }

    function runNextGitJob() {
        if (gitQueue.length === 0)
            return
        var q = gitQueue.slice()
        var job = q.shift()
        gitQueue = q
        startGitJob(job)
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
        // H22: полный diff может быть в мегабайты — обрезаем, чтобы не
        // вешать отрисовку одним гигантским Text
        gitRun("diff", "git --no-pager diff | head -c 200000")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space4

        // ── шапка ──────────────────────────────────────────────
        Row {
            Layout.fillWidth: true
            height: Theme.headerH
            spacing: Theme.space3

            Text {
                text: "DEVELOPMENT"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: projectModel.loaded
                    ? projectModel.projects.length + " проектов"
                    : "поиск…"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMicro
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
            height: Theme.rowH
            spacing: Theme.space2

            Repeater {
                model: [
                    { label: "VS CODE",  action: "code" },
                    { label: "ТЕРМИНАЛ", action: "term" },
                    { label: "ОБНОВИТЬ", action: "refresh" }
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: 122
                    height: Theme.rowH
                    radius: Theme.radius

                    color: quickMouse.containsMouse
                        ? Theme.hoverStrong
                        : Theme.fill

                    // кнопка быстрого действия: рамка — аффорданс, оставляю
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
                        font.pixelSize: Theme.fontTiny
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
                height: Theme.rowHComfy
                radius: Theme.radius

                // статичная строка: фон вместо рамки (этап «воздух»)
                color: rowMouse.containsMouse
                    ? Theme.hoverStrong
                    : Theme.fill

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
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    spacing: Theme.space3

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: Theme.radius
                        // статичный бейдж инициалов: фон вместо рамки
                        color: Theme.hoverStrong

                        Text {
                            anchors.centerIn: parent
                            text: projectModel.initials(modelData.name)
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
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
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: Theme.space2

                            Text {
                                text: "󰓁 " + (modelData.branch || "—")
                                color: Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontMicro
                            }

                            Text {
                                text: modelData.dirty > 0
                                    ? "● " + modelData.dirty + " изм."
                                    : "чисто"
                                color: modelData.dirty > 0
                                    ? Theme.accent
                                    : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontMicro
                            }

                            Text {
                                width: 190
                                text: modelData.last || ""
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontMicro
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // в RowLayout ширину задаёт Layout.preferredWidth, а не
                    // width: иначе implicitWidth кнопки (120) побеждает и она распухает
                    ActionButton {
                        label: "CODE"
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: Theme.rowHCompact
                        fontSize: 10
                        onClicked: projectModel.openCode(modelData.path)
                    }

                    ActionButton {
                        label: "TERM"
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: Theme.rowHCompact
                        fontSize: 10
                        onClicked: projectModel.openTerm(modelData.path)
                    }

                    ActionButton {
                        label: "GIT"
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: Theme.rowHCompact
                        fontSize: 10
                        onClicked: page.openGit(modelData)
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
                font.pixelSize: Theme.fontTiny
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
        color: Theme.surfacePanel
        // акцентная рамка — граница панели над списком, оставляю
        border.width: 1
        border.color: Theme.accent

        // перехват кликов по фону
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.space4
            spacing: Theme.space3

            // заголовок
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3

                SectionHeader { text: page.gitProject ? page.gitProject.name : ""; textColor: Theme.text; size: Theme.fontSmall; bold: true }

                Text {
                    Layout.fillWidth: true
                    text: page.gitProject ? page.gitProject.path : ""
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMicro
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
                        text: "󰅖"
                        color: closeMouse.containsMouse
                            ? Theme.danger
                            : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSmall
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
            SectionHeader { text: "ВЕТКИ"; textColor: Theme.text; size: Theme.fontSmall; bold: true }

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
                        height: Theme.rowHCompact
                        radius: Theme.radius

                        color: modelData.current
                            ? Theme.active
                            : Theme.fill

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
                            font.pixelSize: Theme.fontTiny
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
                spacing: Theme.space2

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.rowH
                    radius: Theme.radius
                    // поле ввода коммита: рамка — аффорданс, оставляю
                    color: Theme.bgCard
                    border.width: 1
                    border.color: msgInput.activeFocus ? Theme.borderAccent : Theme.border

                    // L34: плейсхолдер — сосед TextInput (объявлен раньше,
                    // значит ниже по z и не перехватывает клики/фокус)
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space3
                        anchors.rightMargin: Theme.space3
                        verticalAlignment: Text.AlignVCenter
                        text: "сообщение коммита…"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        visible: msgInput.text === ""
                    }

                    TextInput {
                        id: msgInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space3
                        anchors.rightMargin: Theme.space3
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                        clip: true
                        focus: page.gitOpen
                        onTextChanged: page.commitMsg = text
                        Keys.onEscapePressed: page.gitOpen = false
                        Keys.onReturnPressed: page.commitChanges()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: Theme.rowH
                    radius: Theme.radius
                    color: commitMouse.containsMouse
                        ? Theme.active
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
                        font.pixelSize: Theme.fontTiny
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
                spacing: Theme.space2

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
                        height: Theme.rowHCompact
                        radius: Theme.radius

                        color: actMouse.containsMouse
                            ? Theme.active
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
                            font.pixelSize: Theme.fontTiny
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
            SectionHeader { text: "ВЫВОД"; textColor: Theme.text; size: Theme.fontSmall; bold: true }

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
                    font.pixelSize: Theme.fontSize(10)
                    wrapMode: Text.NoWrap
                }
            }
        }
    }

    Process { id: actionProc; running: false }

    // H21: refresh — свой Process (разбор веток/статуса), действия — отдельный
    Process {
        id: gitProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var t = text
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
            }
        }

        onExited: {
            if (page.gitRefreshAgain)
                page.refreshGit()
        }
    }

    // действия: commit/switch/pull/push/diff
    Process {
        id: gitActionProc
        running: false
        property string action: ""

        stdout: StdioCollector { id: gitActOut }
        stderr: StdioCollector { id: gitActErr }

        onExited: (exitCode) => {
            var t = gitActOut.text.trim()
            var e = gitActErr.text.trim()
            if (t === "" && e !== "")
                t = e
            // M52: при неудаче не пересканируем все проекты — показываем ошибку
            if (exitCode !== 0) {
                page.gitOut = t === ""
                    ? "ошибка git (код " + exitCode + ")"
                    : "ошибка git (код " + exitCode + "):\n" + t
            } else {
                page.gitOut = t === "" ? "готово" : t
                if (["commit", "switch", "pull", "push"].indexOf(gitActionProc.action) >= 0) {
                    page.refreshGit()
                    projectModel.load()
                }
            }
            page.runNextGitJob()
        }
    }

    QtObject {
        id: projectModel
        property var projects: []
        property bool loaded: false
        // M51: скан уже идёт, а попросили ещё — повторим после него
        property bool scanAgain: false

        Component.onCompleted: load()

        function initials(name) {
            if (!name) return "?"
            var parts = name.trim().split(/\s+/)
            if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
        }

        function load() {
            // M51: во время скана кнопка «ОБНОВИТЬ» не должна молча теряться
            if (scanProc.running) {
                scanAgain = true
                return
            }
            scanAgain = false
            scanProc.command = ["python3", "-c", `
import json, os, glob, subprocess

roots = [
    "~/Projects", "~/projects", "~/dev", "~/code",
    "~/src", "~/work", "~/rice", "~/git",
]
MAX = 60
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
    if len(projects) >= MAX:
        return
    path = os.path.realpath(path)
    if path in seen or not os.path.isdir(os.path.join(path, ".git")):
        return
    seen.add(path)
    # одна команда git даёт и ветку, и число изменений
    st = git(path, "status", "--porcelain", "--branch")
    lines = st.splitlines()
    branch = ""
    if lines and lines[0].startswith("## "):
        branch = lines[0][3:].split("...")[0].strip()
        lines = lines[1:]
    dirty = len([l for l in lines if l.strip()])
    projects.append({
        "name": os.path.basename(path),
        "path": path,
        "branch": branch,
        "dirty": dirty,
        "last": git(path, "log", "-1", "--pretty=%s"),
    })


for r in roots:
    if len(projects) >= MAX:
        break
    r = os.path.expanduser(r)
    if os.path.isdir(r):
        add(r)  # сам корень может быть репозиторием
        for sub in sorted(glob.glob(os.path.join(r, "*"))):
            if len(projects) >= MAX:
                break
            add(sub)

# заодно репозитории первого уровня прямо в домашнем каталоге
for g in sorted(glob.glob(os.path.expanduser("~/*/.git"))):
    if len(projects) >= MAX:
        break
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

        onExited: {
            if (projectModel.scanAgain) {
                projectModel.scanAgain = false
                projectModel.load()
            }
        }
    }

    // M51: не оставляем висящий скан git при уходе со страницы
    Component.onDestruction: scanProc.running = false
}
