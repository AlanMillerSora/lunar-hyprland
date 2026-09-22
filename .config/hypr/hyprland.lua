-- ════════════════════════════════════════════════════════════════
--  Hyprland — "Lunar Eclipse"  (КОНФИГ НА LUA)
--
--  ВАЖНО: начиная с Hyprland 0.55 конфиг грузится ТОЛЬКО из
--  ~/.config/hypr/hyprland.lua. hyprland.conf игнорируется.
--
--  Палитра — из превью D:\test\hyperland-preview (style.css):
--    фон        #000000        текст      #e6e6e6
--    поверхность rgba(10,10,10,.72)        тусклый  #6f6f6f
--    рамка      rgba(255,255,255,.10)      свет     rgba(255,255,255,.35)
--    акцент     #7ea6ff        светлее    #b7ccff
--
--  Цвета в формате 0xAARRGGBB (альфа — ПЕРВЫЙ байт).
-- ════════════════════════════════════════════════════════════════

local COL = {
  -- Hyprland Lua: цвета в формате 0xAARRGGBB (альфа — ПЕРВЫЙ байт!)
  bg        = "0xff000000",
  surface   = "0xb70a0a0a",  -- rgba(10,10,10,0.72)
  border    = "0x19ffffff",  -- rgba(255,255,255,0.10)
  glow      = "0x59ffffff",  -- rgba(255,255,255,0.35)
  text      = "0xffe6e6e6",
  dim       = "0xff6f6f6f",
  accent    = "0xff7ea6ff",
  accentDim = "0xffb7ccff",
}

-- ─────────────────────────────── Окружение ────────────────────
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")

-- ─────────────────────── NVIDIA: окружение ──────────────────────
-- Ставим переменные ТОЛЬКО если NVIDIA реально есть в системе —
-- на AMD/Intel ничего не меняется (иначе сломается рендер).
-- Определяем по sysfs: 0x10de — NVIDIA, 0x1002 — AMD, 0x8086 — Intel.
-- В Arch 615 модули ядра NVIDIA открытые (nvidia-open-dkms), user-space
-- проприетарный — для Hyprland это штатный вариант.

-- производители всех GPU в системе
local function gpu_vendors()
  local out = {}
  local p = io.popen("ls -d /sys/class/drm/card*/device/vendor 2>/dev/null")
  if not p then return out end
  for path in p:lines() do
    local f = io.open(path, "r")
    if f then
      local v = (f:read("*a") or ""):gsub("%s+", "")
      f:close()
      if v ~= "" then out[#out + 1] = v end
    end
  end
  p:close()
  return out
end

-- производители GPU, к которым подключён хотя бы один монитор
local function display_vendors()
  local out = {}
  local p = io.popen(
    "for s in /sys/class/drm/card*-*/status; do " ..
    "[ \"$(cat \"$s\" 2>/dev/null)\" = connected ] || continue; " ..
    "c=\"${s#/sys/class/drm/}\"; c=\"${c%%-*}\"; " ..
    "cat \"/sys/class/drm/$c/device/vendor\" 2>/dev/null; done | sort -u")
  if not p then return out end
  for line in p:lines() do
    local v = line:gsub("%s+", "")
    if v ~= "" then out[#out + 1] = v end
  end
  p:close()
  return out
end

local function has_vendor(list, id)
  for _, v in ipairs(list) do
    if v == id then return true end
  end
  return false
end

if has_vendor(gpu_vendors(), "0x10de") then
  -- NVIDIA есть: аппаратное декодирование видео (официальный VA-API)
  hl.env("LIBVA_DRIVER_NAME", "nvidia")

  -- Если монитор подключён к NVIDIA — она и рисует рабочий стол.
  -- (на гибридных ноутах с выводом через iGPU эти строки не ставятся)
  if has_vendor(display_vendors(), "0x10de") then
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")  -- XWayland: GLX через NVIDIA
    hl.env("GBM_BACKEND", "nvidia-drm")            -- GBM через nvidia-drm
    hl.env("NVD_BACKEND", "direct")                -- прямой scanout/текстуры
  end
end

hl.config({
  general = {
    border_size = 1,          -- тонкая рамка 1px, как у карточки Hub
    gaps_in    = 12,
    gaps_out   = 20,
    layout     = "dwindle",
    resize_on_border = false,
    allow_tearing = false,
    col = {
      -- единый стиль системы: белая рамка у активного окна, приглушённая у остальных
      active_border   = "0xffffffff",
      inactive_border = "0x33ffffff",
    },
  },

  decoration = {
    rounding       = 6,       -- радиус 6, как у Hub
    rounding_power = 2.0,      -- скругленные "сквирклы" как в превью
    active_opacity   = 1.0,
    inactive_opacity = 0.95,
    dim_inactive     = true,
    dim_strength     = 0.12,

    shadow = {
      enabled        = true,
      range          = 18,
      render_power   = 2,
      offset         = { 0, 4 },
      color          = "0xff000000",   -- 0xAARRGGBB
      color_inactive = "0x66000000",
    },

    blur = {
      enabled = true,
      size    = 6,               -- баланс качества и FPS (iGPU слабый)
      passes  = 3,
      ignore_opacity = false,
      vibrancy = 0.25,
      popups   = true,
      xray     = true,           -- меньше перерисовки
      new_optimizations = true,
    },
  },

  input = {
    kb_layout   = "us,ru",
    kb_variant  = ",winkeys",
    kb_options  = "grp:lalt_lshift_toggle",   -- Alt+Shift меняет раскладку
    numlock_by_default = true,
    repeat_rate  = 50,
    repeat_delay = 300,

    follow_mouse    = 1,
    accel_profile   = "flat",
    sensitivity     = -0.15,

    touchpad = {
      natural_scroll        = true,
      disable_while_typing  = true,
      middle_button_emulation = false,
    },
  },

  -- Плавность: без логотипа, окна тянутся/ресайзятся анимированно
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    animate_manual_resizes = true,
    animate_mouse_windowdragging = true,
    vrr = 2,                    -- FreeSync/GSync (плавно в играх)
    focus_on_activate = true,
  },
})

-- ──────────────────────────────────── Мониторы ─────────────────────
-- Авто: всё, что подключено, с нативной частотой.
-- Нужен свой?  hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144",
--                            position = "0x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
-- Привязка рабочего стола к монитору (если их несколько):
-- hl.workspace_rule({ workspace = "1", monitor = "DP-1" })

-- ──────────────────────────────────── Анимации ─────────────────────
-- Скруглённые "лунные" кривые для всего.
hl.curve("moon", {
  type = "bezier",
  points = { { 0.05, 0.7 }, { 0.1, 1.0 } },   -- плавный заход, мягкое приземление
})
hl.curve("eclipse", {
  type = "bezier",
  points = { { 0.4, 0.0 }, { 0.2, 1.0 } },    -- драматичное перекрытие
})

-- Доска: фазы затмения заезжают поверх друг друга
-- (стили попроще: slidefadediagonal/popin тяжелы для iGPU)
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,  bezier = "eclipse", style = "slide" })
hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "moon" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 8,  bezier = "moon" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7,  bezier = "moon" })
hl.animation({ leaf = "fade",        enabled = true, speed = 8,  bezier = "moon" })
hl.animation({ leaf = "fadeSwitch",  enabled = true, speed = 7,  bezier = "moon" })
hl.animation({ leaf = "border",      enabled = true, speed = 7, bezier = "moon" })
-- Плавное появление/уход слоёв (уведомления mako, попапы)
hl.animation({ leaf = "layers",      enabled = true, speed = 6, bezier = "moon", style = "fade" })
hl.animation({ leaf = "fadeLayers",  enabled = true, speed = 6, bezier = "moon" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "eclipse", style = "slidevert" })

-- ─────────────────────────── Рабочие столы = фазы ──────────────────
-- 8 фаз затмения. Имена I..VIII (римские, как в превью);
-- панель рисует Quickshell; id 1..8 — триггер для скрипта обоев.
hl.workspace_rule({ workspace = "1", default_name = "01" })
hl.workspace_rule({ workspace = "2", default_name = "02" })
hl.workspace_rule({ workspace = "3", default_name = "03" })
hl.workspace_rule({ workspace = "4", default_name = "04" })
hl.workspace_rule({ workspace = "5", default_name = "05" })
hl.workspace_rule({ workspace = "6", default_name = "06" })
hl.workspace_rule({ workspace = "7", default_name = "07" })
hl.workspace_rule({ workspace = "8", default_name = "08" })

-- ─────────────────────────────────── Окна ──────────────────────────
-- Плавающие окна утилит по центру, со скруглением темы
hl.window_rule({ match = { class = "^(wofi)$" },              float = true, center = true, rounding = 14 })
hl.window_rule({ match = { class = "nm-connection-editor" },  float = true, center = true })
hl.window_rule({ match = { class = "blueman-manager" },       float = true, center = true })
hl.window_rule({ match = { class = "org.pulseaudio.pavucontrol" }, float = true, center = true })

-- Терминал: чуть прозрачнее неактивного, чтобы "пустота" ночи сквозила
hl.window_rule({ match = { class = "^(kitty)$" }, opacity = "1.0 override 0.92 override" })

-- VS Code: терминальный вид — прямые углы, тонкая рамка (тема в ~/.config/Code)
hl.window_rule({ match = { class = "^(code|code-url-handler)$" }, rounding = 0, border_size = 1 })

-- Попапы райса: календарь, шпаргалка хоткеев, ввод пароля — по центру, без рамок
hl.window_rule({ match = { class = "eclipse-calendar" },   float = true, center = true, rounding = 16, border_size = 0 })
hl.window_rule({ match = { class = "eclipse-cheatsheet" }, float = true, center = true, rounding = 6, border_size = 0 })
hl.window_rule({ match = { class = "eclipse-askpass" },    float = true, center = true, rounding = 16, border_size = 0 })

-- Quickshell: единая оболочка Lunar Eclipse (панель, лаунчер, sidebar, настройки, OSD)
hl.layer_rule({ match = { namespace = "quickshell" }, blur = true, ignore_alpha = 0.25 })


-- Запрет blur окон под полноэкранной игрой/видео
hl.window_rule({ match = { fullscreen = true }, no_blur = true })

-- ─────────── Автораскладка: приложение → свой стол ───────────
-- Окна сами открываются на нужной фазе (столе). Чтобы отключить —
-- убери строку класса или весь блок.
local app_ws = {
  ["2"] = { "firefox", "firefox-developer-edition", "chromium",
            "google-chrome", "brave-browser", "vivaldi-stable",
            "zen", "zen-browser" },
  ["3"] = { "code", "code-oss", "code-url-handler", "cursor", "zed",
            "jetbrains-.*" },
  ["4"] = { "steam", "gamescope", "heroic", "lutris",
            "com.heroicgameslauncher.hgl", "prismlauncher" },
  ["5"] = { "dolphin", "org.kde.dolphin", "nautilus",
            "org.gnome.Nautilus", "thunar" },
  ["6"] = { "telegram-desktop", "org.telegram.desktop", "discord",
            "vesktop", "signal-desktop", "org.signal.Signal" },
  ["7"] = { "spotify", "vlc", "mpv" },
}
for ws, classes in pairs(app_ws) do
  for _, cls in ipairs(classes) do
    -- "silent" — окно открывается на столе, но фокус не уводит
    hl.window_rule({ match = { class = "^(" .. cls .. ")$" }, workspace = ws .. " silent" })
  end
end

-- ─────────────────────────────────── Клавиши ───────────────────────
local dsp = hl.dsp
local M = "SUPER"

hl.bind(M .. " + RETURN",  dsp.exec_cmd("kitty"))
hl.bind(M .. " + D",       dsp.exec_cmd("wofi --show drun"))
hl.bind(M .. " + A",       dsp.exec_cmd("wofi --show run"))
hl.bind(M .. " + G",       dsp.exec_cmd("qs ipc call hub toggle"))      -- Lunar Hub: launch + settings (Quickshell)
hl.bind(M .. " + E",       dsp.exec_cmd("dolphin"))
hl.bind(M .. " + V",       dsp.exec_cmd("qs ipc call clipboard toggle"))   -- буфер обмена (cliphist, Quickshell)
hl.bind(M .. " + SHIFT + E", dsp.exec_cmd("qs ipc call sidebar toggle"))   -- боковая панель слева (Quickshell)
hl.bind(M .. " + SHIFT + R", dsp.exec_cmd("qs ipc call rsidebar toggle"))  -- панель справа: уведомления/музыка/календарь
hl.bind(M .. " + SHIFT + D", dsp.exec_cmd("sh -c 'qs ipc call hub nav 9; qs ipc call hub open'"))  -- Hub: раздел «Разработка»
hl.bind(M .. " + SLASH",   dsp.exec_cmd("~/.config/hypr/scripts/eclipse-cheatsheet.py"))
hl.bind(M .. " + Q",       dsp.window.close())
hl.bind(M .. " + W",       dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(M .. " + SHIFT + W", dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(M .. " + F",       dsp.window.float())
hl.bind(M .. " + P",       dsp.window.pseudo())
hl.bind(M .. " + SPACE",   dsp.window.cycle_next())

-- фокус: HJKL и стрелки
hl.bind(M .. " + LEFT",  dsp.focus({ direction = "left" }))
hl.bind(M .. " + RIGHT", dsp.focus({ direction = "right" }))
hl.bind(M .. " + UP",    dsp.focus({ direction = "up" }))
hl.bind(M .. " + DOWN",  dsp.focus({ direction = "down" }))
hl.bind(M .. " + H",     dsp.focus({ direction = "left" }))
hl.bind(M .. " + L",     dsp.focus({ direction = "right" }))
hl.bind(M .. " + K",     dsp.focus({ direction = "up" }))
hl.bind(M .. " + J",     dsp.focus({ direction = "down" }))

-- перестановка окон
hl.bind(M .. " + SHIFT + LEFT",  dsp.window.move({ direction = "left" }))
hl.bind(M .. " + SHIFT + RIGHT", dsp.window.move({ direction = "right" }))
hl.bind(M .. " + SHIFT + UP",    dsp.window.move({ direction = "up" }))
hl.bind(M .. " + SHIFT + DOWN",  dsp.window.move({ direction = "down" }))
-- SHIFT+HJKL не нужны: перенос окон уже покрыт стрелками выше

-- мышь: тянуть/ресайзить окно (рамок нет — тянем за содержимое)
hl.bind(M .. " + mouse:272", dsp.window.drag(),   { mouse = true })  -- SUPER + ЛКМ
hl.bind(M .. " + mouse:273", dsp.window.resize(), { mouse = true })  -- SUPER + ПКМ

-- стеки = фазы
for ws = 1, 8 do
  hl.bind(M .. " + " .. ws,
    dsp.focus({ workspace = ws }))
  hl.bind(M .. " + SHIFT + " .. ws,
    function() hl.dispatch(dsp.window.move({ workspace = tostring(ws) })) end)
end

-- группы (лайк-вкладки)
hl.bind(M .. " + T",   dsp.group.toggle())
hl.bind(M .. " + SHIFT + T", dsp.group.lock_active())

-- special:scratchpad (всегда под рукой)
hl.bind(M .. " + S", dsp.workspace.toggle_special("scratchpad"))
hl.bind(M .. " + SHIFT + S", dsp.window.move({ workspace = "special:scratchpad" }))

-- скриншоты / перезагрузка / меню питания
hl.bind("PRINT",           dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind(M .. " + PRINT",   dsp.exec_cmd("grim - | wl-copy"))
hl.bind(M .. " + R",       dsp.exec_cmd("hyprctl reload"))
hl.bind(M .. " + C",       dsp.exec_cmd("qs ipc call hub toggle"))       -- Lunar Hub: launch + settings (Quickshell)
hl.bind(M .. " + ESCAPE",  dsp.exec_cmd("qs ipc call power toggle"))     -- меню питания (Quickshell)

-- медиа-клавиши (громкость через PipeWire/wpctl)
hl.bind("XF86AudioRaiseVolume", dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute",        dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute",     dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- яркость (ноут — backlight, внешние мониторы — ddcutil) + OSD
hl.bind("XF86MonBrightnessUp",   dsp.exec_cmd("sh -c '~/.config/hypr/scripts/eclipse-brightness.sh up; qs ipc call brightness open'"))
hl.bind("XF86MonBrightnessDown", dsp.exec_cmd("sh -c '~/.config/hypr/scripts/eclipse-brightness.sh down; qs ipc call brightness open'"))

-- ─────────────────────────────── Автозапуск ─────────────────────────
hl.on("hyprland.start", function()
  hl.exec_cmd("awww-daemon")
  -- waybar заменён верхней панелью Quickshell (LunarPanel.qml)
  hl.exec_cmd("quickshell")
  hl.exec_cmd("mako")
  hl.exec_cmd("hypridle")
  -- история буфера обмена (клипборд Quickshell, SUPER+V)
  hl.exec_cmd("wl-paste --type text  --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("~/.config/hypr/scripts/eclipse-walls.sh")
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
  hl.exec_cmd("~/.config/hypr/scripts/eclipse-transparency.sh")
  -- курсор Bibata (тема применяется на лету)
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
  -- btop на 8-м столе (фаза затмения), без перехвата фокуса
  hl.exec_cmd("[workspace 8 silent] kitty --class lunar-btop --title btop -e btop")
end)

-- Проверка:  hyprctl configerrors
-- Применение на лету:  hyprctl eval 'hl.config({ ... })'
-- Сменить обои вручную:  hyprctl eval 'hl.dispatch(hl.dsp.exec_cmd("awww img ~/Pictures/EclipseWalls/eclipse_04.png"))'
-- (в Hyprland 0.56 hyprctl dispatch/exec парсятся как Lua, поэтому eval)