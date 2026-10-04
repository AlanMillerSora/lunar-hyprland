import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "widgets/shared"

// ════════════════════════════════════════════════════════════════
//  LunarWallpapers — переключатель обоев «как у 43PR».
//
//  Полноэкранный прозрачный оверлей (слой Overlay), по центру веер обоев:
//  центр крупный, края мельче и разъезжаются. Колесо/драг листают, наведение
//  ставит выбор, клик/Space — поставить и выйти, Esc/W/клик мимо — выйти.
//
//  Производительность: полку сканирую один раз, картинки декодирую не
//  полноразмерно, а из кэша миниатюр (~/.cache/lunar/wall-thumbs), и гружу
//  только близкие к экрану; при закрытии источники освобождаю.
//
//  Открывается по SUPER + B или `qs ipc call wallpapers toggle`.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    property bool showing: false
    // плавный вход/выход: окно живёт, пока идёт затухание (иначе резко мигает)
    property bool closing: false
    property real fade: 0
    Behavior on fade { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
    // наведение выбирает карточку только после того, как мышь реально двинулась —
    // иначе при открытии курсор «наводится» на случайную карточку и выбор прыгает
    property bool hoverArmed: false
    property var walls: []
    property bool scanned: false
    // имя файла -> 1 (какие миниатюры уже готовы)
    property var thumbSet: ({})
    property string thumbDir: Quickshell.env("HOME") + "/.cache/lunar/wall-thumbs"

    // ── веер ──
    property int visibleCount: 8
    property real zoomScale: 0.8
    property real edgeScale: 0.3
    property real edgeSpacing: 80
    property int tileHeight: 1080

    visible: root.showing || root.closing
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "lunar-wallpapers"

    IpcHandler {
        target: "wallpapers"
        function toggle(): void { root.showing = !root.showing }
        function open(): void { root.showing = true }
        function close(): void { root.showing = false }
        function next(): void { root.moveSel(1) }
        function prev(): void { root.moveSel(-1) }
        function apply(): void { root.commit(carousel.selectedIndex) }
        function rescan(): void { root.scanned = false; wallScan.running = true }
    }

    // при открытии: фокус на ловца клавиш; сканирую только если ещё не сканировал
    onShowingChanged: {
        if (showing) {
            root.closing = false
            root.fade = 1
            root.hoverArmed = false
            if (!root.scanned)
                wallScan.running = true
            keyCatcher.forceActiveFocus()
            Qt.callLater(carousel.centerOnStart)
        } else {
            // плавный выход: гасим, окно прячем после затухания
            root.closing = true
            root.fade = 0
            closeHide.restart()
            // закрыли до подтверждения — отменяю его
            confirmTimer.stop()
            revealTimer.stop()
            root.confirming = false
        }
    }

    // окно прячем только когда затухание доиграло
    Timer {
        id: closeHide
        interval: 220
        repeat: false
        onTriggered: root.closing = false
    }

    // ── полка: картинки из ~/Pictures, ~/Wallpapers, ~/Pictures/Wallpapers ──
    Process {
        id: wallScan
        running: true
        command: ["bash", "-c",
            "find \"$HOME/Pictures\" \"$HOME/Wallpapers\" \"$HOME/Pictures/Wallpapers\" " +
            "-maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "2>/dev/null | sort -u | head -150"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.walls = text.trim().split("\n").filter(function(x) { return x.length > 0 })
                root.scanned = true
                // готовлю/обновляю миниатюры — фоном, один раз
                thumbGen.running = true
                Qt.callLater(carousel.centerOnStart)
            }
        }
    }

    // ── миниатюры: тяжёлый декод гигантов делаю один раз, в кэш ──
    Process {
        id: thumbGen
        running: false
        command: ["bash", "-c",
            "C=\"$HOME/.cache/lunar/wall-thumbs\"; mkdir -p \"$C\"; " +
            "find \"$HOME/Pictures\" \"$HOME/Wallpapers\" \"$HOME/Pictures/Wallpapers\" " +
            "-maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "2>/dev/null | while IFS= read -r p; do " +
            "b=$(basename \"$p\"); t=\"$C/$b.jpg\"; " +
            "if [ -s \"$t\" ] && [ \"$t\" -nt \"$p\" ]; then continue; fi; " +
            "magick \"$p\" -thumbnail x1000 -strip -quality 82 \"$t\" 2>/dev/null || true; " +
            "done; true"]
        onExited: (exitCode) => { thumbList.running = true }
    }

    Process {
        id: thumbList
        running: false
        command: ["bash", "-c", "ls -1 \"$HOME/.cache/lunar/wall-thumbs\"/*.jpg 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = ({})
                text.trim().split("\n").forEach(function(x) {
                    if (!x) return
                    var b = x.substring(x.lastIndexOf("/") + 1).replace(/\.jpg$/, "")
                    s[b] = 1
                })
                root.thumbSet = s
            }
        }
    }

    // ── выбрать файл (вне полки) ──
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
                    Theme.applyPhotoPalette(f)
                    // палитра/кроссфейд стартуют за ширмой, потом гаснем
                    revealTimer.restart()
                }
            }
        }
    }

    // ── поставить и выйти ──
    property bool confirming: false
    property int commitIndex: -1

    Timer {
        id: confirmTimer
        interval: 300
        repeat: false
        onTriggered: {
            var p = root.walls[root.commitIndex]
            Theme.wallpaperPath = p
            Theme.wallpaperMode = "image"
            Theme.applyPhotoPalette(p)
            // обои и палитра встают ПОД тёмной подложкой, потом оверлей гаснет —
            // так смена цвета не бьёт по глазам
            revealTimer.restart()
        }
    }

    // короткая пауза, чтобы кроссфейд обоев и палитра начали работу за ширмой
    Timer {
        id: revealTimer
        interval: 320
        repeat: false
        onTriggered: {
            root.confirming = false
            root.showing = false
        }
    }

    function commit(i) {
        if (i < 0 || i >= root.walls.length)
            return
        if (root.confirming)
            return
        // короткое подтверждение: выбранная карточка приподнимается и светлеет,
        // потом обои встают и оверлей уходит
        root.confirming = true
        root.commitIndex = i
        carousel.selectedIndex = i
        carousel.contentX = i * carousel.step
        confirmTimer.restart()
    }

    function moveSel(delta) {
        if (root.walls.length <= 0)
            return
        carousel.selectedIndex = Math.max(0,
            Math.min(carousel.selectedIndex + delta, root.walls.length - 1))
        carousel.contentX = carousel.selectedIndex * carousel.step
    }

    // клавиши ловлю на отдельном Item — он в фокусе всегда, даже на пустой полке
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_J || event.key === Qt.Key_L
                    || event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                root.moveSel(1)
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_H
                    || event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                root.moveSel(-1)
            } else if (event.key === Qt.Key_Tab) {
                carousel.selectedIndex = root.walls.length > 0
                    ? (carousel.selectedIndex + 1) % root.walls.length : 0
                carousel.contentX = carousel.selectedIndex * carousel.step
            } else if (event.key === Qt.Key_Backtab) {
                carousel.selectedIndex = root.walls.length > 0
                    ? ((carousel.selectedIndex - 1) % root.walls.length + root.walls.length) % root.walls.length : 0
                carousel.contentX = carousel.selectedIndex * carousel.step
            } else if (event.key === Qt.Key_D) {
                root.moveSel(root.visibleCount)
            } else if (event.key === Qt.Key_U) {
                root.moveSel(-root.visibleCount)
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter) {
                root.commit(carousel.selectedIndex)
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_W) {
                root.showing = false
            } else {
                return
            }
            event.accepted = true
        }
    }

    // затемнение фона: объём и фокус на карточках; клик мимо закрывает
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.fade * (root.confirming ? 0.62 : 0.42)
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }
        MouseArea {
            anchors.fill: parent
            onClicked: root.showing = false
        }
    }

    // ── пустая полка ──
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: root.walls.length === 0
        opacity: root.fade
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "обоев нет"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(22)
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "положи картинки в ~/Pictures или ~/Wallpapers\nи открой заново (SUPER + B)"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── веер обоев ──
    Flickable {
        id: carousel

        width: parent.width
        height: root.tileHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        visible: root.walls.length > 0
        clip: true
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        // вход: лента мягко проявляется (fade уже анимирован на root)
        opacity: root.fade
        scale: 0.97 + 0.03 * root.fade
        transformOrigin: Item.Center

        property int selectedIndex: 0
        property bool ready: false
        readonly property real tileWidth: Math.max(80, width / root.visibleCount - 10)
        readonly property real step: tileWidth
        readonly property real viewportCenterX: width / 2
        readonly property real sideMargin: Math.max(0, viewportCenterX - tileWidth / 2)
        contentWidth: strip.width + 2 * sideMargin

        // текущая обои: сперва точный путь, потом по имени файла (на случай
        // переезда каталога). Если не нашли — 0, а не середина списка
        // (середина читалась как «случайная»).
        function currentIndex() {
            var p = Theme.wallpaperPath
            if (p !== "") {
                var i = root.walls.indexOf(p)
                if (i >= 0)
                    return i
                var b = p.substring(p.lastIndexOf("/") + 1)
                for (var j = 0; j < root.walls.length; j++)
                    if (root.walls[j].substring(root.walls[j].lastIndexOf("/") + 1) === b)
                        return j
            }
            return 0
        }

        // открываюсь ровно на выбранной обои и сразу, без длинного глайда
        function centerOnStart() {
            if (root.walls.length <= 0 || width <= 0)
                return
            ready = false
            selectedIndex = Math.max(0, Math.min(currentIndex(), root.walls.length - 1))
            contentX = selectedIndex * step
            ready = true
        }

        onWidthChanged: centerOnStart()
        // после свободного флика мягко довожу ближайшую карточку в центр
        onMovementEnded: {
            if (root.walls.length <= 0)
                return
            selectedIndex = Math.max(0, Math.min(Math.round(contentX / step), root.walls.length - 1))
            contentX = selectedIndex * step
        }

        Behavior on contentX {
            // глайдом (SmoothedAnimation), но спокойно: 5000 px/s читалось как «рывок»
            enabled: carousel.ready
            SmoothedAnimation { velocity: 1600; duration: 650 }
        }

        Row {
            id: strip
            x: carousel.sideMargin
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: root.walls

                delegate: Item {
                    id: delegateItem
                    required property string modelData
                    required property int index

                    width: carousel.tileWidth
                    height: carousel.height
                    property bool active: index === carousel.selectedIndex

                    readonly property real baseCenterX: carousel.sideMargin + x - carousel.contentX + width / 2
                    readonly property real distance: Math.abs(baseCenterX - carousel.viewportCenterX)
                    readonly property real fraction: Math.min(1, distance / carousel.viewportCenterX)
                    readonly property real compression: {
                        const t = fraction
                        return t * t * t * t
                    }
                    readonly property real edgeOffset: {
                        const amount = root.edgeSpacing * compression
                        return baseCenterX < carousel.viewportCenterX ? amount : -amount
                    }
                    readonly property real scaleFactor: {
                        const t = 1 - fraction * fraction * (3 - 2 * fraction)
                        return root.edgeScale + (root.zoomScale - root.edgeScale) * t
                    }
                    // гружу только близкие к экрану и только пока оверлей открыт
                    readonly property bool near: root.showing
                        && baseCenterX > -600 && baseCenterX < carousel.width + 600
                    readonly property string base: modelData.substring(modelData.lastIndexOf("/") + 1)
                    readonly property string thumbUrl: root.thumbSet[base]
                        ? "file://" + root.thumbDir + "/" + base + ".jpg" : ""

                    Item {
                        id: content
                        anchors.verticalCenter: parent.verticalCenter
                        width: delegateItem.width
                        height: delegateItem.height
                        x: delegateItem.edgeOffset
                        scale: delegateItem.scaleFactor
                            * (root.confirming && delegateItem.index === root.commitIndex ? 1.07 : 1)
                        transformOrigin: Item.Center
                        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Theme.easeOut } }

                        // тень — запечённый PNG, 9-слайс: один квад, без MultiEffect
                        BorderImage {
                            source: Qt.resolvedUrl("assets/wall-shadow.png")
                            x: 8
                            y: 10
                            width: parent.width
                            height: parent.height
                            border { left: 44; top: 44; right: 44; bottom: 44 }
                            horizontalTileMode: BorderImage.Stretch
                            verticalTileMode: BorderImage.Stretch
                            visible: delegateItem.near
                            opacity: 0.55
                            smooth: true
                        }

                        Image {
                            id: img
                            anchors.fill: parent
                            opacity: 0.95
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            smooth: true
                            source: delegateItem.near
                                ? (delegateItem.thumbUrl !== "" ? delegateItem.thumbUrl : "file://" + modelData)
                                : ""
                            sourceSize.width: Math.round(delegateItem.width * root.zoomScale)
                            sourceSize.height: Math.round(delegateItem.height * root.zoomScale)
                        }

                        Rectangle {
                            z: 10
                            anchors.fill: parent
                            visible: delegateItem.active || (root.confirming && delegateItem.index === root.commitIndex)
                            color: "transparent"
                            border.width: 2
                            border.color: (root.confirming && delegateItem.index === root.commitIndex)
                                ? Theme.accent : Theme.activeBorder
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        // выбор наведением — только после реального движения мыши,
                        // иначе при открытии курсор перебивает выбранную обои
                        onPositionChanged: root.hoverArmed = true
                        onEntered: if (root.hoverArmed) carousel.selectedIndex = index
                        onClicked: root.commit(index)
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y === 0)
                                return
                            // спокойно: один шаг за щелчок (раньше было слишком быстро)
                            root.moveSel(wheel.angleDelta.y > 0 ? -1 : 1)
                            wheel.accepted = true
                        }
                    }
                }
            }
        }
    }

    // ── подсказка, «файл» и возврат на «сцену» ──
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space5
        text: "колесо — листать · наведение — выбор · клик / Space — поставить · Esc — выйти"
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        opacity: root.fade
    }

    SectionHeader {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space5
        text: "СЦЕНА"
        textColor: Theme.textDim
        size: Theme.fontSmall
        bold: false
        opacity: root.fade
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.space2
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Theme.wallpaperMode = "scene"
                root.showing = false
            }
        }
    }

    SectionHeader {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space5
        text: "ФАЙЛ…"
        textColor: Theme.textDim
        size: Theme.fontSmall
        bold: false
        opacity: root.fade
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.space2
            cursorShape: Qt.PointingHandCursor
            onClicked: pickProc.running = true
        }
    }
}
