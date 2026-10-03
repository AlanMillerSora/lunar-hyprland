import QtQuick
import QtQuick.Effects
import ".."

        Column {
            property var host
            visible: BarState.mode === "notifs"
            opacity: host.panelContentOpacity
            anchors.fill: parent
            anchors.margins: Theme.barPad
            anchors.topMargin: Theme.panelHeaderH + Theme.space1
            spacing: Theme.space2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 60
                visible: NotifModel.items.length === 0
                text: NotifModel.dnd ? "режим «не беспокоить»" : "уведомлений нет"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
            }

            // список (скроллится)
            ListView {
                id: notifList
                width: parent.width
                height: parent.height - y
                clip: true
                spacing: Theme.space2
                model: NotifModel.items

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool expanded: NotifModel.expandedId === modelData.id
                    width: notifList.width
                    height: expanded ? Math.min(150, bodyText.implicitHeight + 52) : 44
                    radius: Theme.cardRadius
                    border.width: 1
                    border.color: expanded ? Theme.alpha(Theme.accent, 0.35) : Theme.border
                    color: expanded ? Theme.active : (notifMouse.containsMouse ? Theme.hoverStrong : Theme.cardBg)

                    // важность слева
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height - 16
                        radius: 1.5
                        color: modelData.urgency === "critical" ? Theme.danger
                            : (modelData.urgency === "low" ? Theme.borderAccent : Theme.accent)
                        opacity: 0.8
                    }

                    // иконка приложения (монохром)
                    Item {
                        id: notifIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        Image {
                            id: nIcon
                            anchors.fill: parent
                            visible: false
                            asynchronous: true
                            sourceSize: Qt.size(40, 40)
                            fillMode: Image.PreserveAspectFit
                            source: {
                                var ic = modelData.icon || ""
                                if (ic === "") return ""
                                if (ic.charAt(0) === "/") return "file://" + ic
                                if (ic.indexOf("file://") === 0 || ic.indexOf("image://") === 0) return ic
                                return Quickshell.hasThemeIcon(ic) ? Quickshell.iconPath(ic, true) : ""
                            }
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: nIcon
                            visible: nIcon.status === Image.Ready
                            saturation: -1.0
                            brightness: 0.15
                            contrast: 0.05
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: nIcon.status !== Image.Ready
                            text: "\uf0f3"
                            color: Theme.textFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(13)
                        }
                    }

                    Column {
                        anchors.left: notifIcon.right
                        anchors.leftMargin: Theme.space3
                        anchors.right: dismissBtn.left
                        anchors.rightMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: modelData.app
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: modelData.summary
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                            font.bold: true
                        }
                        Text {
                            id: bodyText
                            width: parent.width
                            visible: expanded && modelData.body.length > 0
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            text: modelData.body
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                        }
                    }

                    Text {
                        id: dismissBtn
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf00d"
                        color: dismissMouse.containsMouse ? Theme.danger
                            : (notifMouse.containsMouse ? Theme.textFaint : "transparent")
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(13)
                        MouseArea {
                            id: dismissMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotifModel.dismiss(modelData.id)
                        }
                    }

                    MouseArea {
                        id: notifMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: function(m) {
                            if (m.button === Qt.MiddleButton) NotifModel.dismiss(modelData.id)
                            else NotifModel.toggleExpand(modelData.id)
                        }
                    }
                }
            }
        }
