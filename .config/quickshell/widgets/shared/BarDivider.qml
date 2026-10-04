import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  BarDivider — тонкая вертикальная черта между ячейками бара.
//  Тот же почерк, что у разделителей вокруг часов в центре:
//  доля высоты ячейки, едва заметный штрих текста.
//  В стиль-профиле architect — выше и с акцентным тоном.
// ════════════════════════════════════════════════════════════════
Rectangle {
    width: Theme.line
    height: Math.round(Theme.barCellH * (Theme.arch ? 0.62 : 0.5))
    radius: Theme.arch ? 0 : 1
    color: Theme.arch ? Theme.hairAccent : Theme.alpha(Theme.barText, 0.12)
}
