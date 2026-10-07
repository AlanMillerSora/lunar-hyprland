import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../widgets/shared"

Item {
    id: page

    property var monitors: []
    property int rightMargin: 36
    property real nightlightValue: 0.5
    property bool nightlightEnabled: false
    property string monitorSequence: ""
    property int monitorStep: 0
    // M48: последняя ошибка hyprctl (stderr/код возврата)
    property string lastError: ""

    // ── запись экрана (качество/битрейт/герцовка) ──
    // Значения хранятся в ~/.config/lunar/record.json и читаются
    // скриптом eclipse-record.sh (Hub → Monitors).
    property bool recReady: false
    property int recQp: 24
    property int recBitrate: 12
    property string recFps: "auto"
    property string recError: ""

    property FileView recFile: FileView {
        path: Quickshell.env("HOME") + "/.config/lunar/record.json"
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onAdapterUpdated: { if (page.recReady) writeAdapter() }
        onLoaded: {
            page.recQp = recAdapter.qp
            page.recBitrate = recAdapter.bitrate
            page.recFps = recAdapter.fps
            page.recReady = true
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                writeAdapter()
                page.recReady = true
            } else {
                // M49: при прочих ошибках не гоним повторные неудачные записи
                page.recError = "record.json не читается"
            }
        }
        onSaved: page.recError = ""
        onSaveFailed: (error) => {
            page.recError = "record.json не сохранить"
        }

        JsonAdapter {
            id: recAdapter
            property int qp: 24
            property int bitrate: 12
            property string fps: "auto"
        }
    }

    // Живой кодек записи: probe сам выбирает путь (NVENC/VAAPI/софт) и отдаёт
    // человекочитаемое имя — показываю его в разделе ЗАПИСЬ, чтобы было видно,
    // что настройки качества/битрейта/герцовки уходят именно в этот кодек.
    property string recCodec: ""

    Process {
        id: recCodecProc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/eclipse-record.sh", "probe"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/кодек:\s*(.+)/)
                if (m) page.recCodec = m[1].trim()
            }
        }
    }

    onRecQpChanged: if (recReady) recAdapter.qp = recQp
    onRecBitrateChanged: if (recReady) recAdapter.bitrate = recBitrate
    onRecFpsChanged: if (recReady) recAdapter.fps = recFps

    // ── превью раскладки: общий bounding box мониторов (логические px) ──
    readonly property var monitorBounds: {
        var l = 0, t = 0, r = 0, b = 0, first = true
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i]
            if (first) {
                l = m.x; t = m.y; r = m.x + m.width; b = m.y + m.height; first = false
            } else {
                l = Math.min(l, m.x); t = Math.min(t, m.y)
                r = Math.max(r, m.x + m.width); b = Math.max(b, m.y + m.height)
            }
        }
        return { x: l, y: t, w: Math.max(1, r - l), h: Math.max(1, b - t) }
    }

    function monScale(aw, ah) {
        var bb = monitorBounds
        return Math.min((aw - 28) / bb.w, (ah - 28) / bb.h)
    }
    function monOffsetX(aw, ah) {
        return (aw - monitorBounds.w * monScale(aw, ah)) / 2
    }
    function monOffsetY(aw, ah) {
        return (ah - monitorBounds.h * monScale(aw, ah)) / 2
    }

    Process { id: nightlightProcess }

    function nightlightTemperature(value) {
        return Math.round(2500 + value * 4000)
    }

    // H18: применяем ночную подсветку не на каждый кадр перетаскивания,
    // а с паузой, и каждый раз перезапускаем gammastep с новым значением.
    Timer {
        id: nightlightDebounce
        interval: 160
        onTriggered: {
            if (page.nightlightEnabled)
                page.startNightlight(page.nightlightValue)
        }
    }

    function startNightlight(value) {
        nightlightProcess.command = [
            "sh",
            "-c",
            "pkill -x gammastep 2>/dev/null; " +
            "sleep 0.05; " +
            "nohup gammastep -O " +
            nightlightTemperature(value) +
            " >/dev/null 2>&1 &"
        ]
        nightlightProcess.running = true
    }

    function nightlightOn() {
        nightlightEnabled = true
        nightlightDebounce.stop()
        startNightlight(nightlightValue)
    }

    function nightlightOff() {
        nightlightEnabled = false
        nightlightDebounce.stop()
        // снимаем немедленно, не через Process (иначе установка command на
        // уже запущенном процессе игнорируется)
        Quickshell.execDetached(["pkill", "-x", "gammastep"])
    }

    function commitNightlight(value) {
        nightlightValue = value
        if (nightlightEnabled)
            nightlightDebounce.restart()
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
        // M48: раньше считалось, что hyprctl всегда успешен — проверяем
        // код возврата, а stderr используем как текст ошибки
        stderr: StdioCollector { id: pApplyErr }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                var e = pApplyErr.text.trim()
                page.lastError = e !== "" ? e : ("hyprctl: код " + exitCode)
                return
            }
            page.lastError = ""
            refreshTimer.restart()
            tearingProc.running = true
        }
    }

    // доступные частоты для текущего разрешения монитора.
    // Без кэша в свойстве: функция вызывается из биндинга model:, а запись
    // в свойство, которое она же читает, Qt считает binding loop.
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
        stderr: StdioCollector { id: pModeErr }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                var e = pModeErr.text.trim()
                page.lastError = e !== "" ? e : ("hyprctl: код " + exitCode)
                return
            }
            page.lastError = ""
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

    Flickable {
        id: pageScroll
        anchors {
            left: parent.left
            right: parent.right
            rightMargin: page.rightMargin
            top: parent.top
            bottom: parent.bottom
        }
        clip: true
        contentWidth: width
        contentHeight: pageCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: pageCol
            width: parent.width
            spacing: Theme.space4

            Row {
                width: parent.width

                Text {
                    text: "MONITORS"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle
                    font.letterSpacing: 3
                }

                Item {
                    width: parent.width - 150
                    height: 1
                }

                Text {
                    text: "󰑐"
                    color: Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSize(22)

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

            // M48: видимая ошибка применения настроек монитора
            Text {
                visible: page.lastError !== ""
                width: parent.width
                text: "hyprctl: " + page.lastError
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                wrapMode: Text.Wrap
            }

            // ── превью раскладки мониторов (пропорционально) ──
            Item {
                id: monPreview
                width: parent.width
                height: 170
                visible: page.monitors.length > 0
                clip: true

                Repeater {
                    model: page.monitors

                    delegate: Rectangle {
                        required property var modelData
                        readonly property real s: page.monScale(monPreview.width, monPreview.height)
                        x: page.monOffsetX(monPreview.width, monPreview.height)
                           + (modelData.x - page.monitorBounds.x) * s
                        y: page.monOffsetY(monPreview.width, monPreview.height)
                           + (modelData.y - page.monitorBounds.y) * s
                        width: Math.max(2, modelData.width * s)
                        height: Math.max(2, modelData.height * s)
                        radius: Theme.radius
                        color: Theme.hover

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name + "\n" + modelData.width + "×" + modelData.height
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            horizontalAlignment: Text.AlignHCenter
                        }
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

                SectionHeader { text: "MONITOR MODE"; textColor: Theme.text; size: Theme.fontSmall; bold: true }

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
                            height: Theme.rowH
                            radius: Theme.radius
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTiny
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
                                    parent.color = "transparent"
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
                property int controlMargin: 25

                Row {
                    anchors.fill: parent
                    spacing: parent.controlMargin

                    Slider {
                        width: parent.width - 70 - parent.spacing
                        height: parent.height
                        label: "NIGHT LIGHT"
                        icon: "󰖔"
                        value: page.nightlightValue
                        accentColor: Theme.accent

                        onMoved: value =>
                            page.commitNightlight(value)
                    }

                    Rectangle {
                        width: 74
                        height: Theme.rowHCompact
                        radius: Theme.radius
                        anchors.verticalCenter: parent.verticalCenter

                        color: page.nightlightEnabled
                            ? Theme.active
                            : Theme.alpha(Theme.textDim, 0.15)

                        border.width: 1
                        border.color: page.nightlightEnabled
                            ? Theme.accent
                            : Theme.textDim

                        Text {
                            anchors.centerIn: parent
                            text: page.nightlightEnabled ? "ON" : "OFF"
                            color: page.nightlightEnabled
                                ? Theme.accent
                                : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
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
                spacing: Theme.space4

                Repeater {
                    model: page.monitors

                    delegate: Rectangle {
                        id: monCard
                        required property var modelData

                        width: parent.width
                        height: 176
                        radius: Theme.radius
                        color: modelData.focused
                            ? Theme.active
                            : Theme.fill

                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.space4
                            spacing: 10

                            Row {
                                spacing: 10

                                Text {
                                    text: modelData.name
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
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
                                    font.pixelSize: Theme.fontSmall
                                }

                                Text {
                                    visible: modelData.focused
                                    text: "ACTIVE"
                                    color: Theme.accent2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                }
                            }

                            // частота обновления (FPS монитора)
                            Row {
                                spacing: 6

                                Text {
                                    text: "ЧАСТОТА"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
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
                                            ? Theme.active
                                            : (rateMouse.containsMouse ? Theme.hover : "transparent")
                                        border.width: 1
                                        border.color: active ? Theme.accent : Theme.border
                                        Text {
                                            anchors.centerIn: parent
                                            text: Math.round(parseFloat(modelData)) + " Hz"
                                            color: active ? Theme.accent : Theme.textDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontTiny
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
                                spacing: Theme.space2

                                Text {
                                    text: "VRR"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: 58
                                    height: 30
                                    radius: Theme.radius
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: monCard.modelData.vrr
                                        ? Theme.active : "transparent"
                                    border.width: 1
                                    border.color: monCard.modelData.vrr ? Theme.accent : Theme.border
                                    Text {
                                        anchors.centerIn: parent
                                        text: monCard.modelData.vrr ? "ON" : "OFF"
                                        color: monCard.modelData.vrr ? Theme.accent : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontTiny
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
                                    font.pixelSize: Theme.fontTiny
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
                                    font.pixelSize: Theme.fontTiny
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Repeater {
                                    model: [1.0, 1.25, 1.5, 1.75, 2.0]

                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool active:
                                            Math.abs(monCard.modelData.scale - modelData) < 0.01
                                        width: 62
                                        height: 30
                                        radius: Theme.radius
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: active
                                            ? Theme.active
                                            : (scaleMouse.containsMouse ? Theme.hover : "transparent")
                                        border.width: 1
                                        border.color: active ? Theme.accent : Theme.border
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.toFixed(2)
                                            color: active ? Theme.accent : Theme.textDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontTiny
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
                    height: Theme.rowHComfy
                    radius: Theme.radius
                    color: Theme.fill

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            text: "TEARING"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 58
                            height: 30
                            radius: Theme.radius
                            anchors.verticalCenter: parent.verticalCenter
                            color: page.tearing ? Theme.active : "transparent"
                            border.width: 1
                            border.color: page.tearing ? Theme.accent : Theme.border
                            Text {
                                anchors.centerIn: parent
                                text: page.tearing ? "ON" : "OFF"
                                color: page.tearing ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTiny
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
                            font.pixelSize: Theme.fontTiny
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ── запись экрана: качество / битрейт / герцовка ──
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Row {
                width: parent.width

                SectionHeader { text: "ЗАПИСЬ"; textColor: Theme.text; size: Theme.fontBody; bold: true }

                Item {
                    width: parent.width - 150
                    height: 1
                }

                Text {
                    text: "SUPER + SHIFT + R"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }
            }

            Column {
                width: parent.width
                spacing: 10

                Row {
                    spacing: Theme.space1

                    Text {
                        text: "КОДЕК"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }

                    Text {
                        text: page.recCodec !== "" ? page.recCodec : "…"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        width: 110
                        text: "КАЧЕСТВО"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        spacing: Theme.space2

                        Repeater {
                            model: [
                                { t: "ЭКОНОМ", q: 34 },
                                { t: "ОБЫЧНОЕ", q: 28 },
                                { t: "ВЫСОКОЕ", q: 24 },
                                { t: "МАКСИМУМ", q: 20 }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: page.recQp === modelData.q

                                width: 106
                                height: 32
                                radius: Theme.radius
                                color: active ? Theme.active : "transparent"
                                border.width: 1
                                border.color: active ? Theme.accent : Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.t
                                    color: active ? Theme.accent : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.recQp = modelData.q
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 58
                    spacing: 25

                    Slider {
                        width: parent.width - 130 - parent.spacing
                        height: parent.height
                        label: "BITRATE"
                        icon: "󰕧"
                        value: (page.recBitrate - 2) / 48
                        accentColor: Theme.accent

                        onMoved: value =>
                            page.recBitrate = Math.round(2 + value * 48)
                    }

                    Text {
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.recBitrate + " Мбит/с"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        width: 110
                        text: "ГЕРЦОВКА"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        spacing: Theme.space2

                        Repeater {
                            model: [
                                { t: "АВТО", v: "auto" },
                                { t: "30", v: "30" },
                                { t: "60", v: "60" },
                                { t: "120", v: "120" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: page.recFps === modelData.v

                                width: 78
                                height: 32
                                radius: Theme.radius
                                color: active ? Theme.active : "transparent"
                                border.width: 1
                                border.color: active ? Theme.accent : Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.t
                                    color: active ? Theme.accent : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.recFps = modelData.v
                                }
                            }
                        }
                    }
                }

                Text {
                    text: "качество — уровень (ниже лучше); битрейт — потолок; применяется со следующей записи"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }

                // M49: видимая ошибка чтения/записи record.json
                Text {
                    visible: page.recError !== ""
                    text: page.recError
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                }
            }
        }
    }

    Component.onCompleted: {
        tearingProc.running = true
    }

    // M50: gammastep запускается через nohup и переживал страницу — при
    // уничтожении страницы гасим его, иначе тумблер не вернуть.
    Component.onDestruction: {
        nightlightDebounce.stop()
        if (page.nightlightEnabled)
            Quickshell.execDetached(["pkill", "-x", "gammastep"])
    }
}
