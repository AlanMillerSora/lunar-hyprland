import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: page

    property string mono: "JetBrainsMono Nerd Font"
    property int rightMargin: 36

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
