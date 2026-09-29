import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../"

// ════════════════════════════════════════════════════════════════
//  WALLPAPERS — живые обои (QML-сцена).
//  Сцену рисует Quickshell (LunarWallpaper.qml, фоновый слой),
//  фаза — по активному столу. Здесь: живое превью фаз и тумблер
//  «живые / лёгкий режим».
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    property string mono: "JetBrainsMono Nerd Font"
    property int rightMargin: 36

    // живое превью обоев: показываем фазу активного стола (или выбранную)
    readonly property var ws: Hyprland.activeWorkspace || Hyprland.focusedWorkspace
    // L40: фаза — строго номер стола 1..9. Специальные/внемерные столы
    // не мапим молча: берём focusedWorkspace, иначе фазу 5 (затмение).
    readonly property int activePhase: {
        var id = ws ? ws.id : 0
        if (id >= 1 && id <= 9)
            return id
        var f = Hyprland.focusedWorkspace
        if (f && f.id >= 1 && f.id <= 9)
            return f.id
        return 5
    }
    property int previewPhase: -1
    readonly property int shownPhase: previewPhase > 0 ? previewPhase : activePhase

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
                // L33: пустые/горизонтальные события не съедаем
                if (delta === 0)
                    return
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

            // ── блок: живое превью обоев ──
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: previewPhase > 0
                        ? "ПРЕВЬЮ · фаза " + shownPhase
                        : "ПРЕВЬЮ · фаза " + shownPhase + " (текущий стол)"
                    color: Theme.textFaint
                    font.family: page.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }

                // 16:9 мини-экран с живой сценой
                Item {
                    width: Math.min(parent.width, 512)
                    height: width * 9 / 16
                    clip: true

                    LunarWallpaperScene {
                        anchors.fill: parent
                        phase: page.shownPhase
                        live: true
                        optimize: true
                        tickMs: 33
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.radius
                        border.color: Theme.border
                        border.width: 1
                    }
                }

                // выбор фазы (1..9) — какой стол показать в превью
                Row {
                    spacing: 6

                    Repeater {
                        model: 9

                        delegate: Rectangle {
                            required property int index
                            readonly property int ph: index + 1
                            width: 30
                            height: 24
                            radius: Theme.radius
                            color: page.shownPhase === ph
                                ? Theme.active
                                : (phMouse.containsMouse ? Theme.hoverStrong : Theme.fill)
                            border.width: 1
                            border.color: page.shownPhase === ph ? Theme.accent : Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: index + 1
                                color: page.shownPhase === ph ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: phMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.previewPhase = page.previewPhase === ph ? -1 : ph
                            }
                        }
                    }
                }
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
                            : "лёгкий режим: без звёзд/метеоров/пыли"
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

        }
    }
}
