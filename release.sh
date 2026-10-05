#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — релиз: тег v<VERSION> + push
#
#  Тег пушится в origin; GitHub Actions (.github/workflows/release.yml)
#  сам создаёт Release с заметками из коммитов.
#
#  Использование:
#    ./release.sh            # тег v<VERSION> и push
#    ./release.sh --force    # перезаписать существующий тег
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

VERSION="$(cat VERSION | tr -d '[:space:]')"
TAG="v${VERSION}"

if [[ -z "$VERSION" ]]; then
  echo "ОШИБКА: VERSION пуст" >&2
  exit 1
fi

# VERSION должен быть больше последнего тега v* — иначе это тег «назад»:
# релиз получит меньший номер, и заметки/история поедут. Равный тег ловит
# проверка ниже (нужен --force для перезаписи), а меньший не пускаем никогда.
LAST_TAG="$(git tag --list 'v*' --sort=-v:refname | head -n1 || true)"
if [[ -n "$LAST_TAG" ]]; then
  LAST_VER="${LAST_TAG#v}"
  HIGHEST="$(printf '%s\n%s\n' "$LAST_VER" "$VERSION" | sort -V | tail -n1)"
  if [[ "$HIGHEST" == "$LAST_VER" && "$VERSION" != "$LAST_VER" ]]; then
    echo "ОШИБКА: VERSION=$VERSION не больше последнего тега $LAST_TAG — назад не тегаем" >&2
    echo "  подними версию: ./bump.sh patch|minor|major" >&2
    exit 1
  fi
fi

# рабочее дерево должно быть чистым, иначе релиз уедет без правок
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ОШИБКА: есть незакоммиченные изменения — сначала закоммить" >&2
  git status --short >&2
  exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  if [[ "$FORCE" != 1 ]]; then
    echo "Тег $TAG уже существует. Перезаписать: ./release.sh --force" >&2
    exit 1
  fi
  echo "==> удаляю существующий тег $TAG (--force)"
  git tag -d "$TAG" >/dev/null
  git push origin ":refs/tags/$TAG" 2>/dev/null || true
fi

echo "==> ветка:    $(git rev-parse --abbrev-ref HEAD)"
echo "==> коммит:   $(git rev-parse --short HEAD)"
echo "==> тег:      $TAG"

git tag -a "$TAG" -m "Lunar Eclipse ${VERSION}"
git push origin HEAD
git push origin "$TAG"

echo
echo "Готово: тег $TAG отправлен."
echo "Release соберётся сам: https://github.com/AlanMillerSora/lunar-hyprland/actions"
