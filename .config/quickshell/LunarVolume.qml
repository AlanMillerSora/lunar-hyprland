import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// ════════════════════════════════════════════════════════════════
//  LunarVolume — попап громкости (клик по значку на панели):
//  крупный ползунок, выбор вывода (колонки/наушники/HDMI) и входа
//  (микрофон). IPC: qs ipc call volume toggle|open|close
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    // попап открывается кликом — забираем клавиатуру, чтобы сразу работал Esc
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? backdrop : null
    }

    property bool showing: false

    function openPanel() { showing = true; Theme.volumePopupOpen = true }
    function closePanel() { showing = false; Theme.volumePopupOpen = false }
    function toggle() { showing ? closePanel() : openPanel() }
    // окно может быть пересоздано (reload) — снимаем флаг, иначе OSD навсегда
    // перестанет показываться
    Component.onDestruction: Theme.volumePopupOpen = false

    IpcHandler {
        target: "volume"
        function toggle(): void { root.toggle() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false
    readonly property bool hasSink: !!(sink && sink.audio)

    function setVol(v) {
        if (sink && sink.audio) {
            sink.audio.muted = false
            sink.audio.volume = Math.max(0, Math.min(1, v))
        }
    }

    function toggleMute() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted
    }

    // ── устройства вывода / входа (без потоков и мониторов) ──
    // Кэшируем отфильтрованные списки: граф меняется часто, а новый массив
    // в Repeater пересоздаёт все строки — обновляем только при смене состава.
    property var sinks: []
    property var sources: []

    function sameDevices(a, b) {
        if (a.length !== b.length)
            return false
        for (var i = 0; i < a.length; i++)
            if (a[i] !== b[i])
                return false
        return true
    }

    function refreshDevices() {
        var ns = Pipewire.nodes.values
        var out = [], inp = []
        for (var i = 0; i < ns.length; i++) {
            var n = ns[i]
            if (!n.audio)
                continue
            if (n.isSink && !n.isStream)
                out.push(n)
            else if (!n.isSink && !n.isStream
                    && ("" + n.name).indexOf(".monitor") < 0)
                inp.push(n)
        }
        if (!sameDevices(out, root.sinks))
            root.sinks = out
        if (!sameDevices(inp, root.sources))
            root.sources = inp
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.refreshDevices() }
    }
    Component.onCompleted: root.refreshDevices()

    function devName(n) {
        return (n && (n.description || n.nickname || n.name)) || ""
    }

    function devIcon(n) {
        if (root.sources.indexOf(n) >= 0)
            return "\uf130"                                    // микрофон
        var s = devName(n).toLowerCase()
        if (s.indexOf("head") >= 0 || s.indexOf("науш") >= 0)
            return "\uf025"                                    // наушники
        if (s.indexOf("bluetooth") >= 0)
            return "\uf293"                                    // bluetooth
        if (s.indexOf("hdmi") >= 0 || s.indexOf("digital") >= 0
                || s.indexOf("display") >= 0 || s.indexOf("spdif") >= 0)
            return "\uf108"                                    // монитор/HDMI
        return "\uf028"                                        // динамики
    }

    Process { id: mixerProc; running: false }
    function openMixer() {
        // pavucontrol может отсутствовать — проверяем перед запуском
        mixerProc.command = ["bash", "-c",
            "command -v pavucontrol >/dev/null 2>&1 && setsid pavucontrol >/dev/null 2>&1 &"]
        mixerProc.running = true
        closePanel()
    }

    // клик мимо попапа — закрыть
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

    // строка устройства: иконка + имя, клик — выбрать
    component DeviceRow: Item {
        id: row
        property var device
        property bool active: false
        signal picked()
        implicitHeight: 22

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusM
            color: row.active
                ? Theme.active
                : (rowMouse.containsMouse ? Theme.hover : "transparent")
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: Theme.space2

            Text {
                text: root.devIcon(row.device)
                color: row.active ? Theme.accent : Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: 14
            }
            Text {
                Layout.fillWidth: true
                text: root.devName(row.device)
                color: row.active ? Theme.text : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideMiddle
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
        }
    }

    Rectangle {
        id: card
        width: 360
        height: col.implicitHeight + Theme.space6
        anchors.top: parent.top
        anchors.topMargin: 52
        anchors.right: parent.right
        anchors.rightMargin: 12
        radius: Theme.radiusL
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

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.space4
            spacing: Theme.space3

            // ── шапка: mute · процент · микшер · закрыть ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                Text {
                    text: root.muted
                        ? "󰖁"
                        : (root.vol < 0.34 ? "󰕿" : (root.vol < 0.67 ? "󰖀" : "󰕾"))
                    color: root.muted ? Theme.textFaint : Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: 18

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }

                Text {
                    text: root.muted ? "MUTE" : Math.round(root.vol * 100) + "%"
                    color: root.muted ? Theme.textDim : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "микшер"
                    color: mixerMouse.containsMouse ? Theme.accent : Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9

                    MouseArea {
                        id: mixerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openMixer()
                    }
                }

                Text {
                    text: "\uf00d"
                    color: closeMouse.containsMouse ? Theme.danger : Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: 11

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePanel()
                    }
                }
            }

            // ── крупный ползунок ──
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 66
                visible: root.hasSink
                trackHeight: 12
                handleSize: 24
                value: root.muted ? 0 : root.vol
                onMoved: (v) => root.setVol(v)
                onCommitted: (v) => root.setVol(v)
            }

            // ── нет аудиоустройств ──
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 66
                visible: !root.hasSink
                text: "нет аудиоустройств"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            // ── вывод звука (список, если есть из чего выбирать) ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space1
                visible: root.sinks.length > 1

                Text {
                    text: "ВЫВОД"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Repeater {
                    model: root.sinks

                    delegate: DeviceRow {
                        required property var modelData
                        Layout.fillWidth: true
                        device: modelData
                        active: modelData === Pipewire.defaultAudioSink
                        onPicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            // ── вход: микрофон ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space1
                visible: root.sources.length > 1

                Text {
                    text: "ВХОД"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Repeater {
                    model: root.sources

                    delegate: DeviceRow {
                        required property var modelData
                        Layout.fillWidth: true
                        device: modelData
                        active: modelData === Pipewire.defaultAudioSource
                        onPicked: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "колесо по значку на панели — быстрый шаг"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }
        }
    }
}
