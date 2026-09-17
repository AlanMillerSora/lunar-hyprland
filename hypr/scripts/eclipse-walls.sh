#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Hyprland "Lunar Eclipse" — обои по фазам на каждом столе
#  Нужно: awww + python3 (демон поднимается сам)
#
#  Установка:
#    chmod +x ~/.local/bin/eclipse-walls.sh
#    В hyprland.lua уже подключено через
#      hl.on("hyprland.start", ...) — hl.exec_cmd("~/.local/bin/eclipse-walls.sh")
#
#  Обои: ~/Pictures/EclipseWalls/eclipse_01..08.{png,jpg}
#
#  NOTE: В Hyprland 0.56.2 socket2 events сломаны (postEvent не
#  перезаписывает буфер при EAGAIN — callback-и перепутаны).
#  Используем опрос hyprctl activeworkspace — работает стабильно.
# ════════════════════════════════════════════════════════════

WALLDIR="${1:-$HOME/Pictures/EclipseWalls}"

pgrep -x awww-daemon >/dev/null || { awww-daemon >/dev/null 2>&1 & sleep 1; }

active_ws() {
  hyprctl activeworkspace -j 2>/dev/null | python3 -c 'import sys, json
try:
    print(json.load(sys.stdin)["id"])
except Exception:
    pass'
}

set_wallpaper() {
  local ws="$1"
  [[ "$ws" =~ ^[0-9]+$ ]] || return
  local file
  file="$(ls "$WALLDIR"/eclipse_$(printf '%02d' "$ws").{jpg,png} 2>/dev/null | head -n1)"
  [[ -n "$file" ]] && awww img "$file" \
    --transition-type=wipe \
    --transition-duration=0.7 \
    --transition-bezier=0.4,0,0.2,1
}

# Ставим обои активного стола сразу, затем опрашиваем каждые 0.3с
set_wallpaper "$(active_ws)"
prev=""
while true; do
  cur="$(active_ws)"
  if [[ -n "$cur" && "$cur" != "$prev" ]]; then
    set_wallpaper "$cur"
    prev="$cur"
  fi
  sleep 0.3
done
