import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarPlayer — плеер обычным окном (FloatingWindow). Hyprland сам
//  даёт тянуть за края, двигать, блюрит (окно полупрозрачное) и
//  скругляет (правило в hyprland.lua по заголовку «Lunar Player»).
//  Так честнее: это не слой — раньше полноэкранный слой с блюром
//  съедал GPU (до +34%).
//  IPC:  qs ipc call player toggle|open|close|nav N
// ════════════════════════════════════════════════════════════════
FloatingWindow {
    id: root

    title: "Lunar Player"
    color: Theme.bgPanel          // полупрозрачный фон — его и блюрит Hyprland
    visible: Theme.playerOpen
    implicitWidth: 1180
    implicitHeight: 740
    minimumSize: Qt.size(720, 460)

    readonly property int pageIndex: Theme.playerPage

    property var pages: [
        { name: "СЕЙЧАС",   icon: "\uf001", source: "PlayerNowPlaying.qml" },
        { name: "ОЧЕРЕДЬ",  icon: "\uf03a", source: "PlayerQueue.qml" },
        { name: "ПОИСК",    icon: "\uf002", source: "PlayerSearch.qml" },
        { name: "ЛОКАЛЬНЫЕ", icon: "\uf07b", source: "PlayerLibrary.qml" }
    ]

    function goto(i) { Theme.playerPage = Math.max(0, Math.min(pages.length - 1, i)) }

    // mpv поднимаю лениво, только когда реально открываю плеер
    function openPanel() { PlayerCore.ensurePlayer(); Theme.playerOpen = true }
    function closePanel() {
        Theme.playerOpen = false
        // закрыл и ничего не играет — демон больше не нужен, гашу (освободит память)
        PlayerCore.maybeStopDaemon()
    }
    function toggle() { Theme.playerOpen ? closePanel() : openPanel() }
    function nav(i) { goto(i) }

    // модальные оверлеи взаимоисключающие (как Hub/Agent): показался плеер —
    // гашу Hub, открылся Hub — гашу плеер, всё в одном процессе и плавно
    onVisibleChanged: if (visible) Theme.activeOverlay = "player"
    Connections {
        target: Theme
        function onActiveOverlayChanged() {
            if (Theme.activeOverlay !== "player" && root.visible)
                root.closePanel()
        }
    }

    IpcHandler {
        target: "player"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
        function nav(i: int): void { root.nav(i) }
    }

    // клавиатура обычного окна
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closePanel()
        Keys.onSpacePressed: PlayerCore.toggle()
        Keys.onLeftPressed: PlayerCore.seekBy(-5)
        Keys.onRightPressed: PlayerCore.seekBy(5)
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_N) { PlayerCore.next(); e.accepted = true }
            else if (e.key === Qt.Key_P) { PlayerCore.prev(); e.accepted = true }
        }

        HudCorners { color: Theme.accent; size: 16; thickness: 1; margin: 10 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 22

                // ── навигация ──
                Item {
                    Layout.preferredWidth: 176
                    Layout.fillHeight: true

                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "LUNAR PLAYER"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(16)
                            font.bold: true
                            font.letterSpacing: 3
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.border
                        }

                        Item { width: 1; height: 8 }

                        Repeater {
                            model: root.pages

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 42
                                radius: Theme.radius
                                color: root.pageIndex === index
                                    ? Theme.active
                                    : (navMouse.containsMouse ? Theme.hover : "transparent")
                                border.width: root.pageIndex === index ? 1 : 0
                                border.color: Theme.alpha(Theme.accent, 0.5)

                                Rectangle {
                                    visible: root.pageIndex === index
                                    width: 3
                                    height: parent.height - 12
                                    radius: 1.5
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    color: Theme.accent
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    spacing: 12

                                    Text {
                                        text: modelData.icon
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.fontSize(14)
                                        color: root.pageIndex === index ? Theme.accent : Theme.textDim
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.letterSpacing: 1
                                        color: root.pageIndex === index ? Theme.text : Theme.textDim
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.goto(index)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Theme.border
                }

                // ── страница: Loader'ы живут постоянно, видна только текущая ──
                Item {
                    id: pageHost
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Repeater {
                        model: root.pages

                        delegate: Item {
                            id: pageWrap
                            required property var modelData
                            required property int index

                            anchors.fill: parent
                            visible: opacity > 0.01
                            opacity: root.pageIndex === index ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
                            }

                            Loader {
                                id: pageLoader
                                anchors.fill: parent
                                source: modelData.source
                                // страница сама решает, когда запускать cava и крутить винил
                                onLoaded: {
                                    if (item)
                                        item.pageActive = Qt.binding(function() {
                                            return root.visible && root.pageIndex === pageWrap.index
                                        })
                                }
                            }
                        }
                    }
                }
            }

            // ── нижняя полоса ──
            PlayerBar {
                Layout.fillWidth: true
                active: root.visible
                onExpandRequested: root.goto(0)
            }
        }
    }
}
