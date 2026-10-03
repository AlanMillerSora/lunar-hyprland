import QtQuick
import QtQuick.Layouts
import ".."

        Column {
            property var host
    function focusInput() { searchInput.forceActiveFocus() }
            visible: BarState.mode === "search"
            opacity: host.panelContentOpacity
            anchors.fill: parent
            anchors.margins: Theme.barPad
            anchors.topMargin: Theme.panelHeaderH + Theme.space1
            spacing: Theme.space2

            Rectangle {
                width: parent.width
                height: 36
                radius: Theme.cardRadius
                color: Theme.cardBg
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.borderAccent : Theme.border

                // ведущий глиф поиска
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    color: searchInput.activeFocus ? Theme.accent : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(13)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 34
                    anchors.rightMargin: 52
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(14)
                    clip: true
                    onTextChanged: host.setSearchQuery(text)
                    Keys.onEscapePressed: {
                        if (text !== "") { text = ""; host.setSearchQuery("") }
                        else host.closePanel()
                    }
                    Keys.onUpPressed: host.moveSearch(-1)
                    Keys.onDownPressed: host.moveSearch(1)
                    Keys.onReturnPressed: host.runSearch()
                    Keys.onEnterPressed: host.runSearch()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "поиск: приложение, страница Hub, действие, счёт…"
                        visible: searchInput.text === ""
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(14)
                    }
                }

                // подсказка ввода
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

            Text {
                visible: host.searchQuery.trim() !== "" && host.searchResults.length === 0
                text: "ничего не найдено"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
            }

            Column {
                width: parent.width
                spacing: 2
                Repeater {
                    model: host.searchResults
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 34
                        radius: Theme.cardRadius
                        border.width: 1
                        border.color: index === host.searchIndex ? Theme.alpha(Theme.accent, 0.4) : "transparent"
                        color: index === host.searchIndex ? Theme.active
                            : (resMouse.containsMouse ? Theme.hover : "transparent")
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space3
                            anchors.rightMargin: Theme.space3
                            spacing: Theme.space2
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.icon || ""
                                color: index === host.searchIndex ? Theme.accent : Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(14)
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: modelData.label
                                color: index === host.searchIndex ? Theme.text : Theme.barText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.kind === "page" ? "страница"
                                    : (modelData.kind === "action" ? "действие"
                                    : (modelData.kind === "calc" ? "калькулятор · Enter — копирую"
                                    : (modelData.kind === "unit" ? "конверсия · Enter — копирую"
                                    : (modelData.kind === "emoji" ? "эмодзи · Enter — копирую"
                                    : (modelData.kind === "url" ? "ссылка · Enter — открыть"
                                    : "приложение")))))
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTiny
                            }
                        }
                        MouseArea {
                            id: resMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: host.searchIndex = index
                            onClicked: { host.searchIndex = index; host.runSearch() }
                        }
                    }
                }
            }
        }
