import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  ActionButton — общая плоская кнопка риса с рамкой-аффордансом.
//  Раньше этот стиль был скопирован четырьмя компонентами в разных
//  страницах (Update/System/Network/Dev) и расползался. Теперь один:
//  размеры и кегль задаю свойствами, вид ховера — здесь.
//  Ширина по содержимому, но не меньше minWidth; вызывающий может
//  переопределить width явно (фиксированные кнопки в строках).
// ════════════════════════════════════════════════════════════════
Rectangle {
    id: btn

    property string label: ""
    property bool accent: false
    property bool enabledBtn: true
    property int fontSize: Theme.fontTiny
    property int minWidth: 120
    property int hPad: 34
    property int letterSpacing: 1
    signal clicked()

    implicitWidth: Math.max(minWidth, btnText.implicitWidth + hPad)
    height: Theme.rowH
    radius: Theme.radius
    color: !enabledBtn ? Theme.surfaceCard
         : btnArea.containsMouse ? Theme.surfaceHover
         : Theme.surfaceCard
    // arch: рамки нет, кнопка — подложка surfaceCard
    border.width: 0

    Text {
        id: btnText
        anchors.centerIn: parent
        text: btn.label
        color: !enabledBtn ? Theme.textFaint
             : (btnArea.containsMouse || btn.accent) ? Theme.accent : Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: btn.fontSize
        font.letterSpacing: btn.letterSpacing
    }

    MouseArea {
        id: btnArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: enabledBtn ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: enabledBtn
        onClicked: btn.clicked()
    }
}
