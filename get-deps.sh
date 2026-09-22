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
  wofi mako firefox \
  yazi bat ffmpeg 7zip poppler jq fd ripgrep zoxide fzf \
  playerctl brightnessctl ddcutil jq cliphist wl-clipboard \
  grim slurp wf-recorder \
  pipewire pipewire-pulse wireplumber pavucontrol \
  power-profiles-daemon polkit polkit-kde-agent \
  networkmanager iwd bluez bluez-utils nm-connection-editor blueman \
  gammastep \
  python python-psutil python-gobject \
  pciutils dmidecode pacman-contrib \
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

# ── zapret: обход DPI (Discord / YouTube) ──────────────────────
# Сам zapret ставится из исходников через ./install.sh (zapret/install-zapret.sh),
# тут — только зависимости сборки (gcc/make) и работы (netfilter/nftables).
say "pacman: зависимости zapret (сборка nfqws + netfilter)"
sudo pacman -S --needed --noconfirm \
  gcc make zlib libcap libnetfilter_queue libmnl systemd-libs nftables

# ── VS Code (AUR) ──────────────────────────────────────────────
# В репах есть только code (OSS-сборка). Для официального билда
# Microsoft с полным маркетплейсом ставим visual-studio-code-bin из AUR.
if command -v yay >/dev/null 2>&1; then
  say "AUR: visual-studio-code-bin (VS Code)"
  yay -S --needed --noconfirm visual-studio-code-bin \
    || say "VS Code не установился — вручную: yay -S visual-studio-code-bin"
elif command -v paru >/dev/null 2>&1; then
  say "AUR: visual-studio-code-bin (VS Code)"
  paru -S --needed --noconfirm visual-studio-code-bin \
    || say "VS Code не установился — вручную: paru -S visual-studio-code-bin"
else
  say "yay/paru не найден — VS Code пропущен (вручную: yay -S visual-studio-code-bin)"
fi

say "Обои: awww установлен (mpvpaper — опционально из AUR: yay -S mpvpaper)"

say "Готово. Дальше: ./install.sh"
