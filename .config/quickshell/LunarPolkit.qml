import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarPolkit — свой агент polkit (запрос пароля) в стиле риса.
//  Заменяет светлый KDE-агент: Quickshell сам регистрируется в polkit
//  и на запрос авторизации показывает монохромную карточку.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "lunar-polkit"

    property bool showing: false

    PolkitAgent {
        id: polkit
        onAuthenticationRequestStarted: root.openPanel()
        onIsActiveChanged: if (!polkit.isActive) root.closePanel()
    }
    readonly property var flow: polkit.flow

    function openPanel() {
        pw.text = ""
        showing = true
        focusTimer.restart()
    }
    function closePanel() { showing = false }

    function submit() {
        if (!flow) { closePanel(); return }
        flow.submit(flow.isResponseRequired ? pw.text : "")
    }
    function cancel() {
        if (flow) flow.cancelAuthenticationRequest()
        closePanel()
    }

    mask: Region { item: root.showing ? backdrop : null }

    Timer { id: focusTimer; interval: 60; onTriggered: pw.forceActiveFocus() }

    // клик мимо не закрывает: пароль не должен теряться случайно
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: root.showing ? Theme.alpha(Theme.bgPanel, 0.62) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animMed } }
        focus: root.showing
        Keys.onEscapePressed: root.cancel()
        MouseArea { anchors.fill: parent; onClicked: {} }
    }

    Rectangle {
        id: card
        visible: root.showing
        anchors.centerIn: parent
        width: 460
        height: col.implicitHeight + 32
        radius: Theme.radius
        color: Theme.bgPanel
        border.color: Theme.accent
        border.width: 1

        HudCorners {
            color: Theme.accent
            size: 14
            thickness: 1
            margin: 8
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: "АУТЕНТИФИКАЦИЯ"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 2
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.flow ? (root.flow.message || "") : ""
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                visible: root.flow ? root.flow.isResponseRequired : true
                radius: Theme.radius
                color: Theme.bgCard
                border.width: 1
                border.color: pw.activeFocus ? Theme.accent : Theme.border

                TextInput {
                    id: pw
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    echoMode: (root.flow && root.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                    clip: true
                    onAccepted: root.submit()
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pw.text === ""
                    text: root.flow ? (root.flow.inputPrompt || "пароль…") : "пароль…"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: (root.flow && root.flow.supplementaryMessage) ? root.flow.supplementaryMessage : ""
                color: (root.flow && root.flow.supplementaryIsError) ? Theme.danger : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 30
                    radius: Theme.radius
                    color: cancelMouse.containsMouse ? Theme.active : "transparent"
                    border.width: 1
                    border.color: Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "ОТМЕНА"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancel()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 30
                    radius: Theme.radius
                    color: okMouse.containsMouse ? Theme.active : Theme.hoverStrong
                    border.width: 1
                    border.color: Theme.accent
                    Text {
                        anchors.centerIn: parent
                        text: "ОК"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: okMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
