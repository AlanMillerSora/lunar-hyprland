import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import QtQuick.Layouts
import QtQuick.Effects

// ════════════════════════════════════════════════════════════════
//  LaunchPage — сетка приложений Hub. Данные и запуск — из общего
//  синглтона AppModel; поиск — единый (внизу сайдбара Hub).
//  Крупные плитки: иконка 52 на подложке, имя в две строки, мягкая
//  подсветка. Выбранная клавиатурой помечена акцентной чертой.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── заголовок + обновление ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            height: 36
            spacing: 12

            Text {
                text: "LAUNCH"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 3
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: AppModel.allApps.length
                    ? (AppModel.apps.length + " из " + AppModel.allApps.length)
                    : "сканирую…"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 9
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: Theme.radius
                color: refreshMouse.containsMouse ? Theme.active : "transparent"
                border.width: 1
                border.color: refreshMouse.containsMouse ? Theme.borderAccent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "\uf021"
                    color: refreshMouse.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 13
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

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        // ── сетка приложений ────────────────────────────────────
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 120
            cellHeight: 132
            clip: true
            model: AppModel.apps
            currentIndex: 0
            // M80: без фокуса Keys.* не срабатывают — стрелки/Enter мертвы
            focus: true
            activeFocusOnTab: true

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: 112
                height: 124
                radius: Theme.radiusM
                color: index === grid.currentIndex
                    ? Theme.active
                    : (hover.containsMouse ? Theme.hover : "transparent")
                border.width: index === grid.currentIndex ? 1 : 0
                border.color: Theme.accent
                scale: hover.containsMouse ? 1.02 : 1
                Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                // HUD-штрих у выбранной плитки
                Rectangle {
                    visible: index === grid.currentIndex
                    width: 22
                    height: 2
                    color: Theme.accent2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Item {
                        width: 68
                        height: 68
                        anchors.horizontalCenter: parent.horizontalCenter

                        Image {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 56
                            height: 56
                            sourceSize: Qt.size(128, 128)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            source: modelData.icon
                                ? Quickshell.iconPath(modelData.icon, true)
                                : ""
                            visible: false
                        }

                        // принудительный монохром: тема Tela-lunar уже серая,
                        // но иконки-файлы (yazi, brave) приходят цветными —
                        // гашу насыщенность и чуть поднимаю яркость
                        MultiEffect {
                            anchors.fill: appIcon
                            source: appIcon
                            visible: appIcon.status === Image.Ready
                            saturation: -1.0
                            brightness: 0.15
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: AppModel.initials(modelData.name)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            font.bold: true
                        }
                    }

                    Text {
                        text: modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        width: 102
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
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
