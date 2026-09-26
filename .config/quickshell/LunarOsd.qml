import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarOsd — единый индикатор: громкость и яркость в одном месте.
//  Вид: иконка + число + деления (сегментная шкала).
//
//  Громкость показывается сама при изменении (опрос wpctl).
//  Яркость — по IPC:  qs ipc call brightness open|toggle
//  Значение яркости берём из eclipse-brightness.sh (brightnessctl/ddcutil).
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true }
    implicitHeight: 120
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // кликабелен/рисуется только когда виден — иначе перехватывает клики сверху
    mask: Region {
        item: root.showing ? flyout : null
    }

    property string kind: "volume"      // "volume" | "brightness"
    property int volume: -1
    property bool muted: false
    property int level: -1
    property bool showing: false

    readonly property int segments: 20

    readonly property real frac: {
        if (kind === "brightness")
            return level >= 0 ? Math.min(Math.max(level / 100, 0), 1) : 0
        return (muted || volume <= 0) ? 0 : Math.min(volume / 100, 1)
    }
    readonly property string label: kind === "brightness"
        ? level + "%"
        : (muted ? "mute" : volume + "%")
    // глифы FontAwesome: mute/volume-low/volume-high и солнце
    readonly property string icon: kind === "brightness"
        ? "\uf185"
        : (muted ? "\uf026" : (volume < 50 ? "\uf027" : "\uf028"))

    function showOsd(k) {
        kind = k
        if (k === "volume" && Theme.volumePopupOpen) {
            showing = false
            return
        }
        showing = true
        hideTimer.restart()
    }

    // попап громкости открыт — OSD прячем, чтобы не было дубля по центру
    Connections {
        target: Theme
        function onVolumePopupOpenChanged() {
            if (Theme.volumePopupOpen && root.kind === "volume")
                root.showing = false
        }
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.showing = false
    }

    // ── громкость: следим за значением ──
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
                    root.showOsd("volume")
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

    // ── яркость: по IPC ──
    Process {
        id: brightProc
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/eclipse-brightness.sh get | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(text.trim())
                if (!isNaN(v)) {
                    root.level = v
                    root.showOsd("brightness")
                } else {
                    root.showing = false
                }
            }
        }
    }

    IpcHandler {
        target: "brightness"
        function open(): void { brightProc.running = true }
        function toggle(): void { brightProc.running = true }
    }

    Rectangle {
        id: flyout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 54
        width: 340
        height: 54
        radius: Theme.radius
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.95

        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120 } }

        HudCorners { color: Theme.accent; size: 16; thickness: 1; margin: 6 }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // иконка
            Text {
                text: root.icon
                color: (root.kind === "volume" && root.muted) ? Theme.textDim : Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 17
            }

            // число
            Text {
                Layout.preferredWidth: 46
                horizontalAlignment: Text.AlignLeft
                text: root.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
            }

            // деления
            Row {
                id: segRow
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: root.segments

                    delegate: Rectangle {
                        required property int index
                        readonly property bool on: index < Math.round(root.frac * root.segments)
                        readonly property bool dim: root.kind === "volume" && root.muted

                        width: Math.max(2, (segRow.width - (root.segments - 1) * 3) / root.segments)
                        height: 12
                        radius: 1
                        color: dim ? Theme.alpha(Theme.textDim, 0.45)
                             : on ? Theme.accent
                             : Theme.alpha(Theme.text, 0.10)
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }
            }
        }
    }
}
