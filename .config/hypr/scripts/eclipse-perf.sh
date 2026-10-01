#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Eclipse — облегчённый режим Hyprland (единственный).
#
#  Пресеты NORMAL/OPTIMIZE убраны: блюр всегда лёгкий
#  (size 5, passes 2, тени range 14), но цветность сохранена —
#  vibrancy 0.25 и dim_inactive включены, иначе фон выглядит
#  плоским. Обои (~25 fps, без пыли/метеоров) держит Quickshell.
#
#  Пользовательский ползунок блюра (Hub → Interface) главнее:
#  Quickshell после этого скрипта возвращает своё значение.
#
#  Использование:  eclipse-perf.sh
# ════════════════════════════════════════════════════════════
set -uo pipefail

hyprctl eval 'hl.config({ decoration = { blur = { passes = 2, size = 5, vibrancy = 0.20, noise = 0.05, popups = true }, dim_inactive = true, shadow = { range = 8 } } })' >/dev/null 2>&1
