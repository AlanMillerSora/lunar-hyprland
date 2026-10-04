import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  IslandClip — единый раскрыв барного острова: плашка растёт вниз,
//  а содержимое проявляется клипом + прозрачностью + лёгким scale
//  (идея ArchEclipse IslandExpandClip). Анимируется ТОЛЬКО clip/
//  opacity/scale — раскладка per-frame не дёргается.
//
//  expand: 0 — сложено, 1 — раскрыто. Тон задаёт Theme.islandAnimType
//  (настройка «тон раскрытия» в Hub → Бар).
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property real expand: 0
    property real contentHeight: 0
    // по умолчанию раскрываем от верхней кромки (плашка бара сверху)
    property bool fromTop: true

    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.top: fromTop && parent ? parent.top : undefined
    anchors.bottom: !fromTop && parent ? parent.bottom : undefined

    height: Math.max(0, root.expand * root.contentHeight)
    clip: true
    opacity: Math.max(0, Math.min(1, root.expand * 1.2))
    scale: 0.97 + 0.03 * root.expand
    transformOrigin: root.fromTop ? Item.Top : Item.Bottom
    visible: root.expand > 0.001

    Behavior on expand {
        Anim { type: Theme.islandAnimType }
    }
}
