#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — Vencord (мод Discord)
#
#  Vencord вшивается в клиент Discord патчем app.asar. При обновлении
#  Discord появляется новый каталог app-<версия> и патч «слетает» —
#  тогда достаточно снова применить patch.
#
#  Использование:
#    eclipse-vencord.sh status   # состояние (key=value, для Hub)
#    eclipse-vencord.sh patch    # закрыть Discord, пропатчить, запустить
#    eclipse-vencord.sh repair   # то же, но через -repair
#    eclipse-vencord.sh unpatch  # удалить Vencord
#    eclipse-vencord.sh update   # обновить инсталлятор (AUR) и пропатчить
# ════════════════════════════════════════════════════════════════
set -uo pipefail

DISCORD_DIR="$HOME/.config/discord"
VENCORD_DIR="$HOME/.config/Vencord"

discord_app_dir() { ls -d "$DISCORD_DIR"/app-* 2>/dev/null | sort -V | tail -1; }

is_patched() {
  local d; d="$(discord_app_dir)"
  [ -n "$d" ] && [ -f "$d/resources/_app.asar" ] && [ -f "$VENCORD_DIR/dist/patcher.js" ]
}

installer_version() {
  vencordinstaller -version 2>/dev/null | head -1 | sed 's/^Vencord Installer Cli //'
}

close_discord() {
  echo "== закрываю Discord =="
  pkill -x Discord 2>/dev/null
  sleep 2
  if pgrep -x Discord >/dev/null; then
    kill -9 $(pgrep -x Discord) 2>/dev/null
    sleep 1
  fi
}

case "${1:-status}" in
  status)
    st=notinstalled
    if command -v vencordinstaller >/dev/null 2>&1; then
      if is_patched; then st=patched; else st=unpatched; fi
    fi
    app="$(basename "$(discord_app_dir)" 2>/dev/null)"
    printf 'state=%s\ninstaller=%s\nappdir=%s\n' \
      "$st" "$(installer_version)" "${app:-—}"
    ;;

  patch|repair)
    command -v vencordinstaller >/dev/null 2>&1 || {
      echo "нет vencordinstaller — поставь: yay -S vencord-installer-bin"; exit 1; }

    wasrunning=no; pgrep -x Discord >/dev/null && wasrunning=yes
    close_discord

    echo "== патчу Vencord =="
    if [ "${1}" = repair ]; then vencordinstaller -repair; else vencordinstaller -install; fi
    rc=$?

    if [ "$wasrunning" = yes ] && [ "$rc" -eq 0 ]; then
      echo "== запускаю Discord =="
      setsid discord >/dev/null 2>&1 < /dev/null &
    fi
    exit "$rc"
    ;;

  unpatch)
    command -v vencordinstaller >/dev/null 2>&1 || { echo "нет vencordinstaller"; exit 1; }
    close_discord
    echo "== удаляю Vencord =="
    vencordinstaller -uninstall
    ;;

  update)
    echo "== обновляю инсталлятор (AUR) =="
    if command -v yay >/dev/null 2>&1; then
      yay -S --needed vencord-installer-bin
    elif command -v paru >/dev/null 2>&1; then
      paru -S --needed vencord-installer-bin
    else
      echo "yay/paru не найден — инсталлятор не обновлён"
    fi
    echo
    exec "$0" patch
    ;;

  *)
    echo "usage: $0 {status|patch|repair|unpatch|update}" >&2
    exit 2
    ;;
esac
