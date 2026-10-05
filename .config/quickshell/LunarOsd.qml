import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarOsd — индикатор громкости: иконка + число + деления
//  (сегментная шкала). Показывается сам при изменении звука
//  (напрямую из PipeWire). Пока открыт попап громкости — OSD прячем, без дубля.
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

    // громкость берём прямо из PipeWire — без опроса wpctl через bash
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int volume: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : -1
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    property bool showing: false
    // первый замер после старта не показываем (иначе OSD всплывал бы при
    // запуске шелла). Праймим по времени, а не по первому значению, чтобы
    // не проглотить первое реальное изменение громкости.
    property bool primed: false
    Component.onCompleted: primeTimer.restart()
    Timer {
        id: primeTimer
        interval: 250
        onTriggered: root.primed = true
    }

    // изменение звука → показать OSD (после прайма и при наличии устройства).
    // Пока открыт пузырь звука — не показываю: там свой ползунок громкости.
    onVolumeChanged: if (root.primed && root.volume >= 0 && BarState.mode !== "audio") root.showOsd()
    onMutedChanged: if (root.primed && root.volume >= 0 && BarState.mode !== "audio") root.showOsd()

    readonly property int segments: 20
    readonly property real frac: (muted || volume <= 0) ? 0 : Math.min(volume / 100, 1)

    // плавное заполнение делений при показе и при изменении (как в «Памяти»)
    property real shownFrac: 0
    Behavior on shownFrac { NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.easeOut } }
    onShowingChanged: shownFrac = showing ? frac : 0
    onFracChanged: if (showing) shownFrac = frac
    readonly property string label: muted ? "mute" : (volume < 0 ? "--" : volume + "%")
    // FontAwesome: mute / volume-low / volume-high
    readonly property string icon: muted ? "\uf026" : (volume < 50 ? "\uf027" : "\uf028")

    function showOsd() {
        showing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.showing = false
    }

    Rectangle {
        id: flyout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 54
        width: 340
        height: 54
        radius: Theme.radiusL
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.95

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }

        HudCrosshairs { inset: 10; arm: 5 }
        HudNodes { inset: 5; size: 4 }
        HudInnerFrame { variant: 0 }
        HudDiagonals {}
        HudCorners { color: Theme.accent; size: 16; thickness: 1; margin: Theme.space3 }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.space4
            spacing: Theme.space3

            // иконка
            Text {
                text: root.icon
                color: root.muted ? Theme.textDim : Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSize(17)
            }

            // число
            Text {
                Layout.preferredWidth: 46
                horizontalAlignment: Text.AlignLeft
                text: root.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
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
                        readonly property bool on: index < Math.round(root.shownFrac * root.segments)

                        width: Math.max(2, (segRow.width - (root.segments - 1) * 3) / root.segments)
                        height: 12
                        radius: Theme.radiusHair
                        color: root.muted ? Theme.alpha(Theme.textDim, 0.45)
                             : on ? Theme.accent
                             : Theme.alpha(Theme.text, 0.10)
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }
            }
        }
    }
}
