import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import ".."

// ════════════════════════════════════════════════════════════════
//  PanelSearch — поиск-лаунчер внутри раскрытой плашки бара.
//  Ввод сверху, результаты секциями, минимальные строки с крупной
//  иконкой. Пустой запрос — недавние приложения.
// ════════════════════════════════════════════════════════════════
Item {
    id: root
    property var host

    function focusInput() { searchInput.forceActiveFocus() }

    // при открытии чищу поле: иначе после запуска приложения в нём остаётся
    // старый запрос, а список уже показывает «недавние» — Enter бьёт не по тому
    onVisibleChanged: if (visible) searchInput.text = ""

    visible: BarState.mode === "search"
    opacity: host.panelContentOpacity
    anchors.fill: parent
    anchors.margins: Theme.barPad
    anchors.topMargin: Theme.space3

    // ── строка ввода ──
    Rectangle {
        id: searchField
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 46
        radius: Theme.cardRadius
        color: Theme.cardBg
        border.width: 1
        border.color: searchInput.activeFocus ? Theme.borderAccent : Theme.border

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf002"
            color: searchInput.activeFocus ? Theme.accent : Theme.textDim
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSize(16)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: 42
            anchors.rightMargin: 64
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.bg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(16)
            clip: true
            onTextChanged: Launcher.setQuery(text)
            Keys.onEscapePressed: {
                if (text !== "") { text = ""; Launcher.setQuery("") }
                else BarState.closePanel()
            }
            Keys.onUpPressed: Launcher.move(-1)
            Keys.onDownPressed: Launcher.move(1)
            Keys.onReturnPressed: Launcher.run()
            Keys.onEnterPressed: Launcher.run()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "поиск: приложение, страница Hub, действие, счёт…"
                visible: searchInput.text === ""
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(16)
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            text: "ENTER"
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTiny
            font.letterSpacing: 1
        }
    }

    // ── подсказка-футер ──
    Text {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        text: "↑↓ выбрать · Enter — открыть · Esc — закрыть"
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTiny
        font.letterSpacing: 1
    }

    Text {
        anchors.top: searchField.bottom
        anchors.topMargin: Theme.space4
        anchors.horizontalCenter: parent.horizontalCenter
        visible: Launcher.query.trim() !== "" && Launcher.results.length === 0
        text: "ничего не найдено"
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize(13)
    }

    // ── результаты ──
    ListView {
        id: resList
        anchors.top: searchField.bottom
        anchors.topMargin: Theme.space2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.space1
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: Launcher.results
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
            required property var modelData
            required property int index
            width: resList.width
            height: modelData.isHeader ? 26 : 46

            // заголовок секции
            Row {
                visible: modelData.isHeader === true
                anchors.left: parent.left
                anchors.leftMargin: Theme.space1
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                spacing: Theme.space2
                Rectangle {
                    width: 3
                    height: 12
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title || ""
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                    font.bold: true
                    font.letterSpacing: 2
                }
            }

            // строка результата
            Rectangle {
                visible: modelData.isHeader !== true
                anchors.fill: parent
                radius: Theme.cardRadius
                border.width: 1
                border.color: index === Launcher.index ? Theme.alpha(Theme.accent, 0.4) : "transparent"
                color: index === Launcher.index ? Theme.active
                    : (resMouse.containsMouse ? Theme.hover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space2
                    anchors.rightMargin: Theme.space3
                    spacing: Theme.space3

                    // иконка: картинка для приложений, глиф для прочего
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        Text {
                            anchors.centerIn: parent
                            visible: modelData.image === undefined || modelData.image === ""
                                || resIcon.status !== Image.Ready
                            text: modelData.kind === "app" ? "\uf009" : (modelData.icon || "")
                            color: index === Launcher.index ? Theme.accent : Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: modelData.kind === "app" ? 16 : Theme.fontSize(18)
                        }
                        Image {
                            id: resIcon
                            anchors.fill: parent
                            visible: false
                            source: (modelData.kind === "app" && modelData.image) ? modelData.image : ""
                            sourceSize: Qt.size(60, 60)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: resIcon
                            visible: modelData.kind === "app" && modelData.image !== "" && resIcon.status === Image.Ready
                            saturation: -1.0
                            brightness: 0.35
                            contrast: 0.05
                        }
                    }

                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: modelData.label || ""
                            color: index === Launcher.index ? Theme.text : Theme.barText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                        }
                        Text {
                            width: parent.width
                            visible: (modelData.desc || "") !== ""
                            elide: Text.ElideRight
                            text: modelData.desc || ""
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: modelData.kind === "page" ? "страница"
                            : (modelData.kind === "action" ? "действие"
                            : (modelData.kind === "calc" || modelData.kind === "unit" || modelData.kind === "emoji" ? "Enter — копирую"
                            : (modelData.kind === "url" ? "Enter — открыть"
                            : "приложение")))
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTiny
                    }
                }

                MouseArea {
                    id: resMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: Launcher.index = index
                    onClicked: { Launcher.index = index; Launcher.run() }
                }
            }
        }
    }

    // прокрутка к выбранному при навигации
    Connections {
        target: Launcher
        function onIndexChanged() {
            if (Launcher.index >= 0 && Launcher.index < resList.count)
                resList.positionViewAtIndex(Launcher.index, ListView.Contain)
        }
    }
}
