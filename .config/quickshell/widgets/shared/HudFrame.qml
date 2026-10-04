import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  HudFrame — HUD-скобки по четырём углам (мотив «чертёж»).
//  По умолчанию виден только в стиль-профиле architect; always:true —
//  рисовать всегда (для поверхностей, где скобки были и в classic).
// ════════════════════════════════════════════════════════════════
Item {
    id: root
    anchors.fill: parent

    property color color: Theme.accent
    property int size: Theme.hudCornerSize
    property int thickness: Theme.hudCornerThickness
    property int inset: Theme.hudCornerInset
    property real strength: Theme.hudCornerOpacity
    property bool always: false

    visible: always || Theme.arch
    z: 40

    readonly property color c: Qt.rgba(color.r, color.g, color.b, strength)

    // top-left
    Rectangle { width: root.size; height: root.thickness; color: root.c; x: root.inset; y: root.inset }
    Rectangle { width: root.thickness; height: root.size; color: root.c; x: root.inset; y: root.inset }
    // top-right
    Rectangle { width: root.size; height: root.thickness; color: root.c; x: parent.width - root.inset - width; y: root.inset }
    Rectangle { width: root.thickness; height: root.size; color: root.c; x: parent.width - root.inset - width; y: root.inset }
    // bottom-left
    Rectangle { width: root.size; height: root.thickness; color: root.c; x: root.inset; y: parent.height - root.inset - height }
    Rectangle { width: root.thickness; height: root.size; color: root.c; x: root.inset; y: parent.height - root.inset - height }
    // bottom-right
    Rectangle { width: root.size; height: root.thickness; color: root.c; x: parent.width - root.inset - width; y: parent.height - root.inset - height }
    Rectangle { width: root.thickness; height: root.size; color: root.c; x: parent.width - root.inset - width; y: parent.height - root.inset - height }
}
