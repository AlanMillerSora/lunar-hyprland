import QtQuick
import "../.."
import "../shared"

// ════════════════════════════════════════════════════════════════
//  BarCenterZone — центр бара: ЧАСЫ — ось композиции, стоят ровно по
//  центру экрана. Всё, что в списке до часов, уходит влево, что после —
//  вправо. Своей пилюли больше нет: единую подложку даёт плашка бара.
//  Состав/порядок — из BarSettings (bar.json). host = корень LunarPanel.
// ════════════════════════════════════════════════════════════════
Item {
    id: centerZone
    property var host

    // ссылка на погодную ячейку — открыть пузырь как при клике (IPC)
    property var weatherCellRef: null
    function openWeatherBubble() {
        if (weatherCellRef)
            weatherCellRef.openBubbleFromHere()
    }

    // ── медиа-полоса в центре: показывается, только когда что-то играет
    //    (сквозной прогресс рисует LunarPanel во всю ширину бара) ──
    property var mediaCellRef: null
    property bool mediaActive: false
    Connections {
        target: centerZone.host
        function onMediaActiveChanged() { centerZone.mediaActive = centerZone.host.mediaActive }
    }
    Component.onCompleted: if (host) mediaActive = host.mediaActive

    // ── ячейки центра и ось ──
    readonly property var cells: BarSettings.centerVisible
    // индекс часов: они всегда есть (locked) и служат осью композиции
    readonly property int clockIndex: {
        for (var i = 0; i < cells.length; i++)
            if (cells[i].id === "clock")
                return i
        return -1
    }
    readonly property var leftCells: clockIndex > 0 ? cells.slice(0, clockIndex) : []
    readonly property var rightCells: clockIndex >= 0 ? cells.slice(clockIndex + 1) : []

    // ширина симметрична часам, поэтому центр зоны = центр часов = центр
    // экрана, а ячейки слева/справа заведомо влезают в свои половины
    implicitWidth: clockLoader.implicitWidth
        + 2 * Math.max(leftRow.implicitWidth, rightRow.implicitWidth)
        + 4 * Theme.space3
    implicitHeight: Theme.barH

    // id ячейки → её компонент
    function compFor(id) {
        if (id === "network") return netComp
        if (id === "weather") return weatherComp
        if (id === "media") return mediaComp
        if (id === "clock") return clockComp
        return null
    }

    // колесо над центром — громкость
    WheelHandler {
        onWheel: function (ev) {
            centerZone.host.bumpVol(ev.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    // ── часы: ось, прибита к центру зоны, а зона — к центру экрана ──
    Loader {
        id: clockLoader
        anchors.centerIn: parent
        height: parent.height
        sourceComponent: centerZone.compFor("clock")
    }

    // ── тихие разделители вокруг часов: часы читаются отдельным «островом».
    //    Высота — доля ячейки, цвет — едва заметный штрих текста. ──
    Rectangle {
        width: 1
        height: Math.round(Theme.barCellH * 0.55)
        anchors.right: clockLoader.left
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.alpha(Theme.barText, 0.12)
        visible: centerZone.mediaActive
    }
    Rectangle {
        width: 1
        height: Math.round(Theme.barCellH * 0.55)
        anchors.left: clockLoader.right
        anchors.leftMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.alpha(Theme.barText, 0.12)
        visible: centerZone.rightCells.length > 0
    }

    // ── ячейки слева от часов: прижаты к их левому краю ──
    Row {
        id: leftRow
        anchors.right: clockLoader.left
        anchors.rightMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: 6

        Repeater {
            model: centerZone.leftCells

            delegate: Loader {
                required property var modelData
                width: item ? item.implicitWidth : 0
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                // медиа-полоса появляется только когда есть что играть
                visible: modelData.id === "media" ? centerZone.mediaActive : true
                sourceComponent: centerZone.compFor(modelData.id)
            }
        }
    }

    // ── ячейки справа от часов: прижаты к их правому краю ──
    Row {
        id: rightRow
        anchors.left: clockLoader.right
        anchors.leftMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: 6

        Repeater {
            model: centerZone.rightCells

            delegate: Loader {
                required property var modelData
                width: item ? item.implicitWidth : 0
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                // медиа-полоса появляется только когда есть что играть
                visible: modelData.id === "media" ? centerZone.mediaActive : true
                sourceComponent: centerZone.compFor(modelData.id)
            }
        }
    }

    // ── сеть ↓: клик открывает сеть в Hub ──
    Component {
        id: netComp
        Cell {
            id: netCell
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            accent: centerZone.host.netKind === "off" ? Theme.barFaint : Theme.barDim
            tip: "Сеть (Hub)"
            onClicked: centerZone.host.openNetwork()
            // компактная скорость, как fmtSpeed у arch: 4 знака, без «КБ/с»
            function cs(kb) {
                if (kb >= 1024) {
                    var mb = kb / 1024
                    return (mb >= 10 ? Math.round(mb) : mb.toFixed(1)) + "M"
                }
                return Math.round(kb) + "K"
            }
            Row {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: centerZone.host.netKind === "eth" ? "󰈀" : "\uf1eb"
                    color: centerZone.host.netKind === "off" ? Theme.barFaint : Theme.barText
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(14)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // arch: только «вниз» (входящий поток) — компактно
                    text: "↓" + netCell.cs(SysInfo.rx)
                    color: Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
            }
        }
    }

    // ── погода: иконка + температура; клик раскрывает плашку вниз ──
    Component {
        id: weatherComp
        Cell {
            id: weatherCell
            anchors.verticalCenter: parent.verticalCenter
            interactive: true
            active: BarState.mode === "weather"
            accent: Theme.barFaint
            tip: "Погода"
            function openBubbleFromHere() {
                BarState.togglePanel("weather")
            }
            Component.onCompleted: centerZone.weatherCellRef = weatherCell
            Component.onDestruction: if (centerZone.weatherCellRef === weatherCell)
                centerZone.weatherCellRef = null
            onClicked: openBubbleFromHere()
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.icon
                    color: Weather.ok ? Theme.barText : Theme.barFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(15)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.shortTemp
                    color: Weather.ok ? Theme.barText : Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                }
            }
        }
    }

    // ── медиа-полоса в центре: обложка + трек + прогресс;
    //    клик раскрывает пузырь МЕДИА ──
    Component {
        id: mediaComp
        MediaCell {
            id: mediaStrip
            host: centerZone.host
            stripWidth: 420
            function openBubbleFromHere() {
                BarState.togglePanel("media")
            }
            Component.onCompleted: centerZone.mediaCellRef = mediaStrip
            Component.onDestruction: if (centerZone.mediaCellRef === mediaStrip)
                centerZone.mediaCellRef = null
            onClickedBubble: openBubbleFromHere()
        }
    }

    // ── часы + дата ──
    //    два Text прямо в ячейке: без вложенного Row с anchors — иначе
    //    неявная ширина ячейки не учитывала дату и правый сосед наезжал.
    Component {
        id: clockComp
        Cell {
            anchors.verticalCenter: parent.verticalCenter
            accent: Theme.accent
            tip: centerZone.host.dayText + " " + centerZone.host.dateText
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: centerZone.host.clockText
                color: Theme.barText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(17)
                font.bold: true
                font.letterSpacing: 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: centerZone.host.dayText + " " + centerZone.host.dateText
                color: Theme.barFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
