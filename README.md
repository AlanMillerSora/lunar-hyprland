# Lunar Eclipse · Hyprland rice

Тёмный райс про луну. Восемь рабочих столов — восемь фаз затмения,
обои меняются вместе с ними, waybar в центре показывает «покрытие» фазы.
Сделано с нуля под Hyprland (Lua-конфиг), в репе лежит и веб-превью
в папке `sait/` — оттуда же и тащились цвета.

## Что внутри

- `hypr/hyprland.lua` — сам конфиг. Собирался под Hyprland 0.56, Lua API.
- `hypr/scripts/` — скрипты: `eclipse-walls.sh` (обои по фазам, слушает
  сокет hyprland через socat) и `eclipse-pbar.sh` (прогресс-бар для waybar).
- `waybar/`, `wofi/`, `kitty/`, `mako/`, `hyprlock/`, `hypridle/` — остальная обвязка.
- `wallpapers/` — 8 картинок, фазы луны.

Цвета: чёрный фон, поверхности `rgba(10,10,10,.72)`, акцент `#7ea6ff` —
в общем, всё крутится вокруг лунного света. Скругления 14px, лёгкий blur,
рамка активного окна медленно «дышит» градиентом.

## На что обратить внимание

С Hyprland 0.55 hyprlang упразднили, конфиг теперь только `.lua`.
То есть `~/.config/hypr/hyprland.conf` он **не читает** — весь смысл
в `hyprland.lua`. Долго ловил это сам: ставишь значения в `.conf`,
а Hyprland их молча игнорирует и живёт на дефолтах.

Ещё пара граблей, с которыми уже разобрался в конфигах:

- hypridle с версии 0.1.8 ищет конфиг в `~/.config/hypr/`, а не в
  `~/.config/hypridle/`. И опции у него в listener пишутся через дефис —
  `on-timeout`, а не `on_timeout`. На старых названиях он просто молча
  не выполняет команды.
- Демон обоев — `awww`, не `swww`. swww тут ни при чём.

## Установка

Если Arch чистый, с нуля:

```bash
git clone https://github.com/AlanMillerSora/lunar-hyprland.git ~/rice
cd ~/rice
./setup.sh
sudo reboot
```

`setup.sh` сам ставит пакеты, драйверы GPU (определяет по lspci), кидает
конфиги и добавляет автозапуск Hyprland на tty1. Хочешь автовход без
пароля и русскую локаль — `./setup.sh --autologin --ru`. Запускать один
раз, при повторном запуске флаги не нужны.

Если Hyprland уже стоит — просто:

```bash
cd ~/rice
./install.sh
hyprctl configerrors   # должно быть пусто
hyprctl reload
```

`install.sh` раскладывает всё по `~/.config/`, обои в
`~/Pictures/EclipseWalls/`, `eclipse-walls.sh` — в `~/.local/bin/`.

Нужны пакеты: `hyprland waybar wofi kitty mako awww hyprlock hypridle`
плюс `grim slurp wl-clipboard wireplumber socat` и шрифты
`ttf-jetbrains-mono ttf-inter`.

## Клавиши

| Хоткей | Что делает |
|---|---|
| `SUPER` + `RETURN` | терминал (kitty) |
| `SUPER` + `D` / `A` | меню (wofi: drun / run) |
| `SUPER` + `1..8` | перейти на фазу |
| `SUPER` + `SHIFT` + `1..8` | утащить окно на фазу |
| `SUPER` + `Q` | закрыть окно |
| `SUPER` + `W` | максимизировать |
| `SUPER` + `SHIFT` + `W` | фуллскрин |
| `SUPER` + `F` / `P` | float / псевдотайлинг |
| `SUPER` + `S` | скретчпад |
| `SUPER` + `SHIFT` + `L` | блокировка (hyprlock) |
| `PRINT` | скриншот области |
| `SUPER` + `R` | перечитать конфиг |

## Подстройка под себя

- Монитор: раскомментируй `hl.monitor({...})` в `hypr/hyprland.lua`
  и пропиши свой.
- Раскладка: по умолчанию `us,ru`, переключение Alt+Shift
  (`grp:lalt_lshift_toggle`). Привычнее `Ctrl+Shift` — поменяй в input.
- Задержки блокировки — `hypridle/hypridle.conf` (10 мин до лока,
  15 мин до гашения экрана).
- Долго ли, коротко ли, но scrollback у kitty 10000 строк и прозрачность
  0.94 — сквозь неё видно blur. Если не нужен полупрозрачный фон —
  убери `background_opacity` в `kitty/kitty.conf`.

## Если что-то не так

```bash
hyprctl configerrors           # ошибки конфига
hyprctl activeworkspace -j     # какой стол активен
awww query                     # что сейчас на фоне
journalctl --user -u hyprland -f
```

Известный косяк: если на машине уже живёт другой демон уведомлений
(dunst и т.п.), mako не стартует — `Failed to acquire service name`.
Выключи чужой сервис (`systemctl --user disable --now dunst.service`).

Всё раскладывается в `~/.config/` обычными копиями, без симлинков и
стеллажей — удобно править руками, не задумываясь.