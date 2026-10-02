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
#  pp   — CPU governor (всегда performance; powersave убран)
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

# ── Game Mode / профиль питания / запись ──
GM_FILE="$HOME/.cache/lunar/gamemode"
gm="0"
[ -r "$GM_FILE" ] && gm="$(<"$GM_FILE")"
pp="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo performance)"

# ── CPU / RAM: всегда (лёгкое чтение /proc, без nvidia-smi) ──
cpu=0
read -r a b c d e rest < /proc/stat 2>/dev/null
idle=$((d + e)); total=$((a + b + c + d + e))
if [ -r "$HOME/.cache/lunar/cpu-last" ]; then
  read -r pi pt < "$HOME/.cache/lunar/cpu-last"
  dt=$((total - pt)); di=$((idle - pi))
  [ "$dt" -gt 0 ] && cpu=$(( (100 * (dt - di)) / dt ))
fi
printf '%s %s\n' "$idle" "$total" > "$HOME/.cache/lunar/cpu-last"

# температура CPU (k10temp/zenpower/coretemp)
ctemp=""
for h in /sys/class/hwmon/hwmon*; do
  n="$(cat "$h/name" 2>/dev/null)"
  case "$n" in
    k10temp|zenpower|coretemp)
      v="$(cat "$h/temp1_input" 2>/dev/null)"
      [ -n "$v" ] && { ctemp=$((v / 1000)); break; } ;;
  esac
done

# RAM (процент занятости)
ram=0; rtot=0
if [ -r /proc/meminfo ]; then
  mt=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo)
  ma=$(awk '/^MemAvailable:/{print $2; exit}' /proc/meminfo)
  [ -n "$mt" ] && [ "$mt" -gt 0 ] && { ram=$(( (mt - ma) * 100 / mt )); rtot=$(( mt / 1024 )); }
fi

# сеть: сумма по интерфейсам (u64), QML считает скорость по дельте
rx=0; tx=0
while IFS= read -r l; do
  case "$l" in
    *:*)
      i="${l%%:*}"; [ "$i" = "lo" ] && continue
      set -- ${l#*:}
      rx=$((rx + $1)); tx=$((tx + $9)) ;;
  esac
done < /proc/net/dev

# ── GPU: только в режиме телеметрии ──
# nvidia-smi дорогой (несколько сотен мс) — не дёргаю из бара каждые 3 с;
# панель поднимает cache/lunar-tele, пока открыт её режим.
gpu=""; gput=""
if [ -f "$HOME/.cache/lunar/tele" ]; then
  if command -v nvidia-smi >/dev/null 2>&1; then
    read -r gpu gput < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ' | tr ',' ' ')
  else
    for f in /sys/class/drm/card*/device/gpu_busy_percent; do
      if [ -r "$f" ]; then gpu="$(<"$f")"; break; fi
    done
    for h in /sys/class/hwmon/hwmon*; do
      if [ -r "$h/name" ] && [ "$(<"$h/name")" = "amdgpu" ] && [ -r "$h/temp1_input" ]; then
        gput=$(( $(<"$h/temp1_input") / 1000 )); break
      fi
    done
  fi
fi
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

printf 'net=%s\x1fkb=%s\x1fkbdev=%s\x1fdnd=%d\x1fnotif=%s\x1fcpu=%d\x1fctemp=%s\x1fram=%d\x1frtot=%d\x1frx=%d\x1ftx=%d\x1fgpu=%s\x1fgput=%s\x1fgm=%s\x1fpp=%s\x1frec=%d\n' \
  "$net" "${kb:-EN}" "$kbdev" "$dnd" "$notif" "$cpu" "$ctemp" "$ram" "$rtot" "$rx" "$tx" "${gpu:-}" "${gput:-}" "${gm:-0}" "${pp:-}" "$rec"
