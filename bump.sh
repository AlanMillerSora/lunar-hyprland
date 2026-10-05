#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — поднять VERSION (semver) без git-операций.
#
#  Ошибка «забыл VERSION» лечится тем, что инкремент больше не руками:
#  одна команда, один шаг, старый → новый в выводе. Скрипт только пишет
#  файл VERSION — ни коммитов, ни тегов, ни пуша (это делает release.sh).
#
#  Запуск:
#    ./bump.sh patch    # фиксы:        1.2.3 → 1.2.4
#    ./bump.sh minor    # функциональность: 1.2.3 → 1.3.0
#    ./bump.sh major    # ломающее:     1.2.3 → 2.0.0
#    ./bump.sh          # без аргумента — идемпотентно: показать текущую, не менять
#
#  Тип без аргумента намеренно ничего не делает: повторный запуск безопасен.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
FILE="$REPO/VERSION"

if [[ ! -f "$FILE" ]]; then
  echo "ОШИБКА: не найден $FILE" >&2
  exit 1
fi

CUR="$(tr -d '[:space:]' < "$FILE")"
if [[ ! "$CUR" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "ОШИБКА: VERSION='$CUR' не semver (ожидаю X.Y.Z)" >&2
  exit 1
fi
MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

TYPE="${1:-}"
case "$TYPE" in
  patch) NEW="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
  minor) NEW="${MAJOR}.$((MINOR + 1)).0" ;;
  major) NEW="$((MAJOR + 1)).0.0" ;;
  "")
    # идемпотентный режим: ничего не меняем, просто сообщаем текущую
    echo "VERSION: $CUR (не менял — укажи patch|minor|major)"
    exit 0
    ;;
  *)
    echo "usage: $0 [patch|minor|major]" >&2
    echo "       $0            # показать текущую, не менять" >&2
    exit 1
    ;;
esac

printf '%s\n' "$NEW" > "$FILE"
echo "VERSION: $CUR → $NEW ($TYPE)"
