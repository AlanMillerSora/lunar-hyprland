#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-status.sh — быстрый статус для панели одной строкой:
#     net=wifi:72 kb=RU kbdev=<имя> dnd=0 notif=3
#  net  — eth | wifi:<сигнал> | off
#  kb   — текущая раскладка (RU/EN)
#  dnd  — 1 если mako в режиме «не беспокоить»
#  notif — сколько уведомлений в истории mako
# ════════════════════════════════════════════════════════════════

net="off"
dev_types="$(nmcli -t -f TYPE,STATE device status 2>/dev/null)"
if grep -q '^ethernet:connected' <<<"$dev_types"; then
  net="eth"
elif grep -q '^wifi:connected' <<<"$dev_types"; then
  sig="$(nmcli -t -f IN-USE,SIGNAL device wifi 2>/dev/null | grep '^\*' | head -1 | cut -d: -f2)"
  net="wifi:${sig:-0}"
fi

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

mode="$(makoctl mode 2>/dev/null)"
grep -q '^do-not-disturb$' <<<"$mode" && dnd=1 || dnd=0

notif="$(makoctl list -j 2>/dev/null | python3 -c '
import sys, json
try:
    print(len(json.load(sys.stdin)))
except Exception:
    print(0)' 2>/dev/null)"
[ -z "$notif" ] && notif=0

printf 'net=%s kb=%s kbdev=%s dnd=%d notif=%s\n' \
  "$net" "${kb:-EN}" "$kbdev" "$dnd" "$notif"
