import QtQuick
import QtQuick.Controls
import "../.."

// ════════════════════════════════════════════════════════════════
//  AppTooltip — единый тултип риса: тёмная плашка, рамка, короткий
//  фейд. Использование: AppTooltip { visible: h.hovered; text: "…" }
// ════════════════════════════════════════════════════════════════
ToolTip {
    id: root

    property int cornerRadius: 6

    delay: 600
    leftPadding: 10
    rightPadding: 10
    topPadding: 6
    bottomPadding: 6

    background: Rectangle {
        color: Theme.barPill
        radius: root.cornerRadius
        border.width: 1
        border.color: Theme.border
    }
    contentItem: Text {
        text: root.text
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        textFormat: Text.RichText
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.anim.fastEffects }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.anim.fastEffects }
    }
}
