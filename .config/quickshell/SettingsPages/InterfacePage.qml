import QtQuick
import Quickshell.Io
import QtQuick.Layouts
import "../"

Item {
    id: page

    property string mono: "JetBrainsMono Nerd Font"
    property int rightMargin: 36

    // ── размытие (блюр) — управляет Hyprland, действует на всю систему ──
    property real blurValue: 0.66          // 0..1  → size 0..12
    property bool blurReady: false

    Process {
        id: blurGet
        running: true
        command: ["bash", "-c", "hyprctl -j getoption decoration:blur:size 2>/dev/null | jq -r '.int // 0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                // если ползунок уже выставляли — он главнее текущего Hyprland
                var s = (Theme.blurSize >= 0) ? Theme.blurSize : parseInt(text.trim())
                if (!isNaN(s)) {
                    page.blurValue = Math.max(0, Math.min(1, s / 12))
                    page.blurReady = true
                }
            }
        }
    }

    // M47: uiState может загрузиться позже blurGet — тогда ползунок блюра
    // показывал бы значение из Hyprland, а не сохранённое. Подхватываем Theme.
    Connections {
        target: Theme
        function onBlurSizeChanged() {
            if (Theme.blurSize >= 0) {
                page.blurValue = Math.max(0, Math.min(1, Theme.blurSize / 12))
                page.blurReady = true
            }
        }
    }

    Timer {
        id: blurDebounce
        interval: 120
        onTriggered: page.applyBlur()
    }

    // M45: прозрачность/шрифт раньше писали lunar-ui.json на каждый кадр
    // перетаскивания — теперь только после паузы (как у блюра).
    Timer {
        id: opacityDebounce
        interval: 150
        onTriggered: Theme.interfaceOpacity = opacitySlider.dragValue
    }

    Timer {
        id: fontDebounce
        interval: 150
        onTriggered: Theme.fontScale = 0.75 + fontSlider.dragValue * 0.5
    }

    function applyBlur() {
        var size = Math.round(blurValue * 12)
        var passes = size >= 6 ? 4 : 3
        Theme.setBlur(size, passes)   // запоминает в Theme и применяет
    }

    Flickable {
        id: scrollArea
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: function(event) {
                var delta = event.angleDelta.y
                // L33: горизонтальные/пустые события не съедаем
                if (delta === 0)
                    return
                scrollArea.contentY = Math.max(
                    0,
                    Math.min(
                        scrollArea.contentHeight - scrollArea.height,
                        scrollArea.contentY - delta
                    )
                )
                event.accepted = true
            }
        }

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                rightMargin: page.rightMargin
            }
            spacing: 20

            Text {
                text: "INTERFACE"
                color: Theme.text
                font.family: page.mono
                font.pixelSize: 18
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // M73: ошибка чтения lunar-ui.json (битый JSON / нет доступа) —
            // настройки молча уходят в дефолты, поэтому сообщаем явно
            Rectangle {
                visible: Theme.uiError !== ""
                width: parent.width
                height: errText.implicitHeight + 24
                radius: Theme.radius
                color: Theme.alpha(Theme.danger, 0.08)
                border.width: 1
                border.color: Theme.danger

                Text {
                    id: errText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 12
                    text: "\uf071  настройки интерфейса не прочитаны: " + Theme.uiError
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }

            // Производительность: NORMAL (полный блюр, обои 60 fps)
            //                  / OPTIMIZE (легче, обои ~25 fps)
            Column {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 16

                    Text {
                        text: "\uf0e7"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "производительность"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: Theme.optimizeMode
                                ? "OPTIMIZE — блюр легче, обои ~25 fps (слабое железо)"
                                : "NORMAL — полный блюр, обои ~60 fps"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                Row {
                    spacing: 8

                    Repeater {
                        model: [{ mode: false, label: "NORMAL" }, { mode: true, label: "OPTIMIZE" }]

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: Theme.optimizeMode === modelData.mode

                            width: perfText.implicitWidth + 28
                            height: 30
                            radius: Theme.radius
                            color: active ? Theme.active
                                 : (perfMouse.containsMouse ? Theme.hoverStrong : "transparent")
                            border.width: 1
                            border.color: active ? Theme.accent
                                        : (perfMouse.containsMouse ? Theme.borderAccent : Theme.border)

                            Text {
                                id: perfText
                                anchors.centerIn: parent
                                text: modelData.label
                                color: active ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: active
                            }

                            MouseArea {
                                id: perfMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.optimizeMode = modelData.mode
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // Прозрачность панели
            Column {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 16

                    Text {
                        text: "󰝴"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "прозрачность интерфейса"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: Math.round(Theme.interfaceOpacity * 100) + "%"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                CustomSlider {
                    id: opacitySlider
                    width: parent.width
                    value: Theme.interfaceOpacity
                    // M45/L35: только от пользователя, запись — после паузы
                    onMoved: opacityDebounce.restart()
                }
            }

            // Размытие (блюр) — на всю систему через Hyprland
            Column {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 16

                    Text {
                        text: "\uf043"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "размытие (блюр)"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: page.blurValue <= 0.01
                                ? "выключен"
                                : Math.round(page.blurValue * 100) + "%"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                CustomSlider {
                    width: parent.width
                    value: page.blurValue
                    onMoved: function(v) {
                        page.blurValue = v
                        blurDebounce.restart()
                    }
                }
            }

            // Размер шрифта
            Column {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 16

                    Text {
                        text: "󰬶"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "размер шрифта"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: Math.round(Theme.fontScale * 100) + "%"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                CustomSlider {
                    id: fontSlider
                    width: parent.width
                    value: (Theme.fontScale - 0.75) / 0.5
                    // M45/L35: только от пользователя, запись — после паузы
                    onMoved: fontDebounce.restart()
                }
            }

            // Значков трея в панели
            Column {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 16

                    Text {
                        text: "\uf00a"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "значков трея в панели"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: Theme.trayVisible + " видно, остальные — в списке «+N»"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                Row {
                    spacing: 8

                    Repeater {
                        model: [1, 2, 3, 4, 5, 6]

                        delegate: Rectangle {
                            required property int modelData
                            width: 40
                            height: 30
                            radius: Theme.radius
                            color: Theme.trayVisible === modelData
                                ? Theme.active
                                : "transparent"
                            border.width: 1
                            border.color: Theme.trayVisible === modelData
                                ? Theme.accent
                                : (presetMouse.containsMouse ? Theme.borderAccent : Theme.border)

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: Theme.trayVisible === modelData ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: Theme.trayVisible === modelData
                            }

                            MouseArea {
                                id: presetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.trayVisible = modelData
                            }
                        }
                    }
                }
            }

            // Превью
            Rectangle {
                width: parent.width
                height: 80
                radius: Theme.radiusM
                color: Theme.bgCard
                border.color: Theme.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "превью шрифта"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                }
            }
        }
    }

    component CustomSlider: Rectangle {
        id: slider
        property real value: 0.5
        // значение во время перетаскивания: не трогаем value, иначе рвём
        // привязку вызывающей стороны (L35)
        property real dragValue: 0
        // только от пользователя (программная установка value сюда не шлёт)
        signal moved(real v)
        // «заполнение» при появлении: старт с нуля → плавно к value
        property real shown: 0
        property bool primed: false
        onValueChanged: if (primed) shown = value
        Component.onCompleted: primeTimer.restart()
        Timer {
            id: primeTimer
            interval: 60
            onTriggered: { slider.shown = slider.value; slider.primed = true }
        }
        // пока тянем — значение под курсором, иначе — текущее value
        readonly property real displayValue:
            sliderDrag.pressed ? slider.dragValue : slider.shown
        height: 24
        radius: 12
        color: Theme.trackBg
        border.color: Theme.border
        border.width: 1

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 2
            width: 2 + (parent.width - 20)
                * Math.max(0, Math.min(1, slider.displayValue))
            radius: 10
            color: Theme.accent
            // плавное заполнение, как у полос в «Памяти»
            Behavior on width {
                enabled: !sliderDrag.pressed
                NumberAnimation { duration: 200 }
            }
        }

        MouseArea {
            id: sliderDrag
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            // M46: иначе Flickable перехватывает перетаскивание
            preventStealing: true
            function setFromX(px) {
                var v = Math.max(0, Math.min(1, px / slider.width))
                slider.dragValue = v
                slider.moved(v)
            }
            onPositionChanged: function(mouse) {
                if (pressed)
                    setFromX(mouse.x)
            }
            onPressed: function(mouse) {
                setFromX(mouse.x)
            }
            onReleased: {
                // фиксируем последнее значение, чтобы заполнение не мигало
                // до срабатывания debounce
                slider.shown = slider.dragValue
            }
        }
    }
}
