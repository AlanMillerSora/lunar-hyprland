import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick.Layouts
import "../"

Item {
    id: page

    property string mono: "JetBrainsMono Nerd Font"
    property int rightMargin: 36

    // ── цвет от обоев: генератор считает доминирующий цвет картинки ──
    Process {
        id: photoProc
        running: false
    }

    // открыть окно подбора обоев (SUPER + B)
    Process {
        id: openPickerProc
        running: false
        command: ["qs", "ipc", "call", "wallpapers", "open"]
    }

    function applyPhotoColor() {
        if (Theme.wallpaperPath === "" || photoProc.running)
            return
        var q = "'" + Theme.wallpaperPath.replace(/'/g, "'\\''") + "'"
        photoProc.command = ["bash", "-c",
            "$HOME/.config/hypr/scripts/eclipse-palette.py --from-image " + q + " --apply >/dev/null && "
            + "(pidof kitty >/dev/null && kill -USR1 $(pidof kitty); makoctl reload 2>/dev/null); true"]
        photoProc.running = true
    }

    Process {
        id: pickProc
        running: false
        command: ["bash", "-c",
            "zenity --file-selection --title='Обои' " +
            "--file-filter='Изображения | *.jpg *.jpeg *.png *.webp' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var f = text.trim()
                if (f !== "") {
                    Theme.wallpaperPath = f
                    Theme.wallpaperMode = "image"
                }
            }
        }
    }

    // ── обои (перенесено со страницы WALLPAPERS) ───────────────
    // живое превью: показываем фазу активного стола (или выбранную).
    // L40: фаза строго 1..9, внемерные столы не мапим молча.
    readonly property var ws: Hyprland.activeWorkspace || Hyprland.focusedWorkspace
    readonly property int activePhase: {
        var id = ws ? ws.id : 0
        if (id >= 1 && id <= 9)
            return id
        var f = Hyprland.focusedWorkspace
        if (f && f.id >= 1 && f.id <= 9)
            return f.id
        return 5
    }
    property int previewPhase: -1
    readonly property int shownPhase: previewPhase > 0 ? previewPhase : activePhase

    // ── размытие (блюр) — управляет Hyprland, действует на всю систему ──
    property real blurValue: 0.66          // 0..1  → size 0..12
    property bool blurReady: false

    Process {
        id: blurGet
        running: true
        command: ["bash", "-c", "hyprctl -j getoption decoration:blur:size 2>/dev/null | jq -r '.int // 0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                // если ползунок уже выставляли — он главнее текущего Hyprland
                var s = (Theme.blurSize >= 0) ? Theme.blurSize : parseInt(text.trim())
                if (!isNaN(s)) {
                    page.blurValue = Math.max(0, Math.min(1, s / 12))
                    page.blurReady = true
                }
            }
        }
    }

    // ── палитра: пресеты цвета (генератор eclipse-palette.py) ──
    // Меняю цвета всего риса разом: генератор пишет palette.json (его читает
    // Theme.qml) и файлы для kitty/GTK/qt6ct/mako/btop/yazi. Kitty и mako
    // перечитывают конфиг сразу, остальные — при следующем запуске.
    property bool paletteBusy: false

    Process {
        id: paletteProc
        running: false
        onExited: (exitCode) => page.paletteBusy = false
    }

    function applyPalette(name) {
        if (paletteBusy)
            return
        paletteBusy = true
        paletteProc.command = ["bash", "-c",
            "$HOME/.config/hypr/scripts/eclipse-palette.py --preset " + name + " --apply >/dev/null && "
            + "(pidof kitty >/dev/null && kill -USR1 $(pidof kitty); makoctl reload 2>/dev/null); true"]
        paletteProc.running = true
    }

    // M47: uiState может загрузиться позже blurGet — тогда ползунок блюра
    // показывал бы значение из Hyprland, а не сохранённое. Подхватываем Theme.
    Connections {
        target: Theme
        function onBlurSizeChanged() {
            if (Theme.blurSize >= 0) {
                page.blurValue = Math.max(0, Math.min(1, Theme.blurSize / 12))
                page.blurReady = true
            }
        }
    }

    Timer {
        id: blurDebounce
        interval: 120
        onTriggered: page.applyBlur()
    }

    // M45: прозрачность/шрифт раньше писали lunar-ui.json на каждый кадр
    // перетаскивания — теперь только после паузы (как у блюра).
    Timer {
        id: opacityDebounce
        interval: 150
        onTriggered: Theme.interfaceOpacity = opacitySlider.dragValue
    }

    Timer {
        id: fontDebounce
        interval: 150
        onTriggered: Theme.fontScale = 0.75 + fontSlider.dragValue * 0.5
    }

    function applyBlur() {
        var size = Math.round(blurValue * 12)
        var passes = size >= 6 ? 4 : 3
        Theme.setBlur(size, passes)   // запоминает в Theme и применяет
    }

    Flickable {
        id: scrollArea
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: function(event) {
                var delta = event.angleDelta.y
                // L33: горизонтальные/пустые события не съедаем
                if (delta === 0)
                    return
                scrollArea.contentY = Math.max(
                    0,
                    Math.min(
                        scrollArea.contentHeight - scrollArea.height,
                        scrollArea.contentY - delta
                    )
                )
                event.accepted = true
            }
        }

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                rightMargin: page.rightMargin
            }
            spacing: Theme.space5

            Text {
                text: "INTERFACE"
                color: Theme.text
                font.family: page.mono
                font.pixelSize: Theme.fontTitle
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // M73: ошибка чтения lunar-ui.json (битый JSON / нет доступа) —
            // настройки молча уходят в дефолты, поэтому сообщаем явно
            Rectangle {
                visible: Theme.uiError !== ""
                width: parent.width
                height: errText.implicitHeight + Theme.space5
                radius: Theme.radius
                color: Theme.alpha(Theme.danger, 0.08)
                // рамка уведомления об ошибке — часть акцента, оставляю
                border.width: 1
                border.color: Theme.danger

                Text {
                    id: errText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.space3
                    text: "\uf071  " + Theme.uiError
                    color: Theme.danger
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }

            // Прозрачность панели
            Column {
                width: parent.width
                spacing: Theme.space3

                Row {
                    width: parent.width
                    spacing: Theme.space4

                    Text {
                        text: "󰝴"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: Theme.space1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "прозрачность интерфейса"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: Math.round(Theme.interfaceOpacity * 100) + "%"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                CustomSlider {
                    id: opacitySlider
                    width: parent.width
                    value: Theme.interfaceOpacity
                    // M45/L35: только от пользователя, запись — после паузы
                    onMoved: opacityDebounce.restart()
                }
            }

            // Размытие (блюр) — на всю систему через Hyprland
            Column {
                width: parent.width
                spacing: Theme.space3

                Row {
                    width: parent.width
                    spacing: Theme.space4

                    Text {
                        text: "\uf043"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: Theme.space1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "размытие (блюр)"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: page.blurValue <= 0.01
                                ? "выключен"
                                : Math.round(page.blurValue * 100) + "%"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                CustomSlider {
                    width: parent.width
                    value: page.blurValue
                    onMoved: function(v) {
                        page.blurValue = v
                        blurDebounce.restart()
                    }
                }
            }

            // Размер шрифта
            Column {
                width: parent.width
                spacing: Theme.space3

                Row {
                    width: parent.width
                    spacing: Theme.space4

                    Text {
                        text: "󰬶"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: Theme.space1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "размер шрифта"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: Math.round(Theme.fontScale * 100) + "%"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                CustomSlider {
                    id: fontSlider
                    width: parent.width
                    value: (Theme.fontScale - 0.75) / 0.5
                    // M45/L35: только от пользователя, запись — после паузы
                    onMoved: fontDebounce.restart()
                }
            }

            // Значков трея в панели
            Column {
                width: parent.width
                spacing: Theme.space3

                Row {
                    width: parent.width
                    spacing: Theme.space4

                    Text {
                        text: "\uf00a"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: Theme.space1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "значков трея в панели"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: Theme.trayVisible + " видно, остальные — в списке «+N»"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                Row {
                    spacing: Theme.space2

                    Repeater {
                        model: [1, 2, 3, 4, 5, 6, 8, 10]

                        delegate: Rectangle {
                            required property int modelData
                            width: 40
                            height: 30
                            radius: Theme.radius
                            color: Theme.trayVisible === modelData
                                ? Theme.active
                                : "transparent"
                            border.width: 1
                            border.color: Theme.trayVisible === modelData
                                ? Theme.accent
                                : (presetMouse.containsMouse ? Theme.borderAccent : Theme.border)

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: Theme.trayVisible === modelData ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: Theme.trayVisible === modelData
                            }

                            MouseArea {
                                id: presetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.trayVisible = modelData
                            }
                        }
                    }
                }
            }

            // Превью
            Rectangle {
                width: parent.width
                height: 80
                radius: Theme.radiusM
                // статичная карточка превью: фон вместо рамки
                color: Theme.fill

                Text {
                    anchors.centerIn: parent
                    text: "превью шрифта"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                }
            }

            // ── палитра: пресеты цвета всего риса ──
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Text {
                text: "ПАЛИТРА"
                color: Theme.text
                font.family: page.mono
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 2
            }

            Column {
                width: parent.width
                spacing: Theme.space2

                Row {
                    spacing: Theme.space2

                    Repeater {
                        model: [
                            { id: "lunar", name: "LUNAR" },
                            { id: "graphite", name: "GRAPHITE" },
                            { id: "steel", name: "STEEL" },
                            { id: "photo", name: "ФОТО" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool cur: Theme.palette.preset === modelData.id
                            width: palLabel.implicitWidth + 28
                            height: Theme.rowHCompact
                            radius: Theme.radiusM
                            color: cur ? Theme.active
                                : (palMouse.containsMouse ? Theme.hoverStrong : Theme.fill)
                            border.width: cur ? 1 : 0
                            border.color: Theme.accent

                            Text {
                                id: palLabel
                                anchors.centerIn: parent
                                text: modelData.name
                                color: cur ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.bold: cur
                                font.letterSpacing: 2
                            }

                            MouseArea {
                                id: palMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.id === "photo")
                                        page.applyPhotoColor()
                                    else
                                        page.applyPalette(modelData.id)
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: Theme.palette.preset === "photo"
                        ? "цвет взят с обоев · выбери LUNAR/GRAPHITE/STEEL, чтобы вернуть готовую палитру"
                        : (Theme.palette.preset
                            ? "текущая: " + Theme.palette.preset
                              + " · цвета идут в шелл, kitty, GTK, qt6ct, mako, btop, yazi"
                            : "пресет не выбран — работает палитра по умолчанию")
                    color: Theme.textFaint
                    font.family: page.mono
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }

            // ── обои: живая сцена затмения (перенесено со страницы WALLPAPERS) ──
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Text {
                text: "ОБОИ"
                color: Theme.text
                font.family: page.mono
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 2
            }

            // выбор: живая сцена затмения или обычная картинка
            Row {
                spacing: Theme.space2

                Repeater {
                    model: [
                        { id: "scene", name: "СЦЕНА · ФАЗЫ" },
                        { id: "image", name: "КАРТИНКА" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool cur: Theme.wallpaperMode === modelData.id
                        width: wmLabel.implicitWidth + 28
                        height: Theme.rowHCompact
                        radius: Theme.radiusM
                        color: cur ? Theme.active : (wmMouse.containsMouse ? Theme.hoverStrong : Theme.fill)
                        border.width: cur ? 1 : 0
                        border.color: Theme.accent

                        Text {
                            id: wmLabel
                            anchors.centerIn: parent
                            text: modelData.name
                            color: cur ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.bold: cur
                            font.letterSpacing: 2
                        }

                        MouseArea {
                            id: wmMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.wallpaperMode = modelData.id
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.space3
                visible: Theme.wallpaperMode !== "image"

                Text {
                    text: previewPhase > 0
                        ? "ПРЕВЬЮ · фаза " + shownPhase
                        : "ПРЕВЬЮ · фаза " + shownPhase + " (текущий стол)"
                    color: Theme.textFaint
                    font.family: page.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }

                // 16:9 мини-экран. live = страница видима: вкладка (или Hub)
                // скрыта — Timer сцены стоит и не жжёт CPU вхолостую.
                Item {
                    width: Math.min(parent.width, 512)
                    height: width * 9 / 16
                    clip: true

                    LunarWallpaperScene {
                        anchors.fill: parent
                        phase: page.shownPhase
                        live: page.visible
                        optimize: true
                        tickMs: 33
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.radius
                        border.color: Theme.border
                        border.width: 1
                    }
                }

                // выбор фазы (1..9) — какой стол показать в превью
                Row {
                    spacing: 6

                    Repeater {
                        model: 9

                        delegate: Rectangle {
                            required property int index
                            readonly property int ph: index + 1
                            width: 30
                            height: 24
                            radius: Theme.radius
                            color: page.shownPhase === ph
                                ? Theme.active
                                : (phMouse.containsMouse ? Theme.hoverStrong : Theme.fill)
                            border.width: 1
                            border.color: page.shownPhase === ph ? Theme.accent : Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: index + 1
                                color: page.shownPhase === ph ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: phMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.previewPhase = page.previewPhase === ph ? -1 : ph
                            }
                        }
                    }
                }
            }

            // ── обои-картинка: превью, выбор файла и полка ──
            Column {
                width: parent.width
                spacing: Theme.space3
                visible: Theme.wallpaperMode === "image"

                Item {
                    width: Math.min(parent.width, 512)
                    height: width * 9 / 16
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.fill
                        radius: Theme.radius
                    }

                    Image {
                        anchors.fill: parent
                        visible: Theme.wallpaperPath !== ""
                        source: Theme.wallpaperPath !== "" ? "file://" + Theme.wallpaperPath : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: Theme.wallpaperPath === ""
                        text: "выбери картинку ниже"
                        color: Theme.textFaint
                        font.family: page.mono
                        font.pixelSize: 10
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.radius
                        border.color: Theme.border
                        border.width: 1
                    }
                }

                Row {
                    spacing: Theme.space3

                    Rectangle {
                        width: pickLabel.implicitWidth + 28
                        height: Theme.rowHCompact
                        radius: Theme.radiusM
                        color: pickMouse.containsMouse ? Theme.active : Theme.fill
                        border.width: 1
                        border.color: pickMouse.containsMouse ? Theme.accent : Theme.border

                        Text {
                            id: pickLabel
                            anchors.centerIn: parent
                            text: "ВЫБРАТЬ ФАЙЛ…"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        MouseArea {
                            id: pickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pickProc.running = true
                        }
                    }

                    Rectangle {
                        width: pickLabel.implicitWidth + 28
                        height: Theme.rowHCompact
                        radius: Theme.radiusM
                        color: pickMouse.containsMouse ? Theme.active : Theme.fill
                        border.width: 1
                        border.color: pickMouse.containsMouse ? Theme.accent : Theme.border

                        Text {
                            id: pickLabel
                            anchors.centerIn: parent
                            text: "ПОДБОР ОБОЕВ…"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.letterSpacing: 1
                        }

                        MouseArea {
                            id: pickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: openPickerProc.running = true
                        }
                    }

                    Rectangle {
                        visible: Theme.wallpaperPath !== ""
                        width: photoLabel.implicitWidth + 28
                        height: Theme.rowHCompact
                        radius: Theme.radiusM
                        color: photoMouse.containsMouse ? Theme.active : Theme.fill
                        border.width: 1
                        border.color: photoMouse.containsMouse ? Theme.accent : Theme.border

                        Text {
                            id: photoLabel
                            anchors.centerIn: parent
                            text: "ЦВЕТ ОТ ОБОЕВ"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.letterSpacing: 1
                        }

                        MouseArea {
                            id: photoMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.applyPhotoColor()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - 330)
                        text: Theme.wallpaperPath !== ""
                            ? Theme.wallpaperPath
                            : "картинка не выбрана — открой подбор (SUPER + B)"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideMiddle
                    }
                }
            }

            // ── режим обоев (живые QML / лёгкий) — только для сцены ──
            Row {
                width: parent.width
                spacing: Theme.space3
                visible: Theme.wallpaperMode !== "image"

                Text {
                    text: "\uf03e"
                    color: Theme.accent
                    font.family: page.mono
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: Theme.space1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "live eclipse scene (QML)"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                    Text {
                        text: Theme.wallpaperLive
                            ? "звёзды, метеоры, пыль, серп — анимация включена"
                            : "лёгкий режим: без звёзд/метеоров/пыли"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    id: liveToggle
                    width: 46
                    height: 24
                    radius: Theme.radiusL
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.wallpaperLive ? Theme.accent : Theme.trackBg
                    border.width: 1
                    border.color: Theme.wallpaperLive ? Theme.accent : Theme.border
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.wallpaperLive ? parent.width - width - 3 : 3
                        color: Theme.wallpaperLive ? Theme.bgPanel : Theme.textDim
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Theme.wallpaperLive = !Theme.wallpaperLive
                    }
                }
            }
        }
    }

    component CustomSlider: Rectangle {
        id: slider
        property real value: 0.5
        // значение во время перетаскивания: не трогаем value, иначе рвём
        // привязку вызывающей стороны (L35)
        property real dragValue: 0
        // только от пользователя (программная установка value сюда не шлёт)
        signal moved(real v)
        // «заполнение» при появлении: старт с нуля → плавно к value
        property real shown: 0
        property bool primed: false
        onValueChanged: if (primed) shown = value
        Component.onCompleted: primeTimer.restart()
        Timer {
            id: primeTimer
            interval: 60
            onTriggered: { slider.shown = slider.value; slider.primed = true }
        }
        // пока тянем — значение под курсором, иначе — текущее value
        readonly property real displayValue:
            sliderDrag.pressed ? slider.dragValue : slider.shown
        height: 24
        radius: Theme.radiusL
        color: Theme.trackBg
        border.color: Theme.border
        border.width: 1

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 2
            width: 2 + (parent.width - 20)
                * Math.max(0, Math.min(1, slider.displayValue))
            radius: Theme.radiusM
            color: Theme.accent
            // плавное заполнение, как у полос в «Памяти»
            Behavior on width {
                enabled: !sliderDrag.pressed
                NumberAnimation { duration: 200 }
            }
        }

        MouseArea {
            id: sliderDrag
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            // M46: иначе Flickable перехватывает перетаскивание
            preventStealing: true
            function setFromX(px) {
                var v = Math.max(0, Math.min(1, px / slider.width))
                slider.dragValue = v
                slider.moved(v)
            }
            onPositionChanged: function(mouse) {
                if (pressed)
                    setFromX(mouse.x)
            }
            onPressed: function(mouse) {
                setFromX(mouse.x)
            }
            onReleased: {
                // фиксируем последнее значение, чтобы заполнение не мигало
                // до срабатывания debounce
                slider.shown = slider.dragValue
            }
        }
    }
}
