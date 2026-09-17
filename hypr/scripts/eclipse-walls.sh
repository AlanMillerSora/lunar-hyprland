#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Hyprland "Lunar Eclipse" — обои по фазам на каждом столе
#  Нужно: swww (демон поднимается сам)
#
#  Установка:
#    chmod +x ~/.local/bin/eclipse-walls.sh
#    В hyprland.conf уже подключено через
#      hl.on("hyprland.start", ...) — hl.exec_cmd("~/.local/bin/eclipse-walls.sh")
#
#  Обои: ~/Pictures/EclipseWalls/eclipse_01..08.{png,jpg}
# ════════════════════════════════════════════════════════════

WALLDIR="${1:-$HOME/Pictures/EclipseWalls}"
SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

pgrep -x swww-daemon >/dev/null || { swww-daemon; sleep 1; }

set_wallpaper() {
  local ws="$1"
  [[ "$ws" =~ ^[0-9]+$ ]] || return   # спец-воркспейсы (special:) пропускаем
  local file
  file="$(ls "$WALLDIR"/eclipse_$(printf '%02d' "$ws").{jpg,png} 2>/dev/null | head -n1)"
  [[ -n "$file" ]] && swww img "$file" \
    --transition-type=wipe \
    --transition-duration=0.7 \
    --transition-bezier=0.4,0,0.2,1 \
    --transition-fps=60
}

set_current() {
  local cur
  cur="$(hyprctl activeworkspace -j | sed -n 's/.*"id":\(-\?[0-9][0-9]*\).*/\1/p' | head -n1)"
  [[ -n "$cur" ]] && set_wallpaper "$cur"
}

# Ставим обои активного стола сразу,
# затем слушаем сокет Hyprland (через socat, если он есть)
if command -v socat >/dev/null && [[ -S "$SOCK" ]]; then
  set_current
  while IFS= read -r line; do
    [[ "$line" == workspace>>* ]] || continue
    set_wallpaper "${line#workspace>>}"
  done < <(socat -U - UNIX-CONNECT:"$SOCK")
else
  # Без socat: медленный опрос активного стола
  prev=""
  while true; do
    cur="$(hyprctl activeworkspace -j | sed -n 's/.*"id":\(-\?[0-9][0-9]*\).*/\1/p' | head -n1)"
    if [[ -n "$cur" && "$cur" != "$prev" ]]; then
      set_wallpaper "$cur"
      prev="$cur"
    fi
    sleep 1.5
  done
fi