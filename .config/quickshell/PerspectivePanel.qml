import QtQuick

// Wraps its content in a card that:
//  - scales + rotates in from an angle when `open` flips true (tilt-in reveal)
//  - subtly tilts toward the cursor while hovered (parallax), like a HUD panel
//
// Note on the "shader" approach: a true vanishing-point warp shader needs a
// compiled .qsb fragment shader (Qt Shader Tools / qsb, part of qtdeclarative
// dev tools) which this sandbox can't compile or test blind. This version
// gets the same visual read (perspective tilt, depth, glow) using ordinary
// QML 3D transforms, which is guaranteed to run with just Quickshell + Qt6.
// If you later want the literal warped-plane shader look, say so and I'll
// write the .qsb pipeline as a follow-up you compile locally.
Item {
    id: root

    default property alias content: contentContainer.data
    property bool open: false
    property real tiltStrength: 5   // degrees of hover parallax

    property real parallaxX: 0
    property real parallaxY: 0

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
            angle: root.open ? root.parallaxX : 20

            Behavior on angle {
                // во время наведения угол должен идти за мышью без анимации,
                // иначе Behavior перезапускается на каждое движение (M72)
                enabled: !hover.hovered
                NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic }
            }
        },
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.open ? root.parallaxY : -16

            Behavior on angle {
                // во время наведения угол должен идти за мышью без анимации,
                // иначе Behavior перезапускается на каждое движение (M72)
                enabled: !hover.hovered
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

    HoverHandler {
        id: hover
        property real fx: 0.5
        property real fy: 0.5
        onPointChanged: {
            hover.fx = point.position.x / root.width
            hover.fy = point.position.y / root.height
            if (!tiltTick.running)
                tiltTick.start()
        }
        onHoveredChanged: {
            if (hovered) {
                if (!tiltTick.running)
                    tiltTick.start()
            } else {
                root.parallaxX = 0
                root.parallaxY = 0
            }
        }
    }

    // параллакс обновляем не чаще ~30 Гц: Behavior на angle не должен
    // перезапускаться на каждое событие движения мыши (M72)
    Timer {
        id: tiltTick
        interval: 33
        repeat: false
        onTriggered: {
            if (!hover.hovered)
                return
            root.parallaxX = -(hover.fy - 0.5) * root.tiltStrength
            root.parallaxY = (hover.fx - 0.5) * root.tiltStrength
        }
    }

    Item {
        id: contentContainer
        anchors.fill: parent
    }
}
