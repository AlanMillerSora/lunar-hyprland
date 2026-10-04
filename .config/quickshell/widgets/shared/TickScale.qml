import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  TickScale — технические насечки (мотив «чертёж», профиль architect).
//  value 0..1 подсвечивает заполненные риски акцентом.
// ════════════════════════════════════════════════════════════════
Row {
    id: root

    property int count: 24
    property real value: 0
    property color tickColor: Theme.alpha(Theme.text, 0.14)
    property color onColor: Theme.accent
    property int tickW: 1
    property int tickH: 5

    spacing: 3

    Repeater {
        model: root.count

        delegate: Rectangle {
            required property int index
            width: root.tickW
            height: root.tickH
            color: index < Math.round(root.value * root.count) ? root.onColor : root.tickColor
        }
    }
}
