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

hl.config({
  general = {
    border_size = 0,          -- без рамок у окон (минимализм)
    gaps_in    = 12,
    gaps_out   = 20,
    layout     = "dwindle",
    resize_on_border = false,
    allow_tearing = false,
    col = {
      -- рамок нет; цвета на случай, если включишь border_size обратно
      active_border   = COL.glow,
      inactive_border = COL.border,
    },
  },

  decoration = {
    rounding       = 14,
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
      size    = 6,
      passes  = 3,
      ignore_opacity = false,
      vibrancy = 0.1696,
      popups   = true,
      xray     = true,
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
    animate_manual_resizes = true,
    animate_mouse_windowdragging = true,
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
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "eclipse", style = "slidefadediagonal" })
hl.animation({ leaf = "windows",     enabled = true, speed = 8,  bezier = "moon" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 10, bezier = "moon", style = "popin" })
hl.animation({ leaf = "fade",        enabled = true, speed = 8,  bezier = "moon" })
hl.animation({ leaf = "fadeSwitch",  enabled = true, speed = 7,  bezier = "moon" })
hl.animation({ leaf = "border",      enabled = true, speed = 7, bezier = "moon" })

-- ─────────────────────────── Рабочие столы = фазы ──────────────────
-- 8 фаз затмения. Имена I..VIII (римские, как в превью); иконки-луны
-- рисует waybar; id 1..8 — триггер для скрипта обоев.
hl.workspace_rule({ workspace = "1", default_name = "I" })
hl.workspace_rule({ workspace = "2", default_name = "II" })
hl.workspace_rule({ workspace = "3", default_name = "III" })
hl.workspace_rule({ workspace = "4", default_name = "IV" })
hl.workspace_rule({ workspace = "5", default_name = "V" })
hl.workspace_rule({ workspace = "6", default_name = "VI" })
hl.workspace_rule({ workspace = "7", default_name = "VII" })
hl.workspace_rule({ workspace = "8", default_name = "VIII" })

-- ─────────────────────────────────── Окна ──────────────────────────
-- Плавающие окна утилит по центру, со скруглением темы
hl.window_rule({ match = { class = "^(wofi)$" },              float = true, center = true, rounding = 14 })
hl.window_rule({ match = { class = "nm-connection-editor" },  float = true, center = true })
hl.window_rule({ match = { class = "blueman-manager" },       float = true, center = true })
hl.window_rule({ match = { class = "org.pulseaudio.pavucontrol" }, float = true, center = true })

-- Терминал: чуть прозрачнее неактивного, чтобы "пустота" ночи сквозила
hl.window_rule({ match = { class = "^(kitty)$" }, opacity = "1.0 override 0.92 override" })

-- Попапы райса: календарь, шпаргалка хоткеев, ввод пароля — по центру, без рамок
hl.window_rule({ match = { class = "eclipse-calendar" },   float = true, center = true, rounding = 16, border_size = 0 })
hl.window_rule({ match = { class = "eclipse-cheatsheet" }, float = true, center = true, rounding = 18, border_size = 0 })
hl.window_rule({ match = { class = "eclipse-askpass" },    float = true, center = true, rounding = 16, border_size = 0 })

-- Lunar Launcher: плавающий «стеклянный» оверлей по центру
-- (initialClass chromium-app = "chrome-127.0.0.1__-Default" на wayland)
hl.window_rule({ match = { class = "chrome-127.0.0.1__-Default" }, float = true, center = true,
                 rounding = 16, border_size = 0,
                 opacity = "0.96 override 0.96 override" })


-- Запрет blur окон под полноэкранной игрой/видео
hl.window_rule({ match = { fullscreen = true }, no_blur = true })

-- ─────────────────────────────────── Клавиши ───────────────────────
local dsp = hl.dsp
local M = "SUPER"

hl.bind(M .. " + RETURN",  dsp.exec_cmd("kitty"))
hl.bind(M .. " + D",       dsp.exec_cmd("wofi --show drun"))
hl.bind(M .. " + A",       dsp.exec_cmd("wofi --show run"))
hl.bind(M .. " + G",       dsp.exec_cmd("lunar-launcher.sh toggle"))  -- Lunar Launcher
hl.bind(M .. " + E",       dsp.exec_cmd("dolphin"))
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

-- lock / скриншоты / перезагрузка
-- (SUPER+L занят фокусом вправо → lock перенесён на SUPER+SHIFT+L)
hl.bind(M .. " + SHIFT + L", dsp.exec_cmd("hyprlock"))
hl.bind("PRINT",           dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind(M .. " + PRINT",   dsp.exec_cmd("grim - | wl-copy"))
hl.bind(M .. " + R",       dsp.exec_cmd("hyprctl reload"))
hl.bind(M .. " + C",       dsp.exit())

-- медиа-клавиши (громкость через PipeWire/wpctl)
hl.bind("XF86AudioRaiseVolume", dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute",        dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute",     dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- ─────────────────────────────── Автозапуск ─────────────────────────
hl.on("hyprland.start", function()
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("waybar")
  hl.exec_cmd("mako")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("~/.local/bin/eclipse-walls.sh")
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
  hl.exec_cmd("~/.config/hypr/scripts/eclipse-transparency.sh")
  -- Lunar Launcher: на 1-м рабочем столе при старте системы
  hl.exec_cmd("~/.local/bin/lunar-launcher.sh open")
end)

-- Проверка:  hyprctl configerrors
-- Применение на лету:  hyprctl eval 'hl.config({ ... })'
-- Сменить обои вручную:  hyprctl eval 'hl.dispatch(hl.dsp.exec_cmd("awww img ~/Pictures/EclipseWalls/eclipse_04.png"))'
-- (в Hyprland 0.56 hyprctl dispatch/exec парсятся как Lua, поэтому eval)