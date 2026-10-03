import QtQuick
import "../.."

// Подпись секции панели: мелкий капс с разрядкой (единый ритм).

Text {
    color: Theme.textFaint
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontTiny
    font.letterSpacing: 2
    font.bold: true
}
