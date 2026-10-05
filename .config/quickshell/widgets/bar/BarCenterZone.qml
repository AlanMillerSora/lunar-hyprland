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
        width: implicitWidth
        sourceComponent: centerZone.compFor("clock")
    }

    // (отладочный лог убран)
    // разделители вокруг часов убраны — оставлены только отступы

    // ── «рельса» плеера: пока ничего не играет, на месте медиа-полосы —
    //    тонкая линия в тон орбите столов, чтобы центр не пустовал ──
    Rectangle {
        anchors.right: clockLoader.left
        anchors.rightMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        width: 640
        height: 1
        color: Theme.active
        visible: !centerZone.mediaActive
    }

    // architect: риски вдоль медиа-рельсы
    Row {
        visible: !centerZone.mediaActive && Theme.arch
        anchors.right: clockLoader.left
        anchors.rightMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26
        Repeater {
            model: 25
            delegate: Rectangle {
                required property int index
                width: 1
                height: index % 5 === 0 ? 9 : 4
                color: Theme.hairAccent
            }
        }
    }

    // architect: размерная скобка под часами (технический мотив)
    Item {
        visible: Theme.arch
        anchors.horizontalCenter: clockLoader.horizontalCenter
        anchors.bottom: parent.bottom
        width: clockLoader.width
        height: 5
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1
            color: Theme.hair
        }
        Rectangle {
            anchors { left: parent.left; top: parent.top }
            width: 1; height: 5
            color: Theme.hairAccent
        }
        Rectangle {
            anchors { right: parent.right; top: parent.top }
            width: 1; height: 5
            color: Theme.hairAccent
        }
    }

    // ── ячейки слева от часов: прижаты к их левому краю ──
    Row {
        id: leftRow
        anchors.right: clockLoader.left
        anchors.rightMargin: Theme.space6
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
        anchors.leftMargin: Theme.space6
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barH
        spacing: Theme.space4

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
                // прямой ребёнок Cell кладётся в Row ячейки: centerIn внутри
                // Row запрещён (варнинг) — выравниваю по вертикали, как соседи.
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space3
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: centerZone.host.netKind === "eth" ? "󰈀" : "\uf1eb"
                    color: centerZone.host.netKind === "off" ? Theme.barFaint : Theme.barText
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(14)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // входящий поток
                    text: "↓" + netCell.cs(SysInfo.rx)
                    color: Theme.barDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // исходящий поток
                    text: "↑" + netCell.cs(SysInfo.tx)
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
                spacing: Theme.space2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.icon
                    color: Weather.ok ? Theme.barText : Theme.barFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(15)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.hudBracket(Weather.shortTemp)
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
            stripWidth: 640
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
                text: Theme.hudBracket(centerZone.host.clockText)
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
