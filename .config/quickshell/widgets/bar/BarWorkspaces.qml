import QtQuick
import QtQuick.Effects
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarWorkspaces — ряд лунных фаз столов: фокус, занятость, мигание
//  на новое окно и «пик» после переключения стола. Наведение мышью
//  НЕ раскрывает и не подменяет фазу — ряд остаётся спокойным.
//  Вынесено из LunarPanel; корень передаёт себя как host.
// ════════════════════════════════════════════════════════════════
Item {
    id: root
    property var host
    implicitWidth: wsRow.implicitWidth
    implicitHeight: Theme.barCellH

    // тонкая «орбита» за фазами — связывает индикаторы в цикл
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.active
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        height: Theme.barCellH
        spacing: 7

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
                readonly property string appIcon: host.appIconFor(host.firstClassFor(wsId))
                readonly property bool peek: host.wsPeek === wsId
                // иконка приложения — только на «пике» после переключения
                readonly property bool showApp: !alerting && appIcon !== "" && peek

                // импульс кольца при переходе на этот стол
                onIsFocusedChanged: if (isFocused) focusPulse.restart()

                width: 32
                height: Theme.barCellH
                color: "transparent"

                // мягкое гало под активной фазой — «стол светится»
                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: 16
                    color: Theme.alpha(Theme.accent, wsPill.isFocused ? 0.10 : 0)
                    Behavior on color { ColorAnimation { duration: Theme.animMed } }
                }

                // тонкое кольцо-выделение активного стола
                Rectangle {
                    id: focusRing
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: 14
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.activeBorder
                    opacity: 0.55
                    visible: wsPill.isFocused
                }

                // короткий импульс: вспышка + лёгкое расширение
                ParallelAnimation {
                    id: focusPulse
                    SequentialAnimation {
                        NumberAnimation {
                            target: focusRing
                            property: "scale"
                            from: 1.0
                            to: 1.4
                            duration: 140
                            easing.type: Theme.easeOut
                        }
                        NumberAnimation {
                            target: focusRing
                            property: "scale"
                            from: 1.4
                            to: 1.0
                            duration: 160
                            easing.type: Easing.InCubic
                        }
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: focusRing
                            property: "opacity"
                            from: 1.0
                            to: 0.55
                            duration: 300
                            easing.type: Theme.easeOut
                        }
                    }
                }

                // сама фаза; мигает на новое окно, на «пике» уступает иконке
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
                        : (wsPill.showApp ? 0.0
                           : (wsPill.isFocused ? 1.0
                              : (wsPill.isOccupied ? 0.78 : 0.26)))
                    scale: wsPill.isFocused ? 1.15 : (wsPill.isOccupied ? 1.07 : 1.0)
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                    Behavior on scale { Anim { type: Anim.FastSpatial } }
                }

                // иконка приложения стола — проявляется только на «пике»
                // (монохром, как значки трея), чтобы не пестрить
                Image {
                    id: wsAppImg
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: wsPill.appIcon
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: false
                }
                MultiEffect {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: wsAppImg
                    visible: wsPill.appIcon !== "" && wsAppImg.status === Image.Ready
                    saturation: -1.0
                    brightness: 0.45
                    contrast: 0.05
                    opacity: wsPill.showApp ? 1 : 0
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
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
