import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  Toggle — небольшой переключатель для строк состояния.
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: root

    property bool on: false
    property bool danger: false
    readonly property color onColor: root.danger ? Theme.danger : Theme.accent

    implicitWidth: 30
    implicitHeight: 16
    radius: height / 2
    color: root.on ? Theme.alpha(root.onColor, 0.85) : Theme.fill
    border.width: 1
    border.color: root.on ? Theme.alpha(root.onColor, 0.85) : Theme.border
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Rectangle {
        width: 12
        height: 12
        radius: 6
        y: 1
        x: root.on ? root.width - width - 2 : 2
        color: root.on ? Theme.bg : Theme.textDim
        Behavior on x { Anim { type: Anim.FastSpatial } }
    }
}
