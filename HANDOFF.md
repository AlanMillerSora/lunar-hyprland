# HANDOFF — контекст проекта (для следующего агента)

Райс Hyprland «Lunar Eclipse». Веб-дизайн-источник — папка `sait/`
(index.html + style.css + script.js): палитра `#000` / `rgba(10,10,10,.72)`
/ `rgba(255,255,255,.10)` / `#7ea6ff` / `#b7ccff` / `#f2657a`, шрифты Inter +
JetBrains Mono, фазы затмения с покрытием `[8,40,75,100,68,35,12,0]%`.

## Состояние на 17.09.2026 (push `15b3ebc` → `16fxxxx`)

- **Конфиг Hyprland — `hypr/hyprland.lua`.** С Hyprland 0.55 hyprlang убрали:
  `hyprland.conf` НЕ читается вообще (молча, дефолты). Весь конфиг перенесён
  в `.lua` (в истории это rename). На машине пользователя Hyprland 0.56.2,
  `hyprctl configerrors` пусто.
- При первом реальном чтении конфига вылезли ошибки Lua API — уже исправлены:
  - `active_border` — таблица `{ colors = {...}, angle = 45 }` (строка «цвет цвет»
    давала invalid color);
  - анимации `border`/`borderangle` требуют `bezier` (добавлен `"moon"`);
  - переключение столов: `dsp.focus({ workspace = ws })` (в `change_id` нет поля
    из-за валидатора — там обязателен `workspace`);
  - `SUPER+R` — `dsp.exec_cmd("hyprctl reload")` (`reload_config()` в Lua нет).
- **hypridle**: конфиг — `hypr/hypridle.conf` (с 0.1.8 ищется только там,
  не в `~/.config/hypridle/`!). Опции — `on-timeout`/`on-resume` через дефис.
  Проверено: hypridle стартует и регистрирует правила (600 s lock / 900 s dpms).
- **Уведомления — mako.** На машине пользователя `dunst.service` отключён
  (он держал `org.freedesktop.Notifications`, mako падал). В `setup.sh` —
  зачистка dunst при установке.
- **Обои — `awww`** (НЕ swww): имя демона `awww-daemon`, команда `awww img`.
  swww вычищен из всех скриптов/README/превью.
- **Скрипты** `eclipse-walls.sh` / `eclipse-pbar.sh`: парсинг JSON через
  python3 (jq не ставим; python добавлен в пакеты setup.sh — в Arch base его
  нет). Дубли в `~/.local/bin` и `hypr/scripts/` синхронизированы.
  Обои меняются опросом `hyprctl activeworkspace -j` каждые 0.3с: socket2-
  events в Hyprland 0.56.2 сломаны (postEvent не делает retry write при
  EAGAIN), socat из скрипта и пакетов убран.
- **`setup.sh` переписан** (был «хуита»): под `set -euo pipefail` умирал на
  свежей машине — `[ -e ] && cp` падал, когда конфигов ещё нет; `getent group
  network` тоже нет на Arch; GPU-детект не видел NVIDIA «3D controller»
  (гибридные ноуты). Теперь: `if`-конструкции, `GPU_LC=$(... || true)`,
  детект по полному тексту lspci (nvidia/amd/intel), `--help` через awk,
  автозапуск Hyprland устойчив к пустым `XDG_*` + проверка `DISPLAY`,
  autologin с `daemon-reload`, dunst purge, python в пакетах.
- **`install.sh`**: кладёт `hypridle.conf` в `hypr/`, чистит старые
  `hyprland.conf` и `~/.config/hypridle/hypridle.conf` (миграция со старой
  раскладки).
- **README.md** переписан в человеческом стиле (личная история, грабли
  hypridle/.lua/swww — в тексте, а не в табличках).

## Машина пользователя (проверено вживую)

- Arch, Hyprland 0.56.2, hypridle 0.1.8, hyprlock 0.9.6, awww 0.12.1, kitty.
- `hyprctl configerrors` — пусто. Реально применяются: gaps 12, rounding 14,
  градиент рамок `0xffffff59 → 0x7ea6ff` 45°, numlock on, accel flat,
  layout `grp:lalt_lshift_toggle`, workspace-правила «🌔…🌕».
- Демоны подняты: awww-daemon, waybar (с pbar-модулем), mako (владеет шиной),
  hypridle, `eclipse-walls.sh` в цикле. dunst не запущен.
- Обои переключаются по фазам: на столе 2 показывается `eclipse_02.png`
  (`awww query`).
- **Не проверено после перезагрузки**: автозапуск (`hl.on("hyprland.start")`)
  срабатывает только при старте сессии; env `XCURSOR_SIZE`/`HYPRCURSOR_SIZE`
  (добавлены `hl.env`) применятся при следующем входе.

## Токены / безопасность

- Токен, который светился в переписке и использовался для предыдущих пушей, —
  **считать потёкшим** (точное значение намеренно НЕ записано в этот файл —
  GitHub блокирует пуш, если в коммитах есть живой токен). Юзеру отозвать:
  Settings → Developer settings → Personal access tokens → Delete.
- Дальше пушить либо новым токеном (просить юзера), либо по SSH (ключ в `~/.ssh`
  не заводили). В `.git/config` следов токена нет, `~/.git-credentials` нет.

## Что осталось / следующие шаги

- Попросить юзера перезагрузиться и глянуть, что автозапуск и курсор-размер
  применились (проверка `hyprctl getoption general:gaps_in` ≈ 12 и
  `ps aux | grep -E 'waybar|mako|hypridle|eclipse-walls'`).
- `setup.sh` с нуля на чистой машине НЕ прогонялся (наша машина уже настроена)
  — логика проверена статически (`bash -n`, `--help`, набор пакетов), но
  end-to-end тест впереди.
- Мелочь: `waybar` модуль `tray` без StatusNotifierWatcher (KDE/plasmashell)
  показывает пусто — при желании поставить `snixembed` (AUR) и добавить в
  автозапуск. Не критично.
- Windows-машина юзера (`D:\test\hyperland-preview\dots`) — git-репозиторий
  без пуша; если юзер захочет, туда можно затянуть актуальный remote.