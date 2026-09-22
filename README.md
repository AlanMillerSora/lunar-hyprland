<div align="center">

<img src="assets/logo.svg" width="128" alt="Lunar Eclipse"/>

# Lunar Eclipse

**Hyprland rice · монохромный HUD · весь шелл на Quickshell**

Тонкие рамки, острые уголки, чёрно-белая палитра и ни одной лишней детали.

![Arch](https://img.shields.io/badge/Arch_Linux-050505?style=flat-square&logo=archlinux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-0.56-050505?style=flat-square&logoColor=white)
![Quickshell](https://img.shields.io/badge/Quickshell-0.3-050505?style=flat-square&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-050505?style=flat-square)

</div>

---

## ✨ Что это

Полностью кастомная оболочка для Hyprland: верхняя панель, лаунчер и
настройки, боковая панель, OSD — всё написано на **Quickshell (QML)**, без
waybar и GTK-приложений.

Один визуальный язык на всю систему: **рамка 1px, радиус 6, острые
HUD-скобки**, монохромная палитра, шрифт JetBrains Mono.

## 📸 Скриншоты

**Рабочий стол — фазы затмения**

<div align="center">
  <img src="assets/screens/desktop.png" width="92%" alt="Рабочий стол, фаза 04"/>
  <br/><sub>Стол 04 — полное затмение</sub>
</div>

<div align="center">
  <img src="assets/screens/desktop-5.png" width="92%" alt="Рабочий стол, фаза 05"/>
  <br/><sub>Стол 05 — частное затмение</sub>
</div>

**Hub — настройки и лаунчер**

| System — графики CPU / GPU / RAM | Launch — лаунчер приложений |
|:---:|:---:|
| ![System](assets/screens/hub-system.png) | ![Launch](assets/screens/hub-launch.png) |
| Живые графики загрузки и температуры | Поиск и сетка приложений |

**Терминал и монитор**

| Терминал (zsh + starship) | btop — тема `lunar` |
|:---:|:---:|
| ![Terminal](assets/screens/terminal.png) | ![btop](assets/screens/btop.png) |
| Логотип-затмение + инфо системы | Автозапуск на столе 08 |

<div align="center">
  <img src="assets/screens/bar.png" width="92%" alt="Верхняя панель"/>
  <br/><sub>Верхняя панель — столы 01–08, CPU/RAM/°C, часы, трек, звук, питание</sub>
</div>

## 🧩 Компоненты

| Компонент | Файл | Что делает |
|---|---|---|
| **Панель** | `quickshell/LunarPanel.qml` | 42px сверху. Слева — лого+фаза и столы `01–08`; справа — сеть/раскладка/уведомления, блок действий (Game Mode, профиль питания, запись), CPU/RAM/°C/GPU, mpris, громкость, питание |
| **Статус** | `hypr/scripts/eclipse-status.sh` | Одна строка статуса для панели: сеть, раскладка, DND, уведомления, GPU, Game Mode, профиль питания, запись |
| **Game Mode** | `hypr/scripts/eclipse-gamemode.sh` | Игровой режим: анимации/blur выкл, DND, пауза hypridle, performance, tearing |
| **Запись** | `hypr/scripts/eclipse-record.sh` | Запись экрана (wf-recorder) → `~/Videos/lunar-*.mp4` |
| **Меню питания** | `wlogout/` | Круги с PNG-иконками (стиль 43PR): suspend/hibernate/logout/reboot/shutdown, `SUPER + ESC` |
| **Games** | `quickshell/SettingsPages/GamesPage.qml` | Список игр (desktop-записи с `Categories=Game`) и запуск |
| **Monitors** | `quickshell/SettingsPages/MonitorsPage.qml` | Режим мониторов, яркость, ночной свет, частота обновления (Гц), VRR (FreeSync/GSync), масштаб, tearing |
| **Hub** | `quickshell/LunarHub.qml` | Лаунчер + настройки (980×640, как у 43PR): Launch, System, Sound, Monitors, Network, Bluetooth, Interface, Memory, Games |
| **Memory** | `quickshell/SettingsPages/MemoryPage.qml` | Индикатор заполнения RAM/SWAP и общей памяти (MEM) + очистка системы (кнопка «ОЧИСТИТЬ») |
| **Очистка** | `hypr/scripts/eclipse-cleanup.sh` | Сироты, кэш пакетов, журнал, tmpfiles, кэш yay, эскизы; опционально браузеры |
| **Sidebar** | `quickshell/LunarSidebar.qml` | Выдвигается от левого края (540px): чат (статус Ollama), буфер (cliphist; ПКМ — удалить), заметки |
| **Sidebar R** | `quickshell/LunarSidebarRight.qml` | Выдвигается от правого края: уведомления (mako), «сейчас играет» (mpris), календарь (прокручивается, 18 месяцев), запись экрана со списком |
| **Буфер** | `quickshell/LunarClipboard.qml` | История cliphist с поиском: `SUPER + V` |
| **Громкость** | `quickshell/LunarVolume.qml` | Попап с крупным ползунком (клик по значку громкости на панели) |
| **OSD** | `quickshell/LunarVolumeOsd.qml` | Индикатор громкости с HUD-скобками |
| **Ползунок** | `quickshell/Slider.qml` | Общий слайдер темы (настройки, попап громкости) |
| **Тема** | `quickshell/Theme.qml` | Единая палитра, радиусы, шрифты, ползунки прозрачности и масштаба |
| **btop** | `btop/themes/lunar.theme` | Монитор системы в теме `lunar`, автозапуск на столе 08 |

## 📂 Структура

```
.
├── .config/                # → ~/.config
│   ├── hypr/               # hyprland.lua, scripts/
│   ├── quickshell/         # весь шелл (QML) + assets/moon-phases
│   ├── kitty/              # терминал
│   ├── fastfetch/          # логотип + конфиг
│   ├── btop/               # системный монитор (тема lunar)
│   ├── gtk-3.0/ gtk-4.0/   # GTK-тема
│   ├── kde/                # kdeglobals, dolphin, цвета
│   ├── mako/               # уведомления
│   ├── hypridle/           # idle
│   ├── wofi/ wlogout/      # меню и меню питания
│   ├── lunar/lunar.bash    # bash
│   ├── .zshrc              # zsh
│   └── starship.toml       # промпт
├── wallpapers/             # 8 фаз затмения
├── systemd/                # wifi-guard
├── assets/                 # логотип и скриншоты
├── install.sh              # установка конфигов
└── get-deps.sh             # зависимости
```

## 🚀 Установка

```bash
git clone https://github.com/AlanMillerSora/lunar-hyprland.git ~/rice
cd ~/rice

./get-deps.sh     # зависимости (pacman)
./install.sh      # конфиги → ~/.config, обои, zsh по умолчанию
```

Затем перелогинься в Hyprland (или `hyprctl reload`).

> Требуется **Hyprland 0.55+** (конфиг на Lua — `hyprland.lua`).
> Обои-видео (mpvpaper) — опционально: `yay -S mpvpaper`.

## ⌨️ Горячие клавиши

| Клавиши | Действие |
|---|---|
| `SUPER + RETURN` | Терминал (kitty) |
| `SUPER + G` / `SUPER + C` | Hub: лаунчер + настройки |
| `SUPER + D` / `SUPER + A` | wofi: приложения / команды |
| `SUPER + E` | Файлы (dolphin) |
| `SUPER + V` | Буфер обмена (cliphist) |
| `SUPER + SHIFT + E` | Боковая панель (слева) |
| `SUPER + SHIFT + R` | Панель справа (уведомления/музыка/календарь) |
| `SUPER + /` | Шпаргалка по хоткеям |
| `SUPER + Q` | Закрыть окно |
| `SUPER + W` / `SHIFT+W` | Развернуть / полный экран |
| `SUPER + F` / `P` / `SPACE` | Плавающее / псевдо / следующее |
| `SUPER + ←↑↓→` / `HJKL` | Фокус |
| `SUPER + SHIFT + ←↑↓→` | Перенос окна |
| `SUPER + 1…8` | Рабочий стол (фаза затмения) |
| `SUPER + SHIFT + 1…8` | Перенести окно на стол |
| `SUPER + T` / `SHIFT+T` | Группа / закрепить |
| `SUPER + S` / `SHIFT+S` | Scratchpad |
| `SUPER + ESC` | Меню питания (wlogout) |
| `PRINT` / `SUPER + PRINT` | Скриншот: область / весь экран |
| `SUPER + R` | Перезагрузить Hyprland |

## 🎨 Тема

Всё крутится в **Hub → Interface**:

- **Прозрачность интерфейса** — влияет на фон Hub, Sidebar, OSD и панели;
- **Размер шрифта** — масштабирует весь текст шелла.

Палитра: фон `#050505`, текст `#ffffff`, приглушённый `#888888`, акценты
белые, опасность `#ff003c`.

## 📄 Лицензия

[MIT](LICENSE)
