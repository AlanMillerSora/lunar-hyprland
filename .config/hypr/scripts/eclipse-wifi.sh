#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — Wi-Fi через iwd (iwctl)
#
#  В рисе ассоциацию держит iwd, IP раздаёт systemd-networkd;
#  NetworkManager выключен. Здесь — тонкая обёртка над iwctl,
#  чтобы Hub → Network умел искать сети и подключаться.
#
#  Использование:
#    eclipse-wifi.sh status                 # key=value: device, state, ssid, radio
#    eclipse-wifi.sh scan                   # запустить скан (iwd сканирует в фоне)
#    eclipse-wifi.sh list                   # сети, по строке (поля через \x1f)
#    eclipse-wifi.sh connect <ssid> [pass]  # подключиться (pass — для psk)
#    eclipse-wifi.sh disconnect             # отключиться
#    eclipse-wifi.sh radio on|off           # питание адаптера
#
#  Формат list (поля разделены \x1f, как в eclipse-status.sh):
#    ssid=<имя>\x1fsec=<psk|8021x|owe|sae|open>\x1fsig=<0..100>\x1fconn=<0|1>
#
#  Про пароль: `--passphrase` на миг попадает в argv процесса (виден в ps).
#  Для личного ПК это допустимо: iwctl иначе спрашивает пароль интерактивно,
#  а из QML интерактива нет.
# ════════════════════════════════════════════════════════════════
set -uo pipefail

# адаптер/устройство можно переопределить окружением (на других машинах имя иное)
DEV="${ECLIPSE_WIFI_DEV:-wlan0}"

# --dont-ask: не уходим в интерактивный запрос (из Hub его не видно)
iwctl_() { iwctl --dont-ask "$@"; }

# iwctl печатает ANSI-цвета даже в pipe — снимаю их
noansi() { sed -r 's/\x1b\[[0-9;]*m//g'; }

show_station() { iwctl_ station "$DEV" show | noansi; }

# SSID текущего подключения (пусто, если не подключены)
connected_ssid() {
  show_station \
    | sed -n 's/^ *Connected network[[:space:]][[:space:]]*//p' \
    | sed -e 's/[[:space:]]*$//' | head -1
}

# on | off | unknown
radio_state() {
  local p
  p="$(iwctl_ device "$DEV" show | noansi \
       | sed -n 's/^.*[[:space:]]Powered[[:space:]][[:space:]]*//p' \
       | sed -e 's/[[:space:]]*$//' | head -1)"
  printf '%s' "${p:-unknown}"
}

cmd_status() {
  local state ssid radio
  state="$(show_station \
           | sed -n 's/^ *State[[:space:]][[:space:]]*//p' \
           | sed -e 's/[[:space:]]*$//' | head -1)"
  ssid="$(connected_ssid)"
  radio="$(radio_state)"
  printf 'device=%s\nstate=%s\nssid=%s\nradio=%s\n' \
    "$DEV" "${state:-unknown}" "$ssid" "$radio"
}

cmd_scan() {
  iwctl_ station "$DEV" scan >/dev/null
  printf 'scan=started\n'
}

cmd_list() {
  local conn raw line name sec stars rest c sig
  conn="$(connected_ssid)"
  # Repeater в QML ждёт одну сеть на строку; пустые/служебные строки отсеиваю.
  iwctl_ station "$DEV" get-networks | while IFS= read -r raw; do
    case "$raw" in
      *"Network name"*|*"Available networks"*|*"---"*) continue ;;
    esac
    # Сила сигнала — «яркие» звёзды; остаток iwctl рисует серым
    # (ANSI 1;90). Сначала выбрасываю серые звёзды вместе с их кодом,
    # потом снимаю оставшиеся цвета — и считаю только яркие.
    line="$(printf '%s\n' "$raw" \
            | sed -r 's/\x1b\[[0-9;]*m\*+\x1b\[0m//g' \
            | noansi)"
    line="${line#"${line%%[![:space:]]*}"}"   # ltrim
    line="${line%"${line##*[![:space:]]}"}"   # rtrim
    [ -n "$line" ] || continue
    # хвост строки — звёзды силы сигнала; без них это не сеть
    [[ "$line" =~ ^(.*[^[:space:]])[[:space:]]+(\*+)$ ]] || continue
    rest="${BASH_REMATCH[1]}"; stars="${BASH_REMATCH[2]}"
    # перед звёздами может стоять security-токен, у открытых его нет
    sec="open"
    if [[ "$rest" =~ ^(.*[^[:space:]])[[:space:]]+(psk|8021x|owe|sae|psk-sae)$ ]]; then
      rest="${BASH_REMATCH[1]}"; sec="${BASH_REMATCH[2]}"
    fi
    name="${rest#\>}"                         # маркер текущей сети '>'
    name="${name%"${name##*[![:space:]]}"}"   # rtrim
    [ -n "$name" ] || continue
    sig=$(( ${#stars} * 100 / 4 )); [ "$sig" -gt 100 ] && sig=100
    c=0; [ "$name" = "$conn" ] && c=1
    printf 'ssid=%s\x1fsec=%s\x1fsig=%d\x1fconn=%d\n' "$name" "$sec" "$sig" "$c"
  done
}

cmd_connect() {
  local ssid="${1:-}" pass="${2:-}"
  [ -n "$ssid" ] || { echo "не указана сеть" >&2; return 2; }
  if [ -n "$pass" ]; then
    iwctl_ --passphrase "$pass" station "$DEV" connect "$ssid"
  else
    iwctl_ station "$DEV" connect "$ssid"
  fi
}

cmd_disconnect() { iwctl_ station "$DEV" disconnect; }

cmd_radio() {
  case "${1:-}" in
    on|off) iwctl_ device "$DEV" set-property Powered "$1" ;;
    *) echo "usage: $0 radio on|off" >&2; return 2 ;;
  esac
}

case "${1:-status}" in
  status)     cmd_status ;;
  scan)       cmd_scan ;;
  list)       cmd_list ;;
  connect)    shift; cmd_connect "${1:-}" "${2:-}" ;;
  disconnect) cmd_disconnect ;;
  radio)      shift; cmd_radio "${1:-}" ;;
  *)
    echo "usage: $0 {status|scan|list|connect <ssid> [pass]|disconnect|radio on|off}" >&2
    exit 2
    ;;
esac
