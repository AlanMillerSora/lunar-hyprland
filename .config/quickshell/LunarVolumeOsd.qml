import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    anchors { top: true; left: true; right: true }
    implicitHeight: 120
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Кликабелен/рисуется только когда виден. Без маски эта поверхность
    // (1920x120) перехватывала все клики в верхней части экрана — из-за этого
    // не работали вкладки Chrome.
    mask: Region {
        item: root.showing ? flyout : null
    }

    property int volume: -1
    property bool muted: false
    property bool showing: false

    function showOsd() { showing = true; hideTimer.restart() }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.showing = false
    }

    Process {
        id: volProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                var m = t.match(/Volume:\s*([0-9.]+)/)
                var newVol = m ? Math.round(parseFloat(m[1]) * 100) : root.volume
                var newMuted = t.includes("[MUTED]")
                if (newVol !== root.volume || newMuted !== root.muted) {
                    root.volume = newVol
                    root.muted = newMuted
                    root.showOsd()
                }
            }
        }
    }
    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: volProc.running = true
    }

    Rectangle {
        id: flyout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 54
        width: 160
        height: 44
        radius: Theme.radius
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.95

        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120 } }

        HudCorners {
            color: Theme.accent
            size: 16
            thickness: 1
            margin: 6
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                text: root.muted ? "󰖁" : "󰕾"
                color: root.muted ? Theme.textDim : Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 12
            }

            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 1
                color: Theme.trackBg
                Rectangle {
                    width: parent.width * (root.muted ? 0 : Math.min(root.volume / 100, 1))
                    height: parent.height
                    radius: 1
                    color: root.muted ? Theme.textDim : Theme.accent
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }

            Text {
                text: root.volume + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
    }
}
