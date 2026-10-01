import QtQuick
import Quickshell.Services.Pipewire
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 30
    property real marginTop: 0
    property real marginBottom: 0
    property real contentSpacing: 10
    property real sectionSpacing: 6

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    property var sink: Pipewire.defaultAudioSink

    property real volume: (sink && sink.audio)
        ? sink.audio.volume
        : 0

    property bool muted: (sink && sink.audio)
        ? sink.audio.muted
        : false

    // L38: держим JS-списки стабильными — пересобираем делегатов только
    // когда реально меняется набор id, а не на любое изменение nodes
    property var outputSinks: []
    property var appStreams: []

    function nodeIdList(list) {
        var s = ""
        for (var i = 0; i < list.length; i++)
            s += list[i].id + ","
        return s
    }

    function recomputeAudioLists() {
        var sinks = []
        var streams = []
        var all = Pipewire.nodes.values
        for (var i = 0; i < all.length; i++) {
            var n = all[i]
            if (n.isSink && !n.isStream && n.audio)
                sinks.push(n)
            if (n.isStream && n.isSink)
                streams.push(n)
        }
        if (nodeIdList(page.outputSinks) !== nodeIdList(sinks))
            page.outputSinks = sinks
        if (nodeIdList(page.appStreams) !== nodeIdList(streams))
            page.appStreams = streams
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { page.recomputeAudioLists() }
    }

    Component.onCompleted: recomputeAudioLists()

    Column {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom

            leftMargin: page.marginLeft
            rightMargin: page.marginRight
            topMargin: page.marginTop
            bottomMargin: page.marginBottom
        }

        spacing: Theme.space5

        Text {
            text: "SOUND"
            color: Theme.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Theme.fontTitle
            font.letterSpacing: 3
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Row {
            width: parent.width
            spacing: 2

            Rectangle {
                width: 30
                height: 30
                radius: Theme.radius
                anchors.verticalCenter: parent.verticalCenter

                color: page.muted
                    ? Theme.alpha(Theme.danger, 0.15)
                    : Theme.active

                border.width: 1
                border.color: page.muted
                    ? Theme.danger
                    : Theme.border

                Text {
                    anchors.centerIn: parent

                    text: page.muted
                        ? "\uf026"
                        : "\uf028"

                    color: page.muted
                        ? Theme.danger
                        : Theme.accent

                    font.family: Theme.iconFont
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (page.sink && page.sink.audio) {
                            page.sink.audio.muted =
                                !page.sink.audio.muted
                        }
                    }
                }
            }

            Text {
                width: 82
                anchors.verticalCenter: parent.verticalCenter

                text: " VOLUME"

                color: page.muted
                    ? Theme.textDim
                    : Theme.text

                font.family: Theme.fontFamily
                font.pixelSize: 15
                elide: Text.ElideRight
            }

            Slider {
                width: parent.width - 28 - 82 - 12
                height: 72
                anchors.verticalCenter: parent.verticalCenter

                label: ""
                icon: ""

                value: page.muted
                    ? 0
                    : page.volume

                onCommitted: (v) => {
                    if (page.sink && page.sink.audio) {
                        page.sink.audio.muted = false
                        page.sink.audio.volume = v
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 5

            Text {
                text: "OUTPUT"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 2
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Column {
            width: parent.width
            spacing: page.sectionSpacing

            Repeater {
                model: page.outputSinks

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: Theme.rowH
                    radius: Theme.radius

                    property var output: modelData

                    property bool active:
                        page.sink &&
                        output &&
                        page.sink.id === output.id

                    // статичная строка: фон вместо рамки (этап «воздух»)
                    color: active
                        ? Theme.active
                        : Theme.fill

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space3
                        anchors.rightMargin: Theme.space3
                        spacing: Theme.space2

                        Text {
                            width: 20
                            anchors.verticalCenter: parent.verticalCenter

                            text: active
                                ? "\uf192"
                                : "\uf10c"

                            color: active
                                ? Theme.accent
                                : Theme.textFaint

                            font.family: Theme.iconFont
                            font.pixelSize: 11
                        }

                        Text {
                            width: parent.width - 28
                            anchors.verticalCenter: parent.verticalCenter

                            text: (
                                output.description ||
                                output.nickname ||
                                output.name ||
                                "Unknown output"
                            ).toUpperCase()

                            color: active
                                ? Theme.accent
                                : Theme.text

                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (output) {
                                Pipewire.preferredDefaultAudioSink =
                                    output
                            }
                        }
                    }
                }
            }

            Text {
                visible: page.outputSinks.length === 0

                text: "NO AUDIO OUTPUTS"

                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 1.5

                leftPadding: Theme.space1
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Row {
            width: parent.width
            spacing: Theme.space3

            Text {
                text: "PLAYING APPS"

                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 2

                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: page.appStreams.length

                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 10

                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Column {
            width: parent.width
            spacing: page.sectionSpacing

            Repeater {
                model: page.appStreams

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: Theme.rowHComfy
                    radius: Theme.radius

                    property var stream: modelData

                    property bool streamMuted:
                        stream &&
                        stream.audio &&
                        stream.audio.muted

                    property real streamVolume:
                        stream && stream.audio
                            ? stream.audio.volume
                            : 0

                    // статичная строка: фон вместо рамки (этап «воздух»)
                    color: streamMuted
                        ? Theme.alpha(Theme.danger, 0.06)
                        : Theme.fill

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space3
                        anchors.rightMargin: Theme.space4
                        spacing: 6

                        Rectangle {
                            width: 30
                            height: 30
                            radius: Theme.radius
                            anchors.verticalCenter: parent.verticalCenter

                            color: streamMuted
                                ? Theme.alpha(Theme.danger, 0.15)
                                : Theme.active

                            border.width: 1
                            border.color: streamMuted
                                ? Theme.danger
                                : Theme.border

                            Text {
                                anchors.centerIn: parent

                                text: streamMuted
                                    ? "\uf026"
                                    : "\uf028"

                                color: streamMuted
                                    ? Theme.danger
                                    : Theme.accent

                                font.family: Theme.iconFont
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (stream && stream.audio) {
                                        stream.audio.muted =
                                            !stream.audio.muted
                                    }
                                }
                            }
                        }

                        Text {
                            width: 82
                            anchors.verticalCenter: parent.verticalCenter

                            text: (
                                stream.description ||
                                stream.name ||
                                "Unknown app"
                            ).toUpperCase()

                            color: streamMuted
                                ? Theme.textDim
                                : Theme.text

                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Slider {
                            width: parent.width - 28 - 82 - 12
                            height: 72
                            anchors.verticalCenter: parent.verticalCenter

                            label: ""
                            icon: ""

                            value: streamMuted
                                ? 0
                                : streamVolume

                            onCommitted: (v) => {
                                if (stream && stream.audio) {
                                    stream.audio.muted = false
                                    stream.audio.volume = v
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: page.appStreams.length === 0

                text: "NO ACTIVE AUDIO STREAMS"

                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 1.5

                leftPadding: Theme.space1
            }
        }
    }
}
