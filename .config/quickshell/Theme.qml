pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    property color bg: Qt.rgba(0, 0, 0, 0.85 * interfaceOpacity)
    property color bgPanel: "#050505"
    property color bgCard: "#0d0d0d"
    property color border: "#1e1e1e"
    property color borderAccent: "#2a2a2a"

    property color text: "#ffffff"
    property color textDim: "#888888"
    property color textFaint: "#4a4a4a"

    property color accent: "#ffffff"
    property color accent2: "#ffffff"
    property color danger: "#ff003c"
    property color ok: "#00ff9c"

    property color trackBg: "#161616"

    property string fontFamily: "JetBrains Mono"
    property string iconFont: "JetBrainsMono Nerd Font"

    property real interfaceOpacity: 1.0
    property real fontScale: 1.0

    // живые обои (QML-сцена): false — «лёгкий режим» без звёзд/метеоров/пыли
    property bool wallpaperLive: true

    // Производительность (Hub → Interface):
    //   true  = OPTIMIZE — облегчённый блюр/тени, обои ~25 fps
    //   false = NORMAL   — полный блюр/тени, обои ~60 fps
    property bool optimizeMode: true

    // попап громкости открыт — центральный OSD не показываем (без дубля)
    property bool volumePopupOpen: false

    // Единый радиус системы — как у карточки Hub
    property int radius: 6
    property int radiusM: 6
    property int radiusL: 6

    // сколько значков трея видно в панели (остальные — в списке «+N»)
    property int trayVisible: 3

    // тултип панели: панель выставляет, LunarTooltip показывает
    property bool tooltipShown: false
    property string tooltipText: ""
    property real tooltipX: 0

    property int animFast: 120
    property int animMed: 220
    property int animSlow: 380

    // ─────────── персистентность UI-настроек ───────────
    // Прозрачность интерфейса, масштаб шрифта и число значков трея
    // сохраняются между перезапусками Quickshell.
    property bool uiReady: false

    property FileView uiState: FileView {
        id: uiFile
        path: Quickshell.statePath("lunar-ui.json")
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onAdapterUpdated: { if (theme.uiReady) writeAdapter() }
        onLoaded: { theme.uiReady = true }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
            theme.uiReady = true
        }

        JsonAdapter {
            id: uiAdapter
            property real interfaceOpacity: 1.0
            property real fontScale: 1.0
            property int trayVisible: 3
            property bool wallpaperLive: true
            property bool optimizeMode: true

            // файл → UI
            onInterfaceOpacityChanged: theme.interfaceOpacity = interfaceOpacity
            onFontScaleChanged: theme.fontScale = fontScale
            onTrayVisibleChanged: theme.trayVisible = trayVisible
            onWallpaperLiveChanged: theme.wallpaperLive = wallpaperLive
            onOptimizeModeChanged: theme.optimizeMode = optimizeMode
        }
    }

    // UI → файл
    onInterfaceOpacityChanged: uiAdapter.interfaceOpacity = interfaceOpacity
    onFontScaleChanged: uiAdapter.fontScale = fontScale
    onTrayVisibleChanged: uiAdapter.trayVisible = trayVisible
    onWallpaperLiveChanged: uiAdapter.wallpaperLive = wallpaperLive
    onOptimizeModeChanged: uiAdapter.optimizeMode = optimizeMode

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function fontSize(base) {
        return Math.round(base * fontScale)
    }
}
