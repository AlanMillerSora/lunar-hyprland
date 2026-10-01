import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarWallpapers — подбор обоев.
//
//  Два режима: «СЦЕНА · ФАЗЫ» (живая сцена затмения, фаза по столу)
//  и «КАРТИНКИ» (полка картинок с диска, клик — поставить).
//  Открывается по SUPER + B или `qs ipc call wallpapers toggle`.
//  Цвета можно взять прямо с картинки — генератор посчитает палитру
//  (кнопка «ЦВЕТ ОТ ОБОЕВ», eclipse-palette.py --from-image).
// ════════════════════════════════════════════════════════════════
FloatingWindow {
    id: root

    title: "Lunar Wallpapers"
    color: Theme.bgPanel
    visible: root.showing
    implicitWidth: 1180
    implicitHeight: 720
    minimumSize: Qt.size(760, 460)

    property bool showing: false
    property var walls: []

    // фаза для превью — как на рабочем столе (по активному столу)
    readonly property var ws: Hyprland.activeWorkspace || Hyprland.focusedWorkspace
    readonly property int wsId: (ws && ws.id > 0) ? ws.id : 5

    IpcHandler {
        target: "wallpapers"
        function toggle(): void { root.showing = !root.showing }
        function open(): void { root.showing = true }
        function close(): void { root.showing = false }
    }

    // при открытии перечитываю полку — картинки могли добавить
    onShowingChanged: if (showing) {
        wallScan.running = true
        content.focus = true
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
            onStreamFinished: root.walls = text.trim().split("\n").filter(function(x) { return x.length > 0 })
        }
    }

    // ── выбрать любой файл ──
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

    // ── цвет от обоев ──
    Process {
        id: photoProc
        running: false
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

    // ── кнопка-чип ──
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool on: false
        signal clicked()

        width: chipLabel.implicitWidth + 28
        height: Theme.rowHCompact
        radius: Theme.radiusM
        color: chip.on ? Theme.active : (chipMouse.containsMouse ? Theme.hoverStrong : Theme.fill)
        border.width: chip.on ? 1 : 0
        border.color: Theme.accent

        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.label
            color: chip.on ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.bold: chip.on
            font.letterSpacing: 2
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.space6
        focus: true

        // Esc закрывает подбор
        Keys.onEscapePressed: root.showing = false

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.space4

            // ── шапка ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3

                Text {
                    text: "ОБОИ"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    font.letterSpacing: 3
                    Layout.alignment: Qt.AlignVCenter
                }

                Chip {
                    label: "СЦЕНА · ФАЗЫ"
                    on: Theme.wallpaperMode !== "image"
                    onClicked: Theme.wallpaperMode = "scene"
                    Layout.alignment: Qt.AlignVCenter
                }

                Chip {
                    label: "КАРТИНКИ"
                    on: Theme.wallpaperMode === "image"
                    onClicked: Theme.wallpaperMode = "image"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Chip {
                    visible: Theme.wallpaperMode === "image"
                    label: "ВЫБРАТЬ ФАЙЛ…"
                    onClicked: pickProc.running = true
                    Layout.alignment: Qt.AlignVCenter
                }

                Chip {
                    visible: Theme.wallpaperMode === "image" && Theme.wallpaperPath !== ""
                    label: "ЦВЕТ ОТ ОБОЕВ"
                    onClicked: root.applyPhotoColor()
                    Layout.alignment: Qt.AlignVCenter
                }

                Chip {
                    label: "ГОТОВО"
                    onClicked: root.showing = false
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // ── тело: сцена ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.space4
                visible: Theme.wallpaperMode !== "image"

                Item {
                    Layout.preferredWidth: Math.min(parent.width, 640)
                    Layout.preferredHeight: Layout.preferredWidth * 9 / 16
                    clip: true

                    LunarWallpaperScene {
                        anchors.fill: parent
                        phase: Math.max(1, Math.min(9, root.wsId))
                        live: root.showing
                        optimize: true
                        tickMs: 40
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

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "фаза = номер рабочего стола — превью показывает текущий стол"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }

                    Chip {
                        label: Theme.wallpaperLive ? "ЖИВЫЕ ОБОИ" : "ЛЁГКИЙ РЕЖИМ"
                        on: Theme.wallpaperLive
                        onClicked: Theme.wallpaperLive = !Theme.wallpaperLive
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ── тело: картинки ──
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Theme.wallpaperMode === "image"

                Text {
                    id: shelfHint
                    text: root.walls.length > 0
                        ? "полка · " + root.walls.length + " картинок · клик — поставить"
                        : "картинок в ~/Pictures и ~/Wallpapers нет — добавь их туда или нажми «ВЫБРАТЬ ФАЙЛ…»"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }

                Flickable {
                    id: shelfFlick
                    anchors.top: shelfHint.bottom
                    anchors.topMargin: Theme.space3
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true
                    contentWidth: width
                    contentHeight: shelf.height
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        onWheel: function(event) {
                            if (event.angleDelta.y === 0) return
                            shelfFlick.contentY = Math.max(0, Math.min(
                                shelfFlick.contentHeight - shelfFlick.height,
                                shelfFlick.contentY - event.angleDelta.y))
                            event.accepted = true
                        }
                    }

                    Flow {
                        id: shelf
                        width: parent.width
                        spacing: Theme.space3

                        Repeater {
                            model: root.walls

                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool cur: Theme.wallpaperMode === "image" && Theme.wallpaperPath === modelData

                                width: 208
                                height: 117
                                radius: Theme.radiusM
                                color: Theme.fill
                                border.width: cur ? 1 : 0
                                border.color: Theme.accent
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + modelData
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    sourceSize: Qt.size(416, 234)
                                }

                                // затемнение + подпись внизу
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 22
                                    color: Qt.rgba(0, 0, 0, cellMouse.containsMouse ? 0.72 : 0.5)

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideMiddle
                                        text: modelData.substring(modelData.lastIndexOf("/") + 1)
                                        color: cur ? Theme.accent : Theme.barText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontTiny
                                    }
                                }

                                Rectangle {
                                    visible: cur
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: markText.implicitWidth + 12
                                    height: 18
                                    radius: Theme.radius
                                    color: Theme.accent

                                    Text {
                                        id: markText
                                        anchors.centerIn: parent
                                        text: "СЕЙЧАС"
                                        color: Theme.bgPanel
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }
                                }

                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Theme.wallpaperPath = modelData
                                        Theme.wallpaperMode = "image"
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
