import Quickshell

// Порядок объявления задаёт порядок layer-поверхностей одного слоя.
// Модальные полноэкранные input-регионы (Hub, буфер, питание) объявлены
// раньше поп-апов, чтобы их backdrop не перехватывал клики у открытых
// Volume/Media/Tray; тултип — самый верхний (L54).
ShellRoot {
    LunarWallpaper {}   // живые обои (фоновый слой) — первыми, под всем
    LunarPanel {}
    LunarHub {}
    LunarClipboard {}
    LunarPower {}
    LunarAgent {}
    LunarOverview {}
    LunarSidebar {}
    LunarSidebarRight {}
    LunarOsd {}
    LunarVolume {}
    LunarMedia {}
    LunarTray {}
    LunarTooltip {}
}
