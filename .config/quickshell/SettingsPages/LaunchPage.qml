import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LaunchPage — сетка приложений Hub. Данные и запуск — из общего
//  синглтона AppModel; поиск теперь единый (внизу сайдбара Hub).
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── заголовок ───────────────────────────────────────────
        Row {
            Layout.fillWidth: true
            height: 36
            spacing: 12

            Text {
                text: "LAUNCH"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: AppModel.allApps.length
                    ? (AppModel.apps.length + " из " + AppModel.allApps.length)
                    : "сканирую…"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        // ── обновить список ─────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 42
                radius: Theme.radius
                color: refreshMouse.containsMouse
                    ? Theme.alpha(Theme.accent, 0.10)
                    : Theme.alpha(Theme.text, 0.025)
                border.width: 1
                border.color: refreshMouse.containsMouse ? Theme.borderAccent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "ОБНОВИТЬ"
                    color: refreshMouse.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppModel.load()
                }
            }
        }

        // ── сетка приложений ────────────────────────────────────
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 140
            cellHeight: 104
            clip: true
            model: AppModel.apps
            currentIndex: 0

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: 132
                height: 96
                radius: Theme.radius
                color: index === grid.currentIndex
                    ? Theme.alpha(Theme.accent, 0.12)
                    : (mouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : Theme.alpha(Theme.text, 0.025))
                border.color: index === grid.currentIndex ? Theme.accent : Theme.border
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 46
                        height: 46
                        radius: Theme.radius
                        color: Theme.alpha(Theme.accent, 0.08)
                        border.color: Theme.borderAccent
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        Image {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            source: modelData.icon
                                ? Quickshell.iconPath(modelData.icon, true)
                                : ""
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: AppModel.initials(modelData.name)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    Text {
                        text: modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        width: 120
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: grid.currentIndex = index
                    onClicked: AppModel.launch(modelData)
                }
            }

            Keys.onLeftPressed:  currentIndex = Math.max(0, currentIndex - 1)
            Keys.onRightPressed: currentIndex = Math.min(count - 1, currentIndex + 1)
            Keys.onUpPressed:    currentIndex = Math.max(0, currentIndex - Math.floor(width / cellWidth))
            Keys.onDownPressed:  currentIndex = Math.min(count - 1, currentIndex + Math.floor(width / cellWidth))
            Keys.onReturnPressed: {
                if (currentIndex >= 0 && currentIndex < AppModel.apps.length)
                    AppModel.launch(AppModel.apps[currentIndex])
            }

            Text {
                anchors.centerIn: parent
                visible: AppModel.apps.length === 0
                text: AppModel.allApps.length === 0 ? "ищу приложения…" : "ничего не найдено"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
}
