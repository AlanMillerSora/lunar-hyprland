#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — монохромные иконки из Tela
#
#  Собирает ~/.local/share/icons/Tela-lunar: копирует Tela-dark и
#  обесцвечивает все SVG по яркости. Затем назначает тему через
#  gsettings — потому что GTK3 под Wayland читает gsettings, а НЕ
#  ~/.config/gtk-3.0/settings.ini.
#
#  Нужен пакет tela-icon-theme (AUR). Флаг: --force — пересобрать.
#  Использование: eclipse-mono-icons.sh [--force]
# ════════════════════════════════════════════════════════════════
set -uo pipefail

SRC=/usr/share/icons/Tela-dark
DST="$HOME/.local/share/icons/Tela-lunar"

if [ ! -d "$SRC" ]; then
  echo "нет $SRC — поставь пакет tela-icon-theme" >&2
  exit 1
fi

if [ ! -d "$DST" ] || [ "${1:-}" = "--force" ]; then
  echo "собираю монохромные иконки → $DST"
  rm -rf "$DST"
  cp -rL "$SRC" "$DST" 2>/dev/null || true
  python3 - "$DST" <<'PY'
import os, re, sys
root = sys.argv[1]
hexre = re.compile(r'#([0-9a-fA-F]{6})')

def mono(m):
    h = m.group(1)
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    y = round(0.2126 * r + 0.7152 * g + 0.0722 * b)
    return '#%02x%02x%02x' % (y, y, y)

for dp, _, fs in os.walk(root):
    for fn in fs:
        if not fn.endswith('.svg'):
            continue
        p = os.path.join(dp, fn)
        try:
            s = open(p, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        s2 = hexre.sub(mono, s)
        if s2 != s:
            try:
                open(p, 'w', encoding='utf-8').write(s2)
            except OSError:
                pass
PY
  gtk-update-icon-cache -f -t "$DST" >/dev/null 2>&1 || true
fi

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface icon-theme 'Tela-lunar' 2>/dev/null || true
fi

echo "монохромные иконки: Tela-lunar готовы"
