#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Eclipse — профиль производительности Hyprland.
#
#    normal   — полный блюр и тени (как было);
#    optimize — облегчённый блюр/тени для слабого iGPU.
#
#  Обои (60 fps / 25 fps) переключает сам Quickshell по
#  Theme.optimizeMode (Hub → Interface). Этот скрипт меняет
#  только настройки композитора на лету.
#
#  Использование:  eclipse-perf.sh normal|optimize
# ════════════════════════════════════════════════════════════
set -uo pipefail

case "${1:-normal}" in
  optimize)
    hyprctl eval 'hl.config({ decoration = { blur = { passes = 2, size = 5, vibrancy = 0.0, popups = false }, dim_inactive = false, shadow = { range = 14 } } })' >/dev/null 2>&1
    ;;
  normal)
    hyprctl eval 'hl.config({ decoration = { blur = { passes = 3, size = 6, vibrancy = 0.25, popups = true }, dim_inactive = true, shadow = { range = 18 } } })' >/dev/null 2>&1
    ;;
  *)
    echo "usage: $0 normal|optimize" >&2
    exit 1
    ;;
esac
