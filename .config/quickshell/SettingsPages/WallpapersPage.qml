import QtQuick
import Quickshell.Io
import "../"

// ════════════════════════════════════════════════════════════════
//  WALLPAPERS — живые обои + статика фаз.
//  Живую сцену рисует Quickshell (LunarWallpaper.qml, фоновый слой),
//  фаза — по активному столу. Здесь: тумблер «живые / лёгкий режим»
//  и генерация статических PNG под разрешение (headless Chromium,
//  сайт-спека ~/.config/lunar/sait/index.html) для фолбэка.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    property string mono: "JetBrainsMono Nerd Font"
    property int rightMargin: 36

    // ── состояние ─────────────────────────────────────────────
    property string curRes: "—"           // разрешение текущего монитора
    property string genRes: "—"           // какое разрешение генерируем
    property bool busy: false
    property string log: ""
    property var sets: []                 // готовые наборы в ~/.local/share/lunar/walls

    readonly property string wallsRoot: "$HOME/.local/share/lunar/walls"

    component ActionBtn: Rectangle {
        id: btn
        property string label: ""
        property bool accent: false
        property bool enabledBtn: true
        signal clicked()

        width: Math.max(96, btnText.implicitWidth + 30)
        height: 34
        radius: Theme.radius
        color: !btn.enabledBtn ? Theme.alpha(Theme.text, 0.02)
             : btn.accent ? Theme.alpha(Theme.accent, btnMouse.containsMouse ? 0.2 : 0.12)
             : (btnMouse.containsMouse ? Theme.alpha(Theme.accent, 0.1) : Theme.alpha(Theme.text, 0.03))
        border.width: 1
        border.color: !btn.enabledBtn ? Theme.border
                    : btn.accent ? Theme.accent
                    : (btnMouse.containsMouse ? Theme.borderAccent : Theme.border)

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: !btn.enabledBtn ? Theme.textFaint
                 : btn.accent ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 1
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.enabledBtn ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: btn.enabledBtn
            onClicked: btn.clicked()
        }
    }

    // ── определение монитора ──────────────────────────────────
    Process {
        id: pRes
        running: true
        command: ["bash", "-c",
            "hyprctl monitors -j 2>/dev/null | jq -r '.[0] | \"\\(.width)x\\(.height)\"'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim()
                if (s !== "" && s !== "null") {
                    page.curRes = s
                    if (page.genRes === "—") page.genRes = s
                }
            }
        }
    }

    // ── список готовых наборов ────────────────────────────────
    Process {
        id: pSets
        command: ["bash", "-c",
            "ls -1 \"$HOME/.local/share/lunar/walls\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var s = lines[i].trim()
                    if (s !== "") out.push(s)
                }
                page.sets = out
            }
        }
    }

    // ── генерация ─────────────────────────────────────────────
    Process {
        id: pGen
        onRunningChanged: {
            if (running) { page.busy = true; page.log = "rendering " + page.genRes + "…" }
        }
        stdout: StdioCollector { onStreamFinished: page.log = text.trim() }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") page.log = text.trim() }
        onExited: {
            page.busy = false
            pSets.running = true
        }
    }

    function generate() {
        if (page.busy) return
        page.log = ""
        pGen.command = ["bash", "-c",
            "$HOME/.config/hypr/scripts/eclipse-walls-gen.sh " + page.genRes + " 2>&1 | tail -n 4"]
        pGen.running = true
    }

    function applySet(res) {
        page.log = ""
        pGen.command = ["bash", "-c",
            "$HOME/.config/hypr/scripts/eclipse-walls.sh set "
            + "\"$HOME/.local/share/lunar/walls/" + res + "\" 2>&1"]
        pGen.running = true
    }

    Component.onCompleted: {
        pSets.running = true
    }

    // ── разметка ──────────────────────────────────────────────
    Flickable {
        id: scrollArea
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: function(event) {
                var delta = event.angleDelta.y
                if (delta !== 0)
                    scrollArea.contentY = Math.max(0, Math.min(
                        scrollArea.contentHeight - scrollArea.height,
                        scrollArea.contentY - delta))
                event.accepted = true
            }
        }

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.rightMargin
            spacing: 20

            Text {
                text: "WALLPAPERS"
                color: Theme.text
                font.family: page.mono
                font.pixelSize: 18
                font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ── блок: режим обоев (живые QML / лёгкий) ──
            Row {
                width: parent.width
                spacing: 12

                Text {
                    text: "\uf03e"
                    color: Theme.accent
                    font.family: page.mono
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "live eclipse scene (QML)"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                    Text {
                        text: Theme.wallpaperLive
                            ? "звёзды, метеоры, пыль, серп — анимация включена"
                            : "лёгкий режим: без звёзд/метеоров/пыли (слабое железо)"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                // тумблер
                Rectangle {
                    id: liveToggle
                    width: 46
                    height: 24
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.wallpaperLive ? Theme.accent : Theme.trackBg
                    border.width: 1
                    border.color: Theme.wallpaperLive ? Theme.accent : Theme.border
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.wallpaperLive ? parent.width - width - 3 : 3
                        color: Theme.wallpaperLive ? Theme.bgPanel : Theme.textDim
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Theme.wallpaperLive = !Theme.wallpaperLive
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ── блок: генерация под разрешение ──
            Column {
                width: parent.width
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 16

                    Text {
                        text: "\uf03e"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "generate eclipse phases"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: "renders sait → wallpapers at the chosen resolution"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                // текущее разрешение монитора + пресеты
                Row {
                    spacing: 8

                    Repeater {
                        model: {
                            var list = []
                            if (page.curRes !== "—") list.push(page.curRes)
                            var std = ["1920x1080", "2560x1440", "3440x1440", "3840x2160"]
                            for (var i = 0; i < std.length; ++i)
                                if (std[i] !== page.curRes) list.push(std[i])
                            return list
                        }

                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool active: page.genRes === modelData

                            width: resText.implicitWidth + 26
                            height: 32
                            radius: Theme.radius
                            color: active ? Theme.alpha(Theme.accent, 0.12)
                                 : (resMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08)
                                 : Theme.alpha(Theme.text, 0.03))
                            border.width: 1
                            border.color: active ? Theme.accent
                                        : (resMouse.containsMouse ? Theme.borderAccent : Theme.border)

                            Text {
                                id: resText
                                anchors.centerIn: parent
                                text: modelData
                                color: parent.active ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.letterSpacing: 1
                            }

                            MouseArea {
                                id: resMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.genRes = modelData
                            }
                        }
                    }
                }

                Row {
                    spacing: 8

                    ActionBtn {
                        label: page.busy ? "RENDERING…" : "GENERATE"
                        accent: true
                        enabledBtn: !page.busy
                        onClicked: page.generate()
                    }
                    ActionBtn {
                        label: "REFRESH"
                        enabledBtn: !page.busy
                        onClicked: { pRes.running = true; pSets.running = true }
                    }
                }

                Text {
                    width: parent.width
                    visible: page.log !== ""
                    text: page.log
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ── блок: готовые наборы ──
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "READY SETS"
                    color: Theme.text
                    font.family: page.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }

                Text {
                    visible: page.sets.length === 0
                    text: "no generated sets yet — pick a resolution and press GENERATE"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Repeater {
                    model: page.sets

                    delegate: Rectangle {
                        required property string modelData
                        width: contentColumn.width
                        height: 46
                        radius: Theme.radius
                        color: setMouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : Theme.alpha(Theme.text, 0.025)
                        border.width: 1
                        border.color: setMouse.containsMouse ? Theme.borderAccent : Theme.border

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                text: "\uf03e"
                                color: Theme.textDim
                                font.family: page.mono
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: setMouse.containsMouse ? "APPLY" : ""
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }

                        MouseArea {
                            id: setMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.applySet(modelData)
                        }
                    }
                }
            }
        }
    }
}
