import QtQuick

// ════════════════════════════════════════════════════════════════
//  preview.qml — проверка сцены обоев без Hyprland и Quickshell.
//
//  Запуск (любая машина с Qt6):
//      qml6 preview.qml          # в части сборок раннер называется просто qml
//  или из репо:  qml6 .config/quickshell/preview.qml
//
//  Клавиши 1..9 — фазы, L — «лёгкий режим».
//  Хоткеи читаются по символу клавиши, поэтому работают и на русской
//  раскладке (там L даёт «д», O — «щ»); те же переключатели есть мышью.
//  Та же сцена, что и в обоях (LunarWallpaperScene.qml), только без
//  слоя и обёртки.
// ════════════════════════════════════════════════════════════════
Window {
    id: win
    width: 1280
    height: 720
    visible: true
    color: "#000000"
    title: "Lunar Eclipse — preview (1..9 — фазы, L — лёгкий)"

    property int phase: 5
    property bool live: true

    LunarWallpaperScene {
        anchors.fill: parent
        phase: win.phase
        live: win.live
        // как в жизни: единственный облегчённый режим (40 мс, без пыли/метеоров)
        optimize: true
        tickMs: 40
    }

    // ── клавиши: по символу, а не по физической клавише (ru-раскладка) ──
    Item {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: (event) => {
            var t = (event.text || "").toLowerCase()
            if (t >= "1" && t <= "9") {
                win.phase = parseInt(t, 10)
                event.accepted = true
                return
            }
            if (t === "l" || t === "д") {
                win.live = !win.live
                event.accepted = true
                return
            }
            // запасной путь по коду клавиши (если text пуст, напр. NumPad)
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                win.phase = event.key - Qt.Key_1 + 1
                event.accepted = true
            } else if (event.key === Qt.Key_L) {
                win.live = !win.live
                event.accepted = true
            }
        }
    }

    // ── мини-контролы (без QtQuick.Controls) ───────────────────
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        spacing: 6

        Repeater {
            model: 9
            delegate: Rectangle {
                required property int index
                width: 34
                height: 30
                radius: 4
                color: win.phase === index + 1 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: win.phase === index + 1 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.18)
                Text {
                    anchors.centerIn: parent
                    text: index + 1
                    color: win.phase === index + 1 ? "#000000" : "#888888"
                    font.pixelSize: Theme.fontSize(13)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.phase = index + 1
                }
            }
        }

        Rectangle {
            width: 96
            height: 30
            radius: 4
            color: win.live ? Qt.rgba(1, 1, 1, 0.08) : "#ffffff"
            border.width: 1
            border.color: win.live ? Qt.rgba(1, 1, 1, 0.18) : "#ffffff"
            Text {
                anchors.centerIn: parent
                text: win.live ? "живые" : "лёгкий"
                color: win.live ? "#888888" : "#000000"
                font.pixelSize: Theme.fontTiny
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: win.live = !win.live
            }
        }
    }
}
