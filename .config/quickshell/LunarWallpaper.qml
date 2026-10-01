import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// ════════════════════════════════════════════════════════════════
//  LunarWallpaper — тонкая обёртка: фоновый слой + фаза по столу.
//
//  Сама сцена — в LunarWallpaperScene.qml (чистый QtQuick, без
//  Quickshell). Здесь только слой (WlrLayer.Background, под окнами и
//  панелями), растяжка на монитор и подписка на активный стол.
//
//  Фаза = номер стола (1..9), вне диапазона — 5 (кольцо).
//  «Лёгкий режим» — тумблер в Hub → Wallpapers (Theme.wallpaperLive).
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Отдельный namespace: иначе layerrule Hyprland блюрит и фоновые обои
    // (полноэкранный blur каждый кадр — на слабом iGPU это главный тормоз).
    WlrLayershell.namespace: "lunar-wallpaper"
    exclusionMode: ExclusionMode.Ignore

    // активный стол: activeWorkspace, а если он не отдаёт объект —
    // focusedWorkspace (проверенный путь из LunarPanel).
    readonly property var ws: Hyprland.activeWorkspace || Hyprland.focusedWorkspace
    readonly property int wsId: (ws && ws.id > 0) ? ws.id : 5

    // Единственный облегчённый режим: на лету задаёт блюр/тени Hyprland
    // (eclipse-perf.sh) и темп анимации обоев (~25 fps, без пыли/метеоров).
    Component.onCompleted: applyPerf()

    // hyprctl reload возвращает decoration из hyprland.lua: заново применяем
    // пресет производительности, а после него — пользовательский блюр
    // (это делает perfProc.onExited, то есть ползунок главнее пресета).
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" || event.name === "config.reloaded")
                root.applyPerf()
        }
    }

    function applyPerf() {
        perfProc.command = ["bash", "-c",
            "$HOME/.config/hypr/scripts/eclipse-perf.sh"]
        perfProc.running = true
    }

    Process {
        id: perfProc
        running: false
        // пресет применён — возвращаем блюр ползунка (если он выставлен)
        onExited: if (Theme.blurSize >= 0) Theme.applyBlur()
    }

    // ── обычная картинка (если выбрана в Hub → Interface) ──
    Rectangle {
        anchors.fill: parent
        visible: Theme.wallpaperMode === "image"
        color: Theme.bg
    }

    Image {
        anchors.fill: parent
        visible: Theme.wallpaperMode === "image" && Theme.wallpaperPath !== ""
        source: Theme.wallpaperPath !== "" ? "file://" + Theme.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
    }

    // ── живая сцена затмения: спит, когда показываем картинку ──
    LunarWallpaperScene {
        anchors.fill: parent
        visible: Theme.wallpaperMode !== "image"
        phase: Math.max(1, Math.min(9, root.wsId))
        live: Theme.wallpaperLive && Theme.wallpaperMode !== "image"
        optimize: true
        tickMs: 40
    }
}
