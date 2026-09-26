import QtQuick
import Quickshell.Io
import "../"

// ════════════════════════════════════════════════════════════════
//  USER — аватар пользователя: показ и смена.
//  Смена: zenity → ~/.config/avatars/avatar.png (круг),
//  затем скрипт синхронизирует аватар с экраном входа SDDM.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    property string mono: "JetBrainsMono Nerd Font"
    property int rightMargin: 36
    property string homeDir: ""
    property int refresh: 0

    Process {
        id: pHome
        command: ["sh", "-c", "printf '%s' \"$HOME\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: page.homeDir = text.trim()
        }
    }

    Process {
        id: pAvatar
        running: false
        command: ["bash", "-c", "\"$HOME/.config/hypr/scripts/eclipse-avatar.sh\""]
        onExited: page.refresh++
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.rightMargin
            spacing: 20

            Text {
                text: "USER"
                color: Theme.text
                font.family: page.mono
                font.pixelSize: 18
                font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // текущий аватар (круглый PNG)
            Image {
                width: 200
                height: 200
                source: page.homeDir !== ""
                    ? "file://" + page.homeDir + "/.config/avatars/avatar.png?v=" + page.refresh
                    : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
            }

            // смена аватара
            Rectangle {
                width: Math.max(170, changeText.implicitWidth + 36)
                height: 38
                radius: Theme.radius
                color: changeArea.containsMouse ? Theme.active : "transparent"
                border.width: 1
                border.color: changeArea.containsMouse ? Theme.accent : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    id: changeText
                    anchors.centerIn: parent
                    text: pAvatar.running ? "ВЫБИРАЮ…" : "СМЕНИТЬ АВАТАР"
                    color: changeArea.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.letterSpacing: 2
                }

                MouseArea {
                    id: changeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !pAvatar.running
                    onClicked: pAvatar.running = true
                }
            }
        }
    }
}
