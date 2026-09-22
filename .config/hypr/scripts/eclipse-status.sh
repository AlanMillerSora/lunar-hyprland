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

# ── раскладка ──
read -r kb kbdev < <(hyprctl devices -j 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    ks = [x for x in d.get("keyboards", []) if x.get("main")] or d.get("keyboards", [])
    if ks:
        print(ks[0].get("active_keymap", "EN")[:2].upper(), ks[0].get("name", ""))
    else:
        print("EN", "")
except Exception:
    print("EN", "")
')

# ── уведомления ──
mode="$(makoctl mode 2>/dev/null)"
grep -q '^do-not-disturb$' <<<"$mode" && dnd=1 || dnd=0

notif="$(makoctl list -j 2>/dev/null | python3 -c '
import sys, json
try:
    print(len(json.load(sys.stdin)))
except Exception:
    print(0)' 2>/dev/null)"
[ -z "$notif" ] && notif=0

# ── GPU ──
gpu=""
gput=""
if command -v nvidia-smi >/dev/null 2>&1; then
  read -r gpu gput < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
    --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ' | tr ',' ' ')
else
  gpu="$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)"
  for h in /sys/class/hwmon/hwmon*; do
    if [ "$(cat "$h/name" 2>/dev/null)" = "amdgpu" ]; then
      t="$(cat "$h/temp1_input" 2>/dev/null)"
      [ -n "$t" ] && gput=$((t / 1000))
    fi
  done
fi

# ── Game Mode / профиль питания / запись ──
gm="$(cat "$HOME/.cache/lunar/gamemode" 2>/dev/null || echo 0)"
pp="$(powerprofilesctl get 2>/dev/null || echo "")"
pgrep -x wf-recorder >/dev/null 2>&1 && rec=1 || rec=0

printf 'net=%s kb=%s kbdev=%s dnd=%d notif=%s gpu=%s gput=%s gm=%s pp=%s rec=%d\n' \
  "$net" "${kb:-EN}" "$kbdev" "$dnd" "$notif" "${gpu:-}" "${gput:-}" "${gm:-0}" "${pp:-}" "$rec"
