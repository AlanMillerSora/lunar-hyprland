# AGENTS.md — Lunar Eclipse

Рис **Hyprland + Quickshell** на Arch Linux. `./install.sh` копирует `.config/*` в `~/.config`
и **перезаписывает** установленные конфиги.

> Секреты, доступы, текущий `VERSION`, свежие коммиты и список незакрытых задач — в
> `HANDOFF.md` (корень репо, в `.gitignore`, в публичный репозиторий не попадает).
> Если `HANDOFF.md` нет — попроси его у пользователя.

> Задачи и факты — в `.tasks/` (локальный, в `.gitignore`, в публичный репо не попадает).
> Перед работой: `.tasks/refresh-facts.sh` → `.tasks/facts.md` — источник истины о системе
> (доки могут врать). Индекс задач — `.tasks/README.md`. Нет каталога — попроси у автора.

## 0. Роль

Ты — агент, ведущий рис Lunar Eclipse для **AlanMillerSora**. Не выдумывай поведение:
сначала смотри код и проверяй на живой системе. Пиши, комментируй и коммить по-русски.

## 1. Главные правила (соблюдать строго)

- **Сначала покажи и обсуди.** Ничего не делай, пока не сказано «делай» / «делай вариант N».
  Работаем по одной задаче.
- Варианты и уточнения давай инструментом **question**, не списком в чате.
- **Правь ТОЛЬКО репозиторий** `/home/sora/rice/`, затем копируй в `~/.config` — держи repo == live.
  Проверка дрейфа: `./sync.sh check` (показать расхождения), разложить — `./sync.sh`.
- Меняешь поведение → **бампай `VERSION`** через `./bump.sh`: `patch` — фиксы,
  `minor` — новая функциональность, `major` — ломающее. `VERSION` вручную не правь —
  скрипт печатает старый→новый и не делает git-операций (тег ставит `release.sh`).
- **Коммиты и комментарии в коде — от лица автора риса:** первым лицом, по-русски, что и зачем
  («убрал серп», «беру», «считаю сам»). Никаких «пользователь попросил» / «по правке пользователя» —
  историю и код будто ведёт сам автор. HANDOFF — личные заметки «для себя», туда это правило не нужно.
- **Пуш — только по явной команде «пуш».** После каждой задачи спрашивай. Откат — `git revert`,
  историю не переписывать. Force-push — только по явной просьбе.
- **Не читай больше ~30 изображений за сессию** — провайдер рвёт сессию, агент «зависает».
  Проверяй `grep`/логи/`hyprctl`; скрины по минимуму; много картинок — собирай в одну
  (`magick montage ... -tile 6x -geometry 300x169`).
- Не раздувай контекст: режь вывод (`grep`, `tail`, `cut`, `head`, `sed -n`), большие выводы — в файл.
- Не чейни команды через `echo "===="` / `printf '---'` — шумно.
- Убивай процессы по PID или `pkill -x <имя>`. **Никогда не `pkill -f`** — бьёт по своему же шеллу.
- Не запускай `edit` и `cp`/`git add` в одном параллельном блоке.
- Библиотеки — Context7/интернет; локально — `qmltypes` в `/usr/lib/qt6/qml/Quickshell/`, `strings /usr/bin/quickshell`.
- **Никогда не гаси экран на живой сессии** — DPMS off оставлял чёрный экран.
- Длинные прогоны (`install.sh`, установка пакетов) — в фоне.
- После тестов UI **закрывай за собой**: `qs ipc call hub close` / `sidebar close` / `rsidebar close`;
  не оставляй лишних окон и процессов (firefox, sddm-greeter, запись).
- **Только ПК.** Яркость удалена (см. §6).
- BIOS/загрузка: GRUB, initramfs, EFI — только с бэкапом и крайней осторожностью.
  GRUB-тему не делать.
- В конце задачи — коротко: что сделал, что проверено, что осталось.

- **Агент риса (`LunarAgent`).** Действия сам не запускает: предлагает блок
  `lunar-action`, оверлей показывает карточку и выполняет только из белого списка
  и **без shell** (argv). `hyprctl` — чтение и `eval`/`dispatch` только с
  диспетчерами `hl.dsp.*` (без `exec_raw`/`os`/`io`/`..`). Не расширять whitelist
  без проверки: это единственная граница между агентом и системой.

## 1.1 Аудит субагентами: сначала материал, потом запуск

Перед запуском аудиторов (`rice-adversary`, `rice-reviewer`) и любых субагентов
готовь материал в `/tmp/opencode/` — им так дешевле, и они не уходят «вширь»
(красный агент уже выбивал лимит шагов и возвращал черновики вместо отчёта):

```sh
git log --oneline <база>..<HEAD> > /tmp/opencode/audit-<тема>.log
git diff          <база>..<HEAD> > /tmp/opencode/audit-<тема>.diff   # + --stat для затравки
```

В промт субагенту вложи:
- путь к диффу и логу **первым делом**; базу и HEAD; список изменённых файлов;
- одну строку «что чинили/меняли» и какие факты уже проверены на живой системе;
- порядок работы: «сначала дифф целиком → потом точечно нужные файлы → сразу отчёт»;
- «если шаги кончаются — стоп и отчёт», «ничего не меняй» (только чтение);
- формат отчёта и требование писать по-русски, сжато;
- известные грабли, чтобы не тратили шаги: `/boot` доступен только root (пустой
  вывод без `sudo` ≠ «файла нет»); shell у субагента может быть недоступен.

`<база>` — предыдущий проверенный HEAD (состояние прошлого аудита), а не «начало».

## 1.2 Скриншоты и бинари

- Скриншоты — по минимуму: снимаю только то, что нужно для проверки или README, и
  **переиспользую имена** (`assets/screens/<раздел>.png`), не плодя вариантов с датами.
- Черновые и промежуточные кадры в git **не коммичу** — снимаю в `/tmp/shots/`; галерея
  не свалка, тяжёлые PNG раздувают `.git`.
- `.gitattributes` держит бинари без diff/merge (`binary`), скриншоты — `-diff`.
- Историю не переписываю: лишний кадр убираю обычным коммитом (старые объекты остаются
  в истории — это осознанно). `filter-branch`/BFG не применяю, `git gc` — без переписывания.

## 2. Рабочий цикл

```sh
cd /home/sora/rice
# 1) правишь .config/... в репо
# 2) копируешь в живое:
cp .config/quickshell/X.qml ~/.config/quickshell/
cp .config/hypr/hyprland.lua ~/.config/hypr/
cp .config/hypr/scripts/X.sh ~/.config/hypr/scripts/
cp systemd/user/foo.service ~/.config/systemd/user/ && systemctl --user daemon-reload
# 3) Hyprland:
hyprctl reload; hyprctl configerrors        # должно быть пусто
# 4) Quickshell (systemd, Restart=on-failure):
systemctl --user restart lunar-quickshell.service
sleep 6; systemctl --user is-active lunar-quickshell.service
L=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1)
strings "$L" | grep -iE "error|not a type|TypeError|ReferenceError|SyntaxError|Cannot assign|upper case" | grep -vi blackholed
# 5) IPC:
qs ipc call hub toggle|open|close|nav N          # nav 0..8 (см. §4)
qs ipc call sidebar|rsidebar|clipboard|volume|media|power|tray toggle|open|close
# 6) скриншот (по минимуму): mkdir -p /tmp/shots; grim -o DP-2 /tmp/shots/x.png
#    сначала уйди на ПУСТОЙ стол:
hyprctl eval 'hl.dispatch(hl.dsp.focus({workspace=5}))'
# 7) полная установка: ./install.sh [флаги]      # см. §8
```

- Диспатчеры Hyprland — только через `hl.dispatch`: `hyprctl eval 'hl.dispatch(hl.dsp.focus({workspace=N}))'`.
  Голое `hl.dsp.focus({...})` возвращает `ok`, но стол **не** переключает. `hyprctl keyword` не работает.
- После правок проверяй баланс скобок скриптом.
- Нагрузка: `systemctl --user show lunar-quickshell.service -p CPUUsageNSec --value` — два чтения с интервалом
  (весь cgroup). `ps %cpu` врёт.
- Память — `VmRSS` из `/proc/<pid>/status`, а не `VmSize`.
- Тест UI без ввода: временно впиши значение в живую копию → перезапусти Quickshell → скрин →
  восстанови из репо (`cp repo live`) и перезапусти. Hover `cursor.move` не даёт.
  Для съёмки сайдбаров временно увеличь `hideTimer` (600 → 600000) в живой копии.

## 3. Окружение

- Arch. **Hyprland 0.56.2 в Lua-режиме**: `~/.config/hypr/hyprland.lua`, `configProvider: lua`.
  Конфиг 0.55+ — Lua (`hl.animation`, `hl.windowrule`), не старый строчный формат.
- Диспатчеры: `hl.dsp.focus({workspace=N})`, `hl.dsp.cursor.move({x=,y=})`,
  `hl.dsp.window.fullscreen({mode="maximized"|"fullscreen"})`.
  В 0.56 у `hl.dsp.window` есть close, kill, float, fullscreen, pseudo, move, swap, center,
  cycle_next, pin, bring_to_top, drag, resize… **НЕТ `cycle_prev`** → «предыдущее окно» = `cycle_next({ next = false })`.
  **Осторожно:** `hl.dsp.window.move({ workspace = N })` переносит АКТИВНОЕ окно — проверяй `activewindow`.
- Бинды матчатся по первой раскладке (`kb_layout = "us,ru"` → по `us`).
- **Quickshell 0.3.1**, юнит `lunar-quickshell.service`. QtQuick 6.11: есть Shapes/Effects/Particles.
  `MultiEffect` работает (монохром обложки; маски через `maskEnabled`/`maskSource`).
  `Qt5Compat.GraphicalEffects` нет. Qt6 `ShaderEffect` **не** принимает GLSL-строку — только `.qsb`
  (`qt6-shadertools` нет); градиенты — Canvas/`Rectangle.gradient`.
- Типы Quickshell: `Process`, `SplitParser`, `StdioCollector`, `FileView` (+`JsonAdapter`), `Socket`, `IpcHandler`.
  `Quickshell.env("VAR")`. `Process.exited(exitCode)` → `onExited: (exitCode) => {}`.
- Hyprland API: `Hyprland.activeToplevel(+activeToplevelChanged)`, `Hyprland.toplevels`
  (UntypedObjectModel, `.values`), `Hyprland.workspaces.values`, `Hyprland.rawEvent(event)` (`event.name`/`event.data`).
- cava: два конфига — `cava-lunar.conf` (20 полос, бар), `cava-lunar-wide.conf` (56 полос, сайдбар). Читать `SplitParser`.
- **GPU-зависимые настройки — только условно.** Переменные NVIDIA (`hyprland.lua`) включаются по
  `/sys/class/drm/*/device/vendor` (`0x10de`), иначе ломается рендер на AMD/Intel.
  Драйвер NVIDIA в Arch 615 — `nvidia-open` (`nvidia-open-dkms` — для нештатных ядер;
  проприетарного `nvidia-dkms` больше нет).
- systemd-user: `lunar-quickshell` (+`lunar-quickshell-failure`),
  `lunar-homepage`, `lunar-player`, `lunar-tgproxy`.
  systemd system: `zapret.service`, `cronie.service`, `lunar-cpu-performance*.service`;
  `fwupd.service` (static).
- Пакеты, которые **не трогать** (стоят, не удалять): `noto-fonts-cjk`, `qt5-wayland`,
  `vim/nano`, `openssh`, `wget`, `smartmontools`, `lsof`, `pipewire-jack`.
  **Не ставить** без нужды: `chromium`, `nodejs`/`npm`, `inter-font`, `socat`.
- Рабочая машина: RTX 5070 + Ryzen 7 7700 + 32 ГБ, монитор DP-2 3440×1440@165.
  Работаем на ПК; скриншоты — `grim -o DP-2`.
- **polkit:** свой агент `LunarPolkit.qml` (`Quickshell.Services.Polkit`) вместо
  `polkit-kde-authentication-agent-1` (его запуск убран из `hyprland.lua`).
- **Quickshell reload:** встроенный светлый попап о сбое заглушён
  (`QS_NO_RELOAD_POPUP=1` в юните), ошибка идёт уведомлением mako (`shell.qml`).
- **Wi-Fi:** ассоциирует **iwd** (`iwd.service`, `/etc/iwd/main.conf`:
  `EnableNetworkConfiguration=false` + `PowerSaveDisable=ath12k*`), IP раздаёт
  **systemd-networkd** (`/etc/systemd/network/20-wlan.network`); NetworkManager
  не используем. Поиск сетей — `iwctl station wlan0 get-networks` (без sudo).
- **Сеть:** дроп-ин `zapret/wait-online-any.conf` — `systemd-networkd-wait-online`
  не ждёт неактивный `wlan0` (иначе zapret стартует только через 2 минуты).
- **Автозапуск:** firefox (стол 2) и discord (стол 3) из `hyprland.start`, тихо.
- **Обзор столов:** `SUPER+O` / `SUPER+SHIFT+TAB`; окна перетаскиваются между столами.
- **Меню трея (ПКМ):** штатные меню Quickshell (QMenu) работают только в режиме
  `QApplication` (`//@ pragma UseQApplication` в `shell.qml`). Палитру даёт
  `QT_QPA_PLATFORMTHEME=qt6ct`: `~/.config/qt6ct/qt6ct.conf` — обязательно
  `custom_palette=true` + своя схема `.config/qt6ct/colors/lunar.conf` (фон
  #050505, текст #ffffff, акцент #ff003c) и `icon_theme=Tela-dark` (обычная
  цветная Tela; монохром Tela-lunar больше не собираю, кастомная иконка
  Firefox `lunar-eclipse` живёт в hicolor). Без
  `custom_palette=true` меню были белыми.
- **faillock:** после 3 неудачных попыток (считается и отменённый polkit-запрос)
  пароль «перестаёт подходить» — лечится `truncate -s 0 /run/faillock/sora`.

## 4. Структура

```
/home/sora/rice/
├── .config/
│   ├── hypr/{hyprland.lua, hypridle.conf, scripts/}
│   │   └── scripts/eclipse-{status,gamemode,record,cleanup,transparency,zapret,zapret-tg,vencord,backup,update,perf,avatar,launch,agent-context,api-limit,media,mono-icons,wifi}.sh,
│   │       eclipse-palette.py, eclipse-calendar.py, eclipse-cheatsheet.py, eclipse-askpass.py
│   ├── quickshell/
│   │   ├── shell.qml грузит: LunarWallpaper, LunarPanel, LunarHub, LunarWallpapers,
│   │   │   LunarClipboard, LunarPower, LunarAgent, LunarOverview, LunarPolkit,
│   │   │   LunarPlayer, LunarSidebar, LunarSidebarRight, LunarOsd, LunarTray
│   │   ├── Lunar*.qml, LunarWallpaperScene.qml, preview.qml, Slider.qml, Theme.qml,
│   │   │   AppModel.qml, HudCorners.qml
│   │   ├── widgets/shared/ (ActionButton, Cell, HoverBg, MiniBar — общий слой),
│   │   │   SettingsPages/ (страницы и секции), assets/ (+moon-phases/, crop-frame.png), pfp3.png,
│   │   │   cava-lunar.conf, cava-lunar-wide.conf
│   ├── avatars/avatar.png       ← единый аватар (рис + экран входа)
│   ├── lunar/{home/firefox-home.html, lunar.bash, gamemode-pause.conf}
│   ├── lunar/{palette.toml, templates/*.in}   ← единая палитра: пресеты + шаблоны
│   ├── fontconfig/fonts.conf                  ← хинтинг/сглаживание (чёткие буквы)
│   ├── bat/ Code/ yazi/ firefox/ hypridle/ mako/ kitty/ fastfetch/ btop/ zsh/
│   └── gtk-3.0/ gtk-4.0/ kdeglobals/ .zshrc starship.toml
├── systemd/{user,system,libexec,sudoers,conf}/  color-schemes/  assets/(+screens/)  zapret/
├── plymouth/lunar/   sddm/lunar/        ← только темы + README
├── install/{dotfiles,system,optional}.sh   ← части установщика
├── packaging/lunar-helpers/{PKGBUILD,*.install} ← root-хелперы в пакете (/usr/libexec/lunar)
├── deps/{packages.txt,aur.txt,snapshot.sh} ← манифест пакетов + снимок версий
├── lunar  doctor.sh  reload.sh            ← точка входа + health-check + перезагрузка риса
├── install.sh get-deps.sh ui.sh release.sh bump.sh
└── README.md LICENSE VERSION AGENTS.md PORTABILITY.md lunar-dorabotki.md .gitattributes
    HANDOFF.md — только локально, в .gitignore
```

- `shell.qml` — корневой `ShellRoot`. Синглтоны (`pragma Singleton`): `Theme`, `AppModel`.
- Hub-страницы (nav, 9): 0 Launch ·1 System ·2 Devices ·3 Network ·4 Interface ·
  5 Games ·6 Dev ·7 Update ·8 Media. Обои (сцена или картинки) — внутри Interface и в окне
  подбора `LunarWallpapers` (IPC `wallpapers`, хоткей `SUPER + B`): оверлей-веер с зумом
  от центра, инерционный глайд, затемнение и подтверждение; картинки — из миниатюр
  `~/.cache/lunar/wall-thumbs`, сами обои — `~/Pictures/Wallpapers` (набор 43PR, 21:9).
- Левый сайдбар: 0 api-limit ·1 заметки. Правый: 0 календарь ·1 запись.
- 9 столов: 1 игры ·2 Firefox ·3 Discord ·4 Steam ·5 затмение/пусто ·6 кодинг ·7/8 пусто ·9 btop.
  **Фаза обоев = номер стола.**
- **Единый установщик** `install.sh` (флаги в §8) — тонкий оркестратор: разбор флагов и счётчик шагов, а работа по частям — `install/dotfiles.sh` (пользовательское), `install/system.sh` (root), `install/optional.sh` (SDDM/Plymouth/zapret). Отдельных sddm/plymouth/zapret-скриптов больше нет.
- Настройки записи: `~/.config/lunar/record.json` (Hub → Monitors), читает `eclipse-record.sh`.
- Палитра: источник — `~/.config/lunar/palette.toml` + шаблоны `lunar/templates/*.in`;
  `hypr/scripts/eclipse-palette.py` раскладывает цвета в файлы приложений (kitty include,
  GTK @import, mako include, qt6ct, btop, yazi, fastfetch) и `~/.cache/lunar/palette.json`
  (читает Theme.qml). Выходы — производные: в git не трекаются (`.gitignore`), при установке
  создаются заново; в `templates/` генератор не пишет. Выбор пресета: `~/.cache/lunar/preset`,
  картинка фотопалитры: `~/.cache/lunar/photo`.
- `assets/screens/` — галерея README, не удалять.

## 5. Стиль

- Палитра — из `~/.cache/lunar/palette.json` (пишет `eclipse-palette.py` из `lunar/palette.toml`).
  Пресеты: **lunar** (по умолчанию, холодный монохром), **graphite** (чёрный, но с лёгким
  холодом — чистый нейтрал на тёплых матрицах читается коричневым), **steel** (серо-синий
  с акцентом), **photo** (`--from-image`: цвет считается с обоев). В `Theme.qml` цвета
  читаются через `hexColor()`: палитра пишет `#RRGGBBAA`, а Qt ждёт `#AARRGGBB`.
- Флэт, без глянца: плашки панели плотные (`barPill` альфа `arch?0.95:0.85`),
  радиус плашек `arch?3:9`, окон 8,
  зазоры окон 5/10, тень короткая (`range 8`, `render_power 3`), зерно тихое (0.07).
  Градиент-блик сверху («стекло») не добавлять — это читается глянцем из нулевых.
- Шрифт интерфейса — `Roboto Mono` (моно, полная кириллица, все веса), иконки —
  `JetBrainsMono Nerd Font`. Не писать имена семейств, которых нет в системе
  (`"JetBrains Mono"`, `Iosevka NFM` без установки) — Qt молча подставит Noto.
- Токены `Theme.qml`: отступы `space1..6` 4/8/12/20/28/32; строки `rowHCompact/rowH/rowHComfy`
  38/42/48, `headerH` 44; радиусы classic `radiusS/radius/radiusM/radiusL` 6/8/10/12
  (arch 0/2/3/4); текст
  `fontMicro/fontTiny/fontSmall/fontBody/fontPanelTitle/fontTitle/fontClock` 9/11/12/14/16/22/16;
  панель `barH/barMargin/barTop/barPad/barRadius` classic 34/5/5/16/9 (arch 38/0/8/16/3),
  ячейка бара `barCellH` 30,
  строки панелей `panelFieldH/panelRowH/sparkH` 46/36/26; `iconXL/cardPad` 30/16;
  `hoverGrow` 1.25 (ховер-рост групп панели); `hover/hoverStrong/active/activeBorder/fill/onAccent`;
  `tooltipDelay` 600; `clamp()`.
- HUD-заголовки секций: `SectionHeader` (`[ ПОДПИСЬ ]` + линия + узел; дефолт 11px `fontTiny`,
  letterSpacing 2, bold; на страницах Hub и в сайдбарах `size` задаётся явно — 11/12/14/15).
  Заголовки страниц Hub: `fontTitle`. (`SectionLabel` удалён.)
- Ховер: `scale` (визуальный, раскладку не трогает) + фоновая подсветка.
- Плавные заполнения: анимация по токену движения (`Theme.animMed`) и заполнение с нуля
  (старт 0 → `Timer{interval:60}` → целевое; `enabled: !pressed`).
- Один акцент — белый (или акцент пресета); красный — «опасное». Зелёного в рисе нет:
  `ok` в палитре тоже нейтральный (светлый) — зелёные «успехи» пользователь убрал.
- Классические серпы/«монеты»/тёмная сторона у иконок фаз — не использовать.

## 6. Закрытые темы (НЕ предлагать)

- Батарея и всё ноутбучное — не нужно.
- Яркость (`XF86MonBrightness`, `brightnessctl`, `ddcutil`, `i2c-dev`) — удалена.
- Профили питания (`power-profiles-daemon`, balanced/powersave) — убраны: CPU всегда
  `performance` (юнит `lunar-cpu-performance`), powersave не возвращать.
- Игры — через **Lutris и Steam** (официальные клиенты + Proton/GE-Proton).
  AAGL и всё, что его касается, вырезано навсегда — не возвращать.
- GPU-выбор — только дискретная NVIDIA: `VK_ICD_FILENAMES=nvidia_icd.json`;
  GPU-env обязан доходить до systemd --user (иначе запуски из Hub уедут на iGPU).
- Обои: два режима (`Theme.wallpaperMode`) — `scene` (QML-сцена затмения, по умолчанию)
  и `image` (картинка с диска; подбор — окно `LunarWallpapers`, `SUPER + B`). Смена картинки
  идёт кроссфейдом в `LunarWallpaper.qml`; в режиме `image` сцена не тикает.
- Видео-обои (mpvpaper/awww, webm/zoompan, headless-Chromium) — убраны.
- `svappy`/редактор скриншотов (PRINT = область в буфер).
- Мониторные хоткеи (`SUPER+,/.`) — не нужны, один экран.
- «Discord падает на слабом GPU» — не баг риса.
- `LunarLauncher.qml`/`LunarSettings.qml` — мусор, удалены; лаунчер = Hub.
- Автогашение экрана и автолок — выключены намеренно.
- Wi-Fi: поднимаем через **iwd** (ассоциация) + **systemd-networkd** (IP), не через
  NetworkManager; powersave для `ath12k*` выключен (`PowerSaveDisable`). Мёртвая
  Wi-Fi-обвязка (NM-dispatcher, гвард, MediaTek-ASPM) удалена и не возвращается.
- Параллакс обоев к курсору — не нужен.
- `ShaderEffect`/`.qsb` для короны (Quickshell, Qt6) — не подключать.
- Полноэкранный блюр layer-оверлеев (`layer_rule … blur` на fullscreen-слой) — НЕ включать:
  Quickshell держит оверлеи fullscreen-слоями, Hyprland блюрит слой целиком → GPU 20→54%.
  Крупные модалки (Hub/буфер/питание/агент/плеер) для этого переведены в обычные окна.
- `decoration:screen_shader` — НЕ включать: он отключает damage tracking, и Hyprland сам пишет
  «massively increase GPU utilization». Зерно делаем тайлами (`blur:noise` + PNG-шум), не шейдером.
- Обёртку `opencode` в scope с `MemoryHigh/Max` (функция в `~/.zshrc`) — не убирать: она держит
  OOM сессии внутри scope, чтобы не ронять всю систему.
- GRUB-тема — не делать.
- «Экономный» пресет — уже есть тумблер **OPTIMIZE** (Hub → Interface), по умолчанию включён.
- Отдельные установщики sddm/plymouth/zapret — не возвращать, всё в `install.sh`.
- `MemoryMax`/`MemoryHigh` и `Restart=always` для quickshell — не ставить (OOM / краш-луп).
- Уже сделаны, не переделывать без просьбы: hover-подсветка секций; импульс кольца стола;
  плавное двоеточие часов; выбор вывода/входа в звуке; единый поиск в Hub; линия/cava в полосе медиа;
  гладкая корона; статичное гало; заметный OPTIMIZE; показатели группами с иконками.

## 7. Грабли (проверено)

**Система и установка**

- `informant`: хук `00-informant.hook` блокирует ЛЮБУЮ транзакцию pacman при непрочитанных новостях.
  Читать от root: `sudo informant read --all`.
- НЕ ставить `systemd-libs` отдельно — частичный апгрейд ломает systemd.
- Steam на AMD/Intel: явно `vulkan-radeon` + `lib32-vulkan-radeon`.
- `install.sh`: `| head` под `set -o pipefail` роняет скрипт (exit 141) — `|| true`.
- `install.sh` спрашивает root один раз: `ensure_root` (один `sudo -v`, дальше системные
  команды через `sudo -n`); нет root — одно предупреждение, системная часть пропускается.
- `pacman -Rns` может унести нужное → сначала `pacman -Rs --print`.
- `timeshift` печатает безобидное `status: No such file or directory`.
- **UKI/загрузка:** `mtime` — красная селёдка (objcopy копирует mtime stub), проверять содержимое
  `objcopy --dump-section .uname=… /boot/EFI/Linux/arch-linux.efi`. Параметры ядра зашиты в UKI
  из `/etc/kernel/cmdline`; `GRUB_CMDLINE_LINUX_DEFAULT` туда не попадает.
  `10_linux` на UKI делает первым пункт без initramfs → паника; лечение `chmod -x /etc/grub.d/10_linux`.
- Plymouth: тема — script-модуль; проверка `plymouth-set-default-theme -l`.
  Резервный UKI без заставки — лучший откат.
- SDDM-greeter на Qt5: QtQuick 2.0 + SddmComponents 2.0; `Rectangle.radius` не скругляет содержимое →
  круглый аватар через `ShaderEffect` (премноженная альфа). Дата — вручную по-русски.
- **Hyprland Lua — точные имена API.** События в `hl.on(...)` точечные: `config.reloaded`,
  `hyprland.start`, `workspace.created`, `window.open_early` и т.п. — **НЕ** слитные
  (`hl.on("configreloaded", …)` валит весь конфиг: «unknown event»). Полный список валидных
  имён печатается в тексте этой ошибки; `strings /usr/bin/Hyprland` даёт и слитную строку —
  ей верить нельзя. После правки `hyprland.lua` — `hyprctl reload` и `hyprctl configerrors`
  (пусто!), причём ошибку в имени события `configerrors` показывает не всегда — смотри и
  вывод самого `hyprctl reload`. Общее правило: имена хостовых API (Lua/QML/Quickshell)
  не угадывать по бинарю, а сверять по докам/стабам и живым вызовом.

**Quickshell / QML (свежее, 1.81–1.100)**
- `Behavior` нельзя объявить отдельным компонентом (`component Grow: Behavior on scale …`)
  и подставлять объектом — Quickshell падает на старте и упирается в `start-limit-hit`.
  Только инлайн рядом со свойством: `Behavior on scale { … }`.
- `anchors.fill` внутри `Row` — ошибка верстки («Row will not function»): оборачивай в `Item`.
- `FloatingWindow` — не `Item`: `Keys.*` и `forceActiveFocus()` на нём не работают,
  вешай их на внутренний `Item` с `focus: true`.
- Палитра: выбранный пресет помню в `~/.cache/lunar/preset`, картинка фотопалитры —
  в `~/.cache/lunar/photo` (иначе переустановка вернёт «заводской» пресет).
- `SUPER + W` занят разворотом окна — подбор обоев на `SUPER + B`.

**Quickshell / QML**

- Имена свойств не могут начинаться с заглавной буквы → страница не грузится.
- `color` НЕ принимает CSS `rgba(...)` — только `#AARRGGBB`/`Qt.rgba`.
- Один `id` нельзя дважды; нельзя дважды присвоить property.
- `QtObject` (`Theme`, `AppModel`) не имеет default property → дочерние только как свойства
  (`property Process p: Process {…}`).
- В кастомной кнопке `MouseArea { onClicked: clicked() }` бьёт по сигналу MouseArea → `parent.clicked()`.
- `CustomSlider` шлёт `valueChanged` при программной установке → для «только от пользователя» есть `moved`.
- `Item` НЕ имеет `radius` (только `Rectangle`).
- `Repeater.itemAt` в биндинге не пересчитывается — добавь зависимость от `count`.
- Вложенные `Repeater` не видят `modelData` внешнего делегата → inline-компонент.
- `Repeater` внутри Row/RowLayout: делегат `required property`; ширина через `parent.width`.
- `Quickshell.iconPath` без иконки в теме даёт магента-заглушку → `hasThemeIcon`.
- `IpcHandler` show/hide конфликтуют с `PanelWindow` → `open`/`close`.
- `hyprland.lua` `layer_rule` по namespace блюрит и фоновый слой — у обоев отдельный namespace.
  Hub без блюра: `WlrLayershell.namespace: "lunar-hub"`.
- Overlay выше окон: zenity оказывается ПОД Hub → на время диалога `hub close`/`open`.
- Quickshell не создаёт/уничтожает объекты динамически (нет `createObject`/`destroy`):
  частицы обоев — делегаты `Repeater`, при `model=[]` удаляются сами.
- Фон оверлея рисуется всегда → прозрачность только при `showing`.
- `qmllint` 1.0 падает (255) на `IpcHandler` — не полагайся на него.
- Раннер `qml` иногда отдаёт «Did not load any objects»; рабочий — `qml6`.
- OSD не всплывает при старте: первый замер только запоминаем (`primed`).
- «Заполнение с нуля»: значение в `shown`, старт 0, `Timer{interval:60}`, `Behavior on width { enabled: !pressed }`.
- Персистентность: `FileView` + `JsonAdapter`, `onAdapterUpdated: writeAdapter()`, `statePath` →
  `by-shell/<id>/`. Для известного пути — `path: Quickshell.env("HOME") + "/….json"`.
- FontAwesome: play `\uf04b`, pause `\uf04c`, prev `\uf048`, next `\uf051`, музыка `\uf001`,
  солнце `\uf185`, close `\uf00d`, user `\uf007`, update `\uf021`, video `\uf03d`.
- Скрытые сайдбары сворачиваются через 600 мс — для съёмки увеличь таймер в живой копии.
- Контекст агента в чате сайдбара — в сессии OpenCode (`--session`); `messages` в QML — только витрина,
  её можно смело ограничивать.
- Хост-API Hyprland: `Hyprland.usingLua` врёт → `hyprctl -j status` (`configProvider`).
  `Hyprland.activeWorkspace` не всегда объект → фолбэк на `focusedWorkspace`.
- MPRIS (Quickshell): `trackArtUrl`, `trackTitle`/`Artist`, `isPlaying`, `canSeek`, `canGoNext/Previous`,
  `position` (write), `seek(offset)`, `togglePlaying`/`next`/`previous`.

**Живая система и мелочи**

- mako: `include=` обязан идти ДО первой секции (`[urgency=…]`), иначе «InvalidConfig»;
  цвета urgency — только из include, в основном конфиге остаются лишь таймауты.
- Проверки экрана: `grim -g "X,Y WxH"` (не `WxH+X+Y`), `-o` и `-g` несовместимы. Окно
  OpenCode живёт в scratchpad (`kitty`, почти во весь экран) — для чистых скринов его прятать
  (`hl.dsp.workspace.toggle_special("scratchpad")`) или замерять пиксель у самого края экрана.
- Не бросай `magick`/массовые конвертации без присмотра: прерванный `magick montage`
  на сотни картинок завис в состоянии `D` и съел 18 ГБ (лечится `kill -9`). Проверять
  `ps -eo pid,stat,rss,comm --sort=-rss | head` и `free -h`; сотни картинок монтировать
  частями, а не одной командой.
- Цвет из картинки: `eclipse-palette.py --from-image ФАЙЛ --apply` (доминирующий цвет через
  ImageMagick → фон/панель/акцент/текст; результат — пресет `photo`).
- `cliphist delete` читает stdin: `cliphist list | grep -P '^ID\t' | cliphist delete`.
- DND: `makoctl mode -t do-not-disturb`.
- Круглая маска magick: `magick in -resize 512x512 \( -size 512x512 xc:black -fill white -draw "circle 256,256 256,2" \) -alpha off -compose CopyOpacity -composite PNG32:out`.
- Root-хелперы риса (`/usr/libexec/lunar/`: `avatar-sync.sh`, `journal-read.sh`,
  `journal-vacuum.sh`, `svc.sh`, `update.sh`, `cpu-performance.sh`) ставит
  `install.sh` (0755 root:root) — **пакетом `lunar-helpers`**
  (`packaging/lunar-helpers/PKGBUILD`, `makepkg -sif` от пользователя), а без
  `base-devel` — прежним копированием (fallback, путь тот же). Обновлять
  хелперы так: правишь `systemd/libexec/lunar-*.sh` → `./bump.sh patch` →
  `cd packaging/lunar-helpers && updpkgsums` (sha256 источников-симлинков) →
  `./install.sh` собирает и ставит пакет. Пакет кладёт файлы под именами без
  префикса `lunar-` (`lunar-svc.sh` → `svc.sh`). В sudoers — только они
  (аргументы валидируются внутри), без масок по пользовательским скриптам.
  Управление сервисами — только через `svc.sh` (allowlist юнитов внутри:
  `zapret.service`, `sddm.service`, `bluetooth.service`); голый `systemctl`
  из sudoers убран. Обновление системы — только через `update.sh`
  (`pacman -Syu` без `--noconfirm`: подтверждение за человеком); широкий
  NOPASSWD на `pacman` убран. Журнал читать через
  `sudo -n /usr/libexec/lunar/journal-read.sh …` — у raw
  `journalctl` отозваны мутирующие режимы (`--vacuum`/`--rotate`).
- CPU всегда `performance`: системный юнит `lunar-cpu-performance` зовёт
  `/usr/libexec/lunar/cpu-performance.sh` (root, вне sudoers); он же гасит
  `power-profiles-daemon` (balanced/powersave).
- `eclipse-askpass.py` — интерактивный GTK-диалог пароля (не автоподстановка).
- Скрины для README: `grim -o DP-2` (3440×1440) → `magick … -resize 1600x900 -strip`.
- `/tmp/shots` может исчезнуть между вызовами — `mkdir -p`.
- Firefox managed-storage: `{name, type:"storage", data:{…}}`; нужен рестарт.
  `browser.newtabpage.enabled=false` мешает перехвату `about:newtab` — держать `true`.
- `vencordinstaller`: `-location` и `-branch` взаимоисключающие.
- fastfetch монохром: `display.color{…}` + `logo.color{1..9}`. bat монохром: `--theme="ansi"`.
- Юнит-гвард: `ExecStartPre=/usr/bin/sh -c 'test -S "$$XDG_RUNTIME_DIR/$$WAYLAND_DISPLAY"'` —
  `$$` systemd превращает в литерал `$`, дальше разворачивает shell.
- **«Глухой» шелл после перелогина** (рисует, столы не работают): причина — в systemd-env не было
  `HYPRLAND_INSTANCE_SIGNATURE`. Лечение: `hyprland.lua` импортирует env и делает
  `systemctl --user --no-block restart lunar-quickshell.service` (именно restart, не start).
  Диагностика: `systemctl --user show-environment | grep HYPR`.
- Крах quickshell без дисплея → core dump (SIGABRT, «no Qt platform plugin»). Гвард + `on-failure` лечат.
- `opencode run --format json` стримит события.

## 8. Быстрые команды

```sh
./lunar help                                                   # точка входа: install|deps|sync|bump|ci|doctor|palette|snapshot|release|reload
./doctor.sh                                                    # health-check риса (шелл/конфиг/сеть/демоны/палитра/дрейф/ci)
./lunar reload                                                 # перезагрузить рис БЕЗ приложений (hyprctl + quickshell + mako + hypridle + cliphist)
./install.sh [--sddm|--plymouth|--zapret|--status|--disable-sddm|--disable-plymouth|--plymouth-rescue|--no-deps|--deps-only]
~/.config/hypr/scripts/eclipse-palette.py                      # палитра: dry-run
~/.config/hypr/scripts/eclipse-palette.py --preset graphite --apply
~/.config/hypr/scripts/eclipse-palette.py --from-image ~/Pictures/wall.jpg --apply
qs ipc call wallpapers toggle|open|close                       # подбор обоев (SUPER + B)
qs ipc call hub nav N                                          # 0..8 (см. §4)
sddm-greeter --test-mode --theme /usr/share/sddm/themes/lunar      # предпросмотр входа
~/.config/hypr/scripts/eclipse-avatar.sh pick|apply <cs> <cx> <cy> [/путь]
~/.config/hypr/scripts/eclipse-record.sh probe                     # проверка записи
sudo ~/rice/install.sh --disable-sddm && sudo systemctl restart sddm   # откат SDDM из TTY
sudo ~/rice/install.sh --disable-plymouth                          # откат Plymouth
sudo mkinitcpio -P                                                 # сборка UKI
./bump.sh patch|minor|major                                        # поднять VERSION (semver)
```

Релиз: `./release.sh` — тег `v<VERSION>` уходит в origin, GitHub Actions
(`.github/workflows/release.yml`) сам создаёт Release с заметками из коммитов.
Пуш атомарный (`git push --atomic origin HEAD "$TAG"`): ветка и тег уходят
одной транзакцией, обрыв не оставит «половину» релиза. Перед тегом скрипт
проверяет доступ к origin (`git ls-remote`) и внятно падает, если remote нет
или он недоступен. `release.sh` не даст тегнуть `VERSION` меньше последнего
тега `v*` (равный — только с `--force`). Перед релизом рабочее дерево чистое.
`./doctor.sh` предупредит, если `VERSION` ушёл вперёд последнего тега больше
чем на минор, — значит, релизы не выпускались.
Опциональный хук `.githooks/pre-commit` (не блокирует) напоминает про VERSION;
включить: `git config core.hooksPath .githooks`.
Зависимости: `./get-deps.sh`. Списки пакетов — `deps/packages.txt` (официальные,
секции `[base]/[updates]/[games]/[zapret]`, GPU-секции `[gpu-amd]/[gpu-intel]/[gpu-nvidia]/[gpu-mesa]`)
и `deps/aur.txt` (AUR). Править только эти файлы: `get-deps.sh` читает их и больше списков не
хранит. GPU-секцию выбирает скрипт по `/sys/class/drm/*/device/vendor` (NVIDIA добавляет
`*-headers` под текущее ядро). Снимок установленных версий для справки (не пин):
`./deps/snapshot.sh` → `deps/snapshot-<дата>.txt`.

## 9. Lunar Player, окна, стекло и зерно (1.76–1.79)

**Плеер.** `PlayerCore.qml` (синглтон) — прямой JSON IPC к mpv: юнит `lunar-player.service`
(on-demand; `ExecStopPost` чистит сокет), поиск через `yt-dlp`, локальная `~/Music`, очередь,
обложки YouTube. UI — окно `LunarPlayer.qml` (`FloatingWindow`, хоткей `SUPER+M`, IPC `player`):
страницы СЕЙЧАС/ОЧЕРЕДЬ/ПОИСК/ЛОКАЛЬНЫЕ, винил, cava, «лунный seek»; вспомогательные —
`PlayerNowPlaying/PlayerQueue/PlayerSearch/PlayerLibrary/PlayerList/PlayerBar.qml`, конфиг cava —
`cava-player.conf`. Демон гашу, когда плеер закрыт, ничего не играет и очередь пуста
(`maybeStopDaemon`). Грабли сокета — issue #1180 Quickshell (первый неудачный коннект навсегда):
держу `test -S` → `LazyLoader` + пересоздание, иначе Socket «застревает». Ошибки
`PeerClosed/ConnectionRefused` при остановке mpv — норма (юнит теперь сам убирает сокет).

**Оверлеи — обычные окна.** Hub, буфер, питание, агент и плеер — `FloatingWindow`:
Hyprland сам двигает/тянет за края/блюрит/скругляет (`window_rule` по заголовку «Lunar …»).
Слоями остались панель, сайдбары, обзор столов и мелкие попапы (OSD/громкость/медиа/трей).
Клик «мимо» окна больше не закрывает — закрытие Esc/хоткеем/IPC.

**Стекло и зерно.** Блюр — только у мелких поверхностей (панель/сайдбары/окна) плюс всем окнам
`active_opacity 0.94 / inactive 0.90` и `blur:popups`. Зерно — тайлами, НЕ шейдером:
`blur:noise 0.05` + PNG-шум. Терминал — `/home/sora/.config/kitty/noise.png` (RGB `#0c0e13`,
шум в альфе ~0.23; kitty уважает альфу тайла, но НЕ применяет `background_opacity` к картинке).
Бар — `assets/noise.png` (`Image { opacity: 0.12 }` в `LunarPanel.qml`). Полная инструкция и
команды пересборки шума — в комментарии `kitty.conf` (блок «ЗЕРНО В ТЕРМИНАЛЕ»).

**Палитра.** Выровнена по всей системе: kitty, GTK3/4, qt6ct/меню, kdeglobals, btop, mako, yazi,
fastfetch/bat, схема `LunarEclipse.colors`. Бар использует отдельные токены
`Theme.barText/barDim/barFaint/barPill` (текст `#d5dce4`, пилюли `#0c0e13`). Живой kitty
перечитывает конфиг без перезапуска: `kill -USR1 $(pgrep -x kitty)`.

**Предохранитель OpenCode.** Сессию в scratchpad (`SUPER+S`) держат сутками, и она может
раздуться в десятки ГБ (был OOM на ~25 ГБ → фриз всей системы). В `~/.zshrc` — функция `opencode`
запускает её в user-scope с `MemoryHigh=8G/MemoryMax=12G/MemorySwapMax=2G`: при разгоне убьёт
только сессию. Это НЕ рис, но чинить больно — оставить.
