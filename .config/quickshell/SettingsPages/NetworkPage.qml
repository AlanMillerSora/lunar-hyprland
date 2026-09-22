import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page
    property bool wifiEnabled: true
    property var networks: []
    property string pendingSsid: ""
    property int contentMargin: 0
    property int contentRightMargin: 48
    property int contentTopMargin: 0
    property int contentBottomMargin: 0

    // ── zapret (обход DPI) ──
    property bool zapActive: false
    property string zapDesync: "?"
    property string zapCommit: ""
    property string zapUpdated: ""
    property string zapMsg: ""

    // кнопка блока ZAPRET
    component ZapBtn: Rectangle {
        property string label: ""
        signal clicked()

        width: 104
        height: 32
        radius: Theme.radius
        color: zbtn.containsMouse ? Theme.alpha(Theme.accent, 0.12) : "transparent"
        border.width: 1
        border.color: zbtn.containsMouse ? Theme.accent : Theme.border

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: zbtn.containsMouse ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 1
        }

        MouseArea {
            id: zbtn
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Process {
        id: pRadioGet
        command: ["nmcli", "radio", "wifi"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.wifiEnabled = text.trim() === "enabled" }
    }

    Process {
        id: pRadioSet
        stdout: StdioCollector {
            onStreamFinished: {
                pRadioGet.running = true
                page.wifiEnabled ? pList.running = true : page.networks = []
            }
        }
    }

    function setWifiEnabled(on) {
        pRadioSet.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        pRadioSet.running = true
    }

    Process {
        id: pList
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i].trim()
                    if (!line) continue
                    var fields = [], current = "", escaped = false
                    for (var j = 0; j < line.length; ++j) {
                        var ch = line[j]
                        if (escaped) {
                            current += ch
                            escaped = false
                        } else if (ch === "\\") {
                            escaped = true
                        } else if (ch === ":" && fields.length < 3) {
                            fields.push(current)
                            current = ""
                        } else {
                            current += ch
                        }
                    }
                    fields.push(current)
                    if (fields.length < 4 || !fields[1]) continue
                    var signal = parseInt(fields[2])
                    if (isNaN(signal)) signal = 0
                    out.push({ssid: fields[1], signal: signal, secured: fields[3] !== "" && fields[3] !== "--", connected: fields[0] === "*"})
                }
                page.networks = out
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: pConnect
        function refresh() {
            page.pendingSsid = ""
            pList.running = true
        }
        stdout: StdioCollector { onStreamFinished: pConnect.refresh() }
        stderr: StdioCollector { onStreamFinished: pConnect.refresh() }
    }

    function connectOpen(ssid) {
        pConnect.command = ["nmcli", "device", "wifi", "connect", ssid]
        pConnect.running = true
    }

    function connectSecured(ssid, password) {
        pConnect.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        pConnect.running = true
    }

    function disconnect(ssid) {
        pConnect.command = ["nmcli", "connection", "down", "id", ssid]
        pConnect.running = true
    }

    Process {
        id: pRescan
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: pList.running = true
    }

    function rescan() {
        pRescan.command = ["bash", "-c", "nmcli device wifi rescan 2>/dev/null; sleep 1"]
        pRescan.running = true
    }

    // Автообновление списка, пока страница открыта и радио включено.
    Timer {
        interval: 8000
        repeat: true
        running: page.visible && page.wifiEnabled
        onTriggered: pList.running = true
    }

    // ── zapret: состояние и управление ─────────────────────
    Process {
        id: pZap
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/eclipse-zapret.sh status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {}
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var p = lines[i].indexOf("=")
                    if (p > 0) m[lines[i].substring(0, p)] = lines[i].substring(p + 1)
                }
                page.zapActive = (m.state === "active")
                page.zapDesync = m.desync || "?"
                page.zapCommit = m.commit || ""
                page.zapUpdated = m.updated || ""
            }
        }
    }

    Process {
        id: pZapAction
        stdout: StdioCollector { onStreamFinished: { page.zapMsg = text.trim(); pZap.running = true } }
        stderr: StdioCollector { onStreamFinished: pZap.running = true }
    }

    function zapToggle() {
        page.zapMsg = ""
        pZapAction.command = ["bash", "-c", "$HOME/.config/hypr/scripts/eclipse-zapret.sh toggle"]
        pZapAction.running = true
    }

    // обновление и подбор стратегии — в терминале (там интерактивный sudo и лог)
    Process {
        id: pZapUpdate
        command: ["kitty", "--hold", "-e", "bash", "-c", "$HOME/.config/hypr/scripts/eclipse-zapret.sh update"]
        onExited: pZap.running = true
    }

    Process {
        id: pZapTune
        command: ["kitty", "--hold", "-e", "bash", "-c", "$HOME/.config/hypr/scripts/eclipse-zapret.sh tune"]
        onExited: pZap.running = true
    }

    Timer {
        interval: 5000
        repeat: true
        running: page.visible
        onTriggered: pZap.running = true
    }

    Component.onCompleted: {
        pRadioGet.running = true
        pList.running = true
        pZap.running = true
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: page.contentMargin
        anchors.rightMargin: page.contentRightMargin
        anchors.topMargin: page.contentTopMargin
        anchors.bottomMargin: page.contentBottomMargin
        spacing: 9

        Item {
            id: header
            width: parent.width
            height: 36

            Text {
                id: networkTitle
                text: "NETWORK"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 3
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // обновить список сетей (иначе он «замерзал» после первого скана)
                Rectangle {
                    id: scanBtn
                    width: 76
                    height: 38
                    radius: Theme.radius
                    color: scanMouse.containsMouse
                        ? Theme.alpha(Theme.accent, 0.08)
                        : Theme.alpha(Theme.text, 0.03)
                    border.width: 1
                    border.color: scanMouse.containsMouse ? Theme.borderAccent : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "СКАН"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: scanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.rescan()
                    }
                }

                Rectangle {
                    id: wifiToggle
                    width: 76
                    height: 38
                    radius: Theme.radius
                    color: page.wifiEnabled ? Theme.alpha(Theme.accent, 0.1) : Theme.alpha("#A0A0A0", 0.15)
                    border.width: 1
                    border.color: page.wifiEnabled ? Theme.accent : "#A0A0A0"

                    Text {
                        anchors.centerIn: parent
                        text: page.wifiEnabled ? "ON" : "OFF"
                        color: page.wifiEnabled ? Theme.accent : "#A0A0A0"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.setWifiEnabled(!page.wifiEnabled)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Item {
            width: parent.width
            height: parent.height - header.height - 12 - 1

            Flickable {
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: list.height

                Column {
                    id: list
                    width: parent.width
                    spacing: 6

                    // ── ZAPRET: обход DPI (Discord / YouTube) ──
                    Rectangle {
                        width: list.width
                        height: 112
                        radius: Theme.radius
                        color: Theme.bgCard
                        border.width: 1
                        border.color: page.zapActive ? Theme.alpha(Theme.accent, 0.45) : Theme.border

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 8

                            Row {
                                spacing: 9

                                Text {
                                    text: "ZAPRET"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.letterSpacing: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "обход DPI · Discord / YouTube"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                width: parent.width
                                text: (page.zapActive ? "● активен" : "○ выключен")
                                      + "   ·   " + page.zapDesync
                                      + (page.zapCommit ? "   ·   " + page.zapCommit : "")
                                color: page.zapActive ? Theme.text : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 8

                                ZapBtn {
                                    label: page.zapActive ? "ВЫКЛЮЧИТЬ" : "ВКЛЮЧИТЬ"
                                    onClicked: page.zapToggle()
                                }

                                ZapBtn {
                                    label: "ОБНОВИТЬ"
                                    onClicked: pZapUpdate.running = true
                                }

                                ZapBtn {
                                    label: "ПОДОБРАТЬ"
                                    onClicked: pZapTune.running = true
                                }
                            }
                        }
                    }

                    Text {
                        visible: !page.wifiEnabled
                        width: parent.width
                        text: "Wi-Fi is disabled"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: page.wifiEnabled && !page.networks.length
                        width: parent.width
                        text: "Scanning Wi-Fi networks"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Repeater {
                        model: page.networks

                        delegate: Column {
                            required property var modelData
                            width: list.width
                            spacing: 6

                            Rectangle {
                                width: parent.width
                                height: 46
                                radius: Theme.radius
                                color: modelData.connected ? Theme.alpha(Theme.accent, 0.10) : "#00000000"
                                border.width: 1
                                border.color: modelData.connected ? Theme.accent : Theme.border

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 9

                                    Text {
                                        text: ""
                                        color: modelData.connected ? Theme.accent : Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        visible: modelData.secured
                                        text: ""
                                        color: Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        text: modelData.ssid
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, list.width - 170)
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.connected ? "DISCONNECT" : "CONNECT"
                                    color: modelData.connected ? Theme.danger : Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10

                                    MouseArea {
                                        cursorShape: Qt.PointingHandCursor
                                        anchors.fill: parent
                                        onClicked: {
                                            if (modelData.connected) {
                                                page.disconnect(modelData.ssid)
                                            } else if (modelData.secured) {
                                                page.pendingSsid = page.pendingSsid === modelData.ssid ? "" : modelData.ssid
                                            } else {
                                                page.connectOpen(modelData.ssid)
                                            }
                                        }
                                    }
                                }
                            }

                            Row {
                                visible: page.pendingSsid === modelData.ssid
                                width: parent.width
                                height: 36
                                spacing: 10

                                Rectangle {
                                    width: 220
                                    height: 36
                                    color: Theme.bgCard
                                    border.color: Theme.accent
                                    border.width: 1
                                    radius: Theme.radius

                                    TextInput {
                                        id: pwField
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        echoMode: TextInput.Password
                                        focus: page.pendingSsid === modelData.ssid
                                        Keys.onReturnPressed: page.connectSecured(modelData.ssid, text)
                                    }
                                }

                                Text {
                                    text: "CONNECT"
                                    color: Theme.accent2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        cursorShape: Qt.PointingHandCursor
                                        anchors.fill: parent
                                        onClicked: page.connectSecured(modelData.ssid, pwField.text)
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
