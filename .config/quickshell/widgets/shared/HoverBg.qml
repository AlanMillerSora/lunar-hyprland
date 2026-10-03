import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  HoverBg — подсветка интерактивной секции при наведении.
//  Раньше жила инлайном в LunarPanel; вынес в общий слой.
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: hb

    anchors.fill: parent
    radius: Theme.radius
    color: Theme.hoverStrong
    opacity: hh.hovered ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
    readonly property bool hovered: hh.hovered
    HoverHandler { id: hh }
}
