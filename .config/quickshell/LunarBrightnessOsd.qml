import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarBrightnessOsd — индикатор яркости (клавиши XF86MonBrightnessUp/Down).
//  Показывается по IPC:  qs ipc call brightness open
//  Значение берётся из eclipse-brightness.sh (ноут — brightnessctl,
//  внешние мониторы — ddcutil), поэтому опрос по таймеру не нужен.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true }
    implicitHeight: 190
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // кликабелен/рисуется только когда виден (иначе перехватывал бы клики)
    mask: Region {
        item: root.showing ? flyout : null
    }

    property int level: -1
    property bool showing: false

    IpcHandler {
        target: "brightness"
        function open(): void { root.refresh() }
        function toggle(): void { root.refresh() }
    }

    function refresh() {
        getProc.running = true
    }

    function showOsd() {
        showing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.showing = false
    }

    Process {
        id: getProc
        command: [
            "bash",
            "-c",
            "$HOME/.config/hypr/scripts/eclipse-brightness.sh get | head -1"
        ]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(text.trim())
                if (!isNaN(v)) {
                    root.level = v
                    root.showOsd()
                } else {
                    root.showing = false
                }
            }
        }
    }

    Rectangle {
        id: flyout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 118          // ниже OSD громкости, чтобы не перекрывались
        width: 320
        height: 56
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
            anchors.margins: 14
            spacing: 12

            Text {
                text: "\uf185"
                color: Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 17
            }

            Rectangle {
                Layout.fillWidth: true
                height: 10
                radius: 5
                color: Theme.trackBg

                Rectangle {
                    width: parent.width * Math.min(Math.max(root.level / 100, 0), 1)
                    height: parent.height
                    radius: 5
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }

            Text {
                text: root.level + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
            }
        }
    }
}
