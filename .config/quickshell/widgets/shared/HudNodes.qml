import QtQuick
import "../.."

// ════════════════════════════════════════════════════════════════
//  HudNodes — регистрационные узлы-квадратики по четырём углам
//  (профиль architect). Технический мотив «чертёж».
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    anchors.fill: parent
    visible: Theme.arch
    property color color: Theme.hairAccent
    property int inset: 6
    property int size: 4
    z: 41

    Rectangle { width: root.size; height: root.size; color: root.color; x: root.inset; y: root.inset }
    Rectangle { width: root.size; height: root.size; color: root.color; x: parent.width - root.inset - width; y: root.inset }
    Rectangle { width: root.size; height: root.size; color: root.color; x: root.inset; y: parent.height - root.inset - height }
    Rectangle { width: root.size; height: root.size; color: root.color; x: parent.width - root.inset - width; y: parent.height - root.inset - height }
}
