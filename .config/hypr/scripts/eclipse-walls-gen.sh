#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Lunar Eclipse — генерация обоев из превью-сайта sait/
#
#  Сайт ~/.config/lunar/sait/index.html описывает фазы затмения
#  на CSS. Chrome/Chromium рендерит сцену в ЛЮБОМ разрешении,
#  поэтому этот скрипт делает кадры eclipse_01..09.png под
#  произвольный экран (ноут 1920x1080, ПК 3440x1440 и т.д.).
#
#  Использование:
#    eclipse-walls-gen.sh                # в разрешении текущего монитора
#    eclipse-walls-gen.sh 3440x1440      # явное разрешение
#    eclipse-walls-gen.sh 3840x2160 1 5  # только кадры 1 и 5
#
#  Результат: ~/.local/share/lunar/walls/<WxH>/eclipse_NN.png
#  Это статика для фолбэка / «лёгкого режима»: живые обои рисует
#  Quickshell (LunarWallpaper.qml). Скопировать кадры в Pictures:
#    eclipse-walls.sh set <каталог>
#
#  Зависимости: chromium (или google-chrome / brave / microsoft-edge)
# ════════════════════════════════════════════════════════════
set -euo pipefail

# ── где лежит сайт ──────────────────────────────────────────
SAIT=""
for d in \
  "$HOME/.config/lunar/sait" \
  "$HOME/rice/sait" \
  "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." 2>/dev/null && pwd)/sait"
do
  [[ -f "$d/index.html" ]] && { SAIT="$d"; break; }
done
if [[ -z "$SAIT" ]]; then
  echo "ОШИБКА: не найден сайт sait/index.html (ожидался в ~/.config/lunar/sait)" >&2
  exit 1
fi

# ── браузер для headless-рендера ────────────────────────────
BROWSER=""
for b in chromium chromium-browser google-chrome-stable google-chrome brave brave-browser microsoft-edge; do
  command -v "$b" >/dev/null 2>&1 && { BROWSER="$b"; break; }
done
if [[ -z "$BROWSER" ]]; then
  echo "ОШИБКА: нет chromium/chrome для рендера обоев" >&2
  exit 1
fi

# ── разрешение ──────────────────────────────────────────────
SIZE="${1:-}"
if [[ -z "$SIZE" ]]; then
  # берём разрешение первого монитора из Hyprland (WxH)
  SIZE="$(hyprctl monitors -j 2>/dev/null | python3 -c 'import sys,json
try:
    m = json.load(sys.stdin)[0]
    print("%dx%d" % (int(m["width"]), int(m["height"])))
except Exception:
    pass' || true)"
fi
[[ -z "$SIZE" ]] && SIZE="1920x1080"

W="${SIZE%x*}"
H="${SIZE#*x}"
[[ "$W" =~ ^[0-9]+$ && "$H" =~ ^[0-9]+$ ]] || { echo "ОШИБКА: разрешение должно быть WxH (например 3440x1440)" >&2; exit 1; }

# ── какие фазы генерировать ─────────────────────────────────
PHASES=("$@")
PHASES=("${PHASES[@]:1}")   # первый аргумент — размер, дальше — номера
if [[ ${#PHASES[@]} -eq 0 ]]; then
  PHASES=(1 2 3 4 5 6 7 8 9)
fi

OUT="$HOME/.local/share/lunar/walls/${W}x${H}"
mkdir -p "$OUT"

echo "Сайт:      $SAIT"
echo "Браузер:   $BROWSER"
echo "Размер:    ${W}x${H}"
echo "Каталог:   $OUT"
echo

for n in "${PHASES[@]}"; do
  [[ "$n" =~ ^[0-9]+$ ]] || continue
  f="$(printf 'eclipse_%02d.png' "$n")"
  echo -n "  фаза $n → $f … "
  "$BROWSER" --headless --disable-gpu --no-sandbox --hide-scrollbars \
    --force-device-scale-factor=1 \
    --window-size="${W},${H}" \
    --virtual-time-budget=4000 \
    --screenshot="$OUT/$f" \
    "file://$SAIT/index.html?phase=$n&clean=1" >/dev/null 2>&1 || true
  if [[ -s "$OUT/$f" ]]; then
    echo "ок"
  else
    echo "ОШИБКА"
  fi
done

echo
echo "Готово: $OUT"
echo "Поставить обои всех столов:  eclipse-walls.sh set \"$OUT\""
