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
#
#  start/stop/toggle сериализуются локом, а stop трогает только свой
#  процесс (по PIDFILE или по каталогу вывода) — чужие записи не бьём.
# ════════════════════════════════════════════════════════════════
set -uo pipefail

DIR="$HOME/Videos"
mkdir -p "$DIR"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/lunar-record.pid"
CODECFILE="${XDG_RUNTIME_DIR:-/tmp}/lunar-record.codec"
LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/lunar-record.lock"
CONF="$HOME/.config/lunar/record.json"

# pid именно нашей записи: сначала PIDFILE, иначе — по каталогу вывода
# ($DIR/lunar-…). Чужие wf-recorder не трогаем.
rec_pid() {
  local p
  p="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [ -n "$p" ] && [ "$(cat "/proc/$p/comm" 2>/dev/null || true)" = "wf-recorder" ]; then
    echo "$p"; return 0
  fi
  for p in $(pgrep -x wf-recorder); do
    if tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -qF -- "$DIR/lunar-"; then
      echo "$p"; return 0
    fi
  done
  return 1
}

running() { rec_pid >/dev/null 2>&1; }

# start/stop/toggle сериализуем: два быстрых нажатия не поднимут две записи
run_locked() {
  exec 9>"$LOCKFILE"
  if ! flock -n 9 2>/dev/null; then
    echo "занято: другая операция с записью выполняется"
    return 0
  fi
  "$@"
}

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
# прогоняем 1 кадр через VAAPI и смотрим, вышел ли файл. Пишем в mktemp,
# чтобы параллельные probe/start не затирали общий /tmp-файл.
vaapi_works() {
  local dev="$1" probe rc=1
  [[ -e "$dev" ]] || return 1
  probe="$(mktemp --suffix=.mp4)" || return 1
  if ffmpeg -hide_banner -loglevel error -y \
       -init_hw_device "vaapi=va:$dev" \
       -f lavfi -i "testsrc=duration=1:size=320x240:rate=30" \
       -vf 'format=nv12,hwupload' -c:v h264_vaapi -frames:v 1 \
       "$probe" >/dev/null 2>&1 && [[ -s "$probe" ]]; then
    rc=0
  fi
  rm -f -- "$probe"
  return $rc
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

  # 9>&- — не наследовать лок записью, иначе stop не сможет его взять
  # shellcheck disable=SC2086
  setsid wf-recorder -f "$out" $params >/dev/null 2>&1 </dev/null 9>&- &
  sleep 0.6
  if [ -z "$(rec_pid 2>/dev/null || true)" ]; then
    # кодек не завёлся — падаем на софт
    label="софт (libx264)"
    params="$(soft_params)"
    # shellcheck disable=SC2086
    setsid wf-recorder -f "$out" $params >/dev/null 2>&1 </dev/null 9>&- &
    sleep 0.6
  fi

  local pid
  pid="$(rec_pid 2>/dev/null || true)"
  if [ -z "$pid" ]; then
    rm -f "$PIDFILE" "$CODECFILE"
    notify-send -a "Запись" "Запись не пошла — кодек не завёлся" 2>/dev/null
    echo "запись не пошла"
    return 1
  fi

  echo "$pid" >"$PIDFILE"
  echo "$label" >"$CODECFILE"
  notify-send -a "Запись" "Запись экрана пошла · $label" "$out" 2>/dev/null
  echo "$out · $label"
}

stop() {
  local pid
  if ! pid="$(rec_pid 2>/dev/null)"; then
    echo "не пишу"
    return 0
  fi
  kill -INT "$pid" 2>/dev/null
  # ждём выхода процесса: иначе следующий toggle примет его за живую запись
  local i=0
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 50 ]; do
    sleep 0.1; i=$((i + 1))
  done
  rm -f "$PIDFILE" "$CODECFILE"
  notify-send -a "Запись" "Запись остановлена" 2>/dev/null
  echo "stopped"
}

toggle() { if running; then stop; else start; fi; }

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
  start)  run_locked start ;;
  stop)   run_locked stop ;;
  toggle) run_locked toggle ;;
  status) running && echo 1 || echo 0 ;;
  probe)  probe ;;
  *) echo "usage: $0 start|stop|toggle|status|probe" >&2; exit 1 ;;
esac
