import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarOsd — индикатор громкости: иконка + значение [ NN% ] + деления
//  (TickScale). Показывается сам при изменении звука
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

    readonly property real frac: (muted || volume <= 0) ? 0 : Math.min(volume / 100, 1)

    // плавное заполнение делений при показе и при изменении (как в «Памяти»)
    property real shownFrac: 0
    Behavior on shownFrac { NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.easeOut } }
    onShowingChanged: shownFrac = showing ? frac : 0
    onFracChanged: if (showing) shownFrac = frac
    // значение в технических скобках: [ 42% ]
    readonly property string label: muted ? "[ mute ]" : (volume < 0 ? "[ -- ]" : "[ " + volume + "% ]")
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
                Layout.preferredWidth: 78
                horizontalAlignment: Text.AlignLeft
                text: root.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.bold: true
            }

            // деления — общий примитив TickScale (технические насечки).
            // Число рисок считаю под доступную ширину, чтобы шкала тянулась
            // по всей полосе, как прежняя сегментная.
            Item {
                id: scaleBox
                Layout.fillWidth: true
                implicitHeight: 12

                readonly property int tickSpacing: 3
                readonly property int tickW: 2
                readonly property int tickCount: Math.max(8,
                    Math.floor((width + tickSpacing) / (tickW + tickSpacing)))

                TickScale {
                    anchors.verticalCenter: parent.verticalCenter
                    count: scaleBox.tickCount
                    value: root.shownFrac
                    tickW: scaleBox.tickW
                    tickH: 12
                    spacing: scaleBox.tickSpacing
                    tickColor: root.muted ? Theme.alpha(Theme.textDim, 0.45)
                             : Theme.alpha(Theme.text, 0.10)
                    onColor: root.muted ? Theme.alpha(Theme.textDim, 0.45)
                             : Theme.accent
                }
            }
        }
    }
}
