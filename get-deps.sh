#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — зависимости (Arch / производные)
#  Всё из официальных репозиториев, AUR не требуется.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

say() { printf '\033[38;5;15m==>\033[0m %s\n' "$*"; }

say "pacman: пакеты"
sudo pacman -S --needed --noconfirm \
  hyprland hyprlock hypridle \
  quickshell \
  kitty fastfetch chafa \
  zsh starship eza zsh-autosuggestions zsh-syntax-highlighting \
  wofi wlogout mako \
  dolphin \
  playerctl brightnessctl jq cliphist wl-clipboard grim slurp \
  networkmanager bluez bluez-utils nm-connection-editor blueman \
  pavucontrol polkit-kde-agent \
  python python-psutil python-gobject \
  librsvg \
  ttf-jetbrains-mono-nerd ttf-iosevka-nerd

say "Обои: awww (mpvpaper — опционально из AUR: yay -S mpvpaper)"

say "Готово. Дальше: ./install.sh"
