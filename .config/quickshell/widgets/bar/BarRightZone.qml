import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarRightZone — правая зона бара: систем-остров, погода, сеть,
//  Game Mode, трей, уведомления и звук. host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Item {
    id: rightZone
    property var host

    implicitWidth: rightRow.implicitWidth + 2 * Theme.space2
    implicitHeight: Theme.barH
    clip: true

    Row {
        id: rightRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: Theme.space2

        // систем-остров — компонент widgets/bar/SystemIsland
        SystemIsland { host: rightZone.host }

        // ── погода: иконка + температура, клик обновляет ──
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: Theme.barFaint
            tip: "Погода"
            onClicked: BarState.togglePanel("weather")
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.icon
                    color: Weather.ok ? Theme.barText : Theme.barFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.shortTemp
                    color: Weather.ok ? Theme.barText : Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }
            }
        }

        // ── сеть: ДВУХЭТАЖНАЯ ячейка — иконка сверху, ↓/↑ мелко снизу ──
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: rightZone.host.netKind === "off" ? Theme.barFaint : Theme.barDim
            tip: "Сеть (Hub)"
            onClicked: rightZone.host.openNetwork()
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Row {
                    spacing: 5
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rightZone.host.netKind === "eth" ? "󰈀" : "\uf1eb"
                        color: rightZone.host.netKind === "off" ? Theme.barFaint : Theme.barText
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontBody
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rightZone.host.netKind === "off" ? "нет"
                            : (rightZone.host.netKind === "eth" ? "eth" : "wifi")
                        color: Theme.barDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                    }
                }
                Text {
                    text: "↓" + SysInfo.fmtRate(SysInfo.rx) + " ↑" + SysInfo.fmtRate(SysInfo.tx)
                    color: Theme.barFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMicro
                }
            }
        }

        // ── действия: Game Mode (REC вынесен отдельной пилюлей справа) ──
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: rightZone.host.gameMode ? Theme.danger : Theme.barFaint
            tip: "Game Mode"
            onClicked: rightZone.host.toggleGameMode()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf11b"
                color: rightZone.host.gameMode ? Theme.danger : Theme.barDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(15)
            }
        }

        // трей — компонент widgets/bar/BarTray
        BarTray { host: rightZone.host }

        // ── уведомления · громкость — ячейками ──
        Cell {
            id: notifCell
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: rightZone.host.notifCount > 0 ? Theme.accent : Theme.barFaint
            tip: "Уведомления"
            onClicked: BarState.togglePanel("notifs")
            // мягкий пульс на НОВОЕ уведомление (только рост счётчика)
            property SequentialAnimation notifPulse: SequentialAnimation {
                NumberAnimation {
                    target: notifCell; property: "scale"; to: 1.15
                    duration: Theme.animMed / 2; easing.type: Theme.easeOut
                }
                NumberAnimation {
                    target: notifCell; property: "scale"; to: 1.0
                    duration: Theme.animMed / 2; easing.type: Theme.easeOut
                }
            }
            property Connections notifWatch: Connections {
                target: rightZone.host
                function onNotifCountChanged() {
                    if (rightZone.host.notifCount > rightZone.host.prevNotifCount) {
                        notifCell.notifPulse.restart()
                        BarState.activate("notifs", 4000)
                    }
                    rightZone.host.prevNotifCount = rightZone.host.notifCount
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: rightZone.host.dnd ? "\uf1f6" : "\uf0f3"
                color: BarState.mode === "notifs" ? Theme.accent
                    : (rightZone.host.dnd ? Theme.barFaint
                       : (rightZone.host.notifCount > 0 ? Theme.barText : Theme.barDim))
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(14)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: rightZone.host.notifCount > 0
                text: rightZone.host.notifCount
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.bold: true
            }
        }

        // volume
        Cell {
            id: volCell
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: rightZone.host.muted ? Theme.danger : Theme.barDim
            tip: "Звук"
            onClicked: rightZone.host.openVolumePanel()
            // пульс на изменение громкости или mute
            property SequentialAnimation volPulse: SequentialAnimation {
                NumberAnimation {
                    target: volCell; property: "scale"; to: 1.15
                    duration: Theme.animMed / 2; easing.type: Theme.easeOut
                }
                NumberAnimation {
                    target: volCell; property: "scale"; to: 1.0
                    duration: Theme.animMed / 2; easing.type: Theme.easeOut
                }
            }
            property Connections volWatch: Connections {
                target: rightZone.host
                function onVolChanged() {
                    if (rightZone.host.pulsePrimed) { volCell.volPulse.restart(); BarState.activate("control", 2500) }
                }
                function onMutedChanged() {
                    if (rightZone.host.pulsePrimed) { volCell.volPulse.restart(); BarState.activate("control", 2500) }
                }
            }
            Item {
                implicitWidth: volContent.implicitWidth
                implicitHeight: Theme.barCellH
                Row {
                    id: volContent
                    anchors.centerIn: parent
                    spacing: Theme.space2
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rightZone.host.muted
                            ? "󰖁"
                            : (rightZone.host.vol < 0.34 ? "󰕿" : (rightZone.host.vol < 0.67 ? "󰖀" : "󰕾"))
                        color: rightZone.host.muted ? Theme.barFaint : Theme.barText
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(16)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rightZone.host.muted ? "mute" : Math.round(rightZone.host.vol * 100) + "%"
                        color: Theme.barDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rightZone.host.openMixer()
                }
                WheelHandler {
                    onWheel: (wheel) => rightZone.host.bumpVol(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                }
            }
        }
    }
}
