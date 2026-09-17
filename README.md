# 🌘 Lunar Eclipse — Hyprland rice

Перенос веб-превью `hyperland-preview` в реальный Hyprland.
Все конфиги — в папках под `~/.config`, обои — 8 фаз затмения.

## Что устанавливают

| Компонент | Конфиг |
|---|---|
| Hyprland (Lua) | `hypr/hyprland.conf` + `hypr/scripts/eclipse-walls.sh` |
| Waybar | `waybar/config.jsonc` + `waybar/style.css` |
| wofi (лаунчер) | `wofi/config` + `wofi/style.css` |
| kitty | `kitty/kitty.conf` (палитра Lunar Eclipse) |
| mako (уведомления) | `mako/config` |
| hyprlock | `hyprlock/hyprlock.conf` (экран Blood Moon) |
| hypridle | `hypridle/hypridle.conf` |
| Обои | `wallpapers/eclipse_01..08.png` |

## Важно: версия Hyprland

Конфиг написан под **новый Lua API** (вики от 12.09.2026):
`hl.config({...})`, `hl.bind`, `hl.on("hyprland.start", ...)`.
Нужна git-сборка: `pacman -S hyprland-git` (релизы могут ещё не нести Lua).

Проверка версии: `hyprctl version` — конфиг загрузится, если Lua актуален.

## Пакеты

```bash
pacman -S hyprland-git waybar wofi kitty mako swww hyprlock hypridle \
          grim slurp wl-clipboard wireplumber socat ttf-jetbrains-mono ttf-inter
```

## Автоустановка с нуля (после чистой Arch)

```bash
git clone <этот репозиторий> ~/rice
cd ~/rice
./setup.sh                  # поставит всё: пакеты, драйверы GPU, конфиги, службы
./setup.sh --autologin --ru # + автовход в Hyprland и русская локаль
sudo reboot
```

`setup.sh` сам: обновит систему, поставит `yay` и `hyprland-git`, драйверы
видеокарты (NVIDIA/AMD/Intel по автоопределению), все пакеты из списка ниже,
сделает бэкап старых конфигов, скопирует райс и включит автозапуск Hyprland
на tty1. Флаги: `--autologin`, `--no-gpu`, `--ru`.

## Установка

```bash
chmod +x install.sh
./install.sh
hyprctl configerrors
hyprctl reload
```

Скрипт копирует всё в `~/.config/...`, обои — в
`~/Pictures/EclipseWalls/`, а `eclipse-walls.sh` — в `~/.local/bin/`
и подставляет полный путь в `hyprlock.conf`.

## Как это устроено

- **8 рабочих столов = 8 фаз затмения.** Имена в waybar:
  `☾  Phase 1..8`. При переключении стола скрипт `eclipse-walls.sh`
  ставит соответствующую картинку фона через `swww img`
  (переход `wipe`).
- **Общий стиль:** чёрный фон, поверхность `rgba(10,10,10,.72)`,
  рамки `rgba(255,255,255,.10)`, акцент `#7ea6ff` (лунное свечение).
  Скруглённые углы 14px, blur, тени — всё в тему превью.
- **Анимации:** кривые `moon`/`eclipse`, заезд досок `slidefade`,
  окна входят `popin`, рамка активного окна медленно "дышит"
  градиентом (`borderangle loop`).
- **Hotkeys:** `SUPER`+`RETURN` kitty, `SUPER`+`D` меню, `SUPER`+`1..8`
  фазы, `SUPER`+`SHIFT`+`1..8` перенос окна, `SUPER`+`S` скретчпад,
  `PRINT` скриншот области, `SUPER`+`SHIFT`+`L` блокировка.

## Ручная настройка под себя

- Монитор: раскомментируй `hl.monitor({...})` в `hypr/hyprland.conf`.
- Раскладка: `grp:lalt_lshift_toggle` = Alt+Shift; смени на
  `grp:ctrl_shift_toggle` или `grp:win_space_toggle`.
- Задержки блокировки: `hypridle/hypridle.conf`.
- Если шрифтов `Inter` / `JetBrains Mono` нет — замени в
  `waybar/style.css`, `wofi/style.css`, `kitty/kitty.conf`, `hyprlock/hyprlock.conf`.

## Отладка

```bash
hyprctl configerrors     # ошибки конфига
hyprctl activeworkspace -j   # текущий стол
swww query               # активные обои
journalctl --user -u hyprland -f
```