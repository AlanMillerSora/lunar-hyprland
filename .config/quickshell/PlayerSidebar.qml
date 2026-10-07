import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// ════════════════════════════════════════════════════════════════
//  PlayerSidebar — правая колонка плеера: «сейчас играет» (монохромная
//  обложка, название/артист, длительность), компактный cava-спектр и
//  «NEXT IN QUEUE». cava держу только когда окно активно и играет.
// ════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool active: false

    readonly property bool hasArt: PlayerCore.artUrl.length > 0 && cover.status !== Image.Error

    readonly property int barCount: 64
    property var barValues: []

    // «далее в очереди»: 5 позиций после текущей
    readonly property var nextItems: {
        var q = PlayerCore.queue || []
        var i = PlayerCore.queueIndex
        var start = i >= 0 ? i + 1 : 0
        var out = []
        for (var k = 0; k < 6 && start + k < q.length; k++) {
            var it = q[start + k]
            out.push({
                title: it && it.title ? it.title : (it && it.filename ? it.filename : "трек"),
                dur: it && it.duration > 0 ? PlayerCore.fmt(it.duration) : ""
            })
        }
        return out
    }

    // «быстрый подъём / плавный спад» — как в баре плеера
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
            out.push(raw > p ? p + (raw - p) * 0.55 : p * 0.80 + raw * 0.20)
        }
        root.barValues = out
    }

    Process {
        id: cavaProc
        running: root.active && PlayerCore.playing
        command: ["cava", "-p", Quickshell.shellPath("cava-player.conf")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.feedCava(line)
        }
        stderr: StdioCollector {}
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── обложка ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 168

            Item {
                id: coverBox
                width: Math.min(168, parent.height)
                height: width
                anchors.centerIn: parent

                Image {
                    id: cover
                    anchors.fill: parent
                    source: PlayerCore.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: cover
                    visible: root.hasArt
                    saturation: -1.0
                    brightness: 0.04
                    colorization: 0.28
                    colorizationColor: Theme.accent
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    visible: !root.hasArt
                    color: Theme.bgCard
                    border.color: Theme.border
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "󰎇"
                        color: Theme.textFaint
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSize(40)
                    }
                }
            }
        }

        // ── название / артист / длительность ──
        Text {
            Layout.fillWidth: true
            text: PlayerCore.hasMedia
                ? (PlayerCore.title.length > 0 ? PlayerCore.title : "без названия")
                : "ничего не играет"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(15)
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            visible: PlayerCore.artist.length > 0
            text: PlayerCore.artist
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(11)
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            Layout.fillWidth: true
            visible: PlayerCore.error !== ""
            text: PlayerCore.error
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(10)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }

        // ── спектр cava (полосы) ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            visible: PlayerCore.hasMedia

            Row {
                anchors.fill: parent
                spacing: 2

                Repeater {
                    model: root.barCount

                    delegate: Item {
                        id: barItem
                        required property int index
                        readonly property real v: root.barValues[index] || 0
                        width: Math.max(1, (parent.width - (root.barCount - 1) * 2) / root.barCount)
                        height: parent.height

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2 + barItem.v * (barItem.height - 6)
                            radius: Theme.radiusDot
                            color: Theme.alpha(Theme.accent, 0.30 + 0.70 * barItem.v)
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // ── далее в очереди ──
        Text {
            Layout.fillWidth: true
            text: "NEXT IN QUEUE"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize(10)
            font.letterSpacing: 2
            font.bold: true
        }

        Column {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.nextItems

                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "▸"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        width: parent.width - 70
                        text: modelData.title
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.dur
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(9)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
