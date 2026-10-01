import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

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
    property var walls: []
    property bool scanned: false
    // имя файла -> 1 (какие миниатюры уже готовы)
    property var thumbSet: ({})
    property string thumbDir: Quickshell.env("HOME") + "/.cache/lunar/wall-thumbs"

    // ── веер ──
    property int visibleCount: 10
    property real zoomScale: 0.8
    property real edgeScale: 0.3
    property real edgeSpacing: 80
    property int tileHeight: 900

    visible: root.showing
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
    onShowingChanged: if (showing) {
        if (!root.scanned)
            wallScan.running = true
        keyCatcher.forceActiveFocus()
        Qt.callLater(carousel.centerOnStart)
    }

    // ── полка: картинки из ~/Pictures, ~/Wallpapers, ~/Pictures/Wallpapers ──
    Process {
        id: wallScan
        running: true
        command: ["bash", "-c",
            "find \"$HOME/Pictures\" \"$HOME/Wallpapers\" \"$HOME/Pictures/Wallpapers\" " +
            "-maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "2>/dev/null | sort -u | head -80"]
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
                    root.showing = false
                }
            }
        }
    }

    // ── поставить и выйти ──
    function commit(i) {
        if (i < 0 || i >= root.walls.length)
            return
        var p = root.walls[i]
        Theme.wallpaperPath = p
        Theme.wallpaperMode = "image"
        Theme.applyPhotoPalette(p)
        root.showing = false
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

    // клик мимо ленты закрывает
    MouseArea {
        anchors.fill: parent
        onClicked: root.showing = false
    }

    // ── пустая полка ──
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: root.walls.length === 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "обоев нет"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 22
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

        property int selectedIndex: 0
        property bool ready: false
        readonly property real tileWidth: Math.max(80, width / root.visibleCount - 10)
        readonly property real step: tileWidth
        readonly property real viewportCenterX: width / 2
        readonly property real sideMargin: Math.max(0, viewportCenterX - tileWidth / 2)
        contentWidth: strip.width + 2 * sideMargin

        function currentIndex() {
            var i = root.walls.indexOf(Theme.wallpaperPath)
            return i >= 0 ? i : Math.floor(root.walls.length / 2)
        }

        function centerOnStart() {
            if (root.walls.length <= 0 || width <= 0)
                return
            selectedIndex = Math.max(0, Math.min(currentIndex(), root.walls.length - 1))
            contentX = selectedIndex * step
            ready = true
        }

        onWidthChanged: centerOnStart()
        // после свободного флика прилипаю выбором к ближайшей к центру карточке
        onMovementEnded: {
            if (root.walls.length <= 0)
                return
            selectedIndex = Math.max(0, Math.min(Math.round(contentX / step), root.walls.length - 1))
        }

        Behavior on contentX {
            enabled: carousel.ready
            SmoothedAnimation { duration: 700 }
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
                        transformOrigin: Item.Center

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
                            visible: delegateItem.active
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.alpha(Theme.accent, 0.6)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: carousel.selectedIndex = index
                        onClicked: root.commit(index)
                        onWheel: function(wheel) {
                            carousel.flick(-wheel.angleDelta.y * 8, 0)
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
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space5
        text: "СЦЕНА"
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        font.letterSpacing: 2
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

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space5
        text: "ФАЙЛ…"
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        font.letterSpacing: 2
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.space2
            cursorShape: Qt.PointingHandCursor
            onClicked: pickProc.running = true
        }
    }
}
