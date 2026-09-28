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

    // поверхность — только верхняя полоса, а не весь экран: меньше рисуется
    // (и меньше блита) при каждом показе подсказки
    anchors { top: true; left: true; right: true }
    implicitHeight: 72
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // рисуем только когда нужно — иначе окно не маппится
    visible: Theme.tooltipShown

    // сторож: если панель не прислала скрытие (мышь ушла нештатно), прячем сами.
    // M68: прежние 8 с обрывали легитимное долгое наведение — продлеваем сторож
    // при смене подсказки/позиции и держим запас 30 с.
    Timer {
        id: watchdog
        interval: 30000
        onTriggered: Theme.tooltipShown = false
    }
    onVisibleChanged: if (visible && watchdog) watchdog.restart()
    Connections {
        target: Theme
        function onTooltipTextChanged() { if (root.visible) watchdog.restart() }
        function onTooltipXChanged() { if (root.visible) watchdog.restart() }
    }

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
