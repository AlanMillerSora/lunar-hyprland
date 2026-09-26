#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-record.sh — запись экрана через wf-recorder.
#
#  Кодирование: аппаратное (VAAPI) с авто-выбором, иначе — софт.
#    · NVIDIA — через VAAPI (libva-nvidia-driver поверх NVENC);
#    · AMD/Intel — через VAAPI (родной драйвер);
#    · если GPU-кодек не завёлся — падаем на libx264 (софт).
#
#  Качество/битрейт/герцовку задают переключатели в Hub → Monitors
#  (файл ~/.config/lunar/record.json). Изменения применяются со
#  следующей записи. Дефолты: QP 24, 12 Мбит/с, герцовка по экрану.
#
#  Запуск:  eclipse-record.sh start|stop|toggle|status|probe
#  Файлы:   ~/Videos/lunar-ГГГГММДД-ЧЧММСС.mp4
# ════════════════════════════════════════════════════════════════
set -uo pipefail

DIR="$HOME/Videos"
mkdir -p "$DIR"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/lunar-record.pid"
CODECFILE="${XDG_RUNTIME_DIR:-/tmp}/lunar-record.codec"
CONF="$HOME/.config/lunar/record.json"

running() { pgrep -x wf-recorder >/dev/null 2>&1; }

# настройки из Hub (--bitrate в JSON — Мбит/с, qp — постоянное качество)
rec_qp=24
rec_bitrate=12
rec_fps=auto

load_conf() {
  [ -r "$CONF" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local v
  v="$(jq -r '.qp // 24' "$CONF" 2>/dev/null)";        [ -n "$v" ] && [ "$v" != null ] && rec_qp="$v"
  v="$(jq -r '.bitrate // 12' "$CONF" 2>/dev/null)";   [ -n "$v" ] && [ "$v" != null ] && rec_bitrate="$v"
  v="$(jq -r '.fps // "auto"' "$CONF" 2>/dev/null)";   [ -n "$v" ] && [ "$v" != null ] && rec_fps="$v"
}

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

# Параметры VAAPI-энкодера: постоянное качество (QP) + потолок битрейта.
vaapi_params() {  # vaapi_params <render-node>
  local p="-c h264_vaapi -d $1 -p rc_mode=CQP -p qp=$rec_qp"
  p="$p -p maxrate=${rec_bitrate}M -p buffersize=$((rec_bitrate * 2))M"
  [ "$rec_fps" != auto ] && p="$p -r $rec_fps"
  echo "$p"
}

# Параметры софт-энкодера (fallback). CRF ≈ QP − 6.
soft_params() {
  local crf=$((rec_qp - 6)); [ "$crf" -lt 0 ] && crf=0
  local p="-c libx264 -p preset=veryfast -p crf=$crf"
  [ "$rec_fps" != auto ] && p="$p -r $rec_fps"
  echo "$p"
}

# Человекочитаемое имя выбранного пути (для notify/статуса).
vaapi_label() {
  if lspci 2>/dev/null | grep -qi nvidia; then
    echo "NVENC (VAAPI)"
  else
    echo "GPU (VAAPI)"
  fi
}

start() {
  if running; then echo "уже пишу"; return 0; fi
  load_conf
  local dev params label
  dev="$(render_node)" || dev=""
  local out="$DIR/lunar-$(date +%Y%m%d-%H%M%S).mp4"

  if [ -n "$dev" ] && vaapi_works "$dev"; then
    params="$(vaapi_params "$dev")"
    label="$(vaapi_label)"
  else
    params="$(soft_params)"
    label="софт (libx264)"
  fi

  # shellcheck disable=SC2086
  setsid wf-recorder -f "$out" $params >/dev/null 2>&1 </dev/null &
  sleep 0.6
  if ! running; then
    # кодек не завёлся — падаем на софт
    label="софт (libx264)"
    params="$(soft_params)"
    # shellcheck disable=SC2086
    setsid wf-recorder -f "$out" $params >/dev/null 2>&1 </dev/null &
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

probe() {
  load_conf
  local dev params label
  dev="$(render_node)" || dev=""
  if [ -n "$dev" ] && vaapi_works "$dev"; then
    params="$(vaapi_params "$dev")"
    label="$(vaapi_label)"
  else
    params="$(soft_params)"
    label="софт (libx264)"
  fi
  echo "кодек: $label"
  echo "настройки: QP $rec_qp · ${rec_bitrate} Мбит/с · герцовка $rec_fps"
  echo "параметры: $params"
}

case "${1:-toggle}" in
  start)  start ;;
  stop)   stop ;;
  toggle) if running; then stop; else start; fi ;;
  status) running && echo 1 || echo 0 ;;
  probe)  probe ;;
  *) echo "usage: $0 start|stop|toggle|status|probe" >&2; exit 1 ;;
esac
