# AGENTS.md — Lunar Eclipse

Рис **Hyprland + Quickshell** на Arch Linux. `./install.sh` копирует `.config/*` в `~/.config`
и **перезаписывает** установленные конфиги.

> Секреты, доступы, текущий `VERSION`, свежие коммиты и список незакрытых задач — в
> `HANDOFF.md` (корень репо, в `.gitignore`, в публичный репозиторий не попадает).
> Если `HANDOFF.md` нет — попроси его у пользователя.

## 0. Роль

Ты — агент, ведущий рис Lunar Eclipse для **AlanMillerSora**. Не выдумывай поведение:
сначала смотри код и проверяй на живой системе. Пиши, комментируй и коммить по-русски.

## 1. Главные правила (соблюдать строго)

- **Сначала покажи и обсуди.** Ничего не делай, пока не сказано «делай» / «делай вариант N».
  Работаем по одной задаче.
- Варианты и уточнения давай инструментом **question**, не списком в чате.
- **Правь ТОЛЬКО репозиторий** `/home/sora/rice/`, затем копируй в `~/.config` — держи repo == live.
- Меняешь поведение → **бампай `VERSION`** (в корне репо): патч — фиксы, минор — новая функциональность.
- **Коммиты — от лица автора риса:** первым лицом, по-русски, что и зачем («убрал серп», «починил…»).
  Никаких «пользователь попросил» / «по правке пользователя» — история будто её ведёт сам автор.
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
- **Не предлагай ничего ноутбучного** — цель ПК. Яркость удалена (см. §6).
- BIOS/загрузка: на дев-ноуте BIOS **заблокирован**, систему не переустановить. GRUB, initramfs, EFI —
  только с бэкапом и крайней осторожностью. GRUB-тему не делать.
- В конце задачи — коротко: что сделал, что проверено, что осталось.

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

## 2. Рабочий цикл

```sh
cd /home/sora/rice
# 1) правишь .config/... в репо
# 2) копируешь в живое:
cp .config/quickshell/X.qml ~/.config/quickshell/
cp .config/hypr/hyprland.lua ~/.config/hypr/
cp .config/hypr/scripts/X.sh ~/.config/hypr/scripts/
cp systemd/foo.service ~/.config/systemd/user/ && systemctl --user daemon-reload
# 3) Hyprland:
hyprctl reload; hyprctl configerrors        # должно быть пусто
# 4) Quickshell (systemd, Restart=on-failure):
systemctl --user restart lunar-quickshell.service
sleep 6; systemctl --user is-active lunar-quickshell.service
L=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1)
strings "$L" | grep -iE "error|not a type|TypeError|ReferenceError|SyntaxError|Cannot assign|upper case" | grep -vi blackholed
# 5) IPC:
qs ipc call hub toggle|open|close|nav N          # nav 0..12 (см. §4)
qs ipc call sidebar|rsidebar|clipboard|volume|media|power|tray toggle|open|close
# 6) скриншот (по минимуму): mkdir -p /tmp/shots; grim -o eDP-1 /tmp/shots/x.png
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
  Драйвер NVIDIA в Arch 615 — `nvidia-open-dkms` (проприетарного `nvidia-dkms` больше нет).
- systemd-user: `lunar-wifi-guard`, `lunar-homepage`, `lunar-quickshell`.
  systemd system: `zapret.service`, `cronie.service`, `fwupd`.
- Пакеты, которые **не трогать**: chromium, noto-fonts-cjk, nodejs/npm, inter-font, qt5-wayland,
  vim/nano, openssh, wget, smartmontools, socat, lsof, pipewire-jack.
- Дев-ноут: eDP-1 1920×1080@60, AMD Ryzen 5 7520U + Radeon 610M.
  Целевой ПК: RTX 5070 + Ryzen 7 7700 + 32 ГБ, 3440×1440.

## 4. Структура

```
/home/sora/rice/
├── .config/
│   ├── hypr/{hyprland.lua, hypridle.conf, scripts/}
│   │   └── scripts/eclipse-{status,gamemode,record,cleanup,transparency,zapret,vencord,backup,update,perf,avatar}.sh,
│   │       eclipse-calendar.py, eclipse-cheatsheet.py, eclipse-askpass.py, eclipse-wifi-guard.py
│   ├── quickshell/
│   │   ├── shell.qml грузит: LunarWallpaper, LunarPanel, LunarHub, LunarSidebar,
│   │   │   LunarSidebarRight, LunarOsd, LunarVolume, LunarMedia, LunarTray, LunarTooltip,
│   │   │   LunarClipboard, LunarPower
│   │   ├── Lunar*.qml, LunarWallpaperScene.qml, preview.qml, Slider.qml, Theme.qml,
│   │   │   AppModel.qml, HudCorners.qml, PerspectivePanel.qml
│   │   ├── SettingsPages/ (13 страниц), assets/ (+moon-phases/, crop-frame.png), pfp3.png,
│   │   │   cava-lunar.conf, cava-lunar-wide.conf
│   ├── avatars/avatar.png       ← единый аватар (рис + экран входа)
│   ├── lunar/{firefox-home.html, lunar.bash, gamemode-pause.conf}
│   ├── bat/ Code/ yazi/ firefox/ hypridle/ mako/ kitty/ fastfetch/ btop/
│   └── gtk-3.0/ gtk-4.0/ kdeglobals/ .zshrc starship.toml
├── systemd/  color-schemes/  assets/(+screens/)  zapret/
├── plymouth/lunar/   sddm/lunar/        ← только темы + README
├── install.sh get-deps.sh ui.sh release.sh
└── README.md LICENSE VERSION AGENTS.md lunar-dorabotki.md
    HANDOFF.md — только локально, в .gitignore
```

- `shell.qml` — корневой `ShellRoot`. Синглтоны (`pragma Singleton`): `Theme`, `AppModel`.
- Hub-страницы (nav): 0 Launch ·1 System ·2 Sound ·3 Monitors ·4 Network ·5 Bluetooth ·
  6 Interface ·7 Memory ·8 Games ·9 Dev ·10 Wallpapers ·11 User ·12 Update.
- Левый сайдбар: 0 чат ·1 заметки. Правый: 0 уведомления ·1 музыка ·2 календарь ·3 запись.
- 9 столов: 1 игры ·2 Firefox ·3 Discord ·4 Steam ·5 затмение/пусто ·6 кодинг ·7/8 пусто ·9 btop.
  **Фаза обоев = номер стола.**
- **Единый установщик** `install.sh` (флаги в §8). Отдельных sddm/plymouth/zapret-скриптов больше нет.
- Настройки записи: `~/.config/lunar/record.json` (Hub → Monitors), читает `eclipse-record.sh`.
- `assets/screens/` — галерея README, не удалять.

## 5. Стиль

- Палитра: фон `#050505`, текст `#ffffff`, dim `#888888`, faint `#4a4a4a`,
  danger `#ff003c`, ok `#00ff9c`. Рамка 1px, радиус 6, HUD-скобки, JetBrains Mono, монохром.
  Всё в `Theme.qml`.
- Токены ритма: `Theme.hover` = accent .06, `hoverStrong` = .08, `active` = .12, `fill` = text .03.
  Прочие: `interfaceOpacity`, `fontScale`, `trayVisible`, `wallpaperLive`, `optimizeMode`,
  `blurSize/-1`, `blurPasses`, `tooltipShown/…`, `volumePopupOpen`, `radius`, `animFast/Med/Slow`,
  `fontFamily`, `iconFont`.
- HUD-заголовки секций: 12px, letterSpacing 2, bold, белый. Заголовки страниц Hub: 18px, letterSpacing 3.
- Плавные заполнения: анимация 200 мс (`Behavior on width`) и заполнение с нуля
  (старт 0 → `Timer{interval:60}` → целевое; `enabled: !pressed`).
- Один акцент — белый; красный — «опасное», зелёный — «ок».
- Классические серпы/«монеты»/тёмная сторона у иконок фаз — не использовать.

## 6. Закрытые темы (НЕ предлагать)

- Батарея и всё ноутбучное.
- Яркость (`XF86MonBrightness`, `brightnessctl`, `ddcutil`, `i2c-dev`) — удалена.
- Статические PNG-обои и их генератор — удалены; обои только QML-сцена (`LunarWallpaper.qml`).
- Видео-обои (mpvpaper/awww, webm/zoompan, headless-Chromium) — убраны.
- `svappy`/редактор скриншотов (PRINT = область в буфер).
- Мониторные хоткеи (`SUPER+,/.`) — не нужны, один экран.
- «Discord падает на слабом iGPU» — не баг риса.
- `LunarLauncher.qml`/`LunarSettings.qml` — мусор, удалены; лаунчер = Hub.
- Автогашение экрана и автолок — выключены намеренно.
- Wi-Fi powersave-off и `mt7921e` ASPM — не трогать.
- Параллакс обоев к курсору — не нужен.
- `ShaderEffect`/`.qsb` для короны (Quickshell, Qt6) — не подключать.
- GRUB-тема — не делать (BIOS заблокирован).
- «Экономный» пресет — уже есть тумблер **OPTIMIZE** (Hub → Interface), по умолчанию включён.
- Отдельные установщики sddm/plymouth/zapret — не возвращать, всё в `install.sh`.
- `MemoryMax`/`MemoryHigh` и `Restart=always` для quickshell — не ставить (OOM / краш-луп).
- Уже сделаны, не переделывать без просьбы: hover-подсветка секций; импульс кольца стола;
  плавное двоеточие часов; выбор вывода/входа в звуке; единый поиск в Hub; линия/cava в полосе медиа;
  гладкая корона; статичное гало; заметный OPTIMIZE; показатели группами с иконками и тултипами.

## 7. Грабли (проверено)

**Система и установка**

- `informant`: хук `00-informant.hook` блокирует ЛЮБУЮ транзакцию pacman при непрочитанных новостях.
  Читать от root: `sudo informant read --all`.
- НЕ ставить `systemd-libs` отдельно — частичный апгрейд ломает systemd.
- Steam на AMD/Intel: явно `vulkan-radeon` + `lib32-vulkan-radeon`.
- `install.sh`: `| head` под `set -o pipefail` роняет скрипт (exit 141) — `|| true`.
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

- `cliphist delete` читает stdin: `cliphist list | grep -P '^ID\t' | cliphist delete`.
- DND: `makoctl mode -t do-not-disturb`.
- Круглая маска magick: `magick in -resize 512x512 \( -size 512x512 xc:black -fill white -draw "circle 256,256 256,2" \) -alpha off -compose CopyOpacity -composite PNG32:out`.
- Root-хелперы риса (`/usr/local/lib/lunar/avatar-sync.sh`, `journal-read.sh`) ставит
  `install.sh` (0755 root:root); в sudoers — только они, без масок по скриптам.
  Журнал читать через `sudo -n /usr/local/lib/lunar/journal-read.sh …` — у raw
  `journalctl` отозваны мутирующие режимы (`--vacuum`/`--rotate`).
- `eclipse-askpass.py` — интерактивный GTK-диалог пароля (не автоподстановка).
- Скрины для README: `grim -o eDP-1` (1920×1080) → `magick … -resize 1600x900 -strip`.
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
./install.sh [--sddm|--plymouth|--zapret|--status|--disable-sddm|--disable-plymouth|--plymouth-rescue|--no-deps|--deps-only]
sddm-greeter --test-mode --theme /usr/share/sddm/themes/lunar      # предпросмотр входа
~/.config/hypr/scripts/eclipse-avatar.sh pick|apply <cs> <cx> <cy> [/путь]
~/.config/hypr/scripts/eclipse-record.sh probe                     # проверка записи
sudo ~/rice/install.sh --disable-sddm && sudo systemctl restart sddm   # откат SDDM из TTY
sudo ~/rice/install.sh --disable-plymouth                          # откат Plymouth
sudo mkinitcpio -P                                                 # сборка UKI
```

Релиз: `./release.sh` — тег `v<VERSION>` уходит в origin, GitHub Actions
(`.github/workflows/release.yml`) сам создаёт Release с заметками из коммитов.
Перед релизом рабочее дерево должно быть чистым.
Зависимости: `./get-deps.sh`.
