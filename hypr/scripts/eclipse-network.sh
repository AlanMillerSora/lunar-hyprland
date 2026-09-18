#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Wi-Fi меню для waybar: wofi + nmcli.
#  Список сетей, подключение (с запросом пароля), отключение,
#  вкл/выкл радио, «Настройки сети…» (nm-connection-editor).
#
#  Запуск:  eclipse-network.sh [menu|toggle]
# ════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKPASS="$SELF_DIR/eclipse-askpass.py"
WOFI=(wofi --dmenu --insensitive --prompt "Сеть")

notify() { notify-send -a "Сеть" "$1" "${2:-}" 2>/dev/null || true; }

wifi_on() { nmcli -t -f WIFI general status 2>/dev/null | grep -q '^enabled'; }

current_ssid() {
  nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
    | awk -F: '$2=="802-11-wireless"{print $1; exit}'
}

toggle_wifi() {
  if wifi_on; then
    nmcli radio wifi off >/dev/null 2>&1 && notify "Wi-Fi выключен"
  else
    nmcli radio wifi on >/dev/null 2>&1 && notify "Wi-Fi включён"
  fi
}

ask_password() {
  local prompt="$1"
  if [ -x "$ASKPASS" ]; then
    "$ASKPASS" "$prompt"
  else
    wofi --dmenu --password --prompt "$prompt" < /dev/null
  fi
}

connect_ssid() {
  local ssid="$1" sec="$2" out rc
  local -a args=(dev wifi connect "$ssid")
  if [ -n "$sec" ] && [ "$sec" != "--" ] && [ "$sec" != "" ]; then
    local pass
    pass="$(ask_password "Пароль для «${ssid}»")"
    [ -z "$pass" ] && return
    args+=(password "$pass")
  fi
  wifi_on || nmcli radio wifi on >/dev/null 2>&1
  out="$(nmcli "${args[@]}" 2>&1)"; rc=$?
  if [ $rc -eq 0 ]; then
    notify "Подключено: ${ssid}"
  else
    notify "Не удалось подключиться" "$out"
  fi
}

disconnect_ssid() {
  nmcli connection down id "$1" >/dev/null 2>&1 \
    && notify "Отключено: $1" || notify "Не удалось отключиться"
}

build_menu() {
  local cur; cur="$(current_ssid)"
  if wifi_on; then
    printf '󰖪  Выключить Wi-Fi\n'
  else
    printf '󰖩  Включить Wi-Fi\n'
  fi
  printf '󰒓  Настройки сети…\n'
  [ -n "$cur" ] && printf '󰅖  Отключиться от «%s»\n' "$cur"
  wifi_on || return 0
  printf '\n'
  # nmcli -t с экранированием «\:» — парсим в python, дедуп по SSID (сильнейший сигнал)
  nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes 2>/dev/null \
  | python3 -c '
import sys
seen = {}
for raw in sys.stdin:
    parts, cur, esc = [], "", False
    for ch in raw.rstrip("\n"):
        if esc: cur += ch; esc = False; continue
        if ch == "\\": esc = True; continue
        if ch == ":": parts.append(cur); cur = ""; continue
        cur += ch
    parts.append(cur)
    if len(parts) < 4: continue
    inuse, ssid, sig, sec = parts[0], parts[1], parts[2], parts[3]
    if not ssid: continue
    try: sig = int(sig)
    except ValueError: sig = 0
    if ssid in seen and seen[ssid][0] >= sig: continue
    seen[ssid] = (sig, inuse, sec)
for ssid, (sig, inuse, sec) in sorted(seen.items(), key=lambda kv: -kv[1][0]):
    mark = "󰄬" if inuse == "*" else "·"
    lock = " 󰌾" if sec and sec != "--" else ""
    print(f"{mark} {ssid} · {sig}%{lock}")
'
}

main_menu() {
  local sel ssid
  sel="$(build_menu | grep -v '^$' | "${WOFI[@]}")" || exit 0
  [ -z "$sel" ] && exit 0
  case "$sel" in
    *"Выключить Wi-Fi"*|*"Включить Wi-Fi"*) toggle_wifi ;;
    *"Настройки сети"*)                    nm-connection-editor >/dev/null 2>&1 & ;;
    *"Отключиться от"*)                    disconnect_ssid "$(current_ssid)" ;;
    ·*|󰄬*)
      ssid="$(printf '%s' "$sel" | sed -E 's/^[^ ]+ +//; s/ ·.*$//')"
      [ -z "$ssid" ] && exit 0
      # SECURITY для выбранной сети
      local sec
      sec="$(nmcli -t -f SSID,SECURITY dev wifi list 2>/dev/null \
        | awk -F: -v s="$ssid" '$1==s{print $2; exit}')"
      connect_ssid "$ssid" "$sec"
      ;;
  esac
}

case "${1:-menu}" in
  toggle) toggle_wifi ;;
  *)      main_menu ;;
esac
