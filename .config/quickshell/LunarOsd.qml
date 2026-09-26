import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarOsd — индикатор громкости: иконка + число + деления
//  (сегментная шкала). Показывается сам при изменении звука
//  (опрос wpctl). Пока открыт попап громкости — OSD прячем, без дубля.
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

    property int volume: -1
    property bool muted: false
    property bool showing: false
    // первый успешный замер — только запоминаем значение, OSD не показываем
    // (иначе при запуске/перезапуске шелла всплывает ползунок под часами)
    property bool primed: false

    readonly property int segments: 20
    readonly property real frac: (muted || volume <= 0) ? 0 : Math.min(volume / 100, 1)
    readonly property string label: muted ? "mute" : volume + "%"
    // FontAwesome: mute / volume-low / volume-high
    readonly property string icon: muted ? "\uf026" : (volume < 50 ? "\uf027" : "\uf028")

    function showOsd() {
        // попап громкости открыт — OSD не нужен (иначе дубль по центру)
        if (Theme.volumePopupOpen) {
            showing = false
            return
        }
        showing = true
        hideTimer.restart()
    }

    Connections {
        target: Theme
        function onVolumePopupOpenChanged() {
            if (Theme.volumePopupOpen)
                root.showing = false
        }
    }

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
                if (!m)
                    return
                var newVol = Math.round(parseFloat(m[1]) * 100)
                var newMuted = t.includes("[MUTED]")
                var changed = newVol !== root.volume || newMuted !== root.muted
                root.volume = newVol
                root.muted = newMuted
                if (!root.primed) {
                    root.primed = true
                    return
                }
                if (changed)
                    root.showOsd()
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
                color: root.muted ? Theme.textDim : Theme.accent
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

                        width: Math.max(2, (segRow.width - (root.segments - 1) * 3) / root.segments)
                        height: 12
                        radius: 1
                        color: root.muted ? Theme.alpha(Theme.textDim, 0.45)
                             : on ? Theme.accent
                             : Theme.alpha(Theme.text, 0.10)
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }
            }
        }
    }
}
