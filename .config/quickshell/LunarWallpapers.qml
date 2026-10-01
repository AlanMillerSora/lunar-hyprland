import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// ════════════════════════════════════════════════════════════════
//  LunarWallpapers — переключатель обоев «как у 43PR».
//
//  Полноэкранный прозрачный оверлей (слой Overlay), во всю ширину идёт
//  веер обоев: центр крупный, края мельче и разъезжаются в стороны.
//  Колесо/драг листают ленту, наведение ставит выбор, клик или Space —
//  поставить обои и выйти, Esc/клик мимо — просто выйти. Цвета с картинки
//  считает генератор (Theme.applyPhotoPalette), если включён авто-режим.
//
//  Открывается по SUPER + B или `qs ipc call wallpapers toggle`.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    // окно видно только когда просили
    property bool showing: false

    // ── лента ──
    property var walls: []
    // сколько плиток видно по ширине (у 43PR — 10; на 21:9 беру 9)
    property int visibleCount: 9
    // веер: центр — zoomScale, края — edgeScale, края разъезжаются на edgeSpacing
    property real zoomScale: 0.8
    property real edgeScale: 0.3
    property real edgeSpacing: 80
    property bool shadowEnabled: true
    property int tileHeight: 520

    visible: root.showing
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // отдельное имя: иначе layer_rule Hyprland может навесить блюр на весь слой
    WlrLayershell.namespace: "lunar-wallpapers"

    IpcHandler {
        target: "wallpapers"
        function toggle(): void { root.showing = !root.showing }
        function open(): void { root.showing = true }
        function close(): void { root.showing = false }
        function next(): void { root.moveSel(1) }
        function prev(): void { root.moveSel(-1) }
        function apply(): void { root.commit(list.selectedIndex) }
    }

    // при открытии перечитываю полку — картинки могли добавить
    onShowingChanged: if (showing) {
        wallScan.running = true
        list.forceActiveFocus()
    }

    // ── полка: картинки из ~/Pictures, ~/Wallpapers, ~/Pictures/Wallpapers ──
    Process {
        id: wallScan
        running: true
        command: ["bash", "-c",
            "find \"$HOME/Pictures\" \"$HOME/Wallpapers\" \"$HOME/Pictures/Wallpapers\" " +
            "-maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "2>/dev/null | sort | head -60"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.walls = text.trim().split("\n").filter(function(x) { return x.length > 0 })
                // лента пересобирается по новой модели — центрирую выбранное
                Qt.callLater(list.centerOnStart)
            }
        }
    }

    // ── поставить и выйти ──
    function commit(i) {
        if (i < 0 || i >= root.walls.length)
            return
        var path = root.walls[i]
        Theme.wallpaperPath = path
        Theme.wallpaperMode = "image"
        Theme.applyPhotoPalette(path)
        root.showing = false
    }

    // сдвиг выбора и доводка ленты (клавиши/IPC)
    function moveSel(delta) {
        if (list.count <= 0)
            return
        list.selectedIndex = Math.max(0, Math.min(list.selectedIndex + delta, list.count - 1))
        list.contentX = list.selectedIndex * list.step
    }

    // клик мимо ленты просто закрывает
    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.showing = false
    }

    // ── пустая полка ──
    Column {
        anchors.centerIn: parent
        spacing: 10
        z: 2
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
    ListView {
        id: list

        width: parent.width
        height: root.tileHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        z: 1
        focus: true
        visible: root.walls.length > 0

        model: root.walls
        orientation: ListView.Horizontal
        spacing: 0
        clip: true
        cacheBuffer: 800
        boundsBehavior: Flickable.StopAtBounds

        property int selectedIndex: 0
        property bool ready: false
        property bool userMoved: false
        readonly property real tileWidth: width / root.visibleCount - 10
        readonly property real viewportCenterX: width / 2
        readonly property real step: tileWidth
        readonly property real sideMargin: Math.max(0, viewportCenterX - tileWidth / 2)

        leftMargin: sideMargin
        rightMargin: sideMargin

        // выбранное — по центру; запускаю после пересборки модели/ширины
        function centerOnStart() {
            if (count <= 0 || width <= 0)
                return
            selectedIndex = Math.max(0, Math.min(selectedIndex, count - 1))
            contentX = selectedIndex * step
            ready = true
        }

        onCountChanged: centerOnStart()
        onWidthChanged: centerOnStart()

        Behavior on contentX {
            enabled: list.ready
            SmoothedAnimation { duration: 500 }
        }

        // ── клавиши: как у 43PR ──
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_J || event.key === Qt.Key_L
                    || event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                root.moveSel(1)
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_H
                    || event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                root.moveSel(-1)
            } else if (event.key === Qt.Key_Tab) {
                list.selectedIndex = list.count > 0 ? (list.selectedIndex + 1) % list.count : 0
                list.contentX = list.selectedIndex * list.step
            } else if (event.key === Qt.Key_Backtab) {
                list.selectedIndex = list.count > 0
                    ? ((list.selectedIndex - 1) % list.count + list.count) % list.count : 0
                list.contentX = list.selectedIndex * list.step
            } else if (event.key === Qt.Key_D) {
                root.moveSel(root.visibleCount)
            } else if (event.key === Qt.Key_U) {
                root.moveSel(-root.visibleCount)
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter) {
                root.commit(list.selectedIndex)
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_W) {
                root.showing = false
            } else {
                return
            }
            event.accepted = true
        }

        delegate: Item {
            id: delegateItem
            width: list.tileWidth
            height: list.height

            property bool active: index === list.selectedIndex
            // доля удаления от центра экрана: у центра 0, у края 1
            readonly property real baseCenterX: x - list.contentX + width / 2
            readonly property real distance: Math.abs(baseCenterX - list.viewportCenterX)
            readonly property real fraction: Math.min(1, distance / list.viewportCenterX)
            readonly property real compression: {
                const t = fraction
                return t * t * t * t
            }
            // края «разъезжаются» в стороны — веер становится шире
            readonly property real edgeOffset: {
                const amount = root.edgeSpacing * compression
                return baseCenterX < list.viewportCenterX ? amount : -amount
            }
            // плавный зум: у центра zoomScale, у края edgeScale
            readonly property real scaleFactor: {
                const t = 1 - fraction * fraction * (3 - 2 * fraction)
                return root.edgeScale + (root.zoomScale - root.edgeScale) * t
            }

            Item {
                id: content
                anchors.verticalCenter: parent.verticalCenter
                width: delegateItem.width * delegateItem.scaleFactor
                height: delegateItem.height * Math.min(1, delegateItem.scaleFactor)
                x: (delegateItem.width - width) / 2 + delegateItem.edgeOffset

                // тень — как у 43PR: смещённая копия картинки, затемнённая и размытая
                Image {
                    id: shadowImage
                    x: 6
                    y: 6
                    width: parent.width
                    height: parent.height
                    source: img.source
                    sourceSize.width: img.sourceSize.width
                    sourceSize.height: img.sourceSize.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    visible: root.shadowEnabled
                    opacity: 0.4
                    layer.enabled: true
                    layer.effect: MultiEffect { brightness: -1; blurEnabled: true; blur: 0.45 }
                }

                Image {
                    id: img
                    anchors.fill: parent
                    opacity: 0.95
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    source: "file://" + modelData
                    sourceSize.width: delegateItem.width * root.zoomScale
                    sourceSize.height: delegateItem.height
                }

                Rectangle {
                    z: 10
                    anchors.fill: parent
                    visible: delegateItem.active
                    color: "transparent"
                    radius: Theme.radiusM
                    border.width: 2
                    border.color: Theme.accent
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: list.ready
                onEntered: {
                    list.userMoved = true
                    list.selectedIndex = index
                }
                onClicked: root.commit(index)
                onWheel: function(wheel) {
                    list.flick(-wheel.angleDelta.y * 8, 0)
                    wheel.accepted = true
                }
            }
        }
    }

    // ── подсказка и возврат на «сцену» ──
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space5
        z: 2
        text: "колесо — листать · наведение — выбор · клик / Space — поставить · Esc — выйти"
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space5
        z: 2
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
}
