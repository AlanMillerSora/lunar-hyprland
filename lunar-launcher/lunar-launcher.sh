#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  lunar-launcher.sh — открыть/скрыть окно Lunar Launcher.
#
#  Запуск:
#    lunar-launcher.sh open    — автозапуск: сервер + окно (раб. стол 1)
#    lunar-launcher.sh toggle  — показать/спрятать (хоткей SUPER+G)
#
#  Окно — chromium в режиме приложения с локальным сервером
#  (python stdlib, слушает только 127.0.0.1).
# ════════════════════════════════════════════════════════════════
set -u

PORT="${LUNAR_LAUNCHER_PORT:-47781}"
URL="http://127.0.0.1:${PORT}"

# Каталог с файлами лаунчера: установка → ~/.local/share/lunar-launcher,
# иначе (прямо из репо) — каталог рядом со скриптом.
DIR="${LUNAR_LAUNCHER_DIR:-}"
if [ -z "$DIR" ]; then
  if [ -d "$HOME/.local/share/lunar-launcher" ]; then
    DIR="$HOME/.local/share/lunar-launcher"
  else
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
fi

start_server() {
  if ! pgrep -f "lunar-launcher/server.py" >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/share/lunar-launcher"
    ( setsid nohup python3 "$DIR/server.py" \
        >>"$HOME/.local/share/lunar-launcher/server.log" 2>&1 & )
    for _ in $(seq 1 40); do
      if python3 -c "import urllib.request,sys; urllib.request.urlopen('${URL}/api/state', timeout=1)" 2>/dev/null; then
        break
      fi
      sleep 0.1
    done
  fi
}

window_addr() {
  hyprctl -j clients 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    for w in data:
        if w.get("title") == "Lunar Launcher":
            print(w.get("address", ""))
            break
except Exception:
    pass
'
}

cmd_open() {
  start_server
  if [ -z "$(window_addr)" ]; then
    command -v chromium >/dev/null 2>&1 || { notify-send -a "Lunar" "chromium не установлен" 2>/dev/null; return 1; }
    ( setsid nohup chromium --app="$URL" --ozone-platform=wayland \
        --class=LunarLauncher --window-size=980,600 \
        --disable-session-crashed-bubble --disable-infobars \
        >>"$HOME/.local/share/lunar-launcher/chromium.log" 2>&1 & )
  fi
}

cmd_toggle() {
  start_server || return 1
  local addr
  addr="$(window_addr)"
  if [ -n "$addr" ]; then
    # в Hyprland 0.56 dispatch — это Lua: закрываем окно через hl.dsp
    hyprctl dispatch "hl.dsp.window.close({ window = 'address:$addr' })" 2>/dev/null
  else
    cmd_open
  fi
}

case "${1:-toggle}" in
  open)   cmd_open ;;
  toggle) cmd_toggle ;;
  *) echo "usage: lunar-launcher.sh [open|toggle]" >&2; exit 1 ;;
esac