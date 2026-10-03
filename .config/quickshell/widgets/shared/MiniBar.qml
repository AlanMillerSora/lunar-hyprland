import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  MiniBar — тонкая полоска-индикатор 0..100 в стиле риса:
//  трек Theme.trackBg, заполнение акцентом, плавный рост.
//  Отрицательное значение — «нет данных» (полоса пустая).
//  Жила инлайном в панели «Телеметрия» — вынес в общий слой,
//  чтобы систем-остров в баре рисовал те же полосы.
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: bar

    property real value: 0
    property color barColor: Theme.accent

    height: 5
    radius: height / 2
    color: Theme.trackBg

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, (bar.value < 0 ? 0 : bar.value) / 100))
        height: parent.height
        radius: parent.radius
        color: bar.barColor
        Behavior on width { NumberAnimation { duration: 250; easing.type: Theme.easeOut } }
    }
}
