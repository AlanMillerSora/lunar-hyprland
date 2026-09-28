#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  lunar-journal-vacuum.sh — root-хелпер: аккуратная чистка журнала.
#
#  Ставится install.sh в /usr/local/lib/lunar/journal-vacuum.sh (0755 root:root).
#  Принимает РОВНО один аргумент — размер или срок: --size=200M / --time=14d
#  (и полные формы --vacuum-size=… / --vacuum-time=…). Так из Hub (update.sh)
#  можно чистить журнал без raw journalctl и без пароля, не открывая
#  произвольные мутирующие режимы (--rotate/--flush/--sync и т.п.).
# ════════════════════════════════════════════════════════════════
set -euo pipefail

[ "$#" -eq 1 ] || { echo "usage: journal-vacuum --size=200M | --time=14d" >&2; exit 2; }

case "$1" in
  --vacuum-size=*[0-9]|--vacuum-size=*[0-9][KMG]|--size=*[0-9]|--size=*[0-9][KMG]) arg="$1" ;;
  --vacuum-time=*[0-9]|--vacuum-time=*[0-9][smhdw]|--time=*[0-9]|--time=*[0-9][smhdw]) arg="$1" ;;
  *) echo "journal-vacuum: недопустимый параметр: $1" >&2; exit 2 ;;
esac

# короткую форму приводим к полной
case "$arg" in
  --size=*) arg="--vacuum-size=${arg#--size=}" ;;
  --time=*) arg="--vacuum-time=${arg#--time=}" ;;
esac

exec /usr/bin/journalctl "$arg"
