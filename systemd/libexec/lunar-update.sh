#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  lunar-update.sh — root-хелпер: обновление системы.
#
#  Ставится install.sh в /usr/libexec/lunar/update.sh (0755 root:root):
#  пакетом lunar-helpers, без пакета — копированием.
#  Запускает ровно `pacman -Syu` — без --noconfirm и без произвольных
#  аргументов: подтверждение остаётся за человеком в терминале, а из
#  sudoers убран широкий NOPASSWD на pacman.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

[ "$#" -eq 0 ] || { echo "usage: update.sh (без аргументов)" >&2; exit 2; }

exec /usr/bin/pacman -Syu
