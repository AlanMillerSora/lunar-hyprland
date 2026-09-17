# HANDOFF — контекст проекта (для следующего агента)

Райс Hyprland «Lunar Eclipse». Веб-дизайн-источник — папка `sait/`
(index.html + style.css + script.js): палитра `#000` / `rgba(10,10,10,.72)`
/ `rgba(255,255,255,.10)` / `#7ea6ff` / `#b7ccff` / `#f2657a`, шрифты Inter +
JetBrains Mono, фазы затмения покрытия `[8,40,75,100,68,35,12,0]%`.

## Что уже сделано

- **Ревью** всех конфигов: найдены и исправлены баги (конфликт `SUPER+L`,
  `center`+`move={0,0}`, инконсистентность `hl.dispatch`, `~` в `hl.exec_cmd`,
  спец-воркспейсы, гонка `swww`, `sed` без экранирования, символический пин).
- **Waybar** (`waybar/config.jsonc`, `waybar/style.css`) — переписан под дизайн:
  бар на всю ширину, height 36, модули слева workspaces+window, по центру
  `custom/eclipse-pbar` + часы `%H:%M:%S`, справа tray/pulseaudio/network/
  cpu/memory/battery/date. `style.css` — Inter, border-bottom 1px, кнопки
  столов 28px, `.total` красный.
- **`hypr/scripts/eclipse-pbar.sh`** — новый модуль прогресс-бара затмения:
  массив `COV=(0 8 40 75 100 68 35 12 0)`, JSON на stdout
  (`text`/`class`=`total`/`tooltip`/`percentage`).
- **`hypr/hyprland.conf`** — имена столов «🌔🌗🌘🌑🌘🌗🌖🌕», блокировка
  экрана перенесена с `SUPER+L` на `SUPER+SHIFT+L`, удалён `move={0,0}` у wofi,
  удалены `SHIFT+HJKL`-брозды, убран задвоенный комментарий. Конфиг — на новом
  Lua API (**нужен `hyprland-git`**, иначе не загрузится).
- **`mako/config`** — `anchor=bottom-right`, `border-color=#FFFFFF1A`, `margin=20`.
- **`wofi/style.css`** — radius 16, Inter.
- **`hypr/scripts/eclipse-walls.sh`** — фильтр строго числовых воркспейсов.
- **`install.sh`** — добавлена копия+chmod `eclipse-pbar.sh`.
- **`dots/setup.sh`** — полный автоустановщик «с нуля», флаги:
  `--autologin`, `--no-gpu`, `--ru`, `-h|--help`. Ставит yay (yay-bin из AUR),
  `hyprland-git`, автоподбор GPU по `lspci`, пакеты (waybar, wofi, kitty, mako,
  swww, hyprlock, hypridle, grim, slurp, wl-clipboard, pipewire, socat,
  ttf-jetbrains-mono, ttf-inter, ttf-noto-color-emoji, xdg-desktop-portal-
  hyprland, thunar, firefox и др.), бэкап конфигов, группы
  `video,input,audio,wheel`+динамика, службы NetworkManager+bluetooth,
  автозапуск Hyprland на tty1.
- **GitHub**: репозиторий `AlanMillerSora/lunar-hyprland` (публичный), ветка
  `main`, последний коммит исправил README (реальная ссылка + ОДИН запуск
  `setup.sh`, не два). Токен `ghp_...` использован один раз — считай его
  потёкшим, юзеру нужно отозвать в Settings → Developer settings → Tokens.

## Как устанавливать (актуально)

```bash
git clone https://github.com/AlanMillerSora/lunar-hyprland.git ~/rice
cd ~/rice
./setup.sh                # один запуск! флаги --autologin --ru сразу при первом
sudo reboot
```

## Открытые вопросы / следующий шаг

- **Статус установки на Arch-машине пользователя НЕИЗВЕСТЕН** — последнее: юзер
  скопировал старый README с плейсхолдером `git clone <этот репозиторий>` →
  команда полетела в bash (угловые скобки = редирект, возможен валяющийся пустой
  файл `репозиторий` в текущей директории). Нужно уточнить: переустановил ли он
  через исправленную команду, что значит «все полетело», и скинул ли вывод
  `hyprctl configerrors`, если Hyprland не стартует.
- Установка Hyprland ранее вообще не выполнялась: **не проверялось**, что Lua-конфиг
  реально парсится на целевой машине (`hyprctl configerrors %`).
- `bash` на Windows-машине недоступен — **`bash -n` для setup.sh, install.sh,
  eclipse-pbar.sh, eclipse-walls.sh не запускался**.
- Клонированный локально репозиторий лежит в `D:\test\hyperland-preview\dots`
  (git уже инициализирован, remote → AlanMillerSora/lunar-hyprland).

## Чувствительные данные

- Токен `ghp_...` попадал в переписку — при следующем агенте НЕ использовать,
  только попросить юзера создать новый.