import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarPower — меню питания в стиле системы (Quickshell).
//  Открывается по SUPER + ESC.  IPC: qs ipc call power toggle|open|close
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? backdrop : null
    }

    property bool showing: false

    function openPanel() { showing = true }
    function closePanel() { showing = false }
    function toggle() { showing ? closePanel() : openPanel() }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    readonly property var actions: [
        { icon: "󰛇", label: "Спящий режим", key: "1", cmd: "systemctl suspend" },
        { icon: "󰤄",  label: "Гибернация",   key: "2", cmd: "systemctl hibernate" },
        { icon: "󰿅",  label: "Выйти",        key: "3", cmd: "hyprctl dispatch 'hl.dsp.exit()'" },
        { icon: "󰓮",  label: "Перезагрузить", key: "4", cmd: "systemctl reboot" },
        { icon: "󰐥",   label: "Выключить",    key: "5", cmd: "systemctl poweroff" }
    ]

    Process { id: runProc; running: false }

    function run(cmd) {
        runProc.command = ["bash", "-c", cmd]
        runProc.running = true
        closePanel()
    }

    // ── затемнение + закрытие ──
    Rectangle {
        id: backdrop
        anchors.fill: parent
        // затемнение/блюр только пока открыто
        color: root.showing ? Theme.alpha(Theme.bgPanel, 0.45) : "transparent"
        focus: root.showing

        Keys.onEscapePressed: root.closePanel()
        Keys.onPressed: function (event) {
            var i = event.key - Qt.Key_1
            if (i >= 0 && i < root.actions.length) {
                root.run(root.actions[i].cmd)
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    // ── карточка ──
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 440
        height: col.implicitHeight + 44
        color: Theme.bgPanel
        radius: Theme.radius
        border.color: Theme.accent
        border.width: 1

        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        HudCorners {
            color: Theme.accent
            size: 18
            thickness: 1
            margin: 10
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "POWER"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    font.bold: true
                    font.letterSpacing: 4
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "ESC — закрыть"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(9)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    height: 48
                    radius: Theme.radius
                    color: rowMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                    border.width: rowMouse.containsMouse ? 1 : 0
                    border.color: Theme.borderAccent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            text: modelData.icon
                            color: Theme.accent
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(18)
                        }

                        Text {
                            text: modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(13)
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: modelData.key
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(modelData.cmd)
                    }
                }
            }
        }
    }
}
