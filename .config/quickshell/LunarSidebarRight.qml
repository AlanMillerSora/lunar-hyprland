import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarSidebarRight — правая панель: музыка, календарь, запись.
//  Выезжает от правого края по наведению. Уведомления переехали в панель бара.
//  IPC:  qs ipc call rsidebar toggle|open|close
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; right: true; bottom: true }
    implicitWidth: 560
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "lunar-sidebar-right"
    WlrLayershell.keyboardFocus: root.collapsed ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

    property bool collapsed: true
    property int tabIndex: 0

    function openPanel() { collapsed = false; recModel.load(); recStatusProc.running = true; cal.reload() }
    function closePanel() { collapsed = true }
    // M35: открытие по IPC тоже подтягивает данные — toggle не должен просто переключать флаг
    function toggle() { if (collapsed) openPanel(); else closePanel() }

    // ── крупный спектр cava во вкладке «музыка» ──
    readonly property bool mediaPlaying: player !== null && player !== undefined && player.isPlaying
    readonly property int barCount: 56
    property var barValues: []

    function feedCava(line) {
        var t = ("" + line).trim()
        if (t.length === 0)
            return
        var parts = t.split(/\s+/)
        var prev = root.barValues
        var out = []
        for (var i = 0; i < root.barCount; i++) {
            var raw = (parseInt(parts[i] === undefined ? "0" : parts[i]) || 0) / 1000
            raw = Math.max(0, Math.min(1, raw))
            var p = prev[i] || 0
            // быстрый подъём, плавный спад — столбики не «дёргаются»
            out.push(raw > p ? p + (raw - p) * 0.55 : p * 0.80 + raw * 0.20)
        }
        root.barValues = out
    }

    // добавление события из формы календаря
    function addCalEvent() {
        if (!cal.selected) return
        cal.add(calTitle.text, cal.selected, calTime.text, calRemind.text)
        calTitle.text = ""
        calTime.text = ""
        calRemind.text = ""
    }

    onCollapsedChanged: {
        if (!collapsed && !stripHover.hovered && !contentHover.hovered)
            hideTimer.restart()
    }

    IpcHandler {
        target: "rsidebar"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
        function tab(idx: int): void { root.tabIndex = Math.max(0, Math.min(2, idx)) }
    }

    // кнопка «горячие клавиши» в шапке панели
    Process {
        id: cheatsheetProc
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/eclipse-cheatsheet.py"]
        running: false
    }

    // cava для вкладки «музыка»: только когда вкладка видна и реально играет
    Process {
        id: cavaProc
        running: root.tabIndex === 0 && root.mediaPlaying && !root.collapsed
        command: ["cava", "-p", Quickshell.shellPath("cava-lunar-wide.conf")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.feedCava(line)
        }
        stderr: StdioCollector {}
    }

    mask: Region {
        item: collapsed ? hoverStrip : contentBox
    }

    // полоска у правого края — триггер выезда
    Item {
        id: hoverStrip
        anchors.top: parent.top
        anchors.topMargin: 46
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 22

        HoverHandler {
            id: stripHover
            onHoveredChanged: {
                // M36: не дёргаем openPanel повторно, если панель уже открыта
                if (hovered && root.collapsed) root.openPanel()
                else if (!contentHover.hovered) hideTimer.restart()
            }
        }
    }

    Rectangle {
        id: contentBox
        anchors.top: parent.top
        anchors.topMargin: 46
        anchors.bottom: parent.bottom
        width: 530
        // уезжает за правый край целиком
        x: root.collapsed ? (root.width + 4) : (root.width - width)
        color: Theme.bg
        radius: Theme.radiusM
        border.color: Theme.border
        border.width: collapsed ? 0 : 1

        HudCorners {
            color: Theme.accent
            size: 16
            thickness: 1
            margin: 8
        }

        Behavior on x {
            NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut }
        }

        HoverHandler {
            id: contentHover
            onHoveredChanged: {
                // M36: панель уже открыта, лишняя перезагрузка данных не нужна
                if (hovered && root.collapsed) root.openPanel()
                else if (!stripHover.hovered) hideTimer.restart()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.space5
            spacing: Theme.space4

            RowLayout {
                spacing: Theme.space2
                Text {
                    text: "LUNAR"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(Theme.fontPanelTitle)
                    font.bold: true
                    font.letterSpacing: 3
                }
                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 30
                    height: 22
                    radius: Theme.radius
                    color: helpMouse.containsMouse ? Theme.hoverStrong : "transparent"
                    border.width: helpMouse.containsMouse ? 1 : 0
                    border.color: Theme.borderAccent
                    Text {
                        anchors.centerIn: parent
                        text: "\uf11c"
                        color: helpMouse.containsMouse ? Theme.accent : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(13)
                    }
                    MouseArea {
                        id: helpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cheatsheetProc.running = true
                    }
                }

                Rectangle {
                    width: 28
                    height: 22
                    radius: Theme.radius
                    color: closeMouse.containsMouse ? Theme.hoverStrong : "transparent"
                    border.width: closeMouse.containsMouse ? 1 : 0
                    border.color: Theme.borderAccent
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(15)
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePanel()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            // ── вкладки ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.rowHCompact

                RowLayout {
                    id: rightTabRow
                    anchors.fill: parent
                    spacing: Theme.space1
                    Repeater {
                        id: rightTabRep
                        model: ["музыка", "календарь", "запись"]
                        delegate: Rectangle {
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            height: Theme.rowHCompact
                            radius: Theme.radius
                            color: root.tabIndex === index
                                ? Theme.active
                                : (tabMouse.containsMouse ? Theme.hover : "transparent")
                            border.color: root.tabIndex === index ? Theme.borderAccent : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: root.tabIndex === index
                                    ? Theme.accent
                                    : (tabMouse.containsMouse ? Theme.text : Theme.textDim)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(14)
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tabIndex = index
                            }
                        }
                    }
                }

                // плавный индикатор активной вкладки
                Rectangle {
                    // M28: держим зависимость от count и ширины строки — иначе itemAt
                    // в биндинге не пересчитается при ресайзе и x/width «залипнут»
                    readonly property int tabCount: rightTabRep.count
                    readonly property real rowW: rightTabRow.width
                    readonly property var active: (tabCount > 0 && rowW > 0) ? rightTabRep.itemAt(root.tabIndex) : null
                    visible: active !== null
                    x: active ? active.x : 0
                    y: rightTabRow.height - 2
                    width: active ? active.width : 0
                    height: 2
                    radius: 1
                    color: Theme.accent
                    Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
                    Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.tabIndex


                // ═══════════ сейчас играет ═══════════
                Rectangle {
                    color: Theme.bgCard
                    radius: Theme.radius

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        spacing: Theme.space3

                        Text {
                            text: "сейчас играет"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                        }

                        Item { Layout.fillHeight: true }

                        // крупный спектр cava, пока играет; иначе — нота
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 128

                            Text {
                                anchors.centerIn: parent
                                visible: !root.mediaPlaying
                                text: "\uf001"
                                color: root.player ? Theme.accent : Theme.textFaint
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(52)
                            }

                            Row {
                                visible: root.mediaPlaying
                                anchors.fill: parent
                                spacing: 2

                                Repeater {
                                    model: root.barCount
                                    delegate: Item {
                                        required property int index
                                        width: Math.max(1, (parent.width - (root.barCount - 1) * 2) / root.barCount)
                                        height: parent.height
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: 2 + (root.barValues[index] || 0) * (parent.height - 6)
                                            radius: 2
                                            color: Theme.alpha(Theme.accent, 0.32 + 0.68 * (root.barValues[index] || 0))

                                            // светлый «кончик» — столбики читаются мягче
                                            Rectangle {
                                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                                height: 2
                                                radius: 1
                                                color: Theme.accent
                                                opacity: 0.25 + 0.75 * (root.barValues[index] || 0)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.player && root.player.trackTitle
                                ? root.player.trackTitle : "ничего не играет"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitle
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.player && root.player.trackArtist
                            text: root.player ? (root.player.trackArtist || "") : ""
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(15)
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        // прогресс
                        Item {
                            id: progBox
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            visible: root.player && root.player.length > 0

                            readonly property real target: root.player && root.player.length > 0
                                ? Math.min(1, root.player.position / root.player.length) : 0
                            property real shown: 0
                            property bool primed: false
                            onTargetChanged: if (primed) shown = target
                            Component.onCompleted: primeTimer.restart()
                            Timer {
                                id: primeTimer
                                interval: 60
                                onTriggered: { progBox.shown = progBox.target; progBox.primed = true }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.trackBg
                                Rectangle {
                                    width: parent.width * progBox.shown
                                    height: parent.height
                                    radius: 2
                                    color: Theme.accent
                                    Behavior on width { NumberAnimation { duration: Theme.animMed } }
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 22

                            Text {
                                text: "\uf048"
                                color: root.player && root.player.canGoPrevious ? Theme.text : Theme.textFaint
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(23)
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.previous()
                                }
                            }
                            Text {
                                text: (root.player && root.player.isPlaying) ? "\uf04c" : "\uf04b"
                                color: Theme.text
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(29)
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.togglePlaying()
                                }
                            }
                            Text {
                                text: "\uf051"
                                color: root.player && root.player.canGoNext ? Theme.text : Theme.textFaint
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.fontSize(23)
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.next()
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // ═══════════ календарь (прокручивается) ═══════════
                Rectangle {
                    color: Theme.bgCard
                    radius: Theme.radius

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        spacing: Theme.space3

                        Text {
                            Layout.fillWidth: true
                            text: root.todayText
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(15)
                        }


                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Flickable {
                                id: monthFlick
                                anchors.fill: parent
                                clip: true
                                contentWidth: width
                                contentHeight: monthsColumn.height
                                boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: monthsColumn
                                width: monthFlick.width
                                spacing: Theme.space4

                                Repeater {
                                    model: root.months

                                    delegate: Column {
                                        required property var modelData
                                        width: monthsColumn.width
                                        spacing: 6

                                        Text {
                                            width: parent.width
                                            text: modelData.title
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize(17)
                                            font.bold: true
                                            font.letterSpacing: 1
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        // тонкая черта под месяцем — HUD-разделитель
                                        Rectangle {
                                            x: (parent.width - width) / 2
                                            width: 34
                                            height: 1
                                            color: Theme.alpha(Theme.accent, 0.35)
                                        }

                                        Row {
                                            x: (parent.width - implicitWidth) / 2
                                            spacing: 0
                                            Repeater {
                                                model: ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]
                                                Text {
                                                    required property string modelData
                                                    // H12: ширина дня считается от ширины контейнера, а не жёсткие 68px
                                                    width: Math.floor(monthsColumn.width / 7)
                                                    text: modelData
                                                    color: Theme.textFaint
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSize(14)
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                        }

                                        Grid {
                                            x: (parent.width - implicitWidth) / 2
                                            columns: 7
                                            spacing: 0
                                            Repeater {
                                                model: modelData.cells
                                                Rectangle {
                                                    required property var modelData
                                                    // H12: ширина дня считается от ширины контейнера
                                                    width: Math.floor(monthsColumn.width / 7)
                                                    height: Theme.rowH
                                                    radius: Theme.radius
                                                    readonly property bool isSel: modelData.day > 0 && cal.selected === modelData.date
                                                    // M34: «сегодня» считаем от текущей даты, а не из зафиксированного при старте значения
                                                    readonly property bool isToday: modelData.day > 0 && modelData.date === root.todayStr
                                                    // M34: точки событий читаются из cal.events, модель месяцев не пересобирается
                                                    readonly property bool hasEvent: modelData.day > 0 && cal.eventsFor(modelData.date).length > 0
                                                    readonly property bool isHover: cellMouse.containsMouse && modelData.day > 0

                                                    // сегодня — кольцо, выбранный — заливка
                                                    color: isSel ? Theme.active
                                                        : (isToday ? Theme.hover
                                                        : (isHover ? Theme.hoverStrong : "transparent"))
                                                    border.width: (isToday || isHover) ? 1 : 0
                                                    border.color: isToday ? Theme.accent : Theme.borderAccent
                                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.day > 0 ? modelData.day : ""
                                                        color: modelData.day === 0
                                                            ? "transparent"
                                                            : ((isToday || isSel) ? Theme.accent : Theme.text)
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Theme.fontSize(16)
                                                        font.bold: isToday || isSel
                                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                                    }
                                                    // точка: на этот день есть события
                                                    Rectangle {
                                                        visible: hasEvent
                                                        width: 5
                                                        height: 5
                                                        radius: 3
                                                        color: (isToday || isSel) ? Theme.accent : Theme.textDim
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        anchors.bottom: parent.bottom
                                                        anchors.bottomMargin: 3
                                                    }
                                                    MouseArea {
                                                        id: cellMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: modelData.day > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        onClicked: if (modelData.day > 0)
                                                            cal.selected = (cal.selected === modelData.date ? "" : modelData.date)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                            // мягкое затухание сверху/снизу — видно, что список листается
                            Rectangle {
                                anchors { top: parent.top; left: parent.left; right: parent.right }
                                height: 16
                                visible: monthFlick.contentY > 1
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Theme.bgCard }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 16
                                visible: monthFlick.contentY < monthFlick.contentHeight - monthFlick.height - 1
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Theme.bgCard }
                                }
                            }
                        }

                        // ── выбранный день: события и добавление ──
                        ColumnLayout {
                            visible: cal.selected !== ""
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: cal.selected
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(15)
                                    font.bold: true
                                }
                                Text {
                                    text: "\uf00d"
                                    color: Theme.textDim
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.fontSize(15)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: cal.selected = ""
                                    }
                                }
                            }

                            Repeater {
                                model: cal.eventsFor(cal.selected)
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Theme.space2
                                    Text {
                                        text: (modelData.time && modelData.time.length > 0) ? modelData.time : "весь"
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(14)
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(14)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: "\uf1f8"
                                        color: Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.fontSize(14)
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: cal.del(modelData.id)
                                        }
                                    }
                                }
                            }

                            // добавление: название · время · за сколько минут напомнить
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 32
                                    radius: Theme.radius
                                    color: Theme.trackBg
                                    border.width: 1
                                    border.color: Theme.border
                                    TextInput {
                                        id: calTitle
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.space2
                                        anchors.rightMargin: Theme.space2
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(14)
                                        clip: true
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: parent.text.length === 0
                                            text: "событие"
                                            color: Theme.textFaint
                                            font: parent.font
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 66
                                    height: 32
                                    radius: Theme.radius
                                    color: Theme.trackBg
                                    border.width: 1
                                    border.color: Theme.border
                                    TextInput {
                                        id: calTime
                                        anchors.fill: parent
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(14)
                                        Text {
                                            anchors.centerIn: parent
                                            visible: parent.text.length === 0
                                            text: "чч:мм"
                                            color: Theme.textFaint
                                            font: parent.font
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 52
                                    height: 32
                                    radius: Theme.radius
                                    color: Theme.trackBg
                                    border.width: 1
                                    border.color: Theme.border
                                    TextInput {
                                        id: calRemind
                                        anchors.fill: parent
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(14)
                                        validator: IntValidator { bottom: 0; top: 600 }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: parent.text.length === 0
                                            text: "мин"
                                            color: Theme.textFaint
                                            font: parent.font
                                        }
                                    }
                                }
                                Text {
                                    text: "\uf067"
                                    color: Theme.accent
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.fontSize(17)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.addCalEvent()
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════ запись экрана ═══════════
                Rectangle {
                    color: Theme.bgCard
                    radius: Theme.radius

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        spacing: Theme.space2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            Text {
                                text: "запись экрана"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize(14)
                            }
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 30
                                radius: Theme.radius
                                color: root.recording
                                    ? Theme.alpha(Theme.danger, 0.16)
                                    : Theme.active
                                border.width: 1
                                border.color: root.recording ? Theme.danger : Theme.borderAccent

                                Text {
                                    anchors.centerIn: parent
                                    text: root.recording ? "■ СТОП" : "● ЗАПИСЬ"
                                    color: root.recording ? Theme.danger : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: recModel.toggle()
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 30
                                radius: Theme.radius
                                color: recRefreshMouse.containsMouse ? Theme.hoverStrong : "transparent"
                                border.width: recRefreshMouse.containsMouse ? 1 : 0
                                border.color: Theme.borderAccent
                                Text {
                                    anchors.centerIn: parent
                                    text: "↻"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(15)
                                }
                                MouseArea {
                                    id: recRefreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: recModel.load()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.recording
                            text: "● идёт запись…"
                            color: Theme.danger
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(13)
                        }

                        ListView {
                            id: recList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 6
                            model: recModel.items

                            delegate: Rectangle {
                                required property var modelData
                                width: recList.width
                                height: 54
                                radius: Theme.radius
                                color: recMouse.containsMouse ? Theme.hover : "transparent"

                                MouseArea {
                                    id: recMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: recModel.open(modelData.path)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space3
                                    anchors.rightMargin: Theme.space3
                                    spacing: Theme.space3

                                    Text {
                                        text: "\uf03d"
                                        color: Theme.accent
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.fontSize(17)
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize(13)
                                            elide: Text.ElideMiddle
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.fmtSize(modelData.size) + "  ·  " + root.fmtDate(modelData.mtime)
                                            color: Theme.textFaint
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize(11)
                                        }
                                    }

                                    Text {
                                        text: "\uf04b"
                                        color: playMouse.containsMouse ? Theme.accent : Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.fontSize(14)
                                        MouseArea {
                                            id: playMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: recModel.open(modelData.path)
                                        }
                                    }
                                    Text {
                                        text: "\uf1f8"
                                        color: delMouse.containsMouse ? Theme.danger : Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.fontSize(13)
                                        MouseArea {
                                            id: delMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: recModel.remove(modelData.path)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: recModel.items.length === 0
                            text: "записей нет"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(13)
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "открыть папку записей"
                            color: folderMouse.containsMouse ? Theme.accent : Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                            horizontalAlignment: Text.AlignHCenter
                            MouseArea {
                                id: folderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: recModel.openFolder()
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            Text {
                text: sysStats.text
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize(13)
            }
        }
    }

    // ─────────────────────────── данные ───────────────────────────
    readonly property var player: {
        var ps = Mpris.players.values
        for (var i = 0; i < ps.length; i++)
            if (ps[i].isPlaying)
                return ps[i]
        return ps.length > 0 ? ps[0] : null
    }

    readonly property var monthNames: [
        "январь", "февраль", "март", "апрель", "май", "июнь",
        "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"
    ]

    // M34: «сегодня» храним строкой и обновляем по таймеру, а не фиксируем при старте
    property string todayStr: root.localDateStr(new Date())

    function localDateStr(d) {
        return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2)
            + "-" + ("0" + d.getDate()).slice(-2)
    }

    function parseDay(s) {
        var p = ("" + s).split("-")
        return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
    }

    readonly property string todayText: {
        var cur = root.todayStr // зависимость: пересчитывается при смене суток
        var d = new Date()
        return d.getDate() + "." + ("0" + (d.getMonth() + 1)).slice(-2) + "." + d.getFullYear()
    }

    // 18 месяцев вперёд — список прокручивается.
    // M34: зависим только от даты (todayStr), а точки событий считаются в делегате
    // от cal.events — добавление события больше не пересобирает весь календарь.
    readonly property var months: {
        var out = []
        var now = root.parseDay(root.todayStr)
        for (var i = 0; i < 18; i++) {
            var first = new Date(now.getFullYear(), now.getMonth() + i, 1)
            var y = first.getFullYear(), m = first.getMonth()
            var startDow = (new Date(y, m, 1).getDay() + 6) % 7
            var days = new Date(y, m + 1, 0).getDate()
            var cells = []
            for (var k = 0; k < startDow; k++)
                cells.push({ day: 0, date: "" })
            for (var dd = 1; dd <= days; dd++) {
                var ds = y + "-" + ("0" + (m + 1)).slice(-2) + "-" + ("0" + dd).slice(-2)
                cells.push({ day: dd, date: ds })
            }
            out.push({ title: monthNames[m] + " " + y, cells: cells })
        }
        return out
    }

    Timer {
        id: hideTimer
        interval: 600
        onTriggered: {
            if (!stripHover.hovered && !contentHover.hovered)
                root.closePanel()
        }
    }

    // M34: раз в минуту сверяем текущие сутки — «сегодня» не залипает на дате старта
    Timer {
        id: todayTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            var s = root.localDateStr(new Date())
            if (s !== root.todayStr)
                root.todayStr = s
        }
    }

    // обновление списка уведомлений, пока панель открыта
    // M36: раз в 5 с вместо 2.5 с — вдвое меньше запусков listProc/modeProc
    Timer {
        interval: 5000
        repeat: true
        running: !root.collapsed
        onTriggered: notif.load()
    }

    // ─────────── локальный календарь (события + напоминания) ───────────
    // Хранилище — ~/.local/share/lunar/calendar.json (скрипт eclipse-calendar.py).
    // Сеть не нужна; CalDAV добавим отдельным этапом.
    QtObject {
        id: cal
        property var events: []
        property var settings: ({})
        property string selected: ""      // выбранный день, YYYY-MM-DD

        function reload() { calList.running = true }

        function eventsFor(date) {
            var out = []
            for (var i = 0; i < events.length; i++)
                if (events[i].date === date) out.push(events[i])
            out.sort(function(a, b) {
                var x = a.time || "99:99", y = b.time || "99:99"
                return x < y ? -1 : (x > y ? 1 : 0)
            })
            return out
        }

        function py() {
            return Quickshell.env("HOME") + "/.config/hypr/scripts/eclipse-calendar.py"
        }

        function add(title, date, time, remind) {
            title = (title || "").trim()
            if (!title || !date) return
            var cmd = ["python3", py(), "add", "--date", date, "--title", title]
            var t = (time || "").trim()
            if (t !== "" && /^\d{1,2}:\d{2}$/.test(t)) {
                if (/^\d:\d{2}$/.test(t)) t = "0" + t
                cmd = cmd.concat(["--time", t])
            }
            var r = (remind || "").trim()
            if (r !== "" && !isNaN(parseInt(r)))
                cmd = cmd.concat(["--remind", "" + Math.max(0, parseInt(r))])
            calAddProc.command = cmd
            calAddProc.running = true
        }

        function del(id) {
            calDelProc.command = ["python3", py(), "del", "--id", id]
            calDelProc.running = true
        }
    }

    Process {
        id: calList
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/eclipse-calendar.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    cal.events = d.events || []
                    cal.settings = d.settings || {}
                } catch (e) {
                    // L25: не обнуляем события молча — оставляем прошлый список
                    console.warn("календарь: не удалось разобрать список событий: " + e)
                }
            }
        }
    }

    // H11: отдельный Process на каждую мутацию — быстрый add+del больше не теряет второй клик.
    // Код выхода проверяем, чтобы не показывать успех при ошибке.
    Process {
        id: calAddProc
        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("календарь: добавление события завершилось с кодом " + exitCode)
            cal.reload()
        }
    }

    Process {
        id: calDelProc
        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("календарь: удаление события завершилось с кодом " + exitCode)
            cal.reload()
        }
    }

    Process {
        id: calReminder
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/eclipse-calendar.py", "reminders"]
    }

    // напоминания проверяем раз в минуту — работает и при закрытой панели
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: calReminder.running = true
    }

    QtObject {
        id: notif
        property var raw: []          // сырой список от mako (история + активные)
        property var items: []        // показываемый список (без скрытых)
        property bool dnd: false
        property int hideBefore: -1   // «очистить»: прячем всё с id <= этого
        property var hiddenIds: ({})  // точечно скрытые (dismiss)
        property var expandedId: -1   // развёрнутое уведомление (клик — раскрыть)

        function toggleExpand(id) {
            expandedId = (expandedId === id) ? -1 : id
        }

        function rebuild() {
            var out = []
            for (var i = 0; i < raw.length; i++) {
                var n = raw[i]
                if (n.id <= hideBefore) continue
                if (hiddenIds[n.id] === true) continue
                out.push({
                    id: n.id,
                    app: n.app_name || "",
                    summary: n.summary || "",
                    body: (n.body || "").replace(/\n/g, " ")
                })
            }
            items = out
        }

        function load() {
            listProc.running = true
            modeProc.running = true
        }

        function dismiss(id) {
            var sid = parseInt(id)
            if (!isFinite(sid)) return
            hiddenIds[sid] = true
            if (expandedId === sid) expandedId = -1
            rebuild()
            actionProc.command = ["bash", "-c", "makoctl dismiss -n " + sid]
            actionProc.running = true
        }

        function clear() {
            // mako не умеет чистить историю (`dismiss --all` её не трогает),
            // поэтому перезапускаю mako — история и активные обнуляются.
            // id начнутся заново, так что фильтры сбрасываю.
            hideBefore = -1
            hiddenIds = ({})
            expandedId = -1
            rebuild()
            actionProc.command = ["bash", "-c",
                "pkill -x mako; sleep 0.3; setsid mako >/dev/null 2>&1 &"]
            actionProc.running = true
        }

        function toggleDnd() {
            actionProc.command = ["bash", "-c", "makoctl mode -t do-not-disturb"]
            actionProc.running = true
        }
    }

    Process {
        id: listProc
        running: false
        // история mako (ограничена max-history=20) + активные, свежие сверху
        command: ["bash", "-c", "jq -s 'add | unique_by(.id) | sort_by(.id) | reverse | .[0:20]' <(makoctl history -j 2>/dev/null || echo '[]') <(makoctl list -j 2>/dev/null || echo '[]')"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    notif.raw = JSON.parse(text)
                    notif.rebuild()
                } catch (e) {
                    // L25: не затираем список уведомлений при сбое разбора
                    console.warn("уведомления: не удалось разобрать вывод makoctl: " + e)
                }
            }
        }
    }

    Process {
        id: modeProc
        running: false
        command: ["bash", "-c", "makoctl mode 2>/dev/null | grep -q '^do-not-disturb$' && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: notif.dnd = (text.trim() === "1")
        }
    }

    Process {
        id: actionProc
        running: false
        onExited: {
            notif.load()
            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 250
        onTriggered: notif.load()
    }

    Process {
        id: sysStats
        command: ["python3", "-c", "import psutil; print(f'CPU {int(psutil.cpu_percent())}%  RAM {int(psutil.virtual_memory().percent)}%')"]
        running: true
        stdout: StdioCollector { onStreamFinished: sysStats.text = text.trim() }
        property string text: "CPU --%  RAM --%"
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: sysStats.running = true
    }

    // ─────────────────── запись экрана ───────────────────
    property bool recording: false

    function fmtSize(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB"
        return Math.max(1, Math.round(b / 1048576)) + " MB"
    }

    function fmtDate(ts) {
        var d = new Date(ts * 1000)
        return ("0" + d.getDate()).slice(-2) + "." + ("0" + (d.getMonth() + 1)).slice(-2)
            + " " + ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
    }

    QtObject {
        id: recModel
        property var items: []

        function load() { recListProc.running = true }

        function toggle() {
            // M26: argv без bash — путь не проходит через шелл
            recActionProc.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/eclipse-record.sh", "toggle"]
            recActionProc.running = true
        }

        function open(p) {
            // M26: argv без bash, --fork отцепляет mpv и не держит Process открытым
            recActionProc.command = ["setsid", "--fork", "mpv", p]
            recActionProc.running = true
        }

        function remove(p) {
            // M26: argv без bash — имя файла не может стать частью команды
            recActionProc.command = ["rm", "-f", "--", p]
            recActionProc.running = true
        }

        function openFolder() {
            recActionProc.command = ["setsid", "--fork", "xdg-open", Quickshell.env("HOME") + "/Videos"]
            recActionProc.running = true
        }
    }

    Process {
        id: recListProc
        running: false
        command: ["python3", "-c", `
import json, os, glob
d = os.path.expanduser("~/Videos")
out = []
for f in sorted(glob.glob(d + "/*.mp4"), key=os.path.getmtime, reverse=True):
    st = os.stat(f)
    out.append({"path": f, "name": os.path.basename(f),
                "size": st.st_size, "mtime": int(st.st_mtime)})
print(json.dumps(out[:200]))
`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    recModel.items = JSON.parse(text)
                } catch (e) {
                    // L25: не очищаем список записей при сбое разбора
                    console.warn("запись: не удалось разобрать список файлов: " + e)
                }
            }
        }
    }

    Process {
        id: recActionProc
        running: false
        onExited: {
            recModel.load()
            recStatusProc.running = true
        }
    }

    Process {
        id: recStatusProc
        running: false
        command: ["bash", "-c", "pgrep -x wf-recorder >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: root.recording = (text.trim() === "1")
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: !root.collapsed
        onTriggered: recStatusProc.running = true
    }

    Component.onCompleted: {
        notif.load()
        recModel.load()
        recStatusProc.running = true
        cal.reload()
    }
}
