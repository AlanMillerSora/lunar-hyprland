#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  lunar-svc.sh — root-хелпер: управление только разрешёнными
#  системными юнитами.
#
#  Ставится install.sh в /usr/local/lib/lunar/svc.sh (0755 root:root).
#  В sudoers разрешён ТОЛЬКО этот хелпер — голый systemctl наружу не
#  выставлен. Allowlist юнитов живёт здесь, аргументы проверяются до
#  вызова systemd, произвольные юниты/флаги не проходят.
#
#  Использование:
#    svc.sh {start|stop|restart|reload|enable|disable} [--now] <unit>
#
#  Юниты: zapret.service sddm.service bluetooth.service
# ════════════════════════════════════════════════════════════════
set -euo pipefail

UNITS="zapret.service sddm.service bluetooth.service"
MUTATE="start stop restart reload enable disable"

usage() {
  printf 'usage: %s {start|stop|restart|reload|enable|disable} [--now] <unit>\n' "${0##*/}" >&2
  printf 'units: %s\n' "$UNITS" >&2
  exit 2
}

[ "$#" -ge 1 ] || usage
verb="$1"; shift

now=0
if [ "${1:-}" = "--now" ]; then now=1; shift; fi

# ровно один позиционный аргумент — юнит; лишнее не принимаем
[ "$#" -eq 1 ] || usage
unit="$1"

case " $MUTATE " in *" $verb "*) ;; *) usage ;; esac
case " $UNITS " in *" $unit "*) ;; *) usage ;; esac

# --now осмыслен только для enable/disable
if [ "$now" = 1 ]; then
  case "$verb" in
    enable|disable) ;;
    *) usage ;;
  esac
  exec /usr/bin/systemctl "$verb" --now "$unit"
fi

exec /usr/bin/systemctl "$verb" "$unit"
