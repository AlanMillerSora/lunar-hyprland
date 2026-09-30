import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarPower — меню питания в стиле системы (Quickshell).
//  Открывается по SUPER + ESC.  IPC: qs ipc call power toggle|open|close
// ════════════════════════════════════════════════════════════════
FloatingWindow {
    id: root

    title: "Lunar Power"
    // фон даёт окно, скругление/блюр — правило Hyprland по заголовку
    color: Theme.bgPanel
    visible: root.showing
    implicitWidth: 440
    implicitHeight: col.implicitHeight + 44
    minimumSize: Qt.size(360, 280)

    property bool showing: false
    // подтверждение необратимых действий (M69)
    property int pendingIndex: -1
    property string status: ""

    Timer {
        id: pendingReset
        interval: 4000
        onTriggered: { root.pendingIndex = -1; root.status = "" }
    }

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
        { icon: "󰛇", label: "Спящий режим", key: "1", cmd: "systemctl suspend", confirm: false },
        { icon: "󰤄",  label: "Гибернация",   key: "2", cmd: "systemctl hibernate", confirm: true },
        { icon: "󰿅",  label: "Выйти",        key: "3", cmd: "hyprctl dispatch 'hl.dsp.exit()'", confirm: true },
        { icon: "󰓮",  label: "Перезагрузить", key: "4", cmd: "systemctl reboot", confirm: true },
        { icon: "󰐥",   label: "Выключить",    key: "5", cmd: "systemctl poweroff", confirm: true }
    ]

    // гибернация недоступна без swap — прячем пункт (M69)
    property bool canHibernate: true

    Process {
        id: hibernateCheck
        running: true
        command: ["loginctl", "can-hibernate"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = ("" + text).trim().toLowerCase()
                if (t === "no")
                    root.canHibernate = false
            }
        }
    }

    Process {
        id: runProc
        running: false
        stderr: StdioCollector { id: runErr }
        // обратная связь: не глотаем ошибку (M69)
        onExited: (code) => {
            if (code !== 0) {
                root.status = (runErr.text || "").trim()
                    || ("команда не выполнилась (код " + code + ")")
                root.openPanel()
            }
        }
    }

    function run(cmd) {
        root.status = ""
        runProc.command = ["bash", "-c", cmd]
        runProc.running = true
        closePanel()
    }

    // запуск действия по индексу; для необратимых — второе подтверждение
    function runAt(i) {
        var a = root.actions[i]
        if (!a)
            return
        if (a.key === "2" && !root.canHibernate)
            return
        if (a.confirm && root.pendingIndex !== i) {
            root.pendingIndex = i
            root.status = "«" + a.label + "» — нажмите ещё раз для подтверждения"
            pendingReset.restart()
            return
        }
        root.pendingIndex = -1
        root.run(a.cmd)
    }

    // содержимое — прямо в окне: фон/рамку/радиус даёт FloatingWindow и
    // правило Hyprland; Esc, цифры и клавиатуру вешаю на предмет во весь экран
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closePanel()
        Keys.onPressed: function (event) {
            // цифры работают только «чистыми»: Ctrl/Alt/Shift+1 — не команды (M70).
            // NumPad (KeypadModifier) не блокируем.
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier
                                   | Qt.MetaModifier | Qt.ShiftModifier))
                return
            var i = event.key - Qt.Key_1
            if (i >= 0 && i < root.actions.length) {
                root.runAt(i)
                event.accepted = true
            }
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

            Text {
                Layout.fillWidth: true
                visible: root.status !== ""
                text: root.status
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(10)
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    visible: !(modelData.key === "2" && !root.canHibernate)
                    Layout.fillWidth: true
                    height: 48
                    radius: Theme.radius
                    color: (rowMouse.containsMouse || root.pendingIndex === index)
                        ? Theme.hoverStrong : "transparent"
                    border.width: (rowMouse.containsMouse || root.pendingIndex === index) ? 1 : 0
                    border.color: root.pendingIndex === index ? Theme.danger : Theme.borderAccent

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
                            color: root.pendingIndex === index ? Theme.danger : Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runAt(index)
                    }
                }
            }
        }
    }
}
