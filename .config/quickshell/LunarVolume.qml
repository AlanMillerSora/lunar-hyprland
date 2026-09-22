import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarVolume — попап громкости с крупным ползунком (клик по
//  значку громкости на панели). Слева — mute, справа — микшер.
//  IPC:  qs ipc call volume toggle|open|close
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    // попап открывается кликом — забираем клавиатуру, чтобы сразу работал Esc
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? backdrop : null
    }

    property bool showing: false

    function openPanel() { showing = true; Theme.volumePopupOpen = true }
    function closePanel() { showing = false; Theme.volumePopupOpen = false }
    function toggle() { showing ? closePanel() : openPanel() }

    IpcHandler {
        target: "volume"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    function setVol(v) {
        if (sink && sink.audio) {
            sink.audio.muted = false
            sink.audio.volume = Math.max(0, Math.min(1, v))
        }
    }

    function toggleMute() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted
    }

    Process { id: mixerProc; running: false }
    function openMixer() {
        mixerProc.command = ["bash", "-c", "setsid pavucontrol >/dev/null 2>&1 &"]
        mixerProc.running = true
        closePanel()
    }

    // клик мимо попапа — закрыть
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"
        focus: root.showing
        Keys.onEscapePressed: root.closePanel()

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    Rectangle {
        id: card
        width: 340
        height: 158
        anchors.top: parent.top
        anchors.topMargin: 52
        anchors.right: parent.right
        anchors.rightMargin: 12
        radius: Theme.radius
        color: Theme.bgPanel
        border.color: Theme.accent
        border.width: 1

        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        HudCorners {
            color: Theme.accent
            size: 14
            thickness: 1
            margin: 8
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.muted
                        ? "󰖁"
                        : (root.vol < 0.34 ? "󰕿" : (root.vol < 0.67 ? "󰖀" : "󰕾"))
                    color: root.muted ? Theme.textFaint : Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: 18

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                Text {
                    text: root.muted ? "MUTE" : Math.round(root.vol * 100) + "%"
                    color: root.muted ? Theme.textDim : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "микшер"
                    color: mixerMouse.containsMouse ? Theme.accent : Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9

                    MouseArea {
                        id: mixerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openMixer()
                    }
                }

                Text {
                    text: "\uf00d"
                    color: closeMouse.containsMouse ? Theme.danger : Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: 11

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePanel()
                    }
                }
            }

            // крупный ползунок — им реально удобно пользоваться
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 66
                trackHeight: 12
                handleSize: 24
                value: root.muted ? 0 : root.vol
                onMoved: (v) => root.setVol(v)
                onCommitted: (v) => root.setVol(v)
            }

            Text {
                Layout.fillWidth: true
                text: "колесо по значку на панели — быстрый шаг"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }
        }
    }
}
