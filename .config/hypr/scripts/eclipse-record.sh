#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-record.sh — запись экрана через wf-recorder.
#
#  Запуск:  eclipse-record.sh start|stop|toggle|status
#  Файлы:   ~/Videos/lunar-ГГГГММДД-ЧЧММСС.mp4
# ════════════════════════════════════════════════════════════════
set -uo pipefail

DIR="$HOME/Videos"
mkdir -p "$DIR"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/lunar-record.pid"

running() { pgrep -x wf-recorder >/dev/null 2>&1; }

start() {
  if running; then echo "уже пишу"; return 0; fi
  out="$DIR/lunar-$(date +%Y%m%d-%H%M%S).mp4"
  setsid wf-recorder -f "$out" >/dev/null 2>&1 </dev/null &
  sleep 0.6
  pgrep -x wf-recorder | head -1 >"$PIDFILE"
  notify-send -a "Запись" "Запись экрана пошла" "$out" 2>/dev/null
  echo "$out"
}

stop() {
  if ! running; then echo "не пишу"; return 0; fi
  pkill -INT -x wf-recorder 2>/dev/null
  rm -f "$PIDFILE"
  notify-send -a "Запись" "Запись остановлена" 2>/dev/null
  echo "stopped"
}

case "${1:-toggle}" in
  start)  start ;;
  stop)   stop ;;
  toggle) if running; then stop; else start; fi ;;
  status) running && echo 1 || echo 0 ;;
  *) echo "usage: $0 start|stop|toggle|status" >&2; exit 1 ;;
esac
