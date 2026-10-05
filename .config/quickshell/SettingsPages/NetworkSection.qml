import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../widgets/shared"

Item {
    id: page
    // ── сеть: линки systemd-networkd (только чтение) ──
    // NetworkManager выключен; Wi-Fi ассоциирует iwd, IP раздаёт systemd-networkd.
    property var links: []

    // ── Wi-Fi (iwd/iwctl): поиск, подключение, отключение ──
    property string wifiState: "unknown"
    property string wifiSsid: ""
    property string wifiRadio: "unknown"
    property var wifiNets: []
    property string wifiPendingSsid: ""
    property string wifiMsg: ""
    property bool wifiBusy: false
    property bool wifiErr: false
    readonly property string wifiScript: Quickshell.env("HOME") + "/.config/hypr/scripts/eclipse-wifi.sh"

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

    // ── Telegram: локальный MTProto-прокси (tg-ws-proxy) ──
    property bool tgActive: false
    property string tgPort: "1443"
    property string tgMsg: ""

    // ── Vencord (мод Discord) ──
    property string vencState: "notinstalled"
    property string vencInstaller: ""
    property string vencApp: "—"

    // networkctl — read-only: имя, тип, состояние и IPv4 каждого линка.
    Process {
        id: pLinks
        command: ["networkctl", "--json=short", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                try {
                    var ifaces = (JSON.parse(text).Interfaces) || []
                    for (var i = 0; i < ifaces.length; ++i) {
                        var it = ifaces[i]
                        if (it.Name === "lo") continue
                        var addr = ""
                        var addrs = it.Addresses || []
                        for (var j = 0; j < addrs.length; ++j) {
                            if (addrs[j].Family === 2) { addr = addrs[j].AddressString || ""; break }
                        }
                        out.push({ name: it.Name || "?",
                                   kind: it.Type || "",
                                   state: it.OperationalState || "?",
                                   addr: addr })
                    }
                } catch (e) {
                    out = []
                }
                page.links = out
            }
        }
        stderr: StdioCollector {}
    }

    // ── Wi-Fi: iwd (iwctl) через eclipse-wifi.sh ─────────────
    // status → device/state/ssid/radio; список — по строке на сеть.
    Process {
        id: pWifiStatus
        command: [page.wifiScript, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {}
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var p = lines[i].indexOf("=")
                    if (p > 0) m[lines[i].substring(0, p)] = lines[i].substring(p + 1)
                }
                page.wifiState = m.state || "unknown"
                page.wifiSsid = m.ssid || ""
                page.wifiRadio = m.radio || "unknown"
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: pWifiList
        command: [page.wifiScript, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    if (!lines[i]) continue
                    // поля строки разделены \x1f (как в eclipse-status.sh)
                    var fields = lines[i].split("\u001f")
                    var o = {}
                    for (var j = 0; j < fields.length; ++j) {
                        var p = fields[j].indexOf("=")
                        if (p > 0) o[fields[j].substring(0, p)] = fields[j].substring(p + 1)
                    }
                    if (!o.ssid) continue
                    out.push({ ssid: o.ssid,
                               sec: o.sec || "open",
                               sig: parseInt(o.sig) || 0,
                               conn: o.conn === "1" })
                }
                // подключённая — сверху, дальше по силе сигнала
                out.sort(function(a, b) {
                    if (a.conn !== b.conn) return a.conn ? -1 : 1
                    return b.sig - a.sig
                })
                page.wifiNets = out
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: pWifiAction
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                if (t !== "") page.wifiMsg = t
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") page.wifiMsg = text.trim() }
        }
        onExited: (exitCode) => {
            page.wifiBusy = false
            page.wifiErr = exitCode !== 0
            if (exitCode !== 0 && page.wifiMsg === "")
                page.wifiMsg = "не удалось выполнить (код " + exitCode + ")"
            if (exitCode === 0 && page.wifiMsg.indexOf("подключаюсь") === 0)
                page.wifiMsg = ""
            page.wifiPendingSsid = ""
            pWifiStatus.running = true
            pWifiList.running = true
        }
    }

    function wifiStatusText() {
        if (page.wifiRadio === "off") return "○ Wi-Fi выключен"
        if (page.wifiState === "connected") return "● подключено   ·   " + (page.wifiSsid || "?")
        if (page.wifiState === "connecting") return "… подключение"
        if (page.wifiState === "disconnected") return "○ не подключено"
        return "○ " + page.wifiState
    }

    function wifiRescan() {
        if (pWifiAction.running) return
        page.wifiErr = false
        page.wifiBusy = true
        page.wifiMsg = "сканирую сети…"
        pWifiAction.command = [page.wifiScript, "scan"]
        pWifiAction.running = true
    }

    function wifiSetRadio(on) {
        if (pWifiAction.running) return
        page.wifiErr = false
        page.wifiBusy = true
        page.wifiMsg = on ? "включаю Wi-Fi…" : "выключаю Wi-Fi…"
        pWifiAction.command = [page.wifiScript, "radio", on ? "on" : "off"]
        pWifiAction.running = true
    }

    function wifiConnect(ssid, pass) {
        if (pWifiAction.running) return
        page.wifiErr = false
        page.wifiBusy = true
        page.wifiMsg = "подключаюсь к «" + ssid + "»…"
        // пароль уходит аргументом скрипта и на миг виден в argv (см. комментарий в скрипте)
        pWifiAction.command = [page.wifiScript, "connect", ssid, pass]
        pWifiAction.running = true
    }

    function wifiDisconnect(ssid) {
        if (pWifiAction.running) return
        page.wifiErr = false
        page.wifiBusy = true
        page.wifiMsg = "отключаюсь от «" + ssid + "»…"
        pWifiAction.command = [page.wifiScript, "disconnect"]
        pWifiAction.running = true
    }

    // человекочитаемое состояние линка (networkctl отдаёт англ. слаги)
    function linkStateText(s) {
        if (s === "routable") return "активен"
        if (s === "degraded") return "частично"
        if (s === "carrier" || s === "enslaved") return "линк"
        if (s === "no-carrier") return "нет линка"
        if (s === "dormant") return "ожидание"
        if (s === "off") return "выключен"
        return s
    }
    function linkIsUp(s) { return s === "routable" || s === "degraded" || s === "carrier" }

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

    function vencStatusText() {
        if (page.vencState === "patched") return "● установлен"
        if (page.vencState === "unpatched") return "○ не пропатчен (обновился Discord?)"
        return "○ не установлен"
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

    // ── Telegram-прокси (tg-ws-proxy): состояние и управление ──
    Process {
        id: pTg
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/eclipse-zapret-tg.sh status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {}
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var p = lines[i].indexOf("=")
                    if (p > 0) m[lines[i].substring(0, p)] = lines[i].substring(p + 1)
                }
                page.tgActive = (m.state === "active")
                page.tgPort = m.port || "1443"
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") page.tgMsg = text.trim() }
        }
    }

    Process {
        id: pTgAction
        stdout: StdioCollector { onStreamFinished: { page.tgMsg = text.trim(); pTg.running = true } }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") page.tgMsg = text.trim(); pTg.running = true }
        }
    }

    function tgToggle() {
        page.tgMsg = ""
        pTgAction.command = ["bash", "-c", "$HOME/.config/hypr/scripts/eclipse-zapret-tg.sh toggle"]
        pTgAction.running = true
    }

    // ссылка tg://proxy — Telegram сам предложит подключить прокси
    function tgOpenLink() {
        page.tgMsg = ""
        pTgAction.command = ["bash", "-c", "$HOME/.config/hypr/scripts/eclipse-zapret-tg.sh open"]
        pTgAction.running = true
    }

    // ── Vencord: состояние и управление ────────────────────
    Process {
        id: pVenc
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/eclipse-vencord.sh status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {}
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var p = lines[i].indexOf("=")
                    if (p > 0) m[lines[i].substring(0, p)] = lines[i].substring(p + 1)
                }
                page.vencState = m.state || "notinstalled"
                page.vencInstaller = m.installer || ""
                page.vencApp = m.appdir || "—"
            }
        }
    }

    Process {
        id: pVencPatch
        command: ["kitty", "--hold", "-e", "bash", "-c", "$HOME/.config/hypr/scripts/eclipse-vencord.sh patch"]
        onExited: pVenc.running = true
    }

    Process {
        id: pVencUpdate
        command: ["kitty", "--hold", "-e", "bash", "-c", "$HOME/.config/hypr/scripts/eclipse-vencord.sh update"]
        onExited: pVenc.running = true
    }

    Timer {
        interval: 5000
        repeat: true
        running: page.visible
        onTriggered: {
            pLinks.running = true
            pZap.running = true
            pTg.running = true
            pVenc.running = true
            pWifiStatus.running = true
            // список не дёргаю, пока открыт ввод пароля, — иначе делегат пересоберётся
            if (page.wifiPendingSsid === "") pWifiList.running = true
        }
    }

    Component.onCompleted: {
        pLinks.running = true
        pZap.running = true
        pTg.running = true
        pVenc.running = true
        pWifiStatus.running = true
        pWifiList.running = true
    }

    // при открытии страницы обновляю Wi-Fi сразу, не жду тика таймера
    onVisibleChanged: if (visible) { pWifiStatus.running = true; pWifiList.running = true }

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
            height: Theme.panelRowH

            Text {
                id: networkTitle
                text: "NETWORK"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.letterSpacing: 3
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
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

                    // ── WI-FI: поиск и подключение через iwd (iwctl) ──
                    Rectangle {
                        width: list.width
                        height: wifiCol.implicitHeight + Theme.space4
                        radius: Theme.radius
                        color: Theme.fill

                        Column {
                            id: wifiCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.space4
                            anchors.rightMargin: Theme.space4
                            spacing: Theme.space2

                            Row {
                                spacing: 9

                                SectionHeader {
                                    text: "WI-FI"
                                    textColor: Theme.text
                                    size: Theme.fontSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "iwd · поиск и подключение"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                width: parent.width
                                text: page.wifiStatusText()
                                color: page.wifiRadio === "off" || page.wifiState !== "connected"
                                       ? Theme.textFaint : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: Theme.space2

                                ActionButton {
                                    label: "СКАН / ОБНОВИТЬ"
                                    width: 168
                                    height: 32
                                    enabledBtn: !page.wifiBusy && page.wifiRadio !== "off"
                                    onClicked: page.wifiRescan()
                                }

                                ActionButton {
                                    label: page.wifiRadio === "off" ? "ВКЛЮЧИТЬ WI-FI" : "ВЫКЛЮЧИТЬ WI-FI"
                                    width: 168
                                    height: 32
                                    enabledBtn: !page.wifiBusy
                                    onClicked: page.wifiSetRadio(page.wifiRadio === "off")
                                }
                            }

                            // обратная связь: «сканирую», «подключаюсь», ошибка
                            Text {
                                visible: page.wifiMsg !== ""
                                width: parent.width
                                text: page.wifiMsg
                                color: page.wifiErr ? Theme.danger : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTiny
                                wrapMode: Text.Wrap
                            }

                            Text {
                                visible: page.wifiRadio !== "off" && !page.wifiNets.length
                                width: parent.width
                                text: page.wifiBusy ? "обновляю список…" : "сети не найдены"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                            }

                            Repeater {
                                model: page.wifiNets

                                delegate: Column {
                                    id: wifiRow
                                    required property var modelData
                                    width: wifiCol.width
                                    spacing: 6

                                    Rectangle {
                                        width: parent.width
                                        height: Theme.rowHCompact
                                        radius: Theme.radius
                                        color: modelData.conn ? Theme.active : Theme.fill

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.space2
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 9

                                            Text {
                                                text: "\uf1eb"
                                                color: modelData.conn ? Theme.accent : Theme.textFaint
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.fontBody
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                visible: modelData.sec !== "open"
                                                text: "\uf023"
                                                color: Theme.textFaint
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.fontTiny
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: modelData.ssid
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSmall
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, wifiCol.width - 260)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: modelData.sig + "%"
                                                color: Theme.textFaint
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontTiny
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.space2
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.conn ? "ОТКЛЮЧИТЬ" : "ПОДКЛЮЧИТЬ"
                                            color: modelData.conn ? Theme.danger : Theme.accent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontTiny

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (page.wifiBusy) return
                                                    if (modelData.conn) {
                                                        page.wifiDisconnect(modelData.ssid)
                                                    } else if (modelData.sec !== "open") {
                                                        page.wifiPendingSsid =
                                                            page.wifiPendingSsid === modelData.ssid ? "" : modelData.ssid
                                                    } else {
                                                        page.wifiConnect(modelData.ssid, "")
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // поле пароля для защищённой сети
                                    Row {
                                        visible: page.wifiPendingSsid === modelData.ssid
                                        width: parent.width
                                        height: Theme.rowHCompact
                                        spacing: 10

                                        Rectangle {
                                            width: 260
                                            height: Theme.rowHCompact
                                            color: Theme.bgCard
                                            radius: Theme.radius
                                            border.width: 1
                                            border.color: Theme.accent

                                            TextInput {
                                                id: pwField
                                                anchors.fill: parent
                                                anchors.margins: Theme.space2
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSmall
                                                echoMode: TextInput.Password
                                                focus: page.wifiPendingSsid === modelData.ssid
                                                Keys.onReturnPressed: page.wifiConnect(modelData.ssid, text)
                                            }
                                        }

                                        ActionButton {
                                            label: "ПОДКЛЮЧИТЬ"
                                            width: 140
                                            height: Theme.rowHCompact
                                            enabledBtn: !page.wifiBusy
                                            onClicked: page.wifiConnect(modelData.ssid, pwField.text)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── СЕТЬ: линки systemd-networkd (только чтение) ──
                    Rectangle {
                        width: list.width
                        height: netCol.implicitHeight + Theme.space4
                        radius: Theme.radius
                        color: Theme.fill

                        Column {
                            id: netCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.space4
                            anchors.rightMargin: Theme.space4
                            spacing: Theme.space2

                            Row {
                                spacing: 9

                                SectionHeader {
                                    text: "СЕТЬ"
                                    textColor: Theme.text
                                    size: Theme.fontSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "systemd-networkd · только чтение"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                visible: !page.links.length
                                width: netCol.width
                                text: "интерфейсы не найдены"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                            }

                            Repeater {
                                model: page.links

                                delegate: Text {
                                    required property var modelData
                                    width: netCol.width
                                    text: modelData.name
                                          + (modelData.kind ? "   ·   " + modelData.kind : "")
                                          + "   ·   " + page.linkStateText(modelData.state)
                                          + (modelData.addr ? "   ·   " + modelData.addr : "")
                                    color: page.linkIsUp(modelData.state) ? Theme.text : Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ── ZAPRET: обход DPI (Discord / YouTube) ──
                    Rectangle {
                        width: list.width
                        height: 112
                        radius: Theme.radius
                        color: Theme.fill

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.space4
                            anchors.rightMargin: Theme.space4
                            spacing: Theme.space2

                            Row {
                                spacing: 9

                                SectionHeader {
                                    text: "ZAPRET"
                                    textColor: Theme.text
                                    size: Theme.fontSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "обход DPI · Discord / YouTube"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
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
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: Theme.space2

                                ActionButton {
                                    label: page.zapActive ? "ВЫКЛЮЧИТЬ" : "ВКЛЮЧИТЬ"
                                    width: 104
                                    height: 32
                                    onClicked: page.zapToggle()
                                }

                                ActionButton {
                                    label: "ОБНОВИТЬ"
                                    width: 104
                                    height: 32
                                    onClicked: pZapUpdate.running = true
                                }

                                ActionButton {
                                    label: "ПОДОБРАТЬ"
                                    width: 104
                                    height: 32
                                    onClicked: pZapTune.running = true
                                }
                            }
                        }
                    }

                    // ── ZAPRET-TG: локальный прокси Telegram (tg-ws-proxy) ──
                    Rectangle {
                        width: list.width
                        height: 112
                        radius: Theme.radius
                        color: Theme.fill

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.space4
                            anchors.rightMargin: Theme.space4
                            spacing: Theme.space2

                            Row {
                                spacing: 9

                                SectionHeader {
                                    text: "ZAPRET-TG"
                                    textColor: Theme.text
                                    size: Theme.fontSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "прокси Telegram · MTProto WebSocket"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                width: parent.width
                                text: (page.tgActive ? "● активен" : "○ выключен")
                                      + "   ·   127.0.0.1:" + page.tgPort
                                      + (page.tgMsg ? "   ·   " + page.tgMsg : "")
                                color: page.tgActive ? Theme.text : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: Theme.space2

                                ActionButton {
                                    label: page.tgActive ? "ВЫКЛЮЧИТЬ" : "ВКЛЮЧИТЬ"
                                    width: 104
                                    height: 32
                                    onClicked: page.tgToggle()
                                }

                                ActionButton {
                                    label: "ОТКРЫТЬ В TG"
                                    width: 132
                                    height: 32
                                    onClicked: page.tgOpenLink()
                                }
                            }
                        }
                    }

                    // ── VENCORD: мод Discord ──
                    Rectangle {
                        width: list.width
                        height: 112
                        radius: Theme.radius
                        color: Theme.fill

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.space4
                            anchors.rightMargin: Theme.space4
                            spacing: Theme.space2

                            Row {
                                spacing: 9

                                SectionHeader {
                                    text: "VENCORD"
                                    textColor: Theme.text
                                    size: Theme.fontSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "мод Discord · плагины и темы"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontTiny
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                width: parent.width
                                text: page.vencStatusText()
                                      + (page.vencInstaller ? "   ·   " + page.vencInstaller : "")
                                      + (page.vencApp !== "—" ? "   ·   " + page.vencApp : "")
                                color: page.vencState === "patched" ? Theme.text : Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: Theme.space2

                                ActionButton {
                                    label: "ПЕРЕПАТЧИТЬ"
                                    width: 104
                                    height: 32
                                    onClicked: pVencPatch.running = true
                                }

                                ActionButton {
                                    label: "ОБНОВИТЬ"
                                    width: 104
                                    height: 32
                                    onClicked: pVencUpdate.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
