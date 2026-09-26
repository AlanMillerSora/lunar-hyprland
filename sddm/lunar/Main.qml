// Lunar Eclipse — экран входа SDDM.
// Продолжение заставки Plymouth: то же затмение и надпись, монохром, JetBrains Mono.

import QtQuick 2.0
import QtQuick.Window 2.0
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#050505"

    // ── палитра (как Theme.qml риса) ──
    readonly property color cText:   "#ffffff"
    readonly property color cDim:    "#888888"
    readonly property color cFaint:  "#4a4a4a"
    readonly property color cDanger: "#ff003c"
    readonly property color cField:  "#0d0d0d"

    // масштаб под высоту экрана: за 1080p принят 1.0
    readonly property real k: Math.min(width / 1920, height / 1080)

    FontLoader { id: fReg;  source: "fonts/JetBrainsMono-Regular.ttf" }
    FontLoader { id: fBold; source: "fonts/JetBrainsMono-Bold.ttf" }

    // ── часы ──
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // русская дата без зависимости от локали greeter'а
    function ruDate(d) {
        var days = ["воскресенье", "понедельник", "вторник", "среда",
                    "четверг", "пятница", "суббота"]
        var months = ["января", "февраля", "марта", "апреля", "мая", "июня",
                      "июля", "августа", "сентября", "октября", "ноября", "декабря"]
        return days[d.getDay()] + ", " + d.getDate() + " "
                + months[d.getMonth()] + " " + d.getFullYear()
    }

    // ── вход ──
    function doLogin() {
        if (passInput.text.length === 0) {
            err.text = "ВВЕДИТЕ ПАРОЛЬ"
            passInput.forceActiveFocus()
            return
        }
        err.text = ""
        sddm.login(userInput.text, passInput.text, sessionBox.index)
    }

    Connections {
        target: sddm
        onLoginFailed: {
            err.text = "НЕВЕРНЫЙ ПАРОЛЬ"
            passInput.text = ""
            passInput.forceActiveFocus()
        }
        onLoginSucceeded: err.text = ""
    }

    // ── центральная колонка ──
    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(24 * k)

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "assets/logo.png"
            sourceSize.width: Math.round(150 * k)
            sourceSize.height: Math.round(150 * k)
            smooth: true
        }

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "assets/wordmark.png"
            sourceSize.height: Math.round(20 * k)
            smooth: true
        }

        // часы + дата
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(4 * k)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, "HH:mm")
                color: cText
                font.family: fBold.name
                font.pixelSize: Math.round(52 * k)
                font.letterSpacing: Math.round(2 * k)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.ruDate(root.now)
                color: cDim
                font.family: fReg.name
                font.pixelSize: Math.round(15 * k)
            }
        }

        // форма
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(12 * k)

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(14 * k)

                // круглый аватар: круг и тонкое кольцо рисует шейдер
                // (Rectangle.radius в этой сборке greeter'а не скругляет)
                Item {
                    width: Math.round(64 * k)
                    height: width

                    Image {
                        id: avSrc
                        source: "assets/avatar.png"
                        visible: false
                        sourceSize.width: Math.round(160 * k)
                        sourceSize.height: Math.round(160 * k)
                    }
                    ShaderEffect {
                        anchors.fill: parent
                        property variant src: avSrc
                        property real px: 1.5 / width
                        fragmentShader: "
                            varying highp vec2 qt_TexCoord0;
                            uniform sampler2D src;
                            uniform lowp float qt_Opacity;
                            uniform highp float px;
                            void main() {
                                highp vec2 p = qt_TexCoord0 - vec2(0.5, 0.5);
                                highp float d = length(p);
                                highp float rImg = 0.5 - 2.0 * px;
                                lowp vec4 c = texture2D(src, qt_TexCoord0);
                                highp float aImg = 1.0 - smoothstep(rImg - px, rImg, d);
                                highp float ring = 1.0 - smoothstep(0.0, 1.4 * px, abs(d - (0.5 - 1.2 * px)));
                                lowp vec3 rgb = mix(c.rgb, vec3(0.29, 0.29, 0.29), ring);
                                lowp float alpha = max(c.a * aImg, ring);
                                gl_FragColor = vec4(rgb * alpha, alpha) * qt_Opacity;
                            }"
                    }
                }

                Column {
                    spacing: Math.round(12 * k)

                    // пользователь
                    Rectangle {
                        width: Math.round(300 * k)
                        height: Math.round(42 * k)
                        color: cField
                        radius: Math.round(6 * k)
                        border.width: 1
                        border.color: userInput.activeFocus ? cText : cFaint
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        TextInput {
                            id: userInput
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(12 * k)
                            anchors.rightMargin: Math.round(12 * k)
                            verticalAlignment: TextInput.AlignVCenter
                            color: cText
                            selectionColor: cFaint
                            selectedTextColor: cText
                            font.family: fReg.name
                            font.pixelSize: Math.round(15 * k)
                            text: userModel.lastUser
                            selectByMouse: true
                            KeyNavigation.tab: passInput
                            KeyNavigation.backtab: passInput
                        }
                    }

                    // пароль
                    Rectangle {
                        width: Math.round(300 * k)
                        height: Math.round(42 * k)
                        color: cField
                        radius: Math.round(6 * k)
                        border.width: 1
                        border.color: passInput.activeFocus ? cText : cFaint
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        TextInput {
                            id: passInput
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(12 * k)
                            anchors.rightMargin: Math.round(12 * k)
                            verticalAlignment: TextInput.AlignVCenter
                            color: cText
                            selectionColor: cFaint
                            selectedTextColor: cText
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            font.family: fReg.name
                            font.pixelSize: Math.round(15 * k)
                            KeyNavigation.tab: userInput
                            KeyNavigation.backtab: userInput
                            Keys.onPressed: {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.doLogin()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }

            // ошибка (место зарезервировано)
            Text {
                id: err
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                color: cDanger
                height: Math.round(18 * k)
                font.family: fReg.name
                font.pixelSize: Math.round(13 * k)
                font.letterSpacing: Math.round(1 * k)
            }

            // кнопка входа
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(300 * k)
                height: Math.round(42 * k)
                radius: Math.round(6 * k)
                color: loginArea.containsMouse ? cText : "transparent"
                border.width: 1
                border.color: cText
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "ВОЙТИ"
                    color: loginArea.containsMouse ? "#050505" : cText
                    font.family: fBold.name
                    font.pixelSize: Math.round(15 * k)
                    font.letterSpacing: Math.round(3 * k)
                }
                MouseArea {
                    id: loginArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogin()
                }
            }
        }

        // сессия
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(10 * k)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "СЕССИЯ"
                color: cFaint
                font.family: fReg.name
                font.pixelSize: Math.round(12 * k)
                font.letterSpacing: Math.round(2 * k)
            }
            ComboBox {
                id: sessionBox
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(240 * k)
                height: Math.round(30 * k)
                model: sessionModel
                index: sessionModel.lastIndex
                color: "transparent"
                borderColor: cFaint
                focusColor: cText
                hoverColor: cText
                menuColor: "#0d0d0d"
                textColor: cText
                arrowColor: "transparent"
                arrowIcon: "assets/chevron.png"
                font.family: fReg.name
                font.pixelSize: Math.round(13 * k)
            }
        }

        // питание
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(18 * k)
            Repeater {
                model: [
                    { label: "ВЫКЛ",         act: "poweroff", show: true },
                    { label: "ПЕРЕЗАГРУЗКА", act: "reboot",   show: true },
                    { label: "СОН",          act: "suspend",  show: sddm.canSuspend }
                ]
                Text {
                    text: modelData.label
                    visible: modelData.show
                    color: pwrArea.containsMouse ? cText : cDim
                    font.family: fReg.name
                    font.pixelSize: Math.round(12 * k)
                    font.letterSpacing: Math.round(2 * k)
                    MouseArea {
                        id: pwrArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.act === "poweroff") sddm.powerOff()
                            else if (modelData.act === "reboot") sddm.reboot()
                            else if (modelData.act === "suspend") sddm.suspend()
                        }
                    }
                }
            }
        }
    }

    // имя хоста
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(24 * k)
        text: sddm.hostName
        color: cFaint
        font.family: fReg.name
        font.pixelSize: Math.round(12 * k)
        font.letterSpacing: Math.round(2 * k)
    }

    Component.onCompleted: {
        if (userInput.text.length > 0) passInput.forceActiveFocus()
        else userInput.forceActiveFocus()
    }
}
