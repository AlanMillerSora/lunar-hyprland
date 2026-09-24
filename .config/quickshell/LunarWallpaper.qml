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

    // Профиль производительности (Theme.optimizeMode): на лету переключает
    // блюр/тени Hyprland (eclipse-perf.sh) и темп анимации обоев (40/16 мс).
    readonly property bool optimize: Theme.optimizeMode
    onOptimizeChanged: applyPerf()
    Component.onCompleted: applyPerf()

    // команду задаём явно перед запуском (binding не успевал обновиться
    // к моменту running=true, и режимы переключались наоборот)
    function applyPerf() {
        perfProc.command = ["bash", "-c",
            "$HOME/.config/hypr/scripts/eclipse-perf.sh " + (root.optimize ? "optimize" : "normal")]
        perfProc.running = true
    }

    Process {
        id: perfProc
        running: false
    }

    LunarWallpaperScene {
        anchors.fill: parent
        phase: Math.max(1, Math.min(9, root.wsId))
        live: Theme.wallpaperLive
        tickMs: root.optimize ? 40 : 16
    }
}
