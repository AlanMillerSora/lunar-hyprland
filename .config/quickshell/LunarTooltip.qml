import Quickshell
import Quickshell.Wayland
import QtQuick

// ════════════════════════════════════════════════════════════════
//  LunarTooltip — всплывающая подпись под элементом панели
//  (сейчас — значки трея). Панель выставляет Theme.tooltipShown /
//  tooltipText / tooltipX, здесь только показываем.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // рисуем только когда нужно — иначе окно не маппится
    visible: Theme.tooltipShown

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // пустая маска — ввод не перехватываем
    mask: Region {}

    Rectangle {
        id: card
        width: label.implicitWidth + 18
        height: 24
        x: Math.max(6, Math.min(root.width - width - 6, Theme.tooltipX - width / 2))
        y: 46
        radius: Theme.radius
        color: Theme.bgPanel
        border.color: Theme.borderAccent
        border.width: 1

        Text {
            id: label
            anchors.centerIn: parent
            text: Theme.tooltipText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(11)
        }
    }
}
