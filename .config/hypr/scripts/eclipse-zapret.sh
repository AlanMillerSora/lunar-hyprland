#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — управление zapret (обход DPI: Discord / YouTube)
#
#  Обёртка над zapret.service. Установка — ~/rice/install.sh --zapret
#
#  Использование:
#    eclipse-zapret.sh status    # состояние (key=value, для Hub)
#    eclipse-zapret.sh on|off    # включить/выключить (+ автозапуск)
#    eclipse-zapret.sh toggle    # переключить
#    eclipse-zapret.sh restart   # перезапустить
#    eclipse-zapret.sh update    # git pull + пересборка + рестарт
#    eclipse-zapret.sh tune      # подбор стратегии (blockcheck.sh)
# ════════════════════════════════════════════════════════════════
set -uo pipefail

ZDIR=/opt/zapret
UNIT=zapret.service

# без пароля (root-хелпер svc.sh ставит install.sh); если хелпер или
# правило не установлены — внятно сообщаем, а не уходим в невидимый
# polkit-диалог pkexec
priv() {
  if sudo -n "$@" 2>/dev/null; then
    return 0
  fi
  echo "zapret: нет прав без пароля (нужен root-хелпер svc.sh — ./install.sh)" >&2
  return 1
}

is_active()  { systemctl is-active  --quiet "$UNIT" 2>/dev/null; }
is_enabled() { systemctl is-enabled --quiet "$UNIT" 2>/dev/null; }

# Game Mode: пересборка/перезапуск zapret рвёт сеть на время — в игре это
# мешает, поэтому update/tune во время игры откладываем.
gm_active() { [[ "$(cat "$HOME/.cache/lunar/gamemode" 2>/dev/null || echo 0)" == 1 ]]; }

gitc() { git -C "$ZDIR" -c safe.directory="$ZDIR" "$@" 2>/dev/null ; }

healthcheck() {
  local ok=0 code
  for u in https://discord.com/api/v9/gateway https://www.youtube.com; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$u" || true)"
    printf '  %-42s %s\n' "$u" "${code:-FAIL}"
    [ "$code" = "200" ] && ok=$((ok + 1))
  done
  [ "$ok" -ge 2 ] && echo "OK: Discord и YouTube доступны" \
                  || echo "!! не все цели открылись (сменилась стратегия DPI? запусти tune)"
}

case "${1:-status}" in
  status)
    state=off;    is_active  && state=active
    enabled=no;   is_enabled && enabled=yes
    commit="$(gitc log -1 --format=%h || echo '?')"
    updated="$(gitc log -1 --format=%cs || echo '')"
    desync="$(grep -m1 -E -- '--filter-tcp=443 .*--dpi-desync=' "$ZDIR/config" 2>/dev/null \
              | grep -o -- '--dpi-desync=[^ ]*' | head -1 | cut -d= -f2)"
    printf 'state=%s\nenabled=%s\ncommit=%s\nupdated=%s\ndesync=%s\n' \
      "$state" "$enabled" "$commit" "$updated" "${desync:-?}"
    ;;

  on)
    if priv /usr/local/lib/lunar/svc.sh enable --now "$UNIT"; then echo "zapret включён"; else echo "не удалось включить"; fi
    ;;
  off)
    if priv /usr/local/lib/lunar/svc.sh disable --now "$UNIT"; then echo "zapret выключен"; else echo "не удалось выключить"; fi
    ;;
  toggle)
    if is_active; then
      priv /usr/local/lib/lunar/svc.sh disable --now "$UNIT" && echo "zapret выключен"
    else
      priv /usr/local/lib/lunar/svc.sh enable --now "$UNIT" && echo "zapret включён"
    fi
    ;;
  restart)
    priv /usr/local/lib/lunar/svc.sh restart "$UNIT" && echo "zapret перезапущен"
    ;;

  update)
    gm_active && { echo "Game Mode включён — обновление zapret отложено"; exit 0; }
    echo "── обновляю zapret ──"
    sudo git -C "$ZDIR" pull --ff-only || { echo "git pull не удался"; exit 1; }
    sudo make -C "$ZDIR" systemd -j"$(nproc)" || { echo "сборка не удалась"; exit 1; }
    priv /usr/local/lib/lunar/svc.sh restart "$UNIT"
    echo
    healthcheck
    ;;

  tune)
    gm_active && { echo "Game Mode включён — подбор стратегии отложен"; exit 0; }
    echo "── подбор стратегии (blockcheck) ──"
    echo "zapret на время теста будет остановлен самим blockcheck'ом"
    sudo "$ZDIR/blockcheck.sh"
    echo
    echo "Готово. Стратегию из SUMMARY впиши в NFQWS_OPT в $ZDIR/config"
    echo "(или перезапусти: $0 restart)"
    ;;

  *)
    echo "usage: $0 {status|on|off|toggle|restart|update|tune}" >&2
    exit 2
    ;;
esac
