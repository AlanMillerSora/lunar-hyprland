#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  lunar-journal-read.sh — root-хелпер: БЕЗОПАСНЫЙ просмотр journal.
#
#  Ставится install.sh в /usr/local/lib/lunar/journal-read.sh (0755 root:root).
#  В sudoers — он один (аргументы любые), но хелпер сам пропускает только
#  читающие опции: мутирующие (--vacuum-*, --rotate, --flush, --sync,
#  --update-catalog, --relinquish-var, --setup-keys) и чужие корни (--root,
#  --image) отвергаются. Пейджер всегда выключен.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

out=()
while [ "$#" -gt 0 ]; do
  a="$1"
  case "$a" in
    --) shift; while [ "$#" -gt 0 ]; do out+=("$1"); shift; done; break ;;
  esac
  if [ "${a#-}" = "$a" ]; then
    out+=("$a"); shift; continue
  fi
  name="${a%%=*}"
  hasval=0; [ "$name" != "$a" ] && hasval=1
  case "$name" in
    -n|--lines|-u|--unit|-p|--priority|-o|--output|--since|--until|-t|--identifier|--grep|-c|--cursor|--after-cursor)
      if [ "$hasval" -eq 1 ]; then
        out+=("$a"); shift
      else
        [ "$#" -ge 2 ] || { echo "journal-read: $name требует значение" >&2; exit 2; }
        out+=("$name" "$2"); shift 2
      fi ;;
    -b|--boot|-e|-k|--dmesg|-x|--catalog|-r|--reverse|-q|--quiet|--no-pager|--no-hostname|--utc|--no-full|-a|--all|--show-cursor|--no-tail)
      out+=("$a"); shift ;;
    -[0-9]|-[0-9][0-9])
      out+=("$a"); shift ;;
    *)
      echo "journal-read: опция не разрешена: $a" >&2; exit 2 ;;
  esac
done

exec /usr/bin/journalctl --no-pager "${out[@]}"
