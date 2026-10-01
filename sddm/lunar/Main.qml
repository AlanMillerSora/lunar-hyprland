// Lunar Eclipse — экран входа SDDM.
// Монохром, JetBrains Mono, палитра риса.
// Компоновка: аватар сверху, под ним WELCOME, ниже — строка пароля,
// «выходящая» из круга аватара (круг врезается в верх карточки).

import QtQuick 2.0
import QtQuick.Window 2.0
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#08090d"

    // ── палитра (как Theme.qml риса) ──
    readonly property color cText:   "#e8ecf2"
    readonly property color cDim:    "#98a1ac"
    readonly property color cFaint:  "#5b636d"
    readonly property color cDanger: "#ff003c"
    readonly property color cField:  "#12151b"

    // масштаб под высоту экрана: за 1080p принят 1.0
    readonly property real k: Math.min(width / 1920, height / 1080)

    // размеры блока входа
    readonly property int avSize: Math.round(150 * k)
    readonly property int cardW:  Math.round(400 * k)
    readonly property int cardH:  Math.round(134 * k)
    readonly property int notch:  Math.round(34 * k)   // насколько круг врезается в карточку

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

    function ruDate(d) {
        var days = ["воскресенье", "понедельник", "вторник", "среда",
                    "четверг", "пятница", "суббота"]
        var months = ["января", "февраля", "марта", "апреля", "мая", "июня",
                      "июля", "августа", "сентября", "октября", "ноября", "декабря"]
        return days[d.getDay()] + ", " + d.getDate() + " "
                + months[d.getMonth()] + " " + d.getFullYear()
    }

    // логин без поля имени: берём последнего пользователя
    function doLogin() {
        if (passInput.text.length === 0) {
            err.text = "ВВЕДИТЕ ПАРОЛЬ"
            passInput.forceActiveFocus()
            return
        }
        err.text = ""
        sddm.login(userModel.lastUser, passInput.text, sessionBox.index)
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
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(22 * k)

        // бренд
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "assets/wordmark.png"
            sourceSize.height: Math.round(16 * k)
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

        // ── аватар + карточка пароля ──
        Item {
            id: formBlock
            width: root.cardW
            height: root.avSize + root.cardH - root.notch
            anchors.horizontalCenter: parent.horizontalCenter

            // карточка: WELCOME и строка пароля
            Rectangle {
                id: card
                x: 0
                y: root.avSize - root.notch
                width: root.cardW
                height: root.cardH
                radius: Math.round(16 * k)
                color: cField
                border.width: 1
                border.color: passInput.activeFocus ? cText : cFaint
                Behavior on border.color { ColorAnimation { duration: 120 } }

                // WELCOME — между кругом и строкой
                Row {
                    id: welcomeRow
                    anchors.top: parent.top
                    anchors.topMargin: root.notch + Math.round(14 * k)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(8 * k)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WELCOME"
                        color: cFaint
                        font.family: fReg.name
                        font.pixelSize: Math.round(13 * k)
                        font.letterSpacing: Math.round(3 * k)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: userModel.lastUser
                        color: cText
                        font.family: fBold.name
                        font.pixelSize: Math.round(16 * k)
                        font.letterSpacing: Math.round(1 * k)
                    }
                }

                // строка пароля
                TextInput {
                    id: passInput
                    anchors.top: welcomeRow.bottom
                    anchors.topMargin: Math.round(12 * k)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - Math.round(80 * k)
                    height: Math.round(30 * k)
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    color: cText
                    selectionColor: cFaint
                    selectedTextColor: cText
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.family: fReg.name
                    font.pixelSize: Math.round(18 * k)
                    font.letterSpacing: Math.round(4 * k)
                    KeyNavigation.tab: loginArea
                    KeyNavigation.backtab: loginArea
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.doLogin()
                            event.accepted = true
                        }
                    }
                }

                // подчёркивание под строкой пароля
                Rectangle {
                    anchors.left: passInput.left
                    anchors.right: passInput.right
                    anchors.top: passInput.bottom
                    height: 1
                    color: passInput.activeFocus ? cText : cFaint
                }

                // раскладка клавиатуры (клик — переключить)
                ComboBox {
                    id: layoutBox
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(18 * k)
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(10 * k)
                    width: Math.round(66 * k)
                    height: Math.round(24 * k)
                    model: keyboard.layouts
                    index: keyboard.currentLayout
                    onValueChanged: keyboard.currentLayout = id
                    color: "transparent"
                    borderColor: cFaint
                    focusColor: cText
                    hoverColor: cText
                    menuColor: "#12151b"
                    textColor: cText
                    arrowColor: "transparent"
                    arrowIcon: "assets/chevron.png"
                    rowDelegate: Text {
                        anchors.fill: parent
                        anchors.margins: Math.round(3 * k)
                        verticalAlignment: Text.AlignVCenter
                        color: root.cText
                        font.family: fReg.name
                        font.pixelSize: Math.round(12 * k)
                        font.letterSpacing: Math.round(2 * k)
                        text: {
                            var mi = parent.modelItem
                            if (!mi)
                                return ""
                            var sn = ""
                            if (mi.modelData && mi.modelData.shortName !== undefined)
                                sn = mi.modelData.shortName
                            else if (mi.shortName !== undefined)
                                sn = mi.shortName
                            return sn ? sn.toString().toUpperCase() : ""
                        }
                    }
                }

                // Caps Lock
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(8 * k)
                    visible: keyboard.capsLock
                    text: "CAPS LOCK"
                    color: cDanger
                    font.family: fReg.name
                    font.pixelSize: Math.round(11 * k)
                    font.letterSpacing: Math.round(2 * k)
                }
            }

            // аватар поверх карточки — врезается в неё сверху
            Item {
                id: avatar
                x: (root.cardW - root.avSize) / 2
                y: 0
                width: root.avSize
                height: root.avSize

                // PNG уже круглый (кольцо и прозрачные углы — в самом файле):
                // Qt6-greeter не принимает ShaderEffect без .qsb, а QSB-шейдеры
                // на GL-сцене SDDM не грузятся — поэтому маска запечена в PNG.
                Image {
                    id: avSrc
                    source: "assets/avatar.png"
                    anchors.fill: parent
                    sourceSize.width: Math.round(root.avSize * 1.1)
                    sourceSize.height: Math.round(root.avSize * 1.1)
                    smooth: true
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

        // кнопка входа со стрелкой
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(300 * k)
            height: Math.round(44 * k)
            radius: Math.round(6 * k)
            color: loginArea.containsMouse ? cText : "transparent"
            border.width: 1
            border.color: cText
            Behavior on color { ColorAnimation { duration: 120 } }
            Row {
                anchors.centerIn: parent
                spacing: Math.round(10 * k)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ВОЙТИ"
                    color: loginArea.containsMouse ? "#08090d" : cText
                    font.family: fBold.name
                    font.pixelSize: Math.round(15 * k)
                    font.letterSpacing: Math.round(3 * k)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "→"
                    color: loginArea.containsMouse ? "#08090d" : cText
                    font.family: fReg.name
                    font.pixelSize: Math.round(17 * k)
                }
            }
            MouseArea {
                id: loginArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.doLogin()
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
                menuColor: "#12151b"
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

    Component.onCompleted: passInput.forceActiveFocus()
}
