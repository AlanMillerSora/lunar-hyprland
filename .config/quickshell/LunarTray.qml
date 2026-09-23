import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarTray — список приложений системного трея. Открывается
//  кнопкой «+N» в панели, когда значков больше, чем помещается.
//  ЛКМ по строке — активировать, ПКМ — родное меню приложения.
//  IPC:  qs ipc call tray toggle|open|close
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? backdrop : null
    }

    property bool showing: false
    readonly property var items: SystemTray.items.values
    // в списке — только свёрнутые (те, что не влезли в панель)
    readonly property var collapsed: SystemTray.items.values.slice(Theme.trayVisible)

    function openPanel() { showing = true }
    function closePanel() { showing = false }
    function toggle() { showing ? closePanel() : openPanel() }

    IpcHandler {
        target: "tray"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    // icon у SNI бывает: путь, file:///image:// или имя темы.
    // Если иконки нет в теме, image://icon отдаёт заглушку — проверяем hasThemeIcon.
    function iconSource(item) {
        if (!item) return ""
        var ic = item.icon || ""
        if (ic.indexOf("file://") === 0 || ic.indexOf("qrc:") === 0) return ic
        if (ic.indexOf("image://icon/") === 0) {
            var n = ic.substring("image://icon/".length)
            return Quickshell.hasThemeIcon(n) ? ic : ""
        }
        if (ic.indexOf("image://") === 0) return ic
        if (ic.charAt(0) === "/") return "file://" + ic
        if (ic && Quickshell.hasThemeIcon(ic)) return Quickshell.iconPath(ic)
        var id = item.id || ""
        if (id && Quickshell.hasThemeIcon(id)) return Quickshell.iconPath(id)
        return ""
    }

    function showMenu(item, area, mx, my) {
        if (!item || !item.hasMenu) return
        var ci = root.contentItem
        var pt = ci ? area.mapToItem(ci, mx, my) : Qt.point(root.width - 320, 60)
        item.display(root, Math.round(pt.x), Math.round(pt.y))
    }

    function activateItem(item) {
        if (!item) return
        if (item.onlyMenu && item.hasMenu) return
        item.activate()
        closePanel()
    }

    // клик мимо — закрыть
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"
        focus: root.showing
        Keys.onEscapePressed: root.closePanel()

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    Rectangle {
        id: card
        width: 300
        height: Math.min(440, 44 + col.height)
        anchors.top: parent.top
        anchors.topMargin: 52
        anchors.right: parent.right
        anchors.rightMargin: 12
        radius: Theme.radius
        color: Theme.bgPanel
        border.color: Theme.accent
        border.width: 1

        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        HudCorners {
            color: Theme.accent
            size: 14
            thickness: 1
            margin: 8
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 12
            spacing: 2

            Row {
                spacing: 8
                width: col.width

                Text {
                    text: "ТРЕЙ"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }

                Text {
                    text: root.collapsed.length + " свёрнуто"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { width: 1; height: 4 }

            Text {
                visible: root.collapsed.length === 0
                width: col.width
                text: "всё помещается в панели"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: root.collapsed

                delegate: Rectangle {
                    required property var modelData
                    width: col.width
                    height: 34
                    radius: Theme.radius
                    color: rowMouse.containsMouse ? Theme.alpha(Theme.accent, 0.07) : "transparent"
                    border.width: rowMouse.containsMouse ? 1 : 0
                    border.color: Theme.border

                    Item {
                        id: rowIconBox
                        width: 18
                        height: 18
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: rowIcon
                            anchors.fill: parent
                            source: root.iconSource(modelData)
                            sourceSize.width: 18
                            sourceSize.height: 18
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                            visible: source != "" && status !== Image.Error
                        }

                        // если у приложения нет иконки — точка-фолбэк
                        Text {
                            anchors.centerIn: parent
                            visible: !rowIcon.visible
                            text: "\uf111"
                            color: Theme.textFaint
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.fontSize(8)
                        }
                    }

                    Text {
                        anchors.left: rowIconBox.right
                        anchors.leftMargin: 10
                        anchors.right: rowHint.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.tooltipTitle || modelData.title || modelData.id
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Text {
                        id: rowHint
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.hasMenu
                        text: "ПКМ"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function (m) {
                            if (m.button === Qt.MiddleButton) {
                                modelData.secondaryActivate()
                            } else if (m.button === Qt.RightButton) {
                                root.showMenu(modelData, rowMouse, m.x, m.y)
                            } else if (modelData.onlyMenu && modelData.hasMenu) {
                                root.showMenu(modelData, rowMouse, m.x, m.y)
                            } else {
                                root.activateItem(modelData)
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 2 }
        }
    }
}
