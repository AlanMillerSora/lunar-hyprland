import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  SystemIsland — систем-остров бара: три тонкие полоски CPU · RAM · GPU
//  стопкой, без подписей (идея ArchEclipse ResourceMonitor). Тише и
//  компактнее прежних строк «CPU 12% [bar]»: значение читается по
//  длине полоски, точные числа — в телеметрии по клику.
//  Источник — eclipse-status.sh (опрос раз в 3 с, GPU из кэша на 10 с).
//  Клик открывает «Телеметрию». host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Cell {
    property var host
    id: sysCell
    anchors.verticalCenter: parent.verticalCenter
    interactive: true
    active: BarState.mode === "sys"
    accent: SysInfo.hot ? Theme.danger : Theme.barDim
    tip: "Телеметрия"
    onClicked: BarState.togglePanel("sys")

    // три полоски стопкой: CPU / RAM / GPU. Фиксированный model: 3 —
    // иначе JS-массив с SysInfo.* пересобирался бы на каждом замере и
    // пересоздавал делегаты.
    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Repeater {
            model: 3
            delegate: Rectangle {
                required property int index
                readonly property int v: index === 0 ? SysInfo.cpu
                    : (index === 1 ? SysInfo.ram : SysInfo.gpu)
                readonly property bool avail: index !== 2 || SysInfo.gpu >= 0
                width: 40
                height: 4
                radius: height / 2
                color: Theme.trackBg

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1,
                        (avail && v >= 0 ? v : 0) / 100))
                    height: parent.height
                    radius: parent.radius
                    color: (avail && v >= 90) ? Theme.danger : Theme.accent
                    Behavior on width { Anim { type: Anim.FastSpatial } }
                }
            }
        }
    }
}
