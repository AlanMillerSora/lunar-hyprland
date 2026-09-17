#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse rice — автоматическая установка «с нуля»
#
#  Запуск (после чистой установки Arch, под своим пользователем):
#     git clone <этот репозиторий> ~/rice     ← либо просто копия папки dots
#     cd ~/rice
#     ./setup.sh
#
#  Флаги:
#     --autologin   автовход в tty1 и сразу запуск Hyprland
#     --no-gpu      не ставить драйверы видеокарты (ставит сам)
#     --ru          включить русскую локаль системы (ru_RU.UTF-8)
#
#  Что делает:
#    1.  Проверяет sudo / добавляет пользователя в wheel
#    2.  Обновляет систему
#    3.  Ставит base-devel, git, pciutils
#    4.  Ставит AUR-хелпер yay
#    5.  Ставит драйверы GPU (по VID:NVIDIA, AMD, Intel)
#    6.  Ставит все пакеты: hyprland-git, waybar, wofi, kitty, mako,
#        swww, hyprlock, hypridle, grim, slurp, wl-clipboard, socat,
#        pipewire, networkmanager, bluez, xdg-desktop-portal-hyprland,
#        шрифты (JetBrains Mono, Inter, Noto), thunar, firefox
#    7.  Бэкапит старые конфиги и копирует райс (install.sh)
#    8.  Группы пользователя, сервисы, автозапуск Hyprland в профиле
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
      sed -n '2,27p' "$0"; exit 0 ;;
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
[ -f "$SRC/install.sh" ] || { echo "install.sh не найден рядом с setup.sh — скрипт должен лежать в репозитории dots."; exit 1; }

# ── 1. sudo ─────────────────────────────────────────────────────
if ! sudo -nv 2>/dev/null; then
  echo "sudo не настроен. От root выполни:"
  echo "  usermod -aG wheel $USER_NAME"
  echo "  echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel"
  echo "Затем перезайди и запусти ./setup.sh снова."
  exit 1
fi

# ── 2. обновление системы ───────────────────────────────────────
say "Шаг 1/8 — обновление системы"
sudo pacman -Syu --noconfirm --needed

# ── 3. инструменты ──────────────────────────────────────────────
say "Шаг 2/8 — base-devel, git, pciutils"
sudo pacman -S --noconfirm --needed base-devel git pciutils

# ── 4. yay ──────────────────────────────────────────────────────
say "Шаг 3/8 — AUR-хелпер yay"
if command -v yay >/dev/null 2>&1; then
  ok "yay уже установлен"
else
  rm -rf /tmp/yay-bin
  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
  ( cd /tmp/yay-bin && makepkg -si --noconfirm )
  ok "yay установлен"
fi

# ── 5. драйверы GPU ─────────────────────────────────────────────
GPU_PKGS=()
if [ "$GPU" -eq 1 ]; then
  say "Шаг 4/8 — драйверы видеокарты"
  VGA="$(lspci | sed -n 's/.*VGA compatible controller: //p' | head -n1)"
  case "$VGA" in
    *NVIDIA*|*nvidia*) GPU_PKGS=(nvidia nvidia-utils nvidia-settings) ;;
    *Advanced\ Micro\ Devices*|*AMD*|*ATI*|*Radeon*) GPU_PKGS=(mesa libva-mesa-driver vulkan-radeon) ;;
    *Intel*|*Intel Corporation*) GPU_PKGS=(mesa libva-intel-driver vulkan-intel) ;;
    *) ok "GPU не определён ($VGA) — пропускаю" ;;
  esac
  [ ${#GPU_PKGS[@]} -gt 0 ] && yay -S --noconfirm --needed "${GPU_PKGS[@]}"
fi

# ── 6. пакеты райса ─────────────────────────────────────────────
say "Шаг 5/8 — пакеты Hyprland-райса"
yay -S --noconfirm --needed \
  hyprland-git waybar wofi kitty mako swww hyprlock hypridle \
  grim slurp wl-clipboard socat \
  pipewire pipewire-pulse wireplumber pavucontrol \
  networkmanager network-manager-applet \
  bluez bluez-utils blueman \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  ttf-jetbrains-mono ttf-inter noto-fonts noto-fonts-emoji \
  thunar firefox

# ── 7. бэкап + копирование конфигов ─────────────────────────────
say "Шаг 6/8 — копирование конфигов (с бэкапом старых)"
for d in hypr waybar wofi kitty mako hyprlock hypridle; do
  [ -e "$HOME_DIR/.config/$d" ] && cp -r "$HOME_DIR/.config/$d" \
    "$HOME_DIR/.config/${d}.bak.$(date +%F_%T)"
done
chmod +x "$SRC/install.sh" "$SRC/hypr/scripts/"*.sh
( cd "$SRC" && ./install.sh )
ok "Конфиги скопированы"

# ── 8. пользователь, сервисы, автозапуск ────────────────────────
say "Шаг 7/8 — группы и сервисы"
GRPS=(video input audio wheel)
for g in storage adm network power; do
  getent group "$g" >/dev/null 2>&1 && GRPS+=( "$g" )
done
sudo usermod -aG "$(IFS=,; echo "${GRPS[*]}")" "$USER_NAME"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
ok "NetworkManager и bluetooth включены"

say "Шаг 8/8 — автозапуск Hyprland"
case "${SHELL:-/bin/bash}" in
  *zsh) PROFILE="$HOME_DIR/.zprofile" ;;
  *)    PROFILE="$HOME_DIR/.bash_profile" ;;
esac
if ! grep -q 'exec Hyprland' "$PROFILE" 2>/dev/null; then
  cat >> "$PROFILE" <<'EOF'

# Lunar Eclipse rice — запуск Hyprland на tty1
if [ -z "${WAYLAND_DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
    exec Hyprland
fi
EOF
  ok "Автозапуск Hyprland добавлен в $PROFILE"
fi

if [ "$AUTOLOGIN" -eq 1 ]; then
  sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
  printf '[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin %s --noclear tty1 linux\n' \
    "$USER_NAME" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
  ok "Автовход включён (tty1 → $USER_NAME)"
fi

if [ "$RU" -eq 1 ]; then
  say "Включение русской локали"
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