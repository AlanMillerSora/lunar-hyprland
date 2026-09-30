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
rgbare = re.compile(r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([0-9.]+)\s*)?\)')

def light(r, g, b):
    # яркость в светлый диапазон 0.35..1.0: тёмные исходники иначе
    # становятся тёмно-серыми и на чёрном фоне почти не видны
    y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
    return round((0.35 + 0.65 * y) * 255)

def mono_hex(m):
    h = m.group(1)
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    v = light(r, g, b)
    return '#%02x%02x%02x' % (v, v, v)

def mono_rgb(m):
    v = light(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    a = m.group(4)
    if a is None:
        return 'rgb(%d,%d,%d)' % (v, v, v)
    return 'rgba(%d,%d,%d,%s)' % (v, v, v, a)

for dp, _, fs in os.walk(root):
    for fn in fs:
        if not fn.endswith('.svg'):
            continue
        p = os.path.join(dp, fn)
        try:
            s = open(p, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        s2 = hexre.sub(mono_hex, s)
        s2 = rgbare.sub(mono_rgb, s2)
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
