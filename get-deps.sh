#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — зависимости (Arch / производные)
#  Всё из официальных репозиториев, AUR не требуется.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

say() { printf '\033[38;5;15m==>\033[0m %s\n' "$*"; }

# ── базовые пакеты ─────────────────────────────────────────────
say "pacman: пакеты"
sudo pacman -S --needed --noconfirm \
  hyprland hypridle \
  quickshell \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  kitty fastfetch chafa \
  zsh starship eza zsh-autosuggestions zsh-syntax-highlighting \
  wofi mako \
  dolphin \
  playerctl brightnessctl ddcutil jq cliphist wl-clipboard \
  grim slurp wf-recorder \
  pipewire pipewire-pulse wireplumber pavucontrol \
  power-profiles-daemon polkit polkit-kde-agent \
  networkmanager iwd bluez bluez-utils nm-connection-editor blueman \
  gammastep \
  python python-psutil python-gobject \
  pciutils dmidecode \
  librsvg curl \
  awww \
  ttf-jetbrains-mono-nerd ttf-iosevka-nerd

# ── NVIDIA ─────────────────────────────────────────────────────
# Ставим только если в системе реально есть карта NVIDIA (по sysfs).
# На AMD/Intel этот блок пропускается — тестовому ноуту ничего не мешает.
#
# ВАЖНО: пакета nvidia/nvidia-dkms (проприетарный модуль) в Arch больше
# нет — NVIDIA свернула его в ветке 615. Официальная замена —
# nvidia-open-dkms (открытые модули ядра от самой NVIDIA, не nouveau).
# User-space (nvidia-utils, nvidia-settings) остаётся проприетарным.
if grep -qi '0x10de' /sys/class/drm/card*/device/vendor 2>/dev/null; then
  # Заголовки ядра под DKMS: у linux — linux-headers, у linux-zen — linux-zen-headers и т.д.
  KERNEL_PKG="$(cat "/usr/lib/modules/$(uname -r)/pkgbase" 2>/dev/null || echo linux)"
  say "NVIDIA: nvidia-open-dkms $KERNEL_PKG-headers + nvidia-utils, nvidia-settings, libva-nvidia-driver"
  sudo pacman -S --needed --noconfirm \
    nvidia-open-dkms "$KERNEL_PKG-headers" \
    nvidia-utils nvidia-settings libva-nvidia-driver
  say "NVIDIA: после установки перезагрузись (см. раздел NVIDIA в README)"
else
  say "NVIDIA не найдена — драйверы NVIDIA пропущены"
fi

say "Обои: awww установлен (mpvpaper — опционально из AUR: yay -S mpvpaper)"

say "Готово. Дальше: ./install.sh"
