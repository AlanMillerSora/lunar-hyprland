#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Hyprland "Lunar Eclipse" — живые обои по фазам на каждом столе
#
#  Два режима (выбирается автоматически):
#    1) mpvpaper + видео (eclipse_NN.webm/mp4) — полный цвет, 60fps,
#       без 256-цветного зерна и полос.  ЛУЧШИЙ вариант.
#    2) awww + GIF (eclipse_NN.gif), иначе PNG/JPG — запасной.
#
#  Файлы фаз: ~/Pictures/EclipseWalls/eclipse_01..08.(webm|mp4|gif|png|jpg)
#  (устанавливаются из репозитория: wallpapers/*.png)
#
#  Установка mpvpaper (AUR, нужен sudo):  yay -S mpvpaper
#  После установки просто перезапусти этот скрипт — он сам подхватит.
#
#  NOTE: В Hyprland 0.56.2 socket2 events сломаны (postEvent не
#  перезаписывает буфер при EAGAIN — callback-и перепутаны).
#  Используем опрос hyprctl activeworkspace — работает стабильно.
# ════════════════════════════════════════════════════════════

WALLDIR="${1:-$HOME/Pictures/EclipseWalls}"
MPV_SOCK="${XDG_RUNTIME_DIR:-/tmp}/eclipse-mpvpaper-$(id -u).sock"

active_ws() {
  hyprctl activeworkspace -j 2>/dev/null | python3 -c 'import sys, json
try:
    print(json.load(sys.stdin)["id"])
except Exception:
    pass'
}

# Видео фазы (приоритет webm → mp4)
pick_video() {
  local base="$WALLDIR/eclipse_$(printf '%02d' "$1")" ext
  for ext in webm mp4; do
    [[ -f "$base.$ext" ]] && { printf '%s' "$base.$ext"; return 0; }
  done
  return 1
}

# Картинка фазы для awww: сначала живая (gif), потом статичная (png/jpg)
pick_wall() {
  local base="$WALLDIR/eclipse_$(printf '%02d' "$1")" ext
  for ext in gif png jpg; do
    [[ -f "$base.$ext" ]] && { printf '%s' "$base.$ext"; return 0; }
  done
  return 1
}

# ── mpvpaper ────────────────────────────────────────────────
# Один процесс на все мониторы, фазу переключаем через IPC (loadfile):
# без чёрных вспышек и перезапусков.
mpv_switch() {
  python3 - "$MPV_SOCK" "$1" <<'PY'
import json, socket, sys
sock, path = sys.argv[1], sys.argv[2]
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock)
except OSError:
    sys.exit(1)
for cmd in (["loadfile", path, "replace"],
            ["set_property", "loop-file", "inf"],
            ["set_property", "pause", "no"]):
    s.sendall((json.dumps({"command": cmd}) + "\n").encode())
s.close()
PY
}

mpv_start() {
  rm -f "$MPV_SOCK"
  mpvpaper -o "no-audio loop input-ipc-server=$MPV_SOCK really-quiet hwdec=auto-safe" \
    '*' "$1" >/dev/null 2>&1 &
  sleep 0.6
  # Чтобы GIF не крутился под видео и не жёг CPU — гасим awww.
  pgrep -x mpvpaper >/dev/null && pkill -x awww-daemon 2>/dev/null
}

mpv_set() {
  local ws="$1" file
  [[ "$ws" =~ ^[0-9]+$ ]] || return
  file="$(pick_video "$ws")" || return
  if ! pgrep -x mpvpaper >/dev/null; then
    mpv_start "$file"
  elif ! mpv_switch "$file"; then
    # IPC не ответил — перезапускаем mpvpaper с нужной фазой.
    pkill -x mpvpaper 2>/dev/null
    sleep 0.3
    mpv_start "$file"
  fi
}

# ── awww (fallback) ─────────────────────────────────────────
awww_set() {
  local ws="$1" file
  [[ "$ws" =~ ^[0-9]+$ ]] || return
  file="$(pick_wall "$ws")" || return
  awww img "$file" \
    --transition-type=fade \
    --transition-duration=0.6 \
    --transition-fps=60 \
    --transition-bezier=0.4,0,0.2,1
}

# ── выбор режима ────────────────────────────────────────────
USE_MPV=0
if command -v mpvpaper >/dev/null 2>&1 && pick_video 1 >/dev/null 2>&1; then
  USE_MPV=1
fi

if [[ "$USE_MPV" == 1 ]]; then
  pkill -x mpvpaper 2>/dev/null && sleep 0.3
  set_wall() { mpv_set "$1"; }
else
  pgrep -x awww-daemon >/dev/null || { awww-daemon >/dev/null 2>&1 & sleep 1; }
  set_wall() { awww_set "$1"; }
fi

# Ставим обои активного стола сразу, затем опрашиваем каждые 0.3с
prev="$(active_ws)"
set_wall "$prev"
while true; do
  cur="$(active_ws)"
  if [[ -n "$cur" && "$cur" != "$prev" ]]; then
    set_wall "$cur"
    prev="$cur"
  fi
  sleep 0.3
done
