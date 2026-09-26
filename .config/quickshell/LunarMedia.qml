import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// ════════════════════════════════════════════════════════════════
//  LunarMedia — попап «сейчас играет» (клик по треку на панели):
//  обложка в монохроме (дуотон), крупный спектр cava, мягкий seek
//  со временем и управление (назад / пауза / вперёд). Источник — MPRIS.
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
    readonly property bool playing: player ? player.isPlaying : false
    readonly property string title: player && player.trackTitle ? player.trackTitle : "ничего не играет"
    readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
    readonly property string art: player && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property real pos: player && player.position ? player.position : 0
    readonly property real len: player && player.length ? player.length : 0
    readonly property real progress: len > 0 ? Math.min(1, pos / len) : 0
    readonly property bool seekable: player !== null && player.canSeek === true && len > 0

    function fmt(s) {
        if (!s || s < 0 || !isFinite(s))
            s = 0
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
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
        width: 460
        height: 306
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
            anchors.margins: 18
            spacing: 14

            // ── шапка ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.playing ? "\uf04c" : "\uf04b"
                    color: root.playing ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(13)
                }
                Text {
                    Layout.fillWidth: true
                    text: "СЕЙЧАС ИГРАЕТ"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    font.letterSpacing: 2
                }
                Text {
                    text: "\uf00d"
                    color: closeMouse.containsMouse ? Theme.danger : Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(11)
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePanel()
                    }
                }
            }

            // ── обложка + трек ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // обложка: монохром/лёгкий дуотон (или заглушка)
                Item {
                    Layout.preferredWidth: 128
                    Layout.preferredHeight: 128
                    clip: true

                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: root.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: coverImg
                        visible: root.art.length > 0
                        saturation: -1.0
                        brightness: 0.04
                        colorization: 0.28
                        colorizationColor: Theme.accent
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: root.art.length === 0
                        color: Theme.bgCard
                        border.color: Theme.border
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "\uf001"
                            color: Theme.textFaint
                            font.family: Theme.iconFont
                            font.pixelSize: 40
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(17)
                        font.bold: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.artist.length > 0
                        text: root.artist
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        wrapMode: Text.Wrap
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // ── мягкий seek со временем ──
            Item {
                id: seek
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                property real dragFrac: 0
                readonly property real frac: seekArea.pressed ? dragFrac : root.progress

                Rectangle {
                    id: seekBg
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -6
                    width: parent.width
                    height: 5
                    radius: 2.5
                    color: Theme.alpha(Theme.text, 0.12)

                    Rectangle {
                        id: seekFill
                        width: parent.width * seek.frac
                        height: parent.height
                        radius: parent.radius
                        color: root.seekable ? Theme.accent : Theme.textDim
                        Behavior on width {
                            enabled: !seekArea.pressed
                            NumberAnimation { duration: 200 }
                        }
                    }

                    // «мягкая» ручка — появляется на наведении/перетаскивании
                    Rectangle {
                        id: seekHandle
                        width: 12
                        height: 12
                        radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(seekBg.width, seekBg.width * seek.frac)) - width / 2
                        color: Theme.text
                        border.color: Theme.accent
                        border.width: 2
                        opacity: (seekArea.pressed || seekArea.containsMouse) && root.seekable ? 1 : 0
                        scale: seekArea.pressed ? 1.15 : 1.0
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                    }
                }

                // время: слева — текущее, справа — длительность
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: seekBg.bottom
                    anchors.topMargin: 7
                    Text {
                        text: root.fmt(seekArea.pressed ? seek.dragFrac * root.len : root.pos)
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.fmt(root.len)
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                    }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    anchors.margins: -8
                    preventStealing: true
                    hoverEnabled: true
                    enabled: root.seekable
                    cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    function setFromX(px) {
                        seek.dragFrac = Math.max(0, Math.min(1, px / seekBg.width))
                    }
                    onPressed: (mouse) => setFromX(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
                    onReleased: {
                        if (root.seekable && root.player && root.len > 0)
                            root.player.position = Math.max(0, Math.min(1, seek.dragFrac)) * root.len
                    }
                }
            }

            // ── управление ──
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 28

                Text {
                    text: "\uf048"
                    color: prevMouse.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(22)
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.previous()
                    }
                }
                Text {
                    text: root.playing ? "\uf04c" : "\uf04b"
                    color: playMouse.containsMouse ? Theme.accent : Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(30)
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.togglePlaying()
                    }
                }
                Text {
                    text: "\uf051"
                    color: nextMouse.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(22)
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
