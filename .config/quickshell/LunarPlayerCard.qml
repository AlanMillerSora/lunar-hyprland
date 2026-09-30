import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarPlayerCard — карточка плеера отдельным окном ровно по размеру.
//  Смысл разделения: Hyprland блюрит слой целиком, поэтому «стекло»
//  дёшево только на маленькой поверхности (правило lunar-player-card).
//  Состояние (открыт, страница) — в Theme.playerOpen/playerPage.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    // центрирую карточку: окно ровно по её размеру, отступы = половина свободного
    readonly property var scr: screen ? screen
        : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    width: Math.min(1180, (scr ? scr.width : 1180) - 120)
    height: Math.min(740, (scr ? scr.height : 740) - 120)
    anchors { top: true; left: true }
    margins.top: scr ? Math.max(0, Math.round((scr.height - height) / 2)) : 0
    margins.left: scr ? Math.max(0, Math.round((scr.width - width) / 2)) : 0

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lunar-player-card"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? card : null }

    // окно держу mapped, пока идёт анимация закрытия, — иначе fade не видно,
    // а пока закрыто, его не рендерит и не блюрит композитор (0 к GPU)
    visible: root.showing || card.opacity > 0.01

    readonly property bool showing: Theme.playerOpen
    readonly property int pageIndex: Theme.playerPage

    property var pages: [
        { name: "СЕЙЧАС",   icon: "\uf001", source: "PlayerNowPlaying.qml" },
        { name: "ОЧЕРЕДЬ",  icon: "\uf03a", source: "PlayerQueue.qml" },
        { name: "ПОИСК",    icon: "\uf002", source: "PlayerSearch.qml" },
        { name: "ЛОКАЛЬНЫЕ", icon: "\uf07b", source: "PlayerLibrary.qml" }
    ]

    function goto(i) { Theme.playerPage = Math.max(0, Math.min(pages.length - 1, i)) }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radiusL
        color: Theme.bgPanel
        border.color: Theme.borderAccent
        border.width: 1

        // невидимую карточку не рендерю: обложки/MultiEffect не грузят GPU
        visible: opacity > 0.01
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

        focus: root.showing
        Keys.onEscapePressed: Theme.playerOpen = false
        Keys.onSpacePressed: PlayerCore.toggle()
        Keys.onLeftPressed: PlayerCore.seekBy(-5)
        Keys.onRightPressed: PlayerCore.seekBy(5)
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_N) { PlayerCore.next(); e.accepted = true }
            else if (e.key === Qt.Key_P) { PlayerCore.prev(); e.accepted = true }
        }

        HudCorners { color: Theme.accent; size: 16; thickness: 1; margin: 10 }

        // клик по карточке не проваливается на подложку и возвращает фокус
        MouseArea { anchors.fill: parent; onClicked: card.forceActiveFocus() }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

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
                                            return root.showing && root.pageIndex === pageWrap.index
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
                active: root.showing
                onExpandRequested: root.goto(0)
            }
        }
    }
}
