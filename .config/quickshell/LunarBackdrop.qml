import Quickshell
import Quickshell.Wayland
import QtQuick

// ════════════════════════════════════════════════════════════════
//  LunarBackdrop — затемняющая подложка под крупными модалками
//  (Hub / Player / Clipboard / Power / Agent / Wallpapers), как
//  dim-backdrop у 43PR.
//
//  Живёт на слое Bottom: выше обоев (Background) и ниже обычных
//  окон. Поэтому темнеет именно фон рабочего стола, а окна и сами
//  модалки остаются чёткими (нюанс: модалки риса — обычные
//  FloatingWindow, поднять над ними layer-подложку нельзя, иначе
//  она накрыла бы и карточку).
//
//  Ввод не перехватывает: пустой mask = сквозной клик. Бар,
//  сайдбары, OSD и попапы подложку не включают — они либо выше
//  (слой Top/Overlay), либо просто не пишут в Theme.setModal.
// ════════════════════════════════════════════════════════════════
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "lunar-backdrop"

    // не держу полноэкранную поверхность замапленной, когда подложка не нужна
    property bool _mapped: Theme.backdropOn
    visible: _mapped
    Timer {
        id: unmapTimer
        interval: Theme.animSlow + 60
        onTriggered: root._mapped = false
    }
    Connections {
        target: Theme
        function onBackdropOnChanged() {
            if (Theme.backdropOn) { unmapTimer.stop(); root._mapped = true }
            else unmapTimer.restart()
        }
    }

    // пустая маска — ни одной кликабельной области, клики идут сквозь
    mask: Region {}

    Rectangle {
        anchors.fill: parent
        color: "black"
        // плавно темнеем, когда открыта любая крупная модалка
        opacity: Theme.backdropOn ? 0.45 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Theme.easeOut
            }
        }
    }
}
