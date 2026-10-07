#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  lunar-statsd.sh — лончер C-сборщика телеметрии.
#
#  Собирает lunar-statsd.c в кэш при первом запуске (или если исходник
#  новее бинаря) и exec'ает его. Бинарь живёт в кэше, а не в репозитории:
#  dotfiles остаются текстовыми, сборка — на машине.
#
#  Зовётся баром (Quickshell), поэтому при ошибке сборки просто выходит
#  с ненулевым кодом — QML перезапустит и покажет ошибку в журнале.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lunar-statsd.c"
bin="${XDG_CACHE_HOME:-$HOME/.cache}/lunar/lunar-statsd"

if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
    mkdir -p "$(dirname -- "$bin")"
    tmp="$bin.$$"
    if gcc -O2 -std=gnu11 -Wall -Wextra -o "$tmp" "$src"; then
        mv -f "$tmp" "$bin"
    else
        rm -f "$tmp"
        echo "lunar-statsd: сборка не удалась (нет gcc?)" >&2
        exit 1
    fi
fi

exec "$bin" "$@"
