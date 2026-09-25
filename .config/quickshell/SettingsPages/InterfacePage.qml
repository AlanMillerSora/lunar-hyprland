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

    Timer {
        id: blurDebounce
        interval: 120
        onTriggered: page.applyBlur()
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
                if (delta !== 0) {
                    scrollArea.contentY = Math.max(
                        0,
                        Math.min(
                            scrollArea.contentHeight - scrollArea.height,
                            scrollArea.contentY - delta
                        )
                    )
                }
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
                            color: active ? Theme.alpha(Theme.accent, 0.12)
                                 : (perfMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent")
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
                    width: parent.width
                    value: Theme.interfaceOpacity
                    onValueChanged: Theme.interfaceOpacity = value
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
                    onValueChanged: {
                        page.blurValue = value
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
                    width: parent.width
                    value: (Theme.fontScale - 0.75) / 0.5
                    onValueChanged: Theme.fontScale = 0.75 + value * 0.5
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
                                ? Theme.alpha(Theme.accent, 0.12)
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
        property real minValue: 0
        property real maxValue: 1
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
            width: 2 + (parent.width - 20) * slider.value
            radius: 10
            color: Theme.accent
        }

        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var v = Math.max(0, Math.min(1, mouse.x / width))
                    slider.value = v
                }
            }
            onPressed: function(mouse) {
                var v = Math.max(0, Math.min(1, mouse.x / width))
                slider.value = v
            }
        }
    }
}
