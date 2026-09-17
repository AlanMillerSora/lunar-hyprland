#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse rice — автоматическая установка «с нуля»
#
#  Запуск (после чистой установки Arch, под своим пользователем):
#     git clone https://github.com/AlanMillerSora/lunar-hyprland.git ~/rice
#     cd ~/rice
#     ./setup.sh
#
#  Флаги:
#     --autologin   автовход в tty1 и сразу запуск Hyprland
#     --no-gpu      не ставить драйверы видеокарты
#     --ru          включить русскую локаль (ru_RU.UTF-8)
#     -h | --help   эта справка
#
#  Что делает:
#    1.  Обновляет систему
#    2.  Ставит base-devel, git, pciutils
#    3.  Ставит AUR-хелпер yay (yay-bin)
#    4.  Ставит драйверы GPU (NVidia / AMD / Intel — опрос lspci)
#    5.  Ставит пакеты райса (hyprland, waybar, wofi, kitty, mako,
#        awww, hyprlock, hypridle, grim, slurp, wl-clipboard, python,
#        pipewire, networkmanager, bluez, xdg-desktop-portal-hyprland,
#        шрифты JetBrains Mono / Inter / Noto, thunar, firefox и др.),
#        вычищает dunst (иначе mako не займёт шину уведомлений)
#    6.  Бэкапит старые конфиги и копирует райс (install.sh)
#    7.  Группы пользователя + службы NetworkManager/bluetooth
#    8.  Автозапуск Hyprland на tty1 (в профиль шелла)
#    9.  Автовход на tty1 (только с --autologin)
#   10.  Русская локаль (только с --ru)
# ════════════════════════════════════════════════════════════════
set -euo pipefail

# ── разбор флагов ───────────────────────────────────────────────
AUTOLOGIN=0; GPU=1; RU=0
for a in "$@"; do
  case "$a" in
    --autologin) AUTOLOGIN=1 ;;
    --no-gpu)    GPU=0      ;;
    --ru)        RU=1       ;;
    -h|--help)
      awk 'NR == 1 { next } /^#/ { print; next } { exit }' "$0"
      exit 0 ;;
    *) echo "Неизвестный флаг: $a (посмотри $0 --help)"; exit 1 ;;
  esac
done

# ── база ────────────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
  echo "Запускай от обычного пользователя (не root)."; exit 1
fi
USER_NAME="$(id -un)"
HOME_DIR="$HOME"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }

# где лежит райс (папка, в которой стоит этот скрипт)
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SRC/install.sh" ] || {
  echo "install.sh не найден рядом с setup.sh — скрипт должен лежать в репозитории rice."
  exit 1
}

if ! grep -qi '^ID=arch' /etc/os-release 2>/dev/null; then
  echo "Внимание: похоже, это не Arch — скрипт заточен под pacman/yay."
  echo "Продолжаем на свой риск."
fi

# ── 1. sudo ─────────────────────────────────────────────────────
if ! sudo -nv 2>/dev/null; then
  echo "sudo не настроен. От root выполни:"
  echo "  usermod -aG wheel $USER_NAME"
  echo "  echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel"
  echo "Затем перезайди и запусти ./setup.sh снова."
  exit 1
fi

# ── 2. обновление системы ───────────────────────────────────────
say "Шаг 1: обновление системы"
sudo pacman -Syu --noconfirm --needed

# ── 3. инструменты ──────────────────────────────────────────────
say "Шаг 2: base-devel, git, pciutils"
sudo pacman -S --noconfirm --needed base-devel git pciutils

# ── 4. yay ──────────────────────────────────────────────────────
say "Шаг 3: AUR-хелпер yay"
if command -v yay >/dev/null 2>&1; then
  ok "yay уже установлен"
else
  rm -rf "$HOME_DIR/.cache/yay-bin"
  git clone https://aur.archlinux.org/yay-bin.git "$HOME_DIR/.cache/yay-bin"
  ( cd "$HOME_DIR/.cache/yay-bin" && makepkg -si --noconfirm )
  ok "yay установлен"
fi

# ── 5. драйверы GPU ─────────────────────────────────────────────
GPU_PKGS=()
if [ "$GPU" -eq 1 ]; then
  say "Шаг 4: драйверы видеокарты"
  # lspci может вернуть и VGA, и 3D controller (NVIDIA на гибридных ноутах)
  GPU_LC="$(lspci 2>/dev/null | grep -iE 'vga compatible|3d controller' | tr '[:upper:]' '[:lower:]' || true)"
  if   [[ "$GPU_LC" == *nvidia* ]]; then
    GPU_PKGS=(nvidia nvidia-utils nvidia-settings)   # hybrid: это только дискретка, вспомни про prime-run
  elif [[ "$GPU_LC" == *amd* || "$GPU_LC" == *ati* || "$GPU_LC" == *radeon* ]]; then
    GPU_PKGS=(mesa libva-mesa-driver vulkan-radeon)
  elif [[ "$GPU_LC" == *intel* ]]; then
    GPU_PKGS=(mesa libva-intel-driver vulkan-intel)
  else
    ok "GPU не определён — пропускаю драйверы"
  fi
  if [ ${#GPU_PKGS[@]} -gt 0 ]; then
    yay -S --noconfirm --needed "${GPU_PKGS[@]}"
  fi
fi

# ── 6. пакеты райса ─────────────────────────────────────────────
say "Шаг 5: пакеты Hyprland-райса"
yay -S --noconfirm --needed \
  hyprland waybar wofi kitty mako awww hyprlock hypridle \
  grim slurp wl-clipboard python \
  pipewire pipewire-pulse wireplumber pavucontrol \
  networkmanager network-manager-applet \
  bluez bluez-utils blueman \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  ttf-jetbrains-mono inter-font noto-fonts noto-fonts-emoji \
  thunar firefox

# dunst конфликтует с mako за org.freedesktop.Notifications — выносим
if pacman -Qi dunst >/dev/null 2>&1; then
  say "  Убираю dunst — он не давал mako занять шину уведомлений"
  sudo pacman -Rns --noconfirm dunst || true
fi
ok "Пакеты установлены"

# ── 7. бэкап + копирование конфигов ─────────────────────────────
say "Шаг 6: копирование конфигов (с бэкапом старых)"
for d in hypr waybar wofi kitty mako hyprlock hypridle; do
  if [ -e "$HOME_DIR/.config/$d" ]; then
    cp -r "$HOME_DIR/.config/$d" "$HOME_DIR/.config/${d}.bak.$(date +%F_%T)"
  fi
done
chmod +x "$SRC/install.sh"
chmod +x "$SRC"/hypr/scripts/*.sh
( cd "$SRC" && ./install.sh )
ok "Конфиги скопированы"

# ── 8. пользователь, сервисы ────────────────────────────────────
say "Шаг 7: группы и сервисы"
GRPS=(video input audio wheel)
for g in storage adm network power; do
  if getent group "$g" >/dev/null 2>&1; then
    GRPS+=("$g")   # group может и не быть — это не повод умирать
  fi
done
sudo usermod -aG "$(IFS=,; echo "${GRPS[*]}")" "$USER_NAME"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
ok "NetworkManager и bluetooth включены"

# ── 9. автозапуск Hyprland ──────────────────────────────────────
say "Шаг 8: автозапуск Hyprland"
case "${SHELL:-/bin/bash}" in
  *zsh) PROFILE="$HOME_DIR/.zprofile" ;;
  *)    PROFILE="$HOME_DIR/.bash_profile" ;;
esac
if ! grep -q 'exec Hyprland' "$PROFILE" 2>/dev/null; then
  cat >> "$PROFILE" <<'EOF'

# Lunar Eclipse rice — запуск Hyprland на tty1
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] && [ "${XDG_VTNR:-}" = "1" ]; then
    exec Hyprland
fi
EOF
  ok "Автозапуск Hyprland добавлен в $PROFILE"
fi

# ── 10. автовход (опционально) ──────────────────────────────────
if [ "$AUTOLOGIN" -eq 1 ]; then
  say "Шаг 9: автовход на tty1"
  sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
  printf '[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin %s --noclear tty1 linux\n' \
    "$USER_NAME" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
  sudo systemctl daemon-reload
  ok "Автовход включён (tty1 → $USER_NAME)"
fi

# ── 11. русская локаль (опционально) ────────────────────────────
if [ "$RU" -eq 1 ]; then
  say "Шаг 10: русская локаль"
  sudo sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
  sudo locale-gen
  sudo localectl set-locale LANG=ru_RU.UTF-8
  ok "Локаль ru_RU.UTF-8"
fi

# ── финал ───────────────────────────────────────────────────────
echo
echo " ════════════════════════════════════════════════════════"
echo "  Готово! Перезагрузись и Hyprland стартует сам:"
echo "    sudo reboot"
echo " ════════════════════════════════════════════════════════"
echo "  Первая проверка после входа:  hyprctl configerrors"
echo "  Горячие клавиши:"
echo "    SUPER+RETURN  терминал      SUPER+D   меню (wofi)"
echo "    SUPER+1..8    фазы          SUPER+SHIFT+1..8  перенос окна"
echo "    SUPER+SHIFT+L блокировка    PRINT     скриншот области"
echo "  Если sudo перестало работать — проверь /etc/sudoers.d/wheel."