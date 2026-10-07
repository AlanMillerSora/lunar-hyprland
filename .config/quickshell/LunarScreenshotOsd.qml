import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarScreenshotOsd — подтверждение скриншота: превью + «сохранён/
//  скопирован». Срабатывает после хоткеев PRINT в hyprland.lua через
//  `qs ipc call screenshot notify <файл> <режим>`. Вид — по мотивам
//  ScreenshotOsd у 43PR (мягкая карточка, крупное превью), но в наших
//  токенах и с HUD-скобками. Живёт на верхнем слое, ввод не ловит.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true }
    implicitHeight: 150
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // кликабелен/рисуется только когда виден — иначе перехватывает клики сверху
    mask: Region {
        item: root.showing ? flyout : null
    }

    property bool showing: false

    // не держу поверхность замапленной, когда OSD скрыт
    property bool _mapped: showing
    visible: _mapped
    Timer {
        id: unmapTimer
        interval: Theme.animSlow + 60
        onTriggered: root._mapped = false
    }
    onShowingChanged: {
        if (showing) { unmapTimer.stop(); _mapped = true }
        else unmapTimer.restart()
    }

    property string imagePath: ""
    // "saved" — в файл, "copied" — в буфер обмена
    property string mode: "saved"

    function showOsd(path, m) {
        root.imagePath = path
        root.mode = m || "saved"
        root.showing = true
        hideTimer.restart()
    }

    // единственная точка входа: хоткеи скриншотов зовут этот target
    IpcHandler {
        target: "screenshot"
        function notify(path: string, mode: string): void {
            root.showOsd(path, mode)
        }
    }

    Timer {
        id: hideTimer
        interval: 2400
        onTriggered: root.showing = false
    }

    readonly property bool copied: root.mode === "copied"
    readonly property string title: root.copied ? "Скопировано в буфер" : "Скриншот сохранён"
    readonly property string fileName: root.imagePath.split("/").pop()
    readonly property string hint: root.copied
        ? "PNG в буфере обмена"
        : "PNG в ~/Pictures/Screenshots"

    Rectangle {
        id: flyout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 54
        width: 360
        height: 78
        radius: Theme.radiusL
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.94

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOut }
        }

        // мелкий попап — только скобки по углам (как в громкости)
        HudCorners { color: Theme.accent; size: 16; thickness: 1; margin: Theme.space3 }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.space4
            spacing: Theme.space3

            // превью снимка: крупная мягкая плитка, картинка обрезана по рамке
            Rectangle {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                radius: Theme.radius
                color: Theme.alpha(Theme.text, 0.06)
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.imagePath ? "file://" + root.imagePath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                // запасной глиф, если файла нет (например, только буфер)
                Text {
                    anchors.centerIn: parent
                    visible: !root.imagePath
                    text: "󰄀"
                    color: Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(20)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    visible: !root.copied && root.fileName !== ""
                    text: root.fileName
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    elide: Text.ElideMiddle
                }
                Text {
                    Layout.fillWidth: true
                    text: root.hint
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(9)
                }
            }
        }
    }
}
