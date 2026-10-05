#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — снимок версий зависимостей.
#
#  Пишет deps/snapshot-<дата>.txt: pacman -Q (имя+версия) по пакетам из
#  deps/packages.txt и deps/aur.txt. Это НЕ пин: Arch rolling, точные
#  версии официальных пакетов и AUR всё равно не зафиксировать. Снимок
#  нужен для справки и диагностики — «что стояло, когда работало».
#
#  Запуск: ./deps/snapshot.sh
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$REPO/deps"
OUT="$DEPS/snapshot-$(date +%Y-%m-%d).txt"

if ! command -v pacman >/dev/null 2>&1; then
  echo "ОШИБКА: pacman не найден — снимок только для Arch" >&2
  exit 1
fi

# Имена пакетов из обоих манифестов: без комментариев, заголовков секций
# и пустых строк, по одному в строке, без дублей.
names=()
while IFS= read -r _p; do
  [ -n "$_p" ] || continue
  names+=("$_p")
done < <(
  awk '!/^[[:space:]]*(#|\[|$)/ { print $1 }' \
    "$DEPS/packages.txt" "$DEPS/aur.txt" | sort -u
)

{
  echo "# Lunar Eclipse — снимок зависимостей"
  echo "# дата:   $(date '+%F %T')"
  echo "# хост:   $(uname -n)  ·  ядро: $(uname -r)"
  echo "# источник: deps/packages.txt + deps/aur.txt"
  echo "# pacman -Q: имя+версия. НЕ пин — только справка/диагностика."
  echo
  # -Q по списку: отсутствующие пакеты уходят в stderr и не мешают
  # остальным; ненулевой код из-за них гасим.
  pacman -Q "${names[@]}" 2>/dev/null || true
} > "$OUT"

count="$(grep -cE '^[^#[:space:]]' "$OUT" || true)"
echo "снимок: ${OUT#"$REPO"/}  ($count пакетов)"
