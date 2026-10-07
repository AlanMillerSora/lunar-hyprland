pragma Singleton
import QtQuick
import Quickshell

// ════════════════════════════════════════════════════════════════
//  Marquee — общий marquee-стейт для бегущей строки в баре.
//  Один тикер на все экраны: ячейка только читает x/animating/textW,
//  а двигает строку единственный Timer. Пока текст помещается —
//  таймеры стоят и репаинтов нет; крутится только когда реально
//  не влезает. Ширину меряю невидимым Text (как в 43PR), чтобы
//  вёрстку видимой строки не трогать.
//  MPRIS остаётся в нашем MediaCore/хосте бара — здесь только
//  механика прокрутки, текст и его видимую ширину даёт ячейка.
// ════════════════════════════════════════════════════════════════
QtObject {
    id: mq

    // строка и её видимая ширина — задаёт ячейка бара
    property string text: ""
    property int maxW: 0

    // движение: 1 px за тик (~30 fps), пауза на старте каждого цикла
    readonly property int step: 1
    readonly property int interval: 33
    readonly property int holdMs: 2500
    // зазор между копиями, чтобы цикл не «слипался»
    readonly property int gap: 24

    // ширина строки — замер невидимым Text
    readonly property real textW: measureText.implicitWidth
    // крутим только когда текст есть и не влезает в maxW
    readonly property bool animating: maxW > 0 && text.length > 0 && textW > maxW

    property real x: 0
    property bool hold: true

    // новая строка/переход в скролл — с начала и с паузы
    onAnimatingChanged: { x = 0; hold = true }
    onTextChanged: { x = 0; hold = true }

    // «Invisible text»: только для замера ширины; шрифт как у строки
    property Item measure: Item {
        visible: false
        Text {
            id: measureText
            text: mq.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(12)
        }
    }

    // пауза на старте: идёт, только когда есть что крутить
    property Timer holdTimer: Timer {
        interval: mq.holdMs
        repeat: false
        running: mq.animating && mq.hold
        onTriggered: mq.hold = false
    }

    // прокрутка: идёт ТОЛЬКО пока строка реально едет — иначе ноль репаинтов
    property Timer scrollTimer: Timer {
        interval: mq.interval
        repeat: true
        running: mq.animating && !mq.hold
        onTriggered: {
            mq.x -= mq.step
            if (mq.x <= -(mq.textW + mq.gap)) {
                mq.x = 0
                mq.hold = true
            }
        }
    }
}
