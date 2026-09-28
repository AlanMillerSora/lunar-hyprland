#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-status.sh — быстрый статус для панели одной строкой:
#     net=… kb=… kbdev=… dnd=… notif=… gpu=… gput=… gm=… pp=…
#  net  — eth | wifi:<сигнал> | off
#  kb   — текущая раскладка (RU/EN), kbdev — устройство
#  dnd  — 1 если mako в режиме «не беспокоить»
#  notif — сколько уведомлений
#  gpu/gput — загрузка и температура GPU (AMD sysfs или NVIDIA)
#  gm   — 1 если включён Game Mode
#  pp   — профиль питания (performance/balanced/power-saver)
#  Без python3: JSON разбирает jq (в зависимостях), уведомления — makoctl -j.
#  GPU отдаём одним «сырым» замером, а сглаживание дёрганого gpu_busy_percent
#  на APU делает панель (EMA) — без sleep-цикла в горячем пути.
# ════════════════════════════════════════════════════════════════

# ── сеть ──
net="off"
dev_types="$(nmcli -t -f TYPE,STATE device status 2>/dev/null)"
if grep -q '^ethernet:connected' <<<"$dev_types"; then
  net="eth"
elif grep -q '^wifi:connected' <<<"$dev_types"; then
  sig="$(nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null | grep '^\*' | head -1 | cut -d: -f2)"
  net="wifi:${sig:-0}"
fi

# ── раскладка ──
# Берём клавиатуру с флагом main, иначе первую. Разбор через jq.
kb="EN"; kbdev=""
if command -v jq >/dev/null 2>&1; then
  # разделитель \x1f — не встречается в имени устройства, поэтому
  # «мышь Logitech USB Receiver» не режется по пробелам
  IFS=$'\x1f' read -r kb kbdev < <(hyprctl devices -j 2>/dev/null | jq -r '
    ([.keyboards[] | select(.main)] + [.keyboards[0]])[0]
    | "\(.active_keymap[:2] | ascii_upcase)\u001f\(.name)"' 2>/dev/null)
fi

# ── уведомления ──
mode="$(makoctl mode 2>/dev/null)"
grep -q '^do-not-disturb$' <<<"$mode" && dnd=1 || dnd=0

# makoctl -j отдаёт JSON-массив уведомлений — считаем его длину через jq
notif="$(makoctl list -j 2>/dev/null | jq 'length' 2>/dev/null)"
notif="${notif:-0}"

# ── GPU (один замер; сглаживание — в панели) ──
# gpu_busy_percent есть не у всех драйверов (только amdgpu) — проверяем файл
gpu=""
gput=""
if command -v nvidia-smi >/dev/null 2>&1; then
  read -r gpu gput < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
    --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ' | tr ',' ' ')
else
  for f in /sys/class/drm/card*/device/gpu_busy_percent; do
    if [ -r "$f" ]; then gpu="$(<"$f")"; break; fi
  done
  for h in /sys/class/hwmon/hwmon*; do
    if [ -r "$h/name" ] && [ "$(<"$h/name")" = "amdgpu" ] && [ -r "$h/temp1_input" ]; then
      gput=$(( $(<"$h/temp1_input") / 1000 ))
      break
    fi
  done
fi

# ── Game Mode / профиль питания / запись ──
GM_FILE="$HOME/.cache/lunar/gamemode"
gm="0"
[ -r "$GM_FILE" ] && gm="$(<"$GM_FILE")"
pp="$(powerprofilesctl get 2>/dev/null || echo "")"
rec=0
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/lunar-record.pid"
rp=""
[ -r "$PIDFILE" ] && rp="$(<"$PIDFILE")"
if [ -n "$rp" ] && [[ "$rp" =~ ^[0-9]+$ ]] \
   && [ -r "/proc/$rp/comm" ] && [ "$(<"/proc/$rp/comm")" = "wf-recorder" ]; then
  rec=1
else
  # своего pid нет — считаем записью только wf-recorder, пишущий в наш каталог
  for p in $(pgrep -x wf-recorder); do
    if grep -aqF -- "$HOME/Videos/lunar-" "/proc/$p/cmdline" 2>/dev/null; then
      rec=1; break
    fi
  done
fi

printf 'net=%s\x1fkb=%s\x1fkbdev=%s\x1fdnd=%d\x1fnotif=%s\x1fgpu=%s\x1fgput=%s\x1fgm=%s\x1fpp=%s\x1frec=%d\n' \
  "$net" "${kb:-EN}" "$kbdev" "$dnd" "$notif" "${gpu:-}" "${gput:-}" "${gm:-0}" "${pp:-}" "$rec"
