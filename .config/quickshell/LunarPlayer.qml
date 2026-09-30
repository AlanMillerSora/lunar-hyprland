import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// ════════════════════════════════════════════════════════════════
//  LunarPlayer — подложка-затемнение плеера и хозяин его состояния.
//  Сама карточка живёт отдельным окном (LunarPlayerCard ровно по размеру):
//  так Hyprland блюрит только её (~0.9 Мп), а не весь экран — на fullscreen
//  блюр уходило с ~20% до ~54% GPU. Фокус клавиатуры держит карточка.
//  IPC:  qs ipc call player toggle|open|close|nav N
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lunar-player"
    // клавиатуру берёт карточка — тут только затемнение
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: root.showing ? backdrop : null }

    readonly property bool showing: Theme.playerOpen

    // mpv поднимаю лениво, только когда реально открываю плеер
    function openPanel() { PlayerCore.ensurePlayer(); Theme.playerOpen = true }
    function closePanel() { Theme.playerOpen = false }
    function toggle() { Theme.playerOpen ? closePanel() : openPanel() }
    function nav(i) { Theme.playerPage = Math.max(0, Math.min(3, i)) }

    // модальные оверлеи взаимоисключающие (как Hub/Agent): открылся плеер —
    // гашу Hub, открылся Hub — гашу плеер, всё в одном процессе и плавно
    onShowingChanged: if (showing) Theme.activeOverlay = "player"
    Connections {
        target: Theme
        function onActiveOverlayChanged() {
            if (Theme.activeOverlay !== "player" && root.showing)
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

    // ── затемнение: клик мимо карточки закрывает ──
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: root.showing ? Theme.bg : "transparent"
        opacity: root.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closePanel()
        }
    }
}
