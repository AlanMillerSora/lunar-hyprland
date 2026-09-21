#!/usr/bin/env bash
# ═══ подсказка текущей раскладки (для hyprlock) ═══
# Напечатает EN/RU — клик по ней выше переключает (`hyprctl switchxkblayout`).

layout="$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[0].active_keymap' 2>/dev/null)"

case "$layout" in
    *English*) echo "EN" ;;
    *Russian*|*Russian\ \(Раскладка\)) echo "RU" ;;
    *) echo "${layout%% *}" ;;
esac
