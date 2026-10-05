#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  sync.sh — repo ↔ live: копирование и дрейф-гейт.
#
#  Держит правило «repo == live» проверяемым, а не на честном слове.
#  Сравнивает ТОЛЬКО отслеживаемые git-файлы конфигов, поэтому
#  производные (palette.json, lunar-colors.css, …) дрейфом не считаются.
#
#  Запуск:
#    ./sync.sh          — скопировать repo → live (как install, но точечно)
#    ./sync.sh check    — только показать расхождения; exit 1, если есть
#
#  Замечание: аватар (~/.config/avatars/avatar.png) — пользовательские данные,
#  install его сохраняет; здесь он тоже НЕ трогается, если в репо дефолт.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-apply}"
case "$MODE" in apply|check) ;; *) echo "usage: $0 [apply|check]" >&2; exit 1 ;; esac

SKIP_AVATAR=0
[ "${LUNAR_SYNC_AVATAR:-0}" = 1 ] || SKIP_AVATAR=1

mapfile -t files < <(git -C "$REPO" ls-files '.config/*' 'color-schemes/*')

drift=0
synced=0
checked=0
for f in "${files[@]}"; do
  src="$REPO/$f"
  case "$f" in
    .config/.zshrc)              dst="$HOME/.zshrc" ;;
    .config/*)                   dst="$HOME/.config/${f#.config/}" ;;
    color-schemes/*)             dst="$HOME/.local/share/color-schemes/${f#color-schemes/}" ;;
    *) continue ;;
  esac
  # производные палитры — их пишет eclipse-palette.py, а не человек; не дрейф
  case "$f" in
    .config/kitty/lunar-theme.conf|.config/gtk-3.0/lunar-colors.css|.config/gtk-4.0/lunar-colors.css|\
    .config/mako/colors.conf|.config/btop/themes/lunar.theme|.config/qt6ct/colors/lunar.conf|\
    .config/yazi/theme.toml|.config/fastfetch/config.jsonc|.config/yazi/flavors/*)
      continue ;;
  esac
  # пользовательский аватар не перетираем
  if [ "$SKIP_AVATAR" = 1 ] && [ "$f" = ".config/avatars/avatar.png" ] && [ -f "$dst" ]; then
    continue
  fi
  checked=$((checked + 1))
  if [ ! -e "$dst" ]; then
    echo "нет в live: ${dst#"$HOME"/}"
    drift=1
    continue
  fi
  cmp -s "$src" "$dst" && continue
  if [ "$MODE" = check ]; then
    echo "дрейф: ${dst#"$HOME"/}"
    drift=1
  else
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
    case "$f" in .config/hypr/scripts/*|.config/.zshrc) chmod +x "$dst" 2>/dev/null || true ;; esac
    echo "sync: ${dst#"$HOME"/}"
    synced=$((synced + 1))
  fi
done

if [ "$MODE" = check ]; then
  if [ "$drift" = 0 ]; then
    echo "live == repo ($checked файлов)"
  else
    echo "→ дрейф. Разложить: ./sync.sh"
    exit 1
  fi
else
  echo "скопировано: $synced (проверено: $checked)"
fi
