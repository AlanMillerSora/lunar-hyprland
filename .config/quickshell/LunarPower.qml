import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarPower — меню питания в стиле системы (Quickshell).
//  Открывается по SUPER + ESC.  IPC: qs ipc call power toggle|open|close
//  Вид подтянут к 43PR PowerMenu: крупные мягкие карточки-строки,
//  плитка-иконка, бейдж горячей клавиши, акцентная подсветка наведения
//  и подтверждения. Функциональность прежняя: спящий/гибернация/выход/
//  перезагрузка/выключение, цифры 1–5, Esc, второе подтверждение.
// ════════════════════════════════════════════════════════════════
FloatingWindow {
    id: root

    title: "Lunar Power"
    // фон даёт окно, скругление/блюр — правило Hyprland по заголовку
    color: Theme.surfacePanel
    visible: root.showing
    implicitWidth: 480
    implicitHeight: col.implicitHeight + Theme.space5 + Theme.space4
    minimumSize: Qt.size(400, 340)

    property bool showing: false
    onShowingChanged: Theme.setModal("power", showing)
    onClosed: Theme.setModal("power", false)
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
        { icon: "󰛇", label: "Спящий режим",  hint: "systemctl suspend",  key: "1", cmd: "systemctl suspend", confirm: false },
        { icon: "󰤄",  label: "Гибернация",    hint: "systemctl hibernate", key: "2", cmd: "systemctl hibernate", confirm: true },
        { icon: "󰿅",  label: "Выйти",         hint: "hyprctl exit",        key: "3", cmd: "hyprctl dispatch 'hl.dsp.exit()'", confirm: true },
        { icon: "󰓮",  label: "Перезагрузить", hint: "systemctl reboot",    key: "4", cmd: "systemctl reboot", confirm: true },
        { icon: "󰐥",   label: "Выключить",     hint: "systemctl poweroff",  key: "5", cmd: "systemctl poweroff", confirm: true }
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

        HudNodes { inset: 6; size: 4 }
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
            anchors.margins: Theme.cardPad
            spacing: Theme.space3

            // ── шапка: заголовок + подпись + бейдж Esc ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3

                ColumnLayout {
                    spacing: 1
                    Text {
                        text: "POWER"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(Theme.fontPanelTitle)
                        font.bold: true
                        font.letterSpacing: 4
                    }
                    Text {
                        text: "ПИТАНИЕ · СИСТЕМА"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNano
                        font.letterSpacing: 2
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 26
                    radius: Theme.radiusS
                    color: Theme.fill
                    border.width: 1
                    border.color: Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "ESC"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNano
                        font.bold: true
                        font.letterSpacing: 1
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            // ── баннер подтверждения/ошибки ──
            Rectangle {
                Layout.fillWidth: true
                visible: root.status !== ""
                implicitHeight: statusText.implicitHeight + Theme.space2 * 2
                radius: Theme.radiusS
                color: Theme.alpha(Theme.danger, 0.10)
                border.width: 1
                border.color: Theme.alpha(Theme.danger, 0.35)

                Text {
                    id: statusText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.space2
                    text: root.status
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    wrapMode: Text.WordWrap
                }
            }

            // ── крупные мягкие карточки действий ──
            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool pending: root.pendingIndex === index
                    readonly property bool hovered: cardMouse.containsMouse

                    visible: !(modelData.key === "2" && !root.canHibernate)
                    Layout.fillWidth: true
                    height: 66
                    radius: Theme.radiusM
                    color: card.pending ? Theme.alpha(Theme.danger, 0.14)
                         : card.hovered ? Theme.hoverStrong
                         : Theme.fill
                    border.width: (card.pending || card.hovered) ? 1 : 0
                    border.color: card.pending ? Theme.alpha(Theme.danger, 0.6)
                                               : Theme.activeBorder

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    // акцентная риска слева — наведение/подтверждение
                    Rectangle {
                        width: 3
                        height: parent.height - 24
                        radius: Theme.radiusHair
                        anchors.left: parent.left
                        anchors.leftMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: card.pending ? Theme.danger : Theme.accent
                        opacity: card.pending ? 1 : (card.hovered ? 0.9 : 0)
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space4
                        anchors.rightMargin: Theme.space4
                        spacing: Theme.space3

                        // плитка-иконка
                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: Theme.radiusTile
                            color: card.pending ? Theme.alpha(Theme.danger, 0.14)
                                                : Theme.alpha(Theme.accent, 0.10)

                            Text {
                                anchors.centerIn: parent
                                text: card.modelData.icon
                                color: card.pending ? Theme.danger : Theme.accent
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(19)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.label
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBody
                                font.bold: card.pending || card.hovered
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: card.pending
                                    ? "нажмите ещё раз — подтвердить"
                                    : card.modelData.hint
                                color: card.pending ? Theme.danger : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNano
                                elide: Text.ElideRight
                            }
                        }

                        // бейдж горячей клавиши
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: Theme.radiusS
                            color: Theme.alpha(Theme.text, 0.07)
                            border.width: 1
                            border.color: card.pending ? Theme.alpha(Theme.danger, 0.5)
                                                       : Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: card.modelData.key
                                color: card.pending ? Theme.danger : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runAt(card.index)
                    }
                }
            }

            // ── подвал: подсказка по клавишам ──
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: "1–5 — выбор · клик — выполнить"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNano
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
