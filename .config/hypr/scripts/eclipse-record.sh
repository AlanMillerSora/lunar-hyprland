#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-record.sh — запись экрана через wf-recorder.
#
#  Кодирование: аппаратное (VAAPI) с авто-выбором, иначе — софт.
#    · NVIDIA — через VAAPI (libva-nvidia-driver поверх NVENC);
#    · AMD/Intel — через VAAPI (родной драйвер);
#    · если GPU-кодек не завёлся — падаем на libx264 (софт).
#
#  Запуск:  eclipse-record.sh start|stop|toggle|status|probe
#  Файлы:   ~/Videos/lunar-ГГГГММДД-ЧЧММСС.mp4
# ════════════════════════════════════════════════════════════════
set -uo pipefail

DIR="$HOME/Videos"
mkdir -p "$DIR"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/lunar-record.pid"
CODECFILE="${XDG_RUNTIME_DIR:-/tmp}/lunar-record.codec"

running() { pgrep -x wf-recorder >/dev/null 2>&1; }

# ближайший render-узел (на ПК с NVIDIA — обычно renderD128)
render_node() {
  for n in /dev/dri/renderD128 /dev/dri/renderD129; do
    [[ -e "$n" ]] && { echo "$n"; return 0; }
  done
  return 1
}

# Проверяем, реально ли энкодер запускается (не только «есть в ffmpeg»):
# прогоняем 1 кадр через VAAPI и смотрим, вышел ли файл.
vaapi_works() {
  local dev="$1"
  [[ -e "$dev" ]] || return 1
  rm -f /tmp/.lunar-vaapi-probe.mp4
  if ffmpeg -hide_banner -loglevel error -y \
       -init_hw_device "vaapi=va:$dev" \
       -f lavfi -i "testsrc=duration=1:size=320x240:rate=30" \
       -vf 'format=nv12,hwupload' -c:v h264_vaapi -frames:v 1 \
       /tmp/.lunar-vaapi-probe.mp4 >/dev/null 2>&1 && [[ -s /tmp/.lunar-vaapi-probe.mp4 ]]; then
    rm -f /tmp/.lunar-vaapi-probe.mp4
    return 0
  fi
  rm -f /tmp/.lunar-vaapi-probe.mp4
  return 1
}

# Подбираем параметры кодека: печатает "-c <codec> -d <dev>" либо "" (софт).
pick_codec() {
  local dev
  dev="$(render_node)" || { echo ""; return; }
  if vaapi_works "$dev"; then
    echo "-c h264_vaapi -d $dev"
  else
    echo ""
  fi
}

# Человекочитаемое имя выбранного пути (для notify/статуса).
codec_label() {
  local params="$1"
  if [[ "$params" == *h264_vaapi* ]]; then
    if lspci 2>/dev/null | grep -qi nvidia; then
      echo "NVENC (VAAPI)"
    else
      echo "GPU (VAAPI)"
    fi
  else
    echo "софт (libx264)"
  fi
}

start() {
  if running; then echo "уже пишу"; return 0; fi
  local params; params="$(pick_codec)"
  local label; label="$(codec_label "$params")"
  local out="$DIR/lunar-$(date +%Y%m%d-%H%M%S).mp4"

  # shellcheck disable=SC2086
  setsid wf-recorder -f "$out" $params >/dev/null 2>&1 </dev/null &
  sleep 0.6
  if ! running; then
    # кодек не завёлся — падаем на софт
    label="софт (libx264)"
    setsid wf-recorder -f "$out" >/dev/null 2>&1 </dev/null &
    sleep 0.6
  fi
  pgrep -x wf-recorder | head -1 >"$PIDFILE"
  echo "$label" >"$CODECFILE"
  notify-send -a "Запись" "Запись экрана пошла · $label" "$out" 2>/dev/null
  echo "$out · $label"
}

stop() {
  if ! running; then echo "не пишу"; return 0; fi
  pkill -INT -x wf-recorder 2>/dev/null
  rm -f "$PIDFILE" "$CODECFILE"
  notify-send -a "Запись" "Запись остановлена" 2>/dev/null
  echo "stopped"
}

case "${1:-toggle}" in
  start)  start ;;
  stop)   stop ;;
  toggle) if running; then stop; else start; fi ;;
  status) running && echo 1 || echo 0 ;;
  probe)  params="$(pick_codec)"; echo "кодек: $(codec_label "$params")  ${params:-—}" ;;
  *) echo "usage: $0 start|stop|toggle|status|probe" >&2; exit 1 ;;
esac
