import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../"

// ════════════════════════════════════════════════════════════════
//  SoundSection — звук в Hub (Devices → «Звук»).
//  Сюда переехал выбор устройств, который раньше жил в попапе
//  LunarVolume (попап убран): громкость вывода, выбор вывода,
//  громкость и выбор входа (микрофон) и громкость приложений.
// ════════════════════════════════════════════════════════════════
Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 30
    property real marginTop: 0
    property real marginBottom: 0
    property real sectionSpacing: 6

    // иконки Nerd Font — одиночный \u (двойной слэш печатался буквально)
    readonly property string icSpeaker: "\uf028"
    readonly property string icMic: "\uf130"
    readonly property string icMute: "\uf026"
    readonly property string icRadioOff: "\uf10c"
    readonly property string icHead: "\uf025"
    readonly property string icBt: "\uf293"
    readonly property string icMonitor: "\uf108"

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    property var sink: Pipewire.defaultAudioSink
    property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    property var source: Pipewire.defaultAudioSource
    property real micVolume: (source && source.audio) ? source.audio.volume : 0
    property bool micMuted: (source && source.audio) ? source.audio.muted : false

    // L38: держим JS-списки стабильными — пересобираем делегатов только
    // когда реально меняется набор id, а не на любое изменение nodes
    property var outputSinks: []
    property var inputSources: []
    property var appStreams: []

    function nodeIdList(list) {
        var s = ""
        for (var i = 0; i < list.length; i++)
            s += list[i].id + ","
        return s
    }

    function recomputeAudioLists() {
        var sinks = []
        var sources = []
        var streams = []
        var all = Pipewire.nodes.values
        for (var i = 0; i < all.length; i++) {
            var n = all[i]
            if (n.isSink && !n.isStream && n.audio)
                sinks.push(n)
            else if (!n.isSink && !n.isStream && n.audio
                     && ("" + n.name).indexOf(".monitor") < 0)
                sources.push(n)
            if (n.isStream && n.isSink)
                streams.push(n)
        }
        if (nodeIdList(page.outputSinks) !== nodeIdList(sinks))
            page.outputSinks = sinks
        if (nodeIdList(page.inputSources) !== nodeIdList(sources))
            page.inputSources = sources
        if (nodeIdList(page.appStreams) !== nodeIdList(streams))
            page.appStreams = streams
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { page.recomputeAudioLists() }
    }

    Component.onCompleted: recomputeAudioLists()

    function devName(n) {
        return (n && (n.description || n.nickname || n.name)) || "Unknown"
    }

    function devIcon(n, isInput) {
        if (isInput)
            return page.icMic
        var s = devName(n).toLowerCase()
        if (s.indexOf("head") >= 0 || s.indexOf("науш") >= 0)
            return page.icHead
        if (s.indexOf("bluetooth") >= 0)
            return page.icBt
        if (s.indexOf("hdmi") >= 0 || s.indexOf("digital") >= 0
                || s.indexOf("display") >= 0 || s.indexOf("spdif") >= 0)
            return page.icMonitor
        return page.icSpeaker
    }

    // значение-строка громкости: [иконка] [название] ———o——— [%]
    // без вложенных anchors/Row, чтобы ширина считалась честно
    component LevelRow: Rectangle {
        id: lr
        property string title: ""
        property string icon: page.icSpeaker
        property real level: 0
        property bool isMuted: false
        property color tone: Theme.accent
        signal picked()
        signal moved(real value)

        width: page.width - page.marginRight
        height: 40
        radius: Theme.radius
        color: Theme.fill

        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: 108
            cursorShape: Qt.PointingHandCursor
            onClicked: lr.picked()
        }

        Text {
            id: lrIcon
            x: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            text: lr.isMuted ? page.icMute : lr.icon
            color: lr.isMuted ? Theme.danger : lr.tone
            font.family: Theme.iconFont
            font.pixelSize: 15
        }

        Text {
            id: lrTitle
            x: lrIcon.x + 24
            width: 110
            anchors.verticalCenter: parent.verticalCenter
            text: lr.title
            color: lr.isMuted ? Theme.textDim : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }

        Text {
            id: lrPct
            anchors.right: parent.right
            anchors.rightMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            text: lr.isMuted ? "mute" : Math.round(lr.level * 100) + "%"
            color: lr.isMuted ? Theme.textFaint : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }

        Slider {
            x: lrTitle.x + lrTitle.width + 10
            width: parent.width - x - 56
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            trackHeight: 5
            handleSize: 12
            value: lr.isMuted ? 0 : lr.level
            onMoved: (v) => lr.moved(v)
            onCommitted: (v) => lr.moved(v)
        }
    }

    // строка устройства: [иконка] ИМЯ
    component DeviceRow: Rectangle {
        id: dr
        property var device
        property bool isInput: false
        required property bool active
        signal picked()
        width: page.width - page.marginRight
        height: Theme.rowH
        radius: Theme.radius
        color: dr.active ? Theme.active : (drMouse.containsMouse ? Theme.hover : Theme.fill)

        Text {
            x: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            text: dr.active ? page.devIcon(dr.device, dr.isInput) : page.icRadioOff
            color: dr.active ? Theme.accent : Theme.textFaint
            font.family: Theme.iconFont
            font.pixelSize: 12
        }
        Text {
            x: Theme.space3 + 24
            width: parent.width - 24 - Theme.space3 * 2
            anchors.verticalCenter: parent.verticalCenter
            text: page.devName(dr.device).toUpperCase()
            color: dr.active ? Theme.accent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTiny
            elide: Text.ElideRight
        }
        MouseArea {
            id: drMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dr.picked()
        }
    }

    Column {
        id: pageCol
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: page.marginLeft
            topMargin: page.marginTop
        }
        width: page.width - page.marginRight
        spacing: Theme.space4

        Text {
            text: "SOUND"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitle
            font.letterSpacing: 3
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // ── ВЫВОД ──
        Text {
            text: "ВЫВОД"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.bold: true
            font.letterSpacing: 2
        }
        LevelRow {
            title: "ГРОМКОСТЬ"
            icon: page.icSpeaker
            level: page.volume
            isMuted: page.muted
            onPicked: if (page.sink && page.sink.audio) page.sink.audio.muted = !page.sink.audio.muted
            onMoved: (v) => {
                if (page.sink && page.sink.audio) {
                    page.sink.audio.muted = false
                    page.sink.audio.volume = v
                }
            }
        }
        Column {
            width: parent.width
            spacing: page.sectionSpacing
            Repeater {
                model: page.outputSinks
                delegate: DeviceRow {
                    required property var modelData
                    device: modelData
                    isInput: false
                    active: page.sink && page.sink.id === modelData.id
                    onPicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // ── ВХОД (микрофон) ──
        Text {
            text: "ВХОД"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.bold: true
            font.letterSpacing: 2
        }
        LevelRow {
            title: "МИКРОФОН"
            icon: page.icMic
            level: page.micVolume
            isMuted: page.micMuted
            onPicked: if (page.source && page.source.audio) page.source.audio.muted = !page.source.audio.muted
            onMoved: (v) => {
                if (page.source && page.source.audio) {
                    page.source.audio.muted = false
                    page.source.audio.volume = v
                }
            }
        }
        Text {
            visible: page.inputSources.length === 0
            text: "НЕТ МИКРОФОНА"
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTiny
        }
        Column {
            width: parent.width
            spacing: page.sectionSpacing
            Repeater {
                model: page.inputSources
                delegate: DeviceRow {
                    required property var modelData
                    device: modelData
                    isInput: true
                    active: page.source && page.source.id === modelData.id
                    onPicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // ── ПРИЛОЖЕНИЯ ──
        Text {
            text: "ПРИЛОЖЕНИЯ · " + page.appStreams.length
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.bold: true
            font.letterSpacing: 2
        }
        Column {
            width: parent.width
            spacing: page.sectionSpacing
            Repeater {
                model: page.appStreams
                delegate: LevelRow {
                    required property var modelData
                    readonly property bool sm: modelData && modelData.audio && modelData.audio.muted
                    title: (modelData.description || modelData.name || "app").toUpperCase()
                    icon: page.icSpeaker
                    level: (modelData && modelData.audio) ? modelData.audio.volume : 0
                    isMuted: sm
                    onPicked: if (modelData && modelData.audio) modelData.audio.muted = !modelData.audio.muted
                    onMoved: (v) => {
                        if (modelData && modelData.audio) {
                            modelData.audio.muted = false
                            modelData.audio.volume = v
                        }
                    }
                }
            }
            Text {
                visible: page.appStreams.length === 0
                text: "НЕТ АКТИВНЫХ ПОТОКОВ"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
            }
        }
    }
}
