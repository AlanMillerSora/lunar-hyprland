import QtQuick
import "../.."

// Подпись секции панели: мелкий капс с разрядкой (единый ритм).
// Цвет/кегль/жирность настраиваются, чтобы свести к одному компоненту
// заголовки оверлеев и Hub без потери текущего вида.

Text {
    property color textColor: Theme.textFaint
    property int size: Theme.fontTiny
    property bool bold: true

    color: textColor
    font.family: Theme.fontFamily
    font.pixelSize: size
    font.letterSpacing: 2
    font.bold: bold
}
