import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    property var monitors: []
    property int rightMargin: 36
    property real brightnessValue: 0.6
    property real nightlightValue: 0.5
    property bool nightlightEnabled: false
    property string monitorSequence: ""
    property int monitorStep: 0

    // Яркость: встроенная панель (brightnessctl) или внешний монитор (ddcutil).
    // Выбор устройства и DDC/CI — внутри eclipse-brightness.sh.
    Process {
        id: brightnessGet
        command: ["sh", "-c", "$HOME/.config/hypr/scripts/eclipse-brightness.sh get"]

        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(text.trim())
                if (!isNaN(pct))
                    page.brightnessValue = pct / 100
            }
        }
    }

    Process { id: brightnessSet }

    function commitBrightness(value) {
        brightnessSet.command = [
            "sh",
            "-c",
            "$HOME/.config/hypr/scripts/eclipse-brightness.sh set " +
            Math.round(value * 100)
        ]
        brightnessSet.running = true
    }

    Process { id: nightlightProcess }

    function nightlightTemperature(value) {
        return Math.round(2500 + value * 4000)
    }

    function startNightlight(value, delay) {
        nightlightProcess.command = [
            "sh",
            "-c",
            "pkill -x gammastep 2>/dev/null; " +
            "sleep " + delay + "; " +
            "nohup gammastep -O " +
            nightlightTemperature(value) +
            " >/dev/null 2>&1 &"
        ]
        nightlightProcess.running = true
    }

    function nightlightOn() {
        nightlightEnabled = true
        startNightlight(nightlightValue, "0.05")
    }

    function nightlightOff() {
        nightlightEnabled = false
        nightlightProcess.command = ["pkill", "-x", "gammastep"]
        nightlightProcess.running = true
    }

    function commitNightlight(value) {
        nightlightValue = value
        if (nightlightEnabled)
            startNightlight(value, "0.03")
    }

    function isInternalMonitor(mon) {
        return mon.name.indexOf("eDP") === 0 ||
               mon.name.indexOf("LVDS") === 0
    }

    function findMonitors() {
        let internal = null
        let external = null

        for (const mon of monitors) {
            if (isInternalMonitor(mon))
                internal = mon
            else if (!external)
                external = mon
        }

        return { internal, external }
    }

    function monitorMode(mon) {
        return mon.width + "x" +
               mon.height + "@" +
               mon.refreshRate.toFixed(2)
    }

    function luaString(value) {
        return String(value)
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
    }

    function monitorLua(mon, options = {}) {
        const values = [
            "output = \"" + luaString(mon.name) + "\""
        ]

        if (options.mode !== undefined)
            values.push("mode = \"" + luaString(options.mode) + "\"")

        if (options.position !== undefined)
            values.push("position = \"" + luaString(options.position) + "\"")

        if (options.scale !== undefined)
            values.push("scale = " + options.scale)

        if (options.vrr !== undefined)
            values.push("vrr = " + options.vrr)

        if (options.disabled !== undefined)
            values.push("disabled = " + options.disabled)

        if (options.mirrorOf !== undefined)
            values.push(
                "mirrorOf = \"" +
                luaString(options.mirrorOf) +
                "\""
            )

        return "hl.monitor({" + values.join(",") + "})"
    }

    Process {
        id: pList
        command: ["hyprctl", "monitors", "-j"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.monitors = JSON.parse(text)
                } catch (error) {
                    page.monitors = []
                }
            }
        }
    }

    function refresh() {
        pList.running = true
    }

    Process {
        id: pApply
        onExited: {
            refreshTimer.restart()
            tearingProc.running = true
        }
    }

    // доступные частоты для текущего разрешения монитора
    function ratesFor(mon) {
        var out = []
        var res = mon.width + "x" + mon.height
        var modes = mon.availableModes || []
        for (var i = 0; i < modes.length; i++) {
            var m = modes[i]
            if (m.indexOf(res + "@") === 0) {
                var hz = m.substring(res.length + 1).replace("Hz", "")
                if (out.indexOf(hz) < 0)
                    out.push(hz)
            }
        }
        out.sort(function (a, b) { return parseFloat(a) - parseFloat(b) })
        return out
    }

    function applyMonitor(mon, extra) {
        var opts = {
            mode: monitorMode(mon),
            position: mon.x + "x" + mon.y,
            scale: mon.scale.toFixed(2),
            vrr: mon.vrr ? 2 : 0
        }
        for (var k in extra)
            opts[k] = extra[k]
        pApply.command = ["hyprctl", "eval", monitorLua(mon, opts)]
        pApply.running = true
    }

    function setRate(mon, hz) {
        applyMonitor(mon, { mode: mon.width + "x" + mon.height + "@" + hz })
    }

    function setVrr(mon, on) {
        applyMonitor(mon, { vrr: on ? 2 : 0 })
    }

    // tearing — глобально (меньше задержка, но возможны разрывы)
    property bool tearing: false

    Process {
        id: tearingProc
        command: ["bash", "-c", "hyprctl -j getoption general:allow_tearing 2>/dev/null | jq -r .bool"]
        stdout: StdioCollector { onStreamFinished: page.tearing = (text.trim() === "true") }
    }

    function toggleTearing() {
        pApply.command = ["hyprctl", "eval",
            "hl.config({general = {allow_tearing = " + (page.tearing ? "false" : "true") + "}})"]
        pApply.running = true
    }

    function setScale(mon, scale) {
        pApply.command = [
            "hyprctl",
            "eval",
            monitorLua(mon, {
                mode: monitorMode(mon),
                position: mon.x + "x" + mon.y,
                scale: scale.toFixed(2)
            })
        ]
        pApply.running = true
    }

    Process {
        id: pMode

        onExited: {
            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 250

        onTriggered: page.refresh()
    }

    function runMonitorLua(lua) {
        pMode.command = ["hyprctl", "eval", lua]
        pMode.running = true
    }

    function applyMonitorMode(mode) {
        if (monitors.length === 0) {
            refresh()
            return
        }

        const { internal, external } = findMonitors()

        if (!internal || !external)
            return

        monitorSequence = mode
        monitorStep = 0

        if (mode === "first") {
            runMonitorLua(monitorLua(internal, {
                mode: monitorMode(internal),
                position: "0x0",
                scale: internal.scale
            }))
        } else if (mode === "second") {
            runMonitorLua(monitorLua(external, {
                mode: monitorMode(external),
                position: "0x0",
                scale: external.scale
            }))
        } else if (mode === "extend") {
            runMonitorLua(monitorLua(external, {
                mode: monitorMode(external),
                position: "0x0",
                scale: external.scale
            }))
        } else if (mode === "duplicate") {
            runMonitorLua(monitorLua(internal, {
                mode: monitorMode(internal),
                position: "0x0",
                scale: internal.scale
            }))
        } else {
            return
        }

        monitorSequenceTimer.restart()
    }

    Timer {
        id: monitorSequenceTimer
        interval: 100

        onTriggered: {
            const displays = findMonitors()
            const internal = displays.internal
            const external = displays.external

            if (!internal || !external)
                return

            if (monitorSequence === "first") {
                if (monitorStep === 0) {
                    runMonitorLua(monitorLua(external, {
                        disabled: true
                    }))
                    return
                }
            }

            if (monitorSequence === "second") {
                if (monitorStep === 0) {
                    refresh()
                    monitorStep = 1
                    interval = 200
                    restart()
                    return
                }

                if (monitorStep === 1) {
                    runMonitorLua(monitorLua(external, {
                        mode: "preferred",
                        position: "0x0",
                        scale: "\"auto\""
                    }))
                    return
                }
            }

            if (monitorSequence === "extend") {
                if (monitorStep === 0) {
                    refresh()
                    monitorStep = 1
                    interval = 200
                    restart()
                    return
                }

                if (monitorStep === 1) {
                    runMonitorLua(monitorLua(external, {
                        mode: monitorMode(external),
                        position: "0x0",
                        scale: external.scale
                    }))
                    monitorStep = 2
                    interval = 100
                    restart()
                    return
                }

                if (monitorStep === 2) {
                    refresh()
                    monitorStep = 3
                    interval = 200
                    restart()
                    return
                }

                if (monitorStep === 3) {
                    runMonitorLua(monitorLua(internal, {
                        mode: monitorMode(internal),
                        position: external.width + "x0",
                        scale: internal.scale
                    }))
                    return
                }
            }

            if (monitorSequence === "duplicate") {
                if (monitorStep === 0) {
                    refresh()
                    monitorStep = 1
                    interval = 200
                    restart()
                    return
                }

                if (monitorStep === 1) {
                    runMonitorLua(monitorLua(external, {
                        mode: monitorMode(internal),
                        position: "0x0",
                        scale: external.scale,
                        mirrorOf: internal.name
                    }))
                }
            }

            interval = 100
        }
    }

    Column {
        anchors {
            left: parent.left
            right: parent.right
            rightMargin: page.rightMargin
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 13

        Row {
            width: parent.width

            Text {
                text: "MONITORS"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 3
            }

            Item {
                width: parent.width - 150
                height: 1
            }

            Text {
                text: "󰑐"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 22

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: page.refresh()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Column {
            width: parent.width
            spacing: 10

            Text {
                text: "MONITOR MODE"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.bold: true
                font.letterSpacing: 2
            }

            Row {
                width: parent.width
                spacing: 10

                Repeater {
                    model: [
                        { name: "FIRST", mode: "first" },
                        { name: "SECOND", mode: "second" },
                        { name: "EXTEND", mode: "extend" },
                        { name: "DUPLICATE", mode: "duplicate" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width: (parent.width - parent.spacing * 3) / 4
                        height: 42
                        radius: Theme.radius
                        color: "#00000000"
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            hoverEnabled: true

                            onEntered: {
                                parent.color = Theme.alpha(
                                    Theme.accent,
                                    0.08
                                )
                                parent.border.color = Theme.accent
                            }

                            onExited: {
                                parent.color = "#00000000"
                                parent.border.color = Theme.border
                            }

                            onClicked: page.applyMonitorMode(
                                modelData.mode
                            )
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 58

            Slider {
                anchors.fill: parent
                label: "BRIGHTNESS"
                icon: "\uf185"
                value: page.brightnessValue
                accentColor: Theme.accent2

                onCommitted: value =>
                    page.commitBrightness(value)
            }
        }

        Item {
            width: parent.width
            height: 58
            property int controlMargin: 25

            Row {
                anchors.fill: parent
                spacing: parent.controlMargin

                Slider {
                    width: parent.width - 70 - parent.spacing
                    height: parent.height
                    label: "NIGHT LIGHT"
                    icon: "\uf186"
                    value: page.nightlightValue
                    accentColor: "#ffffff"

                    onMoved: value =>
                        page.commitNightlight(value)
                }

                Rectangle {
                    width: 70
                    height: 36
                    radius: Theme.radius
                    anchors.verticalCenter: parent.verticalCenter

                    color: page.nightlightEnabled
                        ? Theme.alpha(Theme.accent, 0.1)
                        : Theme.alpha("#A0A0A0", 0.15)

                    border.width: 1
                    border.color: page.nightlightEnabled
                        ? Theme.accent
                        : "#A0A0A0"

                    Text {
                        anchors.centerIn: parent
                        text: page.nightlightEnabled ? "ON" : "OFF"
                        color: page.nightlightEnabled
                            ? Theme.accent
                            : "#A0A0A0"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent

                        onClicked: page.nightlightEnabled
                            ? page.nightlightOff()
                            : page.nightlightOn()
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 16

            Repeater {
                model: page.monitors

                delegate: Rectangle {
                    id: monCard
                    required property var modelData

                    width: parent.width
                    height: 176
                    radius: Theme.radius
                    color: "#00000000"
                    border.width: 1
                    border.color: modelData.focused
                        ? "#454545"
                        : Theme.border

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Row {
                            spacing: 10

                            Text {
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: modelData.width +
                                      "x" +
                                      modelData.height +
                                      " @ " +
                                      Math.round(
                                          modelData.refreshRate
                                      ) +
                                      "Hz"

                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }

                            Text {
                                visible: modelData.focused
                                text: "ACTIVE"
                                color: Theme.accent2
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }

                        // частота обновления (FPS монитора)
                        Row {
                            spacing: 6

                            Text {
                                text: "ЧАСТОТА"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Repeater {
                                model: page.ratesFor(monCard.modelData)

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool active:
                                        Math.abs(parseFloat(modelData) - monCard.modelData.refreshRate) < 0.6
                                    width: 62
                                    height: 26
                                    radius: Theme.radius
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: active
                                        ? Theme.alpha(Theme.accent, 0.14)
                                        : (rateMouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent")
                                    border.width: 1
                                    border.color: active ? Theme.accent : Theme.border
                                    Text {
                                        anchors.centerIn: parent
                                        text: Math.round(parseFloat(modelData)) + " Hz"
                                        color: active ? Theme.accent : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                    }
                                    MouseArea {
                                        id: rateMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setRate(monCard.modelData, modelData)
                                    }
                                }
                            }
                        }

                        // VRR (FreeSync/GSync)
                        Row {
                            spacing: 8

                            Text {
                                text: "VRR"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: 54
                                height: 26
                                radius: Theme.radius
                                anchors.verticalCenter: parent.verticalCenter
                                color: monCard.modelData.vrr
                                    ? Theme.alpha(Theme.accent, 0.14) : "transparent"
                                border.width: 1
                                border.color: monCard.modelData.vrr ? Theme.accent : Theme.border
                                Text {
                                    anchors.centerIn: parent
                                    text: monCard.modelData.vrr ? "ON" : "OFF"
                                    color: monCard.modelData.vrr ? Theme.accent : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.setVrr(monCard.modelData, !monCard.modelData.vrr)
                                }
                            }

                            Text {
                                text: "FreeSync / GSync"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // масштаб — кнопками (слайдер работал криво)
                        Row {
                            spacing: 6

                            Text {
                                text: "МАСШТАБ"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Repeater {
                                model: [1.0, 1.25, 1.5, 1.75, 2.0]

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool active:
                                        Math.abs(monCard.modelData.scale - modelData) < 0.01
                                    width: 58
                                    height: 26
                                    radius: Theme.radius
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: active
                                        ? Theme.alpha(Theme.accent, 0.14)
                                        : (scaleMouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent")
                                    border.width: 1
                                    border.color: active ? Theme.accent : Theme.border
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.toFixed(2)
                                        color: active ? Theme.accent : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                    }
                                    MouseArea {
                                        id: scaleMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setScale(monCard.modelData, modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // tearing — глобально (меньше задержка, возможны разрывы)
            Rectangle {
                width: parent.width
                height: 46
                radius: Theme.radius
                color: "#00000000"
                border.width: 1
                border.color: Theme.border

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: "TEARING"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 54
                        height: 26
                        radius: Theme.radius
                        anchors.verticalCenter: parent.verticalCenter
                        color: page.tearing ? Theme.alpha(Theme.accent, 0.14) : "transparent"
                        border.width: 1
                        border.color: page.tearing ? Theme.accent : Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: page.tearing ? "ON" : "OFF"
                            color: page.tearing ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.toggleTearing()
                        }
                    }

                    Text {
                        text: "меньше задержка (для игр)"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        brightnessGet.running = true
        tearingProc.running = true
    }
}
