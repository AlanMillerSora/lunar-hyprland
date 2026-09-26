# Plymouth — заставка при загрузке

Монохромная заставка **Lunar Eclipse**: тёмный фон `#050505`, кольцо-корона
с диском Луны (затмение), надпись `LUNAR ECLIPSE` (JetBrains Mono) и тонкая
полоса прогресса под ней. Показывается между загрузчиком и экраном входа.

```
plymouth/
├── lunar/                 тема Plymouth (script-модуль)
│   ├── lunar.plymouth     описание темы
│   ├── lunar.script       сцена: логотип, надпись, полоса прогресса
│   ├── logo.png           затмение (из assets/logo.svg)
│   ├── wordmark.png       LUNAR ECLIPSE
│   ├── progress_bar.png   заливка прогресса
│   └── progress_box.png   дорожка прогресса
└── eclipse-plymouth.sh    установка/включение/откат
```

## Как это устроено

Plymouth грузится **из initramfs**, поэтому одного пакета мало — нужны три вещи:

1. **пакет** `plymouth`;
2. **hook `plymouth`** в `/etc/mkinitcpio.conf` (сразу после `udev`/`systemd`) —
   чтобы Plymouth и тема попали в initramfs;
3. **параметр ядра `splash`** (и `quiet`, чтобы убрать текст ядра).

Где живут параметры ядра — зависит от режима загрузки:

| Режим | Файл cmdline |
|---|---|
| UKI (mkinitcpio preset с `*_uki=`, GRUB-команда `uki`) | `/etc/kernel/cmdline` |
| Классический GRUB | `/etc/default/grub` → `GRUB_CMDLINE_LINUX_DEFAULT` |

Параметры GRUB (`GRUB_CMDLINE_LINUX_DEFAULT`) в режиме UKI **не используются** —
cmdline зашит в образ из `/etc/kernel/cmdline`.

## Быстро

```bash
sudo ./plymouth/eclipse-plymouth.sh install   # положить тему и выбрать её
sudo ./plymouth/eclipse-plymouth.sh enable    # включить заставку (hook + cmdline + initramfs)
sudo ./plymouth/eclipse-plymouth.sh rescue    # (для UKI) резервный пункт меню без заставки
./plymouth/eclipse-plymouth.sh status         # что сейчас настроено
sudo ./plymouth/eclipse-plymouth.sh disable   # выключить и вернуть обычную загрузку
```

Скрипт идемпотентен, перед правкой конфигов кладёт `.bak`.

## Откат, если что-то пошло не так

Plymouth не «кирпичит» загрузку: initramfs всё равно грузит ядро, а Plymouth
при сбое падает в текстовый режим. Но на всякий случай есть три уровня.

**1. Прямо при загрузке (разово).** В меню GRUB выбрать пункт
**«Lunar Eclipse (без заставки)»** (появляется после `rescue`) — он грузит
резервный образ без Plymouth. Либо нажать `e` у обычного пункта и убрать
`splash` / добавить `plymouth.enable=0 disablehooks=plymouth`.

**2. Из TTY** (`Ctrl+Alt+F3`, войти):
```bash
sudo ./plymouth/eclipse-plymouth.sh disable
```

**3. Совсем вручную** (если скрипта под рукой нет):
```bash
sudo sed -i -E 's/\bplymouth //; s/ plymouth\b//' /etc/mkinitcpio.conf
sudo sed -i -E 's/ *\b(splash|quiet)\b//g' /etc/kernel/cmdline
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

## Заметки для основного ПК (RTX 5070)

- Требуется KMS у NVIDIA: `nvidia_drm.modeset=1` (и модули `nvidia nvidia_modeset
  nvidia_uvm nvidia_drm` в initramfs), иначе Plymouth уйдёт в текст. На AMD
  (дев-ноут) хватает штатного хука `kms`.
- Разрешение 3440×1440: скрипт темы масштабирует логотип и надпись под высоту
  экрана (`factor = Window.GetHeight()/1080`), так что отдельные ассеты под
  21:9 не нужны.
- Формат темы — `script`, поэтому `qt6-shadertools`/`.qsb` тут не нужны.

## Грабли: UKI + GRUB и `10_linux`

На машине с UKI (`default_uki=` в пресете, GRUB-команда `uki`) старый `grub.cfg`
мог быть собран до этих скриптов. После обновления GRUB и пересборки
`grub-mkconfig` скрипт `10_linux` добавляет **первым** классический пункт
`Arch Linux` вида `linux /vmlinuz-linux … initrd /amd-ucode.img` — **без
initramfs**. При `GRUB_DEFAULT=0` это паника ядра.

Лечение: отключить `10_linux` (`chmod -x /etc/grub.d/10_linux`) — на UKI он
лишний, грузимся через `uki`. Скрипт делает это сам в `enable`/`disable`/`rescue`
(функция `grub_guard`). После обновления пакета `grub` права на файл могут
сброситься — просто прогоните `enable`/`rescue` повторно.
