import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import ".."
import "../widgets/shared"

// ════════════════════════════════════════════════════════════════
//  PanelAudio — пузырь звука в баре: вывод и вход (микрофон).
//  В каждом разделе — выбор устройства чипами, mute и ползунок.
//  Источник — PipeWire напрямую; смена устройства идёт через
//  Pipewire.preferredDefaultAudioSink/Source (как в Hub → Звук).
// ════════════════════════════════════════════════════════════════
Item {
    id: root
    property var host

    readonly property string icSpeaker: "󰕾"
    readonly property string icLow: "󰕿"
    readonly property string icMic: "󰍬"
    readonly property string icMute: "󰖁"

    PwObjectTracker { objects: Pipewire.nodes.values }

    property var sink: Pipewire.defaultAudioSink
    property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    property var source: Pipewire.defaultAudioSource
    property real micVolume: (source && source.audio) ? source.audio.volume : 0
    property bool micMuted: (source && source.audio) ? source.audio.muted : false
    readonly property bool micAvailable: !!(source && source.audio)

    property var outputSinks: []
    property var inputSources: []

    // набор id — чтобы делегаты чипов не пересобирались на каждый замер
    function nodeIdList(list) {
        var s = ""
        for (var i = 0; i < list.length; i++)
            s += list[i].id + ","
        return s
    }
    function recomputeAudioLists() {
        var sinks = []
        var sources = []
        var all = Pipewire.nodes.values
        for (var i = 0; i < all.length; i++) {
            var n = all[i]
            if (n.isSink && !n.isStream && n.audio)
                sinks.push(n)
            else if (!n.isSink && !n.isStream && n.audio
                     && ("" + n.name).indexOf(".monitor") < 0)
                sources.push(n)
        }
        if (nodeIdList(root.outputSinks) !== nodeIdList(sinks))
            root.outputSinks = sinks
        if (nodeIdList(root.inputSources) !== nodeIdList(sources))
            root.inputSources = sources
    }
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.recomputeAudioLists() }
    }
    Component.onCompleted: recomputeAudioLists()

    function devName(n) {
        return (n && (n.description || n.nickname || n.name)) || "Unknown"
    }
    function setVol(v) {
        if (sink && sink.audio) {
            sink.audio.muted = false
            sink.audio.volume = Math.max(0, Math.min(1, v))
        }
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted }
    function setMicVol(v) {
        if (source && source.audio) {
            source.audio.muted = false
            source.audio.volume = Math.max(0, Math.min(1, v))
        }
    }
    function toggleMicMute() { if (source && source.audio) source.audio.muted = !source.audio.muted }

    // ── чип устройства ──
    component Chip: Rectangle {
        id: ch
        property var device
        property bool active: false
        signal picked()

        // не шире ряда: длинные названия усекаю многоточием
        readonly property int maxW: (parent && parent.width > 0) ? parent.width : 260
        width: Math.min(chText.implicitWidth + 20, maxW)
        height: 24
        radius: Theme.radiusS
        color: ch.active ? Theme.active
             : (chMouse.containsMouse ? Theme.hover : Theme.fill)
        border.width: 1
        border.color: ch.active ? Theme.activeBorder : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            id: chText
            anchors.centerIn: parent
            width: parent.width - 16
            text: root.devName(ch.device).toUpperCase()
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: ch.active ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTiny
            font.letterSpacing: 1
        }
        MouseArea {
            id: chMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ch.picked()
        }
    }

    // ── раздел: подпись + mute/% справа, ползунок, чипы устройств ──
    component Section: Column {
        id: sec
        property string title: ""
        property string icon: root.icSpeaker
        property bool isMuted: false
        property real level: 0
        property bool available: true
        property var devices: []
        property var current: null
        property bool isInput: false
        signal toggled()
        signal moved(real value)

        width: parent ? parent.width : implicitWidth
        spacing: Theme.space1

        Item {
            width: parent.width
            height: 18

            SectionHeader {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: sec.title
                textColor: Theme.textDim
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sec.isMuted ? root.icMute : sec.icon
                    color: sec.isMuted ? Theme.danger : Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(15)
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sec.toggled()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sec.isMuted ? "mute" : Math.round(sec.level * 100) + "%"
                    color: sec.isMuted ? Theme.textFaint : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }
            }
        }

        Slider {
            width: parent.width
            height: 18
            compact: true
            trackHeight: 5
            handleSize: 13
            enabled: sec.available
            value: sec.isMuted ? 0 : sec.level
            onMoved: (v) => sec.moved(v)
            onCommitted: (v) => sec.moved(v)
            WheelHandler {
                onWheel: (ev) => sec.moved(sec.level + (ev.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }

        Flow {
            width: parent.width
            spacing: Theme.space1
            Repeater {
                model: sec.devices
                delegate: Chip {
                    required property var modelData
                    device: modelData
                    active: sec.current && sec.current.id === modelData.id
                    onPicked: {
                        if (sec.isInput)
                            Pipewire.preferredDefaultAudioSource = modelData
                        else
                            Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }
        }

        Text {
            visible: sec.devices.length === 0
            text: "НЕТ УСТРОЙСТВА"
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTiny
        }
    }

    visible: BarState.mode === "audio"
    opacity: host.panelContentOpacity
    anchors.top: parent.top
    anchors.topMargin: Theme.panelHeaderH + Theme.space1
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width - Theme.barPad * 2
    implicitHeight: col.height

    Column {
        id: col
        width: parent.width
        spacing: Theme.space3

        // ── ВЫВОД ──
        Section {
            title: "ВЫВОД"
            icon: root.volume < 0.34 ? root.icLow : root.icSpeaker
            isMuted: root.muted
            level: root.volume
            available: !!(root.sink && root.sink.audio)
            devices: root.outputSinks
            current: root.sink
            onToggled: root.toggleMute()
            onMoved: (v) => root.setVol(v)
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // ── ВХОД (микрофон) ──
        Section {
            title: "ВХОД"
            icon: root.icMic
            isMuted: root.micMuted
            level: root.micVolume
            available: root.micAvailable
            devices: root.inputSources
            current: root.source
            isInput: true
            onToggled: root.toggleMicMute()
            onMoved: (v) => root.setMicVol(v)
        }
    }
}
