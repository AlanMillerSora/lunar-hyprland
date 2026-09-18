# HANDOFF — контекст проекта (для следующего агента)

Райс Hyprland «Lunar Eclipse». Веб-дизайн-источник — папка `sait/`
(index.html + style.css + script.js): палитра `#000` / `rgba(10,10,10,.72)`
/ `rgba(255,255,255,.10)` / `#7ea6ff` / `#b7ccff` / `#f2657a`, шрифты Inter +
JetBrains Mono, фазы затмения с покрытием `[8,40,75,100,68,35,12,0]%`.

## Состояние на 18.09.2026 — update 0.1.3

- **Полировка системы (0.1.3).** Waybar: индикатор затмения переделан на
  тонкую полосу `━/─` + глиф фазы + %, на фазе 4 — красный; клики рабочие —
  громкость → `pavucontrol`, Wi-Fi → `eclipse-network.sh` (wofi+nmcli, пароль
  через `eclipse-askpass.py`), часы → `eclipse-calendar.py` (клик по дню
  копирует ISO-дату). `SUPER` + `/` → `eclipse-cheatsheet.py`.
- **kitty** — курсор-beam с трейлом, паддинги, вкладки при ≥2. **fastfetch**
  с логотипом-полузатмением (`fastfetch/eclipse.svg` → `.png`, тип `kitty`);
  запускается из `shell/lunar.bash`, который `install.sh` подключает к
  `~/.bashrc` (там же алиасы и цветной PS1). **wofi** и **Dolphin/KDE**
  (`kde/kdeglobals`, `dolphinrc`, схема `Lunar Eclipse`) — в палитре райса.
- **Грабли GTK3 на python:** обязательно `gi.require_version("Gdk", "3.0")`
  рядом с `Gtk 3.0`, иначе Gdk подтягивается 4.0 и импорт падает.
- **`fastfetch` не установлен** — `sudo -n` недоступен; поставить
  `sudo pacman -S fastfetch`. Конфиг уже разложен.
- Все попапы зарегистрированы оконными правилами (`eclipse-calendar`,
  `eclipse-cheatsheet`, `eclipse-askpass`) — float/center/без рамок.

Отдельный скрипт для правки: `~/.config/hypr/scripts/eclipse-pbar.sh`,
`eclipse-network.sh`, `eclipse-calendar.py`, `eclipse-cheatsheet.py`,
`eclipse-askpass.py`.

## Состояние на 18.09.2026 — update 0.1.2

- **Живые обои — видео 1-в-1 с сайтом, вошло в 0.1.2.** На каждом столе
  `mpvpaper` играет `~/Pictures/EclipseWalls/eclipse_NN.webm` (720 кадров,
  60 fps, VP9 10-бит `yuv420p10le`, петля 12 с). Фаза переключается через IPC
  (`loadfile`) при смене стола. Проверено вживую: `hyprctl layers` — слой
  `mpvpaper` на background 1920×1080, mpv отдаёт `hwdec-current=vaapi`,
  `estimated-vf-fps=60`.
- **`mpvpaper`/`mpv` установлены** (`yay -S mpvpaper`); `sudo -n` по-прежнему
  недоступен, ставит только юзер. В видео-режиме `awww` гасится (иначе GIF
  крутится под видео и жжёт CPU).
- Live-вид численно совпал с `wallpapers/*.png` (mean diff ~1, различий >25 —
  сотые доли процента); все 8 видео валидны.
- **Не держать два `eclipse-walls.sh` сразу.** Старый экземпляр в awww-режиме и
  новый в mpv-режиме дерутся за обои, старый сыплет
  `awww-daemon.sock not found`. При рестарте убивать все и стартовать один.
- **Планировщик live-gen** теперь параллелит фазы (было последовательно,
  ~48 минут на 8 фаз); Chromium запускается через `os.setsid` и убивается по
  группе процессов — осиротевших браузеров не остаётся.

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

## Живые обои (анимированные) — 17.09.2026

- **`hypr/scripts/eclipse-anim-gen.py`** — генератор живых обоев. Рисует сцену
  один-в-один как `sait/script.js` (`exportPhaseSVG`): те же градиенты, солнце,
  луна, кольцо, Бейли, пыль, горизонт, виньетка. Сверху добавляет анимации
  сайта: мерцание звёзд, дыхание гало, дрейф пыли, пульс короны + метеоры
  (фаза 4). Петля бесшовная: все периоды кратны длине петли.
- **Формат — только animated GIF.** Проверено вживую: `awww 0.12.1` проигрывает
  GIF, а animated **WebP и APNG показывает статикой** (даже если декодер в
  бинаре есть). Память демона на 1080p/144 кадра — ~27–30 МБ.
- **Грабли палитры:** `palettegen=stats_mode=diff` морит голодом фон (он
  статичный) → на тёмных градиентах жёсткие полосы (26 тонов вместо ~117).
  Нужен `stats_mode=full` (дефолт в генераторе).
- **Грабли геометрии:** `EX_OFF` в `script.js` — это `[0,-319,-207,-107,0,107,
  207,274,320]` с индексом = номер фазы, т.е. фаза 4 (полное затмение) — это
  смещение **0**. Легко сдвинуть на единицу и получить затмение «не на том столе».
- Дефолт GIF: 6 с петля, 25 fps, 1920×1080, `dither=sierra2_4a`,
  `palette-stat=full`. Рендер 8 фаз на 8 ядрах — ~7 минут. GIF кладутся в
  `~/Pictures/EclipseWalls/` (в git НЕ коммитятся, ~55 МБ).
- `fps` для GIF бери 20/25/50: GIF хранит задержку кадра в сотых, и на 30 fps
  выходит рваная 3/3/4 → лёгкий рывок. 25 fps = ровные 4 сотых.
- Тюнинг: `eclipse-anim-gen.py --duration 8 --fps 25`, `--phases 4`,
  `--dither none`, `--palette-stat full`.
- **Видео-режим (основной, если стоит mpvpaper):**
  `eclipse-anim-gen.py --fps 60 --no-gif --video` → `eclipse_NN.webm`
  (VP9 10-бит `yuv420p10le`, CRF 18, 6 с = 360 кадров). Полный цвет, полос и
  зерна нет — проверено численно: тёмный фон совпадает с 24-бит источником
  (`uniq=13`, `#Δ≥2=1`). `--video-codec h264` даёт `.mp4` (HW-декод легче).
  Монитор 1920×1080@60 Гц, поэтому 60 fps идёт ровно в такт.
- **`eclipse-walls.sh`** сам выбирает режим. Если есть `mpvpaper` и
  `eclipse_NN.webm` → один процесс mpvpaper на все мониторы, фаза
  переключается через IPC (`loadfile` + `loop-file=inf`) по сокету
  `$XDG_RUNTIME_DIR/eclipse-mpvpaper-<uid>.sock` — без перезапусков и вспышек.
  Иначе `awww`: `.gif`, затем `.png`/`.jpg`, переход `fade` 0.6 с.
- **Про качество GIF:** 256 цветов, широкие гало/пыль квантуются с дизером
  (вблизи видно зерно) — это потолок `awww` (он играет только GIF). Сам
  источник гладкий (переходы по 1 luma, полос нет): полосы в GIF брались из
  скудной палитры и лечатся `stats_mode=full`.
- **Грабли GIF-артефактов:** ffmpeg по умолчанию пишет кадры с оптимизацией
  `transdiff` — 59 из 60 кадров идут как прозрачные частичные (проверено
  парсером GCE). Если плеер неверно композитит такие кадры, видно зерно/призраки
  и затмение «раскрывается». Лечится `-gifflags -transdiff` (полные кадры), но
  файл ~2× больше (9.3 МБ → 19.7 МБ на 2 с). Видео-путь этой проблемы лишён.
- **Вид 1-в-1 с сайтом — сделано:** `hypr/scripts/eclipse-live-gen.py` снимает
  кадры с ЖИВОЙ CSS-сцены (`sait/index.html?phase=N&clean=1`) через headless
  Chromium и кодирует в VP9 10-бит. Вид совпадает с `wallpapers/*.png`
  (проверено численно: mean diff 0.006, различие >25 всего 0.00% пикселей).
  Дефолт: 12 с петля, 60 fps, 720 кадров/фаза, один браузер на фазу, фазы
  идут параллельно (общий пул, ~2–3 мин на фазу; на 8 фазах одновременно).
  `--capture proc` — медленный fallback (процесс Chromium на кадр, без CDP).
- **Как сделана бесшовная петля в live-gen:** `capture.html` собирается из
  `index.html` (сам сайт не трогаем): `base href`, `*{transition:none}`,
  seeded `Math.random` (LAF-подобный PRNG, seed 1337), гашение
  `setTimeout/setInterval` (иначе one-shot `nightfallBurst` через 3400 мс
  стрельнёт посреди съёмки). Все анимации замораживаются на времени t через
  `document.getAnimations()` → `pause()` + `currentTime`. Длительности
  квантуются на делители L: звёзды 2–6 с → делители 12 (2/3/4/6),
  пылинки 10–30 с → 6/12, метеоры 1.1–2.7 с → 1.2/1.5/2/2.4, плюс CSS
  `.sun-glow-outer` 5→6 с и `.space-dust` 14→12 с. Иначе шов петли «прыгает».
- **Грабли CDP (chromium 153, `--remote-debugging-pipe`):**
  1) pipe = fd 3 (команды) и fd 4 (события), сообщения — JSON + `\0`;
  2) `close_fds` в Python срабатывает ПОСЛЕ `preexec_fn` и закрывает
     продублированный fd 4 → нужен `close_fds=False`, а сам `dup2` не чистит
     CLOEXEC при `dup2(fd,fd)`, поэтому обязателен `os.set_inheritable(3/4, True)`;
  3) `Page.captureScreenshot` берёт viewport из окна: `--window-size=1920,1080`
     даёт 1920×937 → надо `Emulation.setDeviceMetricsOverride` на 1920×1080;
  4) скорость ~0.46 с/кадр на браузер → параллелим по фазам.
  5) Chromium запускаем с `os.setsid()` в `preexec_fn`, а закрываем через
     `os.killpg(...)` — иначе дети (zygote/renderer) остаются осиротевшими и
     копятся; ручной `pkill -f debugging-pipe` по пути убивает и свою же
     оболочку (её cmdline тоже содержит имя скрипта) — убивать по `[d]`-маске
     или по PID.
- **Расхождение с превью (для eclipse-anim-gen.py):** статичные
  `wallpapers/*.png` — скриншоты ЖИВОЙ CSS-сцены, а `eclipse-anim-gen.py`
  портирует `exportPhaseSVG()` — картинка чуть другая (радиус солнца 160
  против 125; на фазе 4 кровяная луна вместо чёрной с тонким кольцом).
  Нужен вид 1-в-1 — бери `eclipse-live-gen.py`.
- Инструменты на машине: `rsvg-convert`, `ffmpeg` (librsvg/gif/libwebp_anim/
  libvpx/libx264), `python3` (PIL/numpy НЕТ), `chromium` 153 (для live-gen),
  `mpvpaper` + `mpv` (поставлены 18.09 через `yay -S mpvpaper`).

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