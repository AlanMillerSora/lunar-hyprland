import Quickshell
import QtQuick

// Порядок объявления задаёт порядок layer-поверхностей одного слоя.
// Модальные полноэкранные input-регионы (Hub, буфер, питание) объявлены
// раньше поп-апов, чтобы их backdrop не перехватывал клики у открытых
// Volume/Media/Tray; тултип — самый верхний (L54).
ShellRoot {
    // Встроенный попап Quickshell о провале перезагрузки конфига светлый и
    // не в стиле риса — глушу его. Об ошибке сообщаю обычным уведомлением
    // (mako): оно читаемое и попадает в историю уведомлений.
    Component.onCompleted: Quickshell.inhibitReloadPopup()

    // не спамить уведомлениями, если конфиг сыпется подряд
    Timer { id: reloadFailCooldown; interval: 30000 }
    Connections {
        target: Quickshell
        function onReloadFailed(error) {
            if (reloadFailCooldown.running) return
            reloadFailCooldown.start()
            Quickshell.execDetached(["notify-send", "-a", "Lunar Eclipse",
                "-u", "critical", "Ошибка конфига Quickshell", String(error)])
        }
    }

    LunarWallpaper {}   // живые обои (фоновый слой) — первыми, под всем
    LunarPanel {}
    LunarHub {}
    LunarClipboard {}
    LunarPower {}
    LunarAgent {}
    LunarOverview {}
    LunarPolkit {}
    LunarSidebar {}
    LunarSidebarRight {}
    LunarOsd {}
    LunarVolume {}
    LunarMedia {}
    LunarTray {}
    LunarTooltip {}
}
