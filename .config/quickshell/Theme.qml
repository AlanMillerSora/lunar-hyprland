pragma Singleton
import QtQuick

QtObject {
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

    // Единый радиус системы — как у карточки Hub
    property int radius: 6
    property int radiusM: 6
    property int radiusL: 6

    property int animFast: 120
    property int animMed: 220
    property int animSlow: 380

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function fontSize(base) {
        return Math.round(base * fontScale)
    }
}
