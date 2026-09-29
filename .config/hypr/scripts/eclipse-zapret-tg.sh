#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — локальный MTProto WS-прокси для Telegram
#  (tg-ws-proxy, Flowseal). Юнит — lunar-tgproxy.service (systemd --user),
#  поэтому sudo не нужен. Установка/секрет — ~/rice/install.sh.
#
#  Использование:
#    eclipse-zapret-tg.sh status    # состояние (key=value, для Hub)
#    eclipse-zapret-tg.sh link      # tg://proxy-ссылка для Telegram
#    eclipse-zapret-tg.sh on|off    # включить/выключить (+ автозапуск)
#    eclipse-zapret-tg.sh toggle    # переключить
#    eclipse-zapret-tg.sh restart   # перезапустить
#    eclipse-zapret-tg.sh open      # открыть ссылку в Telegram
# ════════════════════════════════════════════════════════════════
set -uo pipefail

UNIT=lunar-tgproxy.service
ENVF="$HOME/.config/lunar/tgproxy.env"

env_get() { grep -m1 "^$1=" "$ENVF" 2>/dev/null | cut -d= -f2-; }
is_active()  { systemctl --user is-active  --quiet "$UNIT" 2>/dev/null; }
is_enabled() { systemctl --user is-enabled --quiet "$UNIT" 2>/dev/null; }

link() {
  # точную ссылку печатает сам прокси в лог (секрет там в формате dd<hex>,
  # который требует Telegram для этого типа прокси)
  local l
  l="$(grep -ho 'tg://proxy?[^ ]*' "$HOME/.cache/lunar/tgproxy.log" 2>/dev/null | tail -1)"
  if [ -n "$l" ]; then printf '%s\n' "$l"; return; fi
  # фолбэк — собрать вручную; префикс dd обязателен
  local port secret
  port="$(env_get TGWSP_PORT)"; secret="$(env_get TGWSP_SECRET)"
  [ -n "$port" ] && [ -n "$secret" ] \
    && printf 'tg://proxy?server=127.0.0.1&port=%s&secret=dd%s\n' "$port" "$secret"
}

case "${1:-status}" in
  status)
    state=off; is_active && state=active
    enabled=no; is_enabled && enabled=yes
    printf 'state=%s\nenabled=%s\nport=%s\n' "$state" "$enabled" "$(env_get TGWSP_PORT || echo 1443)"
    ;;

  link) link ;;

  on)
    systemctl --user enable --now "$UNIT" && echo "прокси Telegram включён" \
      || echo "не удалось включить прокси"
    ;;
  off)
    systemctl --user disable --now "$UNIT" && echo "прокси Telegram выключен" \
      || echo "не удалось выключить прокси"
    ;;
  toggle)
    if is_active; then
      systemctl --user disable --now "$UNIT" && echo "прокси Telegram выключен"
    else
      systemctl --user enable --now "$UNIT" && echo "прокси Telegram включён"
    fi
    ;;
  restart)
    systemctl --user restart "$UNIT" && echo "прокси Telegram перезапущен"
    ;;

  open)
    l="$(link)"
    [ -n "$l" ] || { echo "нет секрета — переустанови рис (./install.sh)"; exit 1; }
    xdg-open "$l" >/dev/null 2>&1 &
    echo "открываю Telegram для подключения прокси"
    ;;

  *)
    echo "usage: $0 {status|link|on|off|toggle|restart|open}" >&2
    exit 2
    ;;
esac
