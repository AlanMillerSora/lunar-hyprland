#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Lunar Eclipse — статические обои фаз (фолбэк / «лёгкий режим»).
#
#  Живые обои рисует Quickshell (LunarWallpaper.qml, фоновый слой) —
#  отдельный процесс/демон больше не нужен. Этот скрипт только
#  обновляет PNG-набор фаз в ~/Pictures/EclipseWalls (например,
#  сгенерированный под своё разрешение: eclipse-walls-gen.sh).
#
#  Использование:
#    eclipse-walls.sh set ~/.local/share/lunar/walls/3440x1440
# ════════════════════════════════════════════════════════════
set -uo pipefail

if [[ "${1:-}" != "set" ]]; then
  echo "Использование: eclipse-walls.sh set <каталог с eclipse_NN.png>" >&2
  exit 1
fi

SRC="${2:-}"
[[ -d "$SRC" ]] || { echo "нет каталога: ${SRC:-<пусто>}" >&2; exit 1; }

mkdir -p "$HOME/Pictures/EclipseWalls"
cp "$SRC"/eclipse_*.png "$HOME/Pictures/EclipseWalls/" 2>/dev/null || true
cp "$SRC"/eclipse_*.jpg "$HOME/Pictures/EclipseWalls/" 2>/dev/null || true
echo "Кадры обоев обновлены из $SRC → ~/Pictures/EclipseWalls"
