#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Waybar: прогресс-бар затмения (покрытие по фазам 1..8)
#  Покрытия — из превью (script.js): 8, 40, 75, 100, 68, 35, 12, 0
#  Возвращает JSON для return-type=json:
#    text / class(total → красный на полном затмении) / tooltip
# ════════════════════════════════════════════════════════════

COV=(8 40 75 100 68 35 12 0)

cur="$(hyprctl activeworkspace -j 2>/dev/null | python3 -c 'import sys, json
try:
    print(json.load(sys.stdin)["id"])
except Exception:
    pass')"

if ! [[ "$cur" =~ ^[0-9]+$ ]] || (( cur < 1 || cur > 8 )); then
  cur=1
fi

pct="${COV[$((cur - 1))]}"
filled=$(( (pct + 5) / 10 ))
empty=$(( 10 - filled ))

bar=""
for ((i = 0; i < filled; i++)); do bar+="█"; done
for ((i = 0; i < empty; i++)); do bar+="░"; done

cls="normal"
(( pct == 100 )) && cls="total"

printf '{"text":"☾ %3d%%  %s", "class":"%s", "tooltip":"Phase %d — покрытие %d%%", "percentage":%d}' \
  "$pct" "$bar" "$cls" "$cur" "$pct" "$pct"