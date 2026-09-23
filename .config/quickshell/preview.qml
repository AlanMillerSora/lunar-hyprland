import QtQuick

// ════════════════════════════════════════════════════════════════
//  preview.qml — проверка сцены обоев без Hyprland и Quickshell.
//
//  Запуск (любая машина с Qt6):
//      qml6 preview.qml          # в части сборок раннер называется просто qml
//  или из репо:  qml6 .config/quickshell/preview.qml
//
//  Клавиши 1..9 — фазы, L — «лёгкий режим». Та же сцена, что и в
//  обоях (LunarWallpaperScene.qml), только без слоя и обёртки.
// ════════════════════════════════════════════════════════════════
Window {
    id: win
    width: 1280
    height: 720
    visible: true
    color: "#000000"
    title: "Lunar Eclipse — preview (1..9 — фазы, L — лёгкий режим)"

    property int phase: 5
    property bool live: true

    LunarWallpaperScene {
        anchors.fill: parent
        phase: win.phase
        live: win.live
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
                    font.pixelSize: 13
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
                font.pixelSize: 11
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: win.live = !win.live
            }
        }
    }

    Shortcut { sequence: "1"; onActivated: win.phase = 1 }
    Shortcut { sequence: "2"; onActivated: win.phase = 2 }
    Shortcut { sequence: "3"; onActivated: win.phase = 3 }
    Shortcut { sequence: "4"; onActivated: win.phase = 4 }
    Shortcut { sequence: "5"; onActivated: win.phase = 5 }
    Shortcut { sequence: "6"; onActivated: win.phase = 6 }
    Shortcut { sequence: "7"; onActivated: win.phase = 7 }
    Shortcut { sequence: "8"; onActivated: win.phase = 8 }
    Shortcut { sequence: "9"; onActivated: win.phase = 9 }
    Shortcut { sequence: "L"; onActivated: win.live = !win.live }
}
