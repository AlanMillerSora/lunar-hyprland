import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarMedia — попап «сейчас играет» (клик по треку на панели):
//  крупно трек/исполнитель, прогресс и управление
//  (назад / пауза / вперёд). Источник — MPRIS.
//  IPC:  qs ipc call media toggle|open|close
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? backdrop : null }

    property bool showing: false

    function openPanel() { showing = true }
    function closePanel() { showing = false }
    function toggle() { showing ? closePanel() : openPanel() }

    IpcHandler {
        target: "media"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    // активный плеер: играющий, иначе первый доступный
    readonly property var player: {
        var ps = Mpris.players.values
        for (var i = 0; i < ps.length; i++)
            if (ps[i].isPlaying) return ps[i]
        return ps.length > 0 ? ps[0] : null
    }
    readonly property string track: player
        ? ((player.trackTitle || "—") + (player.trackArtist ? "\n" + player.trackArtist : ""))
        : "ничего не играет"
    readonly property real pos: player && player.position ? player.position : 0
    readonly property real len: player && player.length ? player.length : 0
    readonly property real progress: len > 0 ? Math.min(1, pos / len) : 0

    function fmt(s) {
        if (!s || s < 0) s = 0
        var m = Math.floor(s / 60), sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"
        focus: root.showing
        Keys.onEscapePressed: root.closePanel()
        MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
    }

    Rectangle {
        id: card
        width: 380
        height: 176
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

        MouseArea { anchors.fill: parent; onClicked: {} }

        HudCorners { color: Theme.accent; size: 14; thickness: 1; margin: 8 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                    color: root.player && root.player.isPlaying ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                }

                Text {
                    Layout.fillWidth: true
                    text: "СЕЙЧАС ИГРАЕТ"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 2
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

            Text {
                Layout.fillWidth: true
                text: root.track
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            // прогресс
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Theme.alpha(Theme.text, 0.12)

                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.fmt(root.pos)
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.fmt(root.len)
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            Item { Layout.fillHeight: true }

            // управление
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                Text {
                    text: "󰒮"
                    color: prevMouse.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 24
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.previous()
                    }
                }
                Text {
                    text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                    color: playMouse.containsMouse ? Theme.accent : Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: 30
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.togglePlaying()
                    }
                }
                Text {
                    text: "󰒭"
                    color: nextMouse.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 24
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.next()
                    }
                }
            }
        }
    }
}
