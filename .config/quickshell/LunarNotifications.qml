import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarNotifications — лицо уведомлений риса: всплывающие тосты и
//  история-панель. Сам демон (D-Bus) и хранение живут в синглтоне
//  NotifModel.qml; здесь только показ в наших токенах. Вид — по мотивам
//  Notifications.qml у 43PR (карточки, миниатюры, ресайз, углы), но
//  палитра/шрифты/радиусы наши.
//
//  IPC: qs ipc call notifications toggle|open|close|clear|dnd
//  Размер и угол запоминает NotifModel (state/notifications-state.json).
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    // отступ сверху — под баром, чтобы тосты не лезли под панель
    property int topGap: Theme.barTop + Theme.barH + Theme.space2
    property int sideGap: Theme.space4
    property int baseWidth: 340

    readonly property real ui: NotifModel.menuSize / 100
    readonly property int cardWidth: Math.round(baseWidth * ui)
    readonly property bool rightSide: NotifModel.pos === "tr" || NotifModel.pos === "br"
    readonly property bool bottomSide: NotifModel.pos === "br" || NotifModel.pos === "bl"

    property bool panelOpen: false

    // Держу поверхность замапленной только когда есть панель или всплывашки:
    // без этого компоситор переливает пустой слой 3440×1440 каждый кадр.
    property bool _mapped: panelOpen || NotifModel.count > 0
    visible: _mapped
    Timer {
        id: unmapTimer
        interval: Theme.animSlow + 60
        onTriggered: root._mapped = false
    }
    function refreshMap() {
        if (panelOpen || NotifModel.count > 0) { unmapTimer.stop(); _mapped = true }
        else unmapTimer.restart()
    }
    onPanelOpenChanged: refreshMap()
    Connections {
        target: NotifModel
        function onCountChanged() { root.refreshMap() }
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"
    WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // пока панель закрыта — кликабельны только тосты; открыта — весь экран
    mask: Region { item: root.panelOpen ? backdrop : stack }

    function px(n) { return Math.round(n * root.ui) }
    function imgSrc(p) { return !p ? "" : (p.startsWith("/") ? "file://" + p : p) }
    function thumbSrc(image, icon) {
        if (image && image !== "") return root.imgSrc(image)
        if (icon && icon !== "") return Quickshell.hasThemeIcon(icon) ? Quickshell.iconPath(icon, true) : ""
        return ""
    }
    function fmtTime(ms) {
        if (!ms) return ""
        var d = new Date(ms)
        return d.toDateString() === new Date().toDateString()
            ? Qt.formatDateTime(d, "HH:mm")
            : Qt.formatDateTime(d, "dd MMM HH:mm")
    }
    function posLabel() {
        if (NotifModel.pos === "tr") return "TR"
        if (NotifModel.pos === "br") return "BR"
        if (NotifModel.pos === "bl") return "BL"
        return "TL"
    }

    // ── единственная точка входа для скриптов/хоткеев ───────────
    IpcHandler {
        target: "notifications"
        function toggle(): void { root.panelOpen = !root.panelOpen }
        function open(): void { root.panelOpen = true }
        function close(): void { root.panelOpen = false }
        function clear(): void { NotifModel.clear() }
        function dnd(): void { NotifModel.toggleDnd() }
        // явная установка DND — Game Mode (eclipse-gamemode.sh)
        function dndon(): void { NotifModel.setDnd(true) }
        function dndoff(): void { NotifModel.setDnd(false) }
    }

    // ── мелкие компоненты в наших токенах ───────────────────────
    component Lbl: Text {
        property real ui: 1
        property real sz: 10
        font.pixelSize: Math.round(sz * ui * Theme.fontScale)
        font.family: Theme.fontFamily
        color: Theme.text
        elide: Text.ElideRight
    }

    component Thumb: Rectangle {
        property real ui: 1
        property real size: 40
        property string src: ""
        width: Math.round(size * ui)
        height: width
        radius: Theme.radius
        clip: true
        color: Theme.alpha(Theme.text, 0.06)
        Image {
            id: im
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: parent.src
        }
        Text {
            anchors.centerIn: parent
            visible: im.status !== Image.Ready
            text: "󰂚"
            font.family: Theme.iconFont
            font.pixelSize: Math.round(parent.size * 0.45 * parent.ui)
            color: Theme.textDim
        }
    }

    component IconBtn: Rectangle {
        id: b
        property real ui: 1
        property string icon: ""
        property string tip: ""
        property color tint: Theme.text
        signal clicked()
        width: Math.round(24 * ui)
        height: width
        radius: Theme.radiusS
        color: Theme.alpha(tint, area.containsMouse ? 0.20 : 0.06)

        Text {
            anchors.centerIn: parent
            text: b.icon
            font.family: Theme.iconFont
            font.pixelSize: Math.round(13 * b.ui)
            color: b.tint
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
        Rectangle {
            visible: area.containsMouse && b.tip !== ""
            anchors.top: parent.bottom
            anchors.topMargin: 6
            anchors.right: parent.right
            width: tipText.implicitWidth + Math.round(14 * b.ui)
            height: tipText.implicitHeight + Math.round(8 * b.ui)
            radius: Theme.radiusS
            color: Theme.bg
            border.width: 1
            border.color: Theme.border2
            z: 20
            Lbl { id: tipText; anchors.centerIn: parent; ui: b.ui; sz: 9; text: b.tip; color: Theme.textDim }
        }
    }

    // кнопка размера/угла — простая текстовая
    component TinyBtn: Text {
        id: t
        property string label: ""
        signal clicked()
        width: Math.round(24 * root.ui)
        height: Math.round(18 * root.ui)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: t.label
        color: tArea.containsMouse ? Theme.accent : Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(10 * root.ui * Theme.fontScale)
        MouseArea {
            id: tArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: t.clicked()
        }
    }

    // Esc закрывает панель
    Item {
        anchors.fill: parent
        focus: root.panelOpen
        Keys.onEscapePressed: root.panelOpen = false
    }

    Item {
        id: backdrop
        anchors.fill: parent
        visible: root.panelOpen
        MouseArea {
            anchors.fill: parent
            enabled: root.panelOpen
            onClicked: root.panelOpen = false
        }
    }

    // ── тосты ───────────────────────────────────────────────────
    Column {
        id: stack
        visible: !root.panelOpen
        width: root.cardWidth
        spacing: root.px(8)
        x: root.rightSide ? parent.width - width - root.sideGap : root.sideGap
        y: root.bottomSide ? parent.height - height - root.topGap : root.topGap

        Repeater {
            model: NotifModel.tracked

            delegate: Item {
                id: wrapper
                required property var modelData
                property bool shown: false
                property bool leaving: false
                property bool wasExpired: false
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property real off: root.rightSide ? root.cardWidth + 40 : -(root.cardWidth + 40)

                width: root.cardWidth
                height: card.height

                function close(expired) {
                    if (wrapper.leaving) return
                    wrapper.wasExpired = expired
                    wrapper.leaving = true
                    wrapper.shown = false
                    gone.start()
                }
                Component.onCompleted: wrapper.shown = true

                Timer {
                    id: gone
                    interval: Theme.animMed
                    onTriggered: wrapper.wasExpired ? wrapper.modelData.expire() : wrapper.modelData.dismiss()
                }

                // критичные не гаснут сами; наведение держит карточку.
                // expireTimeout в Quickshell 0.3.1 — миллисекунды (проверено:
                // notify-send -t 20000 → 20000), поэтому не множу на 1000.
                Timer {
                    interval: wrapper.modelData.expireTimeout > 0
                        ? wrapper.modelData.expireTimeout : 6000
                    running: !wrapper.critical && !hover.containsMouse && !wrapper.leaving
                    onTriggered: wrapper.close(true)
                }

                Rectangle {
                    id: card
                    width: parent.width
                    height: Math.max(root.px(64), content.implicitHeight + root.px(20))
                    radius: Theme.radiusL
                    color: Theme.bg
                    border.width: wrapper.critical ? 1 : 0
                    border.color: Theme.danger
                    x: wrapper.shown ? 0 : wrapper.off
                    opacity: wrapper.shown ? 1 : 0

                    Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton)
                                NotifModel.copy(wrapper.modelData.summary, wrapper.modelData.body)
                            wrapper.close(false)
                        }
                    }

                    Row {
                        id: content
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: root.px(10)
                        }
                        spacing: root.px(10)

                        Thumb {
                            ui: root.ui
                            size: 40
                            src: root.thumbSrc(wrapper.modelData.image, wrapper.modelData.appIcon)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.px(3)
                            width: parent.width - root.px(40) - parent.spacing

                            Lbl {
                                ui: root.ui; sz: 12; font.bold: true
                                width: parent.width
                                text: wrapper.modelData.summary
                            }
                            Lbl {
                                ui: root.ui
                                width: parent.width
                                visible: text !== ""
                                text: wrapper.modelData.body
                                color: Theme.textDim
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                            }
                            Lbl {
                                ui: root.ui; sz: 9
                                width: parent.width
                                text: wrapper.modelData.appName
                                color: Theme.textFaint
                            }

                            Row {
                                visible: wrapper.modelData.actions.length > 0
                                spacing: root.px(6)

                                Repeater {
                                    model: wrapper.modelData.actions
                                    delegate: Rectangle {
                                        required property var modelData
                                        height: root.px(20)
                                        width: actionLabel.implicitWidth + root.px(14)
                                        radius: Theme.radiusS
                                        color: Theme.alpha(Theme.text, actionArea.containsMouse ? 0.22 : 0.10)

                                        Lbl {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            ui: root.ui; sz: 9
                                            text: parent.modelData.text
                                        }
                                        MouseArea {
                                            id: actionArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                parent.modelData.invoke()
                                                wrapper.close(false)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── история-панель ──────────────────────────────────────────
    Rectangle {
        id: panel
        width: root.cardWidth
        height: panelCol.height + root.px(28)
        radius: Theme.radiusL
        color: Theme.bg
        border.width: 1
        border.color: Theme.border2
        visible: opacity > 0
        opacity: root.panelOpen ? 1 : 0
        x: root.rightSide
            ? (root.panelOpen ? parent.width - width - root.sideGap : parent.width + 40)
            : (root.panelOpen ? root.sideGap : -width - 40)
        y: root.bottomSide
            ? Math.max(root.topGap, parent.height - height - root.topGap)
            : root.topGap

        Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        // фон панели не должен закрываться кликом «мимо»
        MouseArea { anchors.fill: parent }

        Column {
            id: panelCol
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                margins: root.px(14)
            }
            spacing: root.px(10)

            Item {
                width: parent.width
                height: root.px(24)
                z: 10

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.px(8)
                    SectionHeader {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "УВЕДОМЛЕНИЯ"
                        textColor: Theme.textDim
                        size: Theme.fontTiny
                        bold: false
                    }
                    Lbl {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: NotifModel.items.length > 0
                        ui: root.ui; sz: 10
                        text: NotifModel.items.length
                        color: Theme.accent
                        font.bold: true
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.px(4)

                    IconBtn {
                        ui: root.ui
                        icon: NotifModel.dnd ? "󰂛" : "󰂚"
                        tip: NotifModel.dnd ? "DND: вкл" : "DND: выкл"
                        tint: NotifModel.dnd ? Theme.danger : Theme.text
                        onClicked: NotifModel.toggleDnd()
                    }
                    IconBtn {
                        ui: root.ui
                        icon: "󰆴"
                        tip: "Очистить всё"
                        tint: Theme.danger
                        visible: NotifModel.items.length > 0
                        onClicked: NotifModel.clear()
                    }
                    IconBtn {
                        ui: root.ui
                        icon: "󰅖"
                        tip: "Закрыть"
                        onClicked: root.panelOpen = false
                    }
                }
            }

            Lbl {
                visible: NotifModel.items.length === 0
                ui: root.ui; sz: 11
                width: parent.width
                height: root.px(40)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: NotifModel.dnd ? "режим «не беспокоить»" : "уведомлений нет"
                color: Theme.textFaint
            }

            ListView {
                id: list
                visible: NotifModel.items.length > 0
                width: parent.width
                height: Math.min(contentHeight, root.height - root.topGap - root.px(140))
                clip: true
                spacing: root.px(8)
                model: NotifModel.items
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    readonly property bool active: modelData.group === "active"
                    property bool copied: false

                    width: list.width
                    height: Math.max(root.px(56), entryCol.implicitHeight + root.px(20))
                    radius: Theme.radiusM
                    color: Theme.alpha(Theme.text, entry.copied ? 0.18
                        : (entryHover.containsMouse ? 0.12 : 0.06))
                    border.width: entry.active ? 1 : 0
                    border.color: Theme.activeBorder

                    Timer { id: copiedTimer; interval: 600; onTriggered: entry.copied = false }

                    MouseArea {
                        id: entryHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NotifModel.copy(entry.modelData.summary, entry.modelData.body)
                            entry.copied = true
                            copiedTimer.restart()
                        }
                    }

                    // важность слева
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: root.px(6)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height - root.px(16)
                        radius: width / 2
                        color: entry.modelData.urgency === "critical" ? Theme.danger
                            : (entry.modelData.urgency === "low" ? Theme.borderAccent : Theme.accent)
                        opacity: 0.85
                    }

                    Thumb {
                        id: eThumb
                        ui: root.ui
                        size: 32
                        src: root.thumbSrc(entry.modelData.image, entry.modelData.icon)
                        anchors {
                            left: parent.left; leftMargin: root.px(16)
                            verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        id: entryCol
                        anchors {
                            left: eThumb.right; leftMargin: root.px(10)
                            right: delBtn.left; rightMargin: root.px(8)
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: root.px(2)

                        Lbl {
                            ui: root.ui; sz: 11; font.bold: true
                            width: parent.width
                            text: entry.modelData.summary
                        }
                        Lbl {
                            ui: root.ui
                            width: parent.width
                            visible: text !== ""
                            text: entry.modelData.body
                            color: Theme.textDim
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                        }
                        Lbl {
                            ui: root.ui; sz: 9
                            width: parent.width
                            color: Theme.textFaint
                            text: (entry.modelData.app !== "" ? entry.modelData.app + " · " : "")
                                + (entry.active ? "активно" : root.fmtTime(entry.modelData.time))
                        }
                    }

                    Item {
                        id: delBtn
                        width: root.px(24)
                        height: width
                        anchors {
                            right: parent.right; rightMargin: root.px(8)
                            verticalCenter: parent.verticalCenter
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.iconFont
                            font.pixelSize: root.px(13)
                            color: delArea.containsMouse ? Theme.danger : Theme.textFaint
                        }
                        MouseArea {
                            id: delArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotifModel.dismiss(entry.modelData.id)
                        }
                    }
                }
            }
        }
    }

    // размер и угол — тонкая строка под панелью
    Row {
        id: sizeRow
        anchors.top: panel.bottom
        anchors.topMargin: 6
        anchors.left: panel.left
        spacing: 2
        visible: root.panelOpen
        opacity: sizeHover.hovered ? 0.9 : 0.25
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        HoverHandler { id: sizeHover }

        TinyBtn { label: "−"; onClicked: NotifModel.setSize(NotifModel.menuSize - 10) }
        TinyBtn { label: "+"; onClicked: NotifModel.setSize(NotifModel.menuSize + 10) }
        TinyBtn { label: root.posLabel(); onClicked: NotifModel.cyclePos() }
    }
}
