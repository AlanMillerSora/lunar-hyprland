import QtQuick
import Quickshell.Io
import "../"

// ════════════════════════════════════════════════════════════════
//  USER — аватар пользователя: показ, смена и обрезка.
//  «СМЕНИТЬ АВАТАР»: Hub сворачивается → zenity выбирает файл → Hub
//  открывается обратно и показывает обрезку (перетаскивание + зум),
//  затем СОХРАНИТЬ кладёт круглый аватар и синкает его с экраном входа.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    property string mono: "JetBrainsMono Nerd Font"
    property int rightMargin: 36
    property string homeDir: ""
    property int refresh: 0

    readonly property string avatarPath: homeDir + "/.config/avatars/avatar.png"
    readonly property string sourcePath: homeDir + "/.cache/lunar/avatar-source"
    readonly property string script: homeDir + "/.config/hypr/scripts/eclipse-avatar.sh"

    // ── кроп ──
    readonly property real viewSize: 260
    property bool cropping: false
    property string cropError: ""
    property int srcTick: 0
    property real srcW: 1
    property real srcH: 1
    property real baseScale: 1
    property real zoom: 1
    property real tx: 0
    property real ty: 0
    readonly property real dispScale: baseScale * zoom

    function resetView() {
        if (srcW <= 1 || srcH <= 1)
            return
        baseScale = Math.max(viewSize / srcW, viewSize / srcH)
        zoom = 1
        tx = (viewSize - srcW * baseScale) / 2
        ty = (viewSize - srcH * baseScale) / 2
    }

    function clampView() {
        var minX = viewSize - srcW * dispScale
        var minY = viewSize - srcH * dispScale
        tx = Math.max(minX, Math.min(0, tx))
        ty = Math.max(minY, Math.min(0, ty))
    }

    function pan(dx, dy) {
        tx += dx
        ty += dy
        clampView()
    }

    function setZoom(z) {
        z = Math.max(1, Math.min(4, z))
        var cx = viewSize / 2 - tx
        var cy = viewSize / 2 - ty
        var old = dispScale
        zoom = z
        var k = dispScale / old
        tx = viewSize / 2 - cx * k
        ty = viewSize / 2 - cy * k
        clampView()
    }

    function applyCrop() {
        var cs = Math.max(1, Math.round(viewSize / dispScale))
        var cx = Math.round(-tx / dispScale)
        var cy = Math.round(-ty / dispScale)
        cx = Math.max(0, Math.min(Math.round(srcW) - cs, cx))
        cy = Math.max(0, Math.min(Math.round(srcH) - cs, cy))
        // M41: путь скрипта — аргументом, без shell и склейки строк
        pApply.command = ["bash", page.script, "apply",
            String(cs), String(cx), String(cy)]
        pApply.running = true
    }

    Process {
        id: pHome
        command: ["sh", "-c", "printf '%s' \"$HOME\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: page.homeDir = text.trim()
        }
    }

    // Hub закрывается → zenity → Hub открывается обратно
    Process {
        id: pPick
        running: false
        // M78: trap EXIT гарантирует возврат Hub даже при сбое/прерывании
        command: ["bash", "-c",
            "trap 'qs ipc call hub open' EXIT; " +
            "qs ipc call hub close; sleep 0.25; " +
            "\"$HOME/.config/hypr/scripts/eclipse-avatar.sh\" pick"]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                page.cropping = true
                page.srcTick++
            }
        }
    }

    Process {
        id: pApply
        running: false
        command: ["bash", "-c", "true"]
        onExited: {
            page.cropping = false
            page.refresh++
        }
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.rightMargin
            spacing: 20

            Text {
                text: "USER"
                color: Theme.text
                font.family: page.mono
                font.pixelSize: 18
                font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ── обычный вид: аватар и кнопка ──
            Column {
                visible: !page.cropping
                spacing: 20

                Image {
                    width: 200
                    height: 200
                    source: page.homeDir !== ""
                        ? "file://" + page.avatarPath + "?v=" + page.refresh : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                Rectangle {
                    width: Math.max(170, changeText.implicitWidth + 36)
                    height: 38
                    radius: Theme.radius
                    color: changeArea.containsMouse ? Theme.active : "transparent"
                    border.width: 1
                    border.color: changeArea.containsMouse ? Theme.accent : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: changeText
                        anchors.centerIn: parent
                        text: pPick.running ? "ВЫБИРАЮ…" : "СМЕНИТЬ АВАТАР"
                        color: changeArea.containsMouse ? Theme.accent : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.letterSpacing: 2
                    }
                    MouseArea {
                        id: changeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !pPick.running
                        onClicked: pPick.running = true
                    }
                }

                Text {
                    visible: page.cropError !== ""
                    width: parent.width
                    text: page.cropError
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }

            // ── вид обрезки ──
            Column {
                visible: page.cropping
                spacing: 16

                Text {
                    text: "ОБРЕЗКА · перетащи мышью, колесо — масштаб"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }

                Item {
                    id: cropArea
                    width: page.viewSize
                    height: page.viewSize
                    clip: true

                    Image {
                        id: srcImg
                        source: page.cropping
                            ? "file://" + page.sourcePath + "?t=" + page.srcTick : ""
                        x: page.tx
                        y: page.ty
                        width: page.srcW * page.dispScale
                        height: page.srcH * page.dispScale
                        smooth: true
                        asynchronous: true
                        onStatusChanged: {
                            if (status === Image.Ready) {
                                page.cropError = ""
                                page.srcW = sourceSize.width
                                page.srcH = sourceSize.height
                                page.resetView()
                            } else if (status === Image.Error) {
                                // M79: битый файл — не оставляем пустой экран обрезки
                                page.cropError = "Не удалось открыть изображение — попробуй другой файл"
                                page.cropping = false
                            }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: "../assets/crop-frame.png"
                        smooth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: Qt.OpenHandCursor
                        property real lx: 0
                        property real ly: 0
                        onPressed: (mouse) => { lx = mouse.x; ly = mouse.y }
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                page.pan(mouse.x - lx, mouse.y - ly)
                                lx = mouse.x
                                ly = mouse.y
                            }
                        }
                    }

                    WheelHandler {
                        onWheel: function(event) {
                            page.setZoom(page.zoom * (event.angleDelta.y > 0 ? 1.1 : 1 / 1.1))
                            event.accepted = true
                        }
                    }
                }

                Row {
                    spacing: 14

                    Rectangle {
                        width: 150
                        height: 38
                        radius: Theme.radius
                        color: saveArea.containsMouse ? Theme.active : "transparent"
                        border.width: 1
                        border.color: saveArea.containsMouse ? Theme.accent : Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: pApply.running ? "СОХРАНЯЮ…" : "СОХРАНИТЬ"
                            color: saveArea.containsMouse ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.letterSpacing: 2
                        }
                        MouseArea {
                            id: saveArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !pApply.running
                            onClicked: page.applyCrop()
                        }
                    }

                    Rectangle {
                        width: 130
                        height: 38
                        radius: Theme.radius
                        color: cancelArea.containsMouse ? Theme.active : "transparent"
                        border.width: 1
                        border.color: cancelArea.containsMouse ? Theme.accent : Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: "ОТМЕНА"
                            color: cancelArea.containsMouse ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.letterSpacing: 2
                        }
                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.cropping = false
                        }
                    }
                }
            }
        }
    }
}
