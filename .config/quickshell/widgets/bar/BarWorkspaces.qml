import QtQuick
import QtQuick.Effects
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarWorkspaces — рабочие столы тонкой полосой (идея ArchEclipse
//  Workspaces): в покое — ряд тонких сегментов, где видно занятость
//  и активный стол; при наведении на ряд или при переключении/новом
//  окне ряд «раскрывается» и показывает иконки приложений каждого стола.
//
//  Фаза-луна как смысл обоев сохранена: активный стол подсвечивается
//  акцентом, столы с окнами — ярче, пустые — приглушены. Мигание на
//  новое окно — как было. host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Item {
    id: root
    property var host

    readonly property int wsCount: 9
    // раскрыт ли ряд в иконки (ховер по ряду или «пик» после переключения)
    readonly property bool expanded: wsBg.hovered || host.wsPeek > 0

    implicitWidth: wsRow.width
    implicitHeight: Theme.barCellH
    height: Theme.barCellH

    HoverBg { id: wsBg }

    // ряд: сегменты-полоски; при раскрытии над полосой проявляется иконка
    Row {
        id: wsRow
        anchors.centerIn: parent
        height: Theme.barCellH
        spacing: 3

        Repeater {
            model: root.wsCount

            delegate: Item {
                id: wsSlot
                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: host.wsFor(wsId)
                readonly property bool isFocused: host.focusedWs !== null && host.focusedWs.id === wsId
                readonly property bool isOccupied: ws !== null && ws.toplevels.values.length > 0
                readonly property bool alerting: host.wsBlink[wsId] !== undefined
                readonly property string appIcon: host.appIconFor(host.firstClassFor(wsId))
                readonly property bool peek: host.wsPeek === wsId

                width: 14
                height: Theme.barCellH

                // импульс полоски при переходе на этот стол
                onIsFocusedChanged: if (isFocused) focusPulse.restart()

                // ── полоска-сегмент: занятость/активность/мигание ──
                // при раскрытии ряда прячу полоску — пусть читается иконка
                Rectangle {
                    id: wsBar
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: height / 2
                    color: root.rwColor(wsSlot)
                    opacity: root.expanded && wsSlot.appIcon !== "" ? 0.0 : 1.0
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on height { Anim { type: Anim.FastSpatial } }
                }

                // короткий импульс: вспышка + лёгкое расширение сегмента
                SequentialAnimation {
                    id: focusPulse
                    NumberAnimation {
                        target: wsBar
                        property: "scale"
                        from: 1.0
                        to: 1.6
                        duration: 140
                        easing.type: Theme.easeOut
                    }
                    NumberAnimation {
                        target: wsBar
                        property: "scale"
                        from: 1.6
                        to: 1.0
                        duration: 160
                        easing.type: Easing.InCubic
                    }
                }

                // ── иконка приложения: проявляется при раскрытии ряда ──
                Item {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    visible: root.expanded && wsSlot.appIcon !== ""
                    opacity: visible ? 1 : 0
                    Behavior on opacity { Anim { type: Anim.FastEffects } }

                    Image {
                        id: wsAppImg
                        anchors.fill: parent
                        source: wsSlot.appIcon
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: wsAppImg
                        visible: wsAppImg.status === Image.Ready
                        saturation: -1.0
                        brightness: 0.45
                        contrast: 0.05
                    }
                    // фолбэк — маленькая точка, если иконка не нашлась
                    Text {
                        anchors.centerIn: parent
                        visible: wsAppImg.status !== Image.Ready
                        text: "\uf111"
                        color: root.rwColor(wsSlot)
                        font.family: Theme.iconFont
                        font.pixelSize: 7
                    }
                }

                // при раскрытии саму полоску прячет wsBar.opacity; слот не гашу

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: host.focusWs(wsSlot.wsId)
                }
            }
        }
    }

    // цвет сегмента: активный — акцент, занятый — светлый, пустой — приглушён;
    // мигание новых окон — как было, двумя фазами.
    function rwColor(slot) {
        if (slot.alerting)
            return host.wsBlinkPhase ? Theme.accent : Theme.alpha(Theme.accent, 0.12)
        if (slot.isFocused)
            return Theme.accent
        if (slot.isOccupied)
            return Theme.barText
        return Theme.barFaint
    }
}
