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

    // общие заглушки тем иконок: у таких приложений лучше читаются инициалы,
    // чем серый квадрат «исполняемый файл»
    readonly property var genericIcons: [
        "application-x-executable", "application-default-icon",
        "exec", "qt", "unknown", "qv4l2", "qvidcap", "qmlscene", ""
    ]

    function hasRealIcon(app) {
        return app.icon !== undefined && app.icon !== ""
            && genericIcons.indexOf(String(app.icon).toLowerCase()) < 0
    }

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
                // «30 из 30» при пустом фильтре — шум: показываю только
                // когда выдача реально урезана (идёт поиск)
                visible: AppModel.allApps.length === 0
                    || AppModel.apps.length !== AppModel.allApps.length
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
                    font.pixelSize: Theme.fontBody
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
            // высота ячейки — от контента (иконка + две строки подписи), а не
            // от ширины: иначе на широком окне между рядами зияли пустоты
            cellHeight: Math.round(Theme.rowHComfy * 2.5)
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
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 8

                    Item {
                        width: 46
                        height: 46
                        anchors.horizontalCenter: parent.horizontalCenter

                        // подложка: даёт иконкам одинаковый вес и «плитку»,
                        // иначе тёмные глифы на тёмной плитке сливаются
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusM
                            color: Theme.cardBg
                            border.width: 1
                            border.color: hover.containsMouse ? Theme.borderAccent : Theme.border
                        }

                        Image {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 34
                            height: 34
                            sourceSize: Qt.size(160, 160)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            source: page.hasRealIcon(modelData)
                                ? Quickshell.iconPath(modelData.icon, true)
                                : ""
                            visible: false
                        }

                        // монохром: только гашу насыщенность, яркость не поднимаю —
                        // иначе заливные иконки (Telegram, Lutris) выбеливались
                        // в безликий диск, теряя внутренний рисунок
                        MultiEffect {
                            anchors.fill: appIcon
                            source: appIcon
                            visible: appIcon.status === Image.Ready
                            saturation: -1.0
                            brightness: 0.04
                            contrast: 0.0
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: AppModel.initials(modelData.name)
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(15)
                            font.bold: true
                        }
                    }

                    // подпись в боксе фиксированной высоты: однострочные и
                    // двухстрочные имена не сдвигают иконки по вертикали
                    Item {
                        width: Math.max(80, grid.cellWidth - 24)
                        height: Math.round(Theme.fontBody * 2.6)

                        Text {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
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
                font.pixelSize: Theme.fontSize(13)
            }
        }
    }
}
