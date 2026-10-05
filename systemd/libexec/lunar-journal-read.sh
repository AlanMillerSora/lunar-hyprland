#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  lunar-journal-read.sh — root-хелпер: БЕЗОПАСНЫЙ просмотр journal.
#
#  Ставится install.sh в /usr/libexec/lunar/journal-read.sh (0755 root:root):
#  пакетом lunar-helpers, без пакета — копированием.
#  В sudoers — он один (аргументы любые), но хелпер сам пропускает только
#  читающие опции: мутирующие (--vacuum-*, --rotate, --flush, --sync,
#  --update-catalog, --relinquish-var) и чужие корни (--root, --image,
#  --directory, --file, -M/--machine) отвергаются. Пейджер всегда выключен.
#
#  Аргументы после `--` передаются journalctl ПОСЛЕ разделителя (позиционные
#  фильтры), поэтому опциями не становятся.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

isnum() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; return 0; }
islines() { local v="${1#+}"; [ "$v" = all ] && return 0; isnum "$v"; }

out=()
while [ "$#" -gt 0 ]; do
  a="$1"
  case "$a" in
    --)
      out+=(--)
      shift
      while [ "$#" -gt 0 ]; do out+=("$1"); shift; done
      break ;;
  esac
  if [ "${a#-}" = "$a" ]; then
    out+=("$a"); shift; continue
  fi
  name="${a%%=*}"
  hasval=0; [ "$name" != "$a" ] && hasval=1
  case "$name" in
    -n[0-9]*|-n+[0-9]*)
      out+=("$a"); shift ;;
    -n|--lines)
      # у journalctl -n — ОПЦИОНАЛЬНЫЙ аргумент: не съедаем следующую опцию
      if [ "$hasval" -eq 1 ]; then
        v="${a#*=}"
        if islines "$v"; then out+=("--lines=$v"); else echo "journal-read: -n ждёт число" >&2; exit 2; fi
        shift
      elif [ "$#" -ge 2 ] && islines "$2"; then
        out+=("--lines=$2"); shift 2
      else
        out+=("-n"); shift
      fi ;;
    -u|--unit|-p|--priority|-o|--output|--since|--until|-t|--identifier|--grep|-c|--cursor|--after-cursor|-F|--field|-N|--fields)
      if [ "$hasval" -eq 1 ]; then
        out+=("$a"); shift
      else
        [ "$#" -ge 2 ] || { echo "journal-read: $name требует значение" >&2; exit 2; }
        out+=("$name" "$2"); shift 2
      fi ;;
    -b|--boot|-e|-k|--dmesg|-x|--catalog|-r|--reverse|-q|--quiet|--no-pager|--no-hostname|--utc|--no-full|-a|--all|--show-cursor|--no-tail|--list-boots|--disk-usage|--verify|--header)
      out+=("$a"); shift ;;
    -[0-9]|-[0-9][0-9])
      out+=("$a"); shift ;;
    *)
      echo "journal-read: опция не разрешена: $a" >&2; exit 2 ;;
  esac
done

exec /usr/bin/journalctl --no-pager "${out[@]}"
