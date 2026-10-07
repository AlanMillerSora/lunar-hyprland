#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-record.sh — запись экрана через wf-recorder.
#
#  Кодирование — аппаратное, с авто-выбором; софт — крайний запасной путь.
#    · NVIDIA — NVENC (ffmpeg h264_nvenc): libva-nvidia-driver умеет только
#      декод, поэтому VAAPI-энкода на NVIDIA нет, а NVENC есть;
#    · AMD/Intel — VAAPI (родной драйвер);
#    · если аппаратный кодек не завёлся — падаем на libx264 (софт).
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

DIR="$HOME/Videos"   # mkdir — только когда реально пишем (start)
# приватный рантайм-каталог; общий /tmp для pid/лока не используем
RUNTIME="${XDG_RUNTIME_DIR:-}"
if [ -z "$RUNTIME" ]; then
  # стабильный per-user каталог: свежий mktemp на каждый вызов ломал связку
  # start/stop (pid писался в один каталог, stop читал другой)
  RUNTIME="${TMPDIR:-/tmp}/lunar-record-$(id -u)"
  mkdir -p "$RUNTIME" 2>/dev/null || true
  chmod 700 "$RUNTIME" 2>/dev/null || true
  [ -d "$RUNTIME" ] || { echo "нет каталога для pid/лока записи" >&2; exit 1; }
fi
PIDFILE="$RUNTIME/lunar-record.pid"
CODECFILE="$RUNTIME/lunar-record.codec"
LOCKFILE="$RUNTIME/lunar-record.lock"
CONF="$HOME/.config/lunar/record.json"

# pid именно нашей записи: сначала PIDFILE, иначе — по каталогу вывода
# ($DIR/lunar-…). Чужие wf-recorder не трогаем.
rec_pid() {
  local p
  p="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [ -n "$p" ] && [ "$(cat "/proc/$p/comm" 2>/dev/null || true)" = "wf-recorder" ] \
     && tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -qF -- "$DIR/lunar-"; then
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
    return 1
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
  # мусор из record.json не тащим в argv: чинится дефолтом
  [[ "$rec_qp" =~ ^[0-9]+$ ]] && [ "$rec_qp" -le 51 ] || rec_qp=24
  [[ "$rec_bitrate" =~ ^[1-9][0-9]*$ ]] || rec_bitrate=12
  [[ "$rec_fps" == auto || "$rec_fps" =~ ^[1-9][0-9]*$ ]] || rec_fps=auto
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

# NVENC (NVIDIA) проверяю пробой. libva-nvidia-driver умеет только декод,
# поэтому VAAPI-энкода на NVIDIA нет; а NVENC (ffmpeg h264_nvenc) есть — он и
# берёт запись, разгружая CPU. На AMD/Intel nvidia-smi нет — ветка мимо.
nvenc_works() {
  command -v nvidia-smi >/dev/null 2>&1 || return 1
  local probe rc=1
  probe="$(mktemp --suffix=.mp4)" || return 1
  if ffmpeg -hide_banner -loglevel error -y \
       -f lavfi -i "testsrc=duration=1:size=320x240:rate=30" \
       -c:v h264_nvenc -frames:v 1 "$probe" >/dev/null 2>&1 && [[ -s "$probe" ]]; then
    rc=0
  fi
  rm -f -- "$probe"
  return $rc
}

# Метка цветового диапазона и матрицы. Без неё wf-recorder пишет yuvj420p с
# флагом pc (full-range), хотя сэмплы уже сжаты в 16–235: плеер верит флагу,
# не разворачивает уровни — и картинка выходит тусклее (белое 235 вместо 255).
# Ограниченный диапазон + BT.709 — стандарт видео: плеер разворачивает 16–235
# обратно в полный, и запись совпадает с экраном пиксель в пиксель.
# NVENC по умолчанию ставит SD-матрицу bt470bg — её тоже перебиваю на bt709.
rec_color=(-p color_range=tv -p colorspace=bt709 -p color_primaries=bt709 -p color_trc=bt709)

# Параметры NVENC: VBR с постоянным качеством (CQ) + потолок битрейта.
# rec_qp/rec_bitrate — те же переключатели Hub → Monitors, что и для софта.
nvenc_params() {
  local p="-c h264_nvenc -p preset=p5 -p tune=hq -p rc=vbr -p cq=$rec_qp"
  p="$p -p b:v=${rec_bitrate}M -p maxrate=${rec_bitrate}M -p bufsize=$((rec_bitrate * 2))M ${rec_color[*]}"
  [ "$rec_fps" != auto ] && p="$p -r $rec_fps"
  echo "$p"
}

# Параметры VAAPI-энкодера (AMD/Intel): постоянное качество (QP) + потолок.
vaapi_params() {  # vaapi_params <render-node>
  local p="-c h264_vaapi -d $1 -p rc_mode=CQP -p qp=$rec_qp"
  p="$p -p maxrate=${rec_bitrate}M -p buffersize=$((rec_bitrate * 2))M ${rec_color[*]}"
  [ "$rec_fps" != auto ] && p="$p -r $rec_fps"
  echo "$p"
}

# Параметры софт-энкодера (fallback). CRF ≈ QP − 6.
soft_params() {
  local crf=$((rec_qp - 6)); [ "$crf" -lt 0 ] && crf=0
  local p="-c libx264 -p preset=veryfast -p crf=$crf ${rec_color[*]}"
  [ "$rec_fps" != auto ] && p="$p -r $rec_fps"
  echo "$p"
}

# Какой путь берём: NVENC (NVIDIA) → VAAPI (AMD/Intel) → софт.
pick_encoder() {
  if nvenc_works; then echo "nvenc"; return 0; fi
  local dev; dev="$(render_node 2>/dev/null)" || dev=""
  if [ -n "$dev" ] && vaapi_works "$dev"; then echo "vaapi"; return 0; fi
  echo "soft"
}

# Человекочитаемое имя пути (для notify/статуса).
encoder_label() {
  case "$1" in
    nvenc) echo "NVIDIA NVENC (GPU)";;
    vaapi) echo "GPU (VAAPI)";;
    *)     echo "софт (libx264)";;
  esac
}

# Параметры для выбранного пути.
encoder_params() {  # encoder_params <kind> <render-node>
  case "$1" in
    nvenc) nvenc_params;;
    vaapi) vaapi_params "$2";;
    *)     soft_params;;
  esac
}

start() {
  if running; then echo "уже пишу"; return 0; fi
  load_conf
  mkdir -p "$DIR"
  local dev kind label out
  local -a params=()
  dev="$(render_node)" || dev=""
  out="$DIR/lunar-$(date +%Y%m%d-%H%M%S).mp4"

  kind="$(pick_encoder)"
  label="$(encoder_label "$kind")"
  read -r -a params <<<"$(encoder_params "$kind" "$dev")"

  # 9>&- — не наследовать лок записью, иначе stop не сможет его взять
  setsid wf-recorder -f "$out" "${params[@]}" >/dev/null 2>&1 </dev/null 9>&- &
  sleep 0.6
  if [ -z "$(rec_pid 2>/dev/null || true)" ]; then
    # выбранный кодек не завёлся — падаем на софт
    kind="soft"; label="$(encoder_label "$kind")"
    read -r -a params <<<"$(soft_params)"
    setsid wf-recorder -f "$out" "${params[@]}" >/dev/null 2>&1 </dev/null 9>&- &
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
  # не вышел за 5 с — эскалируем, иначе снимем pidfile у живого процесса
  kill -0 "$pid" 2>/dev/null && kill -TERM "$pid" 2>/dev/null && sleep 1
  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
  if kill -0 "$pid" 2>/dev/null; then
    echo "процесс $pid не завершился — запись могла остаться"
  fi
  rm -f "$PIDFILE" "$CODECFILE"
  notify-send -a "Запись" "Запись остановлена" 2>/dev/null
  echo "stopped"
}

toggle() { if running; then stop; else start; fi; }

probe() {
  load_conf
  local dev kind label
  local -a params=()
  dev="$(render_node)" || dev=""
  kind="$(pick_encoder)"
  label="$(encoder_label "$kind")"
  read -r -a params <<<"$(encoder_params "$kind" "$dev")"
  echo "кодек: $label"
  echo "настройки: QP $rec_qp · ${rec_bitrate} Мбит/с · герцовка $rec_fps"
  echo "параметры: ${params[*]}"
}

case "${1:-toggle}" in
  start)  run_locked start ;;
  stop)   run_locked stop ;;
  toggle) run_locked toggle ;;
  status) running && echo 1 || echo 0 ;;
  probe)  probe ;;
  *) echo "usage: $0 start|stop|toggle|status|probe" >&2; exit 1 ;;
esac
