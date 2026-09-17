#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Lunar Eclipse rice — установщик
#  Копирует конфиги в ~/.config, обои в ~/Pictures/EclipseWalls,
#  скрипт в ~/.local/bin, подставляет пути в hyprlock.conf.
#
#  Запуск:  ./install.sh
# ════════════════════════════════════════════════════════════
set -euo pipefail

DOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HOME/.config"
WALL="$HOME/Pictures/EclipseWalls"
BIN="$HOME/.local/bin"

mkdir -p "$CONF"/{hypr/scripts,waybar,wofi,kitty,mako,hyprlock}
mkdir -p "$WALL" "$BIN"

echo "== Lunar Eclipse rice: установка конфигов =="

cp -r "$DOTDIR/wallpapers/." "$WALL/"

cp "$DOTDIR/hypr/hyprland.lua" "$CONF/hypr/"
cp "$DOTDIR/hypr/scripts/eclipse-walls.sh" "$CONF/hypr/scripts/"
cp "$DOTDIR/hypr/scripts/eclipse-walls.sh" "$BIN/"
chmod +x "$BIN/eclipse-walls.sh"
cp "$DOTDIR/hypr/scripts/eclipse-pbar.sh" "$CONF/hypr/scripts/"
chmod +x "$CONF/hypr/scripts/eclipse-pbar.sh"

cp "$DOTDIR/waybar/config.jsonc" "$DOTDIR/waybar/style.css" "$CONF/waybar/"
cp "$DOTDIR/wofi/config" "$DOTDIR/wofi/style.css" "$CONF/wofi/"
cp "$DOTDIR/kitty/kitty.conf" "$CONF/kitty/"
cp "$DOTDIR/mako/config" "$CONF/mako/"
# hypridle 0.1.8 ищет конфиг в ~/.config/hypr/, а не в ~/.config/hypridle/!
cp "$DOTDIR/hypridle/hypridle.conf" "$CONF/hypr/hypridle.conf"

sed "s|{ECLIPSE_DIR}|$WALL|g" "$DOTDIR/hyprlock/hyprlock.conf" > "$CONF/hyprlock/hyprlock.conf"

echo
echo "Готово."
echo "  1. Проверка конфига:  hyprctl configerrors"
echo "  2. Перезапуск:        hyprctl reload"
echo "  3. Путь до демона:    awww-daemon запустится сам при входе"