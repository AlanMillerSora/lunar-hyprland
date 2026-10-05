# PORTABILITY.md — что зашито под мою машину

Рис собран под конкретный ПК. Это не инструкция по автонастройке, а карта: где в репо
лежат машинозависимые места и что править при переезде на другое железо или другого
пользователя. Ничего не «универсализирую» — просто перечисляю, чтобы не искать заново.

## Эталонная машина

| Что | Значение |
|---|---|
| Пользователь | `sora` |
| Монитор | `DP-2`, Xiaomi Mi, 3440×1440@165 |
| GPU | NVIDIA RTX 5070 (GB205, Blackwell) |
| iGPU | AMD Raphael (Ryzen 7 7700) |
| CPU / RAM | Ryzen 7 7700, 32 ГБ |
| Ethernet | Realtek RTL8126 5GbE |
| Wi-Fi | Qualcomm WCN785x (драйвер `ath12k`) |
| Ядро | `7.2.7-arch1-1`, загрузка через UKI |

## Что править при переезде

### Монитор
- `.config/hypr/hyprland.lua` — правило по описанию
  `desc:Xiaomi Corporation Mi monitor 5323110105491` с `mode = "3440x1440@165"`.
  На другом экране взять своё описание (`hyprctl monitors` → строка `desc:`) и/или режим;
  для нескольких мониторов добавить `hl.workspace_rule`.
- `.config/quickshell/LunarOverview.qml` — фолбэк ширины `3440`, когда монитор не отдал размер.
- `grim -o DP-2` в документации и заметках (`AGENTS.md`, `README.md`, `DESIGN.md`) — на
  другом порту заменить имя вывода.

### GPU / NVIDIA
- `.config/hypr/hyprland.lua` — переменные NVIDIA (`LIBVA_DRIVER_NAME`, `GBM_BACKEND`,
  `VK_ICD_FILENAMES`, `__GLX_VENDOR_LIBRARY_NAME`) включаются **условно** по вендору
  `0x10de` из sysfs. Логика переносима, но для AMD/Intel-только машины проверить, что
  ветка не сработала, и подставить свои драйверы (напр. `vulkan-radeon`).
- Пакеты из `get-deps.sh`/README: `nvidia-open`, `nvidia-utils`, `libva-nvidia-driver`,
  `lib32-nvidia-utils`. Blackwell/RTX 50xx — драйвер 570+; Pascal и старше — legacy.

### Сеть
- `systemd/conf/iwd-main.conf` — `PowerSaveDisable=ath12k*` прибито к Qualcomm WCN785x. На другой
  Wi-Fi-карте убрать или сменить маску драйвера.
- `/etc/systemd/network/20-wlan.network` (IP раздаёт systemd-networkd) **живёт вне репо** —
  на новой машине создать/поправить под своё имя интерфейса (`wlan0`).
- `zapret/wait-online-any.conf` — дроп-ин рассчитан на неактивный `wlan0`; при другой
  схеме сети пересмотреть.

### Пользователь и пути
- `.config/kitty/kitty.conf` — `background_image /home/sora/.config/kitty/noise.png`.
- `.config/qt6ct/qt6ct.conf` — `color_scheme_path=/home/sora/.config/qt6ct/colors/lunar.conf`.
- `systemd/sudoers/lunar-agent.sudoers` — имя `sora` подставляется `install.sh` по текущему
  пользователю (sed), так что правило переносимо; при ручной установке проверить.
- `systemd/libexec/lunar-avatar-sync.sh` — фолбэк пользователя `sora`.
- Root-хелперы ставятся в `/usr/libexec/lunar/` (пакет `lunar-helpers` или fallback
  `install.sh`); на этот путь смотрят sudoers и системные юниты — при переезде
  ничего менять не нужно.
- Прочие абсолютные `/home/sora` в заметках и `HANDOFF.md` (локальный, в git не входит).

### Загрузка (не автоматизируется)
- UKI, `mkinitcpio`, Plymouth, GRUB, `/etc/kernel/cmdline` — машинозависимы и ставятся
  только флагами `install.sh --sddm/--plymouth`. Без бэкапа не трогать (см. `AGENTS.md`).
