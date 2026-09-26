#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-status.sh — быстрый статус для панели одной строкой:
#     net=… kb=… kbdev=… dnd=… notif=… gpu=… gput=… gm=… pp=… rec=…
#  net  — eth | wifi:<сигнал> | off
#  kb   — текущая раскладка (RU/EN), kbdev — устройство
#  dnd  — 1 если mako в режиме «не беспокоить»
#  notif — сколько уведомлений
#  gpu/gput — загрузка и температура GPU (AMD sysfs или NVIDIA)
#  gm   — 1 если включён Game Mode
#  pp   — профиль питания (performance/balanced/power-saver)
#
#  Скрипт вызывается панелью каждые 1.5 с, поэтому он должен быть
#  максимально дешёвым: без python3 (его запуск — десятки мс) и без
#  лишних процессов. powerprofilesctl — тоже python-скрипт (~160 мс),
#  поэтому профиль читаем через busctl.
# ════════════════════════════════════════════════════════════════

# ── сеть ──
net="off"
dev_types="$(nmcli -t -f TYPE,STATE device status 2>/dev/null)"
if grep -q '^ethernet:connected' <<<"$dev_types"; then
  net="eth"
elif grep -q '^wifi:connected' <<<"$dev_types"; then
  sig="$(nmcli -t -f IN-USE,SIGNAL device wifi 2>/dev/null | grep '^\*' | head -1 | cut -d: -f2)"
  net="wifi:${sig:-0}"
fi

# ── раскладка: блок главной клавиатуры из JSON, разбор без python3 ──
kbjson="$(hyprctl devices -j 2>/dev/null | awk 'BEGIN{RS="}"} /"main": true/{print; exit}')"
[ -z "$kbjson" ] && kbjson="$(hyprctl devices -j 2>/dev/null | head -40)"
kb="$(grep -o '"active_keymap": *"[^"]*"' <<<"$kbjson" | head -1 | sed 's/.*: *"//; s/"$//')"
kb="${kb:0:2}"; kb="${kb^^}"
[ -z "$kb" ] && kb="EN"
kbdev="$(grep -o '"name": *"[^"]*"' <<<"$kbjson" | head -1 | sed 's/.*: *"//; s/"$//')"

# ── уведомления ──
dnd=0
makoctl mode 2>/dev/null | grep -q '^do-not-disturb$' && dnd=1
notif="$(makoctl list -j 2>/dev/null | grep -o '"id"' | wc -l)"
[ -z "$notif" ] && notif=0

# ── GPU + температура CPU ──
gpu=""
gput=""
if command -v nvidia-smi >/dev/null 2>&1; then
  read -r gpu gput < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
    --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ' | tr ',' ' ')
else
  # AMD: gpu_busy_percent на APU «дёргается» 0/100 — усредняем 3 замера
  sum=0; n=0
  for _ in 1 2 3; do
    v="$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)"
    if [ -n "$v" ]; then sum=$((sum + v)); n=$((n + 1)); fi
    sleep 0.04
  done
  [ "$n" -gt 0 ] && gpu=$((sum / n))
fi
# температуры: CPU (k10temp/…) и GPU (amdgpu) — один обход hwmon
ctmp=""
for h in /sys/class/hwmon/hwmon*; do
  [ -r "$h/name" ] || continue
  case "$(<"$h/name")" in
    k10temp|coretemp|zenpower|k8temp)
      [ -r "$h/temp1_input" ] && ctmp=$(( $(<"$h/temp1_input") / 1000 )) ;;
    amdgpu)
      [ -z "$gput" ] && [ -r "$h/temp1_input" ] && gput=$(( $(<"$h/temp1_input") / 1000 )) ;;
  esac
done

# ── Game Mode / профиль питания / запись ──
gm="$(<"$HOME/.cache/lunar/gamemode" 2>/dev/null || echo 0)"
pp="$(busctl get-property org.freedesktop.UPower.PowerProfiles \
  /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles \
  ActiveProfile 2>/dev/null | awk -F'"' '{print $2}')"
pgrep -x wf-recorder >/dev/null 2>&1 && rec=1 || rec=0

printf 'net=%s kb=%s kbdev=%s dnd=%d notif=%s gpu=%s gput=%s ctmp=%s gm=%s pp=%s rec=%d\n' \
  "$net" "${kb:-EN}" "$kbdev" "$dnd" "$notif" "${gpu:-}" "${gput:-}" "${ctmp:-}" "${gm:-0}" "${pp:-}" "$rec"
