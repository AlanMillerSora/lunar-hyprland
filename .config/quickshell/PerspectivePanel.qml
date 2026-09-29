import QtQuick

// Оборачивает содержимое в карточку, которая влетает под углом при `open`
// (tilt-in reveal) и уезжает обратно при закрытии. Параллакс к курсору убран:
// панель больше не наклоняется вслед за мышью.
Item {
    id: root

    default property alias content: contentContainer.data
    property bool open: false

    opacity: open ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
    }

    transform: [
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: root.open ? 0 : 20

            Behavior on angle {
                NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic }
            }
        },
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.open ? 0 : -16

            Behavior on angle {
                NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic }
            }
        },
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.open ? 1 : 0.88
            yScale: root.open ? 1 : 0.88

            Behavior on xScale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack } }
            Behavior on yScale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack } }
        }
    ]

    Item {
        id: contentContainer
        anchors.fill: parent
    }
}
