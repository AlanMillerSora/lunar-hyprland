import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import QtQuick.Layouts

Item {
    id: page

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // Заголовок страницы — как в остальных разделах настроек
        Row {
            Layout.fillWidth: true
            height: 36

            Text {
                text: "LAUNCH"
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
                onTextChanged: appModel.update()
                onAccepted: appModel.launchFirst()

                Text {
                    anchors.fill: parent
                    text: "поиск приложений"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    visible: search.text === "" && !search.activeFocus
                }
            }
        }

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
                // язык карточек из настроек: тонкая рамка + едва заметная заливка
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

                        // настоящая иконка приложения из темы значков (Adwaita),
                        // а «инициалы» — только запасной вариант, если иконки нет
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
        }

        Text {
            text: appModel.apps.length + " приложений"
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: 9
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
        except: continue
        if entry.get("NoDisplay") == "true" or not entry.get("Name"):
            continue
        name = entry["Name"]
        low = name.lower()
        if "avahi" in low or "bluetooth adapter" in low:
            continue
        exec_cmd = entry.get("Exec", "").replace("%f", "").replace("%F", "").replace("%u", "").replace("%U", "").replace("%i", "").replace("%c", "").replace("%k", "").strip()
        apps.append({"id": os.path.splitext(os.path.basename(f))[0], "name": name, "exec": exec_cmd, "icon": entry.get("Icon", "")})
print(json.dumps(apps))
`]
            proc.running = true
        }

        function update() {
            var f = filter.toLowerCase()
            apps = allApps.filter(function(a) {
                return f === "" || (a.name + " " + a.id).toLowerCase().includes(f)
            })
            grid.currentIndex = 0
        }

        function launch(app) {
            launchProc.command = ["bash", "-c", "exec " + app.exec]
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
}
