#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Waybar: заполнение затмения (фазы 1..8)
#  Покрытия — из превью (script.js): 8, 40, 75, 100, 68, 35, 12, 0
#  JSON для return-type=json:  text / class(total) / tooltip
# ════════════════════════════════════════════════════════════

COV=(8 40 75 100 68 35 12 0)
ROMAN=(I II III IV V VI VII VIII)
# лунные глифы фаз (mdi, как в иконках рабочих столов), индекс = фаза-1
MOON=("󰽨" "󰽡" "󰽥" "󰽤" "󰽧" "󰽣" "󰽦" "󰽢")
# человеческое имя фазы
NAME=("тонкий серп" "молодая луна" "прибывающая" "полное затмение" \
      "убывающая" "последняя четверть" "старый серп" "новолуние")

cur="$(hyprctl activeworkspace -j 2>/dev/null | python3 -c 'import sys, json
try:
    print(json.load(sys.stdin)["id"])
except Exception:
    pass')"

if ! [[ "$cur" =~ ^[0-9]+$ ]] || (( cur < 1 || cur > 8 )); then
  cur=1
fi

i=$(( cur - 1 ))
pct="${COV[$i]}"
moon="${MOON[$i]}"

# Тонкая полоса заполнения: 10 делений, «━» заполнено, «─» пусто.
filled=$(( (pct + 5) / 10 ))
bar=""
for ((c = 0; c < 10; c++)); do
  if (( c < filled )); then bar+="━"; else bar+="─"; fi
done

cls="normal"
(( pct == 100 )) && cls="total"

printf '{"text":"%s  %s  %d%%", "class":"%s", "tooltip":"Фаза %s · покрытие %d%% · %s", "percentage":%d}' \
  "$moon" "$bar" "$pct" "$cls" "${ROMAN[$i]}" "$pct" "${NAME[$i]}" "$pct"
