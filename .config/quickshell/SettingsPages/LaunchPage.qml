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
        spacing: Theme.space4

        // ── заголовок + обновление ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            height: Theme.headerH
            spacing: Theme.space3

            Text {
                text: "LAUNCH"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.letterSpacing: 3
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: AppModel.allApps.length
                    ? (AppModel.apps.length + " из " + AppModel.allApps.length)
                    : "сканирую…"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
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
                    font.pixelSize: 14
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
            // колонок тем больше, чем шире окно; ячейка едет за шириной,
            // поэтому сетка не ломается при ресайзе Hub (минимум 820)
            readonly property int cols: Math.max(4, Math.min(8, Math.floor((width - 12) / 150)))
            readonly property real cw: Math.floor((width - 12) / cols)
            cellWidth: cw
            cellHeight: cw + 10
            clip: true
            model: AppModel.apps
            currentIndex: 0
            // M80: без фокуса Keys.* не срабатывают — стрелки/Enter мертвы
            focus: true
            activeFocusOnTab: true

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: grid.cellWidth - 10
                height: grid.cellHeight - 10
                radius: Theme.radiusM
                color: index === grid.currentIndex
                    ? Theme.active
                    : (hover.containsMouse ? Theme.hover : "transparent")
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
                    spacing: 6

                    Item {
                        width: 54
                        height: 54
                        anchors.horizontalCenter: parent.horizontalCenter

                        // подложка: даёт иконкам одинаковый вес и «плитку»,
                        // иначе тёмные глифы на тёмной плитке сливаются
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusM
                            color: Theme.fill
                            border.width: hover.containsMouse ? 1 : 0
                            border.color: Theme.borderAccent
                        }

                        Image {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 40
                            height: 40
                            sourceSize: Qt.size(128, 128)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            source: modelData.icon
                                ? Quickshell.iconPath(modelData.icon, true)
                                : ""
                            visible: false
                        }

                        // принудительный монохром: тема Tela-lunar уже серая, но
                        // иконки-файлы (yazi, brave) приходят цветными — гашу
                        // насыщенность, поднимаю яркость и чуть контраст, чтобы
                        // после перевода в серое не терялись детали
                        MultiEffect {
                            anchors.fill: appIcon
                            source: appIcon
                            visible: appIcon.status === Image.Ready
                            saturation: -1.0
                            brightness: 0.20
                            contrast: 0.22
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: AppModel.initials(modelData.name)
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    Text {
                        text: modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        width: Math.max(80, grid.cellWidth - 24)
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
                font.pixelSize: 13
            }
        }
    }
}
