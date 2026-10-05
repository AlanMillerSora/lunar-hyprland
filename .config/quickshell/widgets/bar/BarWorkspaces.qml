import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarWorkspaces — ряд лунных фаз столов: фокус, занятость, мигание
//  на новое окно. Активный стол подсвечивает скользящая капсула —
//  она плавно едет к фазе и мягко пульсирует при переходе. Наведение
//  мышью фазу не подменяет — ряд остаётся спокойным.
// ════════════════════════════════════════════════════════════════
Item {
    id: root
    property var host
    implicitWidth: wsRow.implicitWidth
    implicitHeight: Theme.barCellH

    readonly property int phaseW: 32
    readonly property int phaseGap: 7
    readonly property int step: phaseW + phaseGap
    readonly property int focusIdx: (host && host.focusedWs && host.focusedWs.id >= 1)
        ? host.focusedWs.id - 1 : -1

    // пульс капсулы при переходе на другой стол
    onFocusIdxChanged: if (root.focusIdx >= 0) capsulePulse.restart()

    // тонкая «орбита» за фазами — связывает индикаторы в цикл
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.active
    }

    // ── скользящая капсула активного стола: плавно едет к фазе ──
    Rectangle {
        id: capsule
        visible: root.focusIdx >= 0
        width: 28
        height: 28
        radius: width / 2
        color: Theme.alpha(Theme.accent, 0.12)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.35)
        y: (parent.height - height) / 2
        x: wsRow.x + root.focusIdx * root.step + (root.phaseW - width) / 2
        opacity: visible ? 1 : 0

        Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        // короткий импульс при переходе: лёгкое расширение и возврат
        ParallelAnimation {
            id: capsulePulse
            SequentialAnimation {
                NumberAnimation {
                    target: capsule; property: "scale"; to: 1.12
                    duration: 130; easing.type: Theme.easeOut
                }
                NumberAnimation {
                    target: capsule; property: "scale"; to: 1.0
                    duration: 170; easing.type: Easing.InCubic
                }
            }
        }
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        height: Theme.barCellH
        spacing: root.phaseGap

        Repeater {
            model: 9

            delegate: Rectangle {
                id: wsPill
                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: host.wsFor(wsId)
                readonly property bool isFocused: host.focusedWs !== null && host.focusedWs.id === wsId
                readonly property bool isOccupied: ws !== null && ws.toplevels.values.length > 0
                readonly property bool alerting: host.wsBlink[wsId] !== undefined

                width: root.phaseW
                height: Theme.barCellH
                color: "transparent"

                // сама фаза; мигает на новое окно, активная — ярче и крупнее
                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: Qt.resolvedUrl("../../assets/moon-phases/phase_"
                        + ("0" + (index + 1)).slice(-2) + ".svg")
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    opacity: wsPill.alerting
                        ? (host.wsBlinkPhase ? 1.0 : 0.12)
                        : (wsPill.isFocused ? 1.0
                           : (wsPill.isOccupied ? 0.78 : 0.26))
                    scale: wsPill.isFocused ? 1.18 : (wsPill.isOccupied ? 1.06 : 1.0)
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                    Behavior on scale { Anim { type: Anim.FastSpatial } }
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: host.focusWs(wsPill.wsId)
                }
            }
        }
    }
}
