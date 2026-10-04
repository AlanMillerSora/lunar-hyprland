import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarRightZone — правая зона бара (arch-стиль): медиа, Game Mode,
//  раскладка, трей, уведомления и звук. Всё «плоское», без плашек.
//  Состав/порядок/видимость — из BarSettings (bar.json). host = LunarPanel.
// ════════════════════════════════════════════════════════════════
Item {
    id: rightZone
    property var host

    implicitWidth: zoneRow.implicitWidth + 2 * Theme.space2
    implicitHeight: Theme.barH
    clip: true

    // медиа: значения прогресса держу локально и обновляю по сигналам
    // корня — через property var в Loader'е они не пересчитываются.
    property bool mediaActive: false
    property real trackLength: 0
    property real trackPosition: 0
    property var mediaCellRef: null
    function openMediaBubble() {
        if (mediaCellRef)
            mediaCellRef.openBubbleFromHere()
    }
    function syncMedia() { if (host) mediaActive = host.mediaActive }
    function syncProgress() {
        if (!host)
            return
        trackLength = host.trackLength
        trackPosition = host.trackPosition
    }
    Connections {
        target: rightZone.host
        function onMediaActiveChanged() { rightZone.syncMedia() }
        function onTrackLengthChanged() { rightZone.syncProgress() }
        function onTrackPositionChanged() { rightZone.trackPosition = host.trackPosition }
    }
    Component.onCompleted: { syncMedia(); syncProgress() }

    function compFor(id) {
        if (id === "media") return mediaComp
        if (id === "game") return gameComp
        if (id === "layout") return layoutComp
        if (id === "tray") return trayComp
        if (id === "notifs") return notifComp
        if (id === "volume") return volComp
        return null
    }

    Row {
        id: zoneRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: Theme.space4

        Repeater {
            model: BarSettings.rightVisible

            delegate: Loader {
                required property var modelData
                width: item ? item.implicitWidth : 0
                height: Theme.barH
                anchors.verticalCenter: parent.verticalCenter
                visible: modelData.id === "media" ? rightZone.mediaActive
                                                   : (item === null ? true : item.visible)
                sourceComponent: rightZone.compFor(modelData.id)
            }
        }
    }

    // ── медиа-ячейка: трек, play/pause, мини-спектр; клик — плашка вниз ──
    Component {
        id: mediaComp
        MediaCell {
            id: mediaCellItem
            host: rightZone.host
            progressLength: rightZone.trackLength
            progressPosition: rightZone.trackPosition
            function openBubbleFromHere() {
                BarState.togglePanel("media")
            }
            Component.onCompleted: rightZone.mediaCellRef = mediaCellItem
            Component.onDestruction: if (rightZone.mediaCellRef === mediaCellItem)
                rightZone.mediaCellRef = null
            onClickedBubble: openBubbleFromHere()
        }
    }

    // ── Game Mode ──
    Component {
        id: gameComp
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            active: rightZone.host.gameMode
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
    }

    // ── раскладка (клик — переключить) ──
    Component {
        id: layoutComp
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: Theme.barDim
            tip: "Раскладка — переключить"
            onClicked: rightZone.host.switchLayout()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: rightZone.host.kbLayout
                color: Theme.barText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.bold: true
            }
        }
    }

    // ── трей ──
    Component {
        id: trayComp
        BarTray { host: rightZone.host }
    }

    // ── уведомления ──
    Component {
        id: notifComp
        Cell {
            id: notifCell
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            active: BarState.mode === "notifs"
            accent: rightZone.host.notifCount > 0 ? Theme.accent : Theme.barFaint
            tip: "Уведомления"
            onClicked: BarState.togglePanel("notifs")
            // мягкий пульс-подсветка на НОВОЕ уведомление (только рост
            // счётчика). Панель сама НЕ раскрывается — открытие по клику.
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
                    if (rightZone.host.notifCount > rightZone.host.prevNotifCount)
                        notifCell.notifPulse.restart()
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
                font.pixelSize: Theme.fontSize(15)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: rightZone.host.notifCount > 0
                text: rightZone.host.notifCount
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(10)
                font.bold: true
            }
        }
    }

    // ── звук ──
    Component {
        id: volComp
        Cell {
            id: volCell
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            active: BarState.mode === "control"
            accent: rightZone.host.muted ? Theme.danger : Theme.barDim
            tip: "Звук"
            onClicked: rightZone.host.openVolumePanel()
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
                        font.pixelSize: Theme.fontSize(11)
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
