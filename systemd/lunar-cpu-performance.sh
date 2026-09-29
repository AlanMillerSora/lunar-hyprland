#!/bin/sh
# ════════════════════════════════════════════════════════════════
#  lunar-cpu-performance.sh — Lunar Eclipse
#
#  Держим CPU всегда на performance: governor + EPP (amd-pstate).
#  power-profiles-daemon и powersave не используем вовсе: его
#  «balanced» на Ryzen = governor powersave, а он давал просадки.
#  Запускается системным юнитом при загрузке и после сна.
# ════════════════════════════════════════════════════════════════
set -u

# $1 — имя файла в cpufreq, $2 — значение
set_all() {
  for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/"$1"; do
    [ -w "$f" ] && printf '%s\n' "$2" >"$f" 2>/dev/null || true
  done
}

set_all scaling_governor performance
set_all energy_performance_preference performance

exit 0
