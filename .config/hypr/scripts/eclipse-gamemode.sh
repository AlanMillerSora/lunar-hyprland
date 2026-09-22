#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-gamemode.sh — игровой режим одним действием.
#
#  Вкл:  без анимаций и blur, DND, пауза hypridle (не лочится),
#        профиль performance, разрешён tearing (меньше задержка).
#  Выкл: всё возвращается.
#
#  Запуск:  eclipse-gamemode.sh on|off|toggle
# ════════════════════════════════════════════════════════════════
set -uo pipefail

STATE="$HOME/.cache/lunar/gamemode"
mkdir -p "$(dirname "$STATE")"

say() { printf '\033[97m==>\033[0m %s\n' "$*"; }

gm_on() {
  hyprctl eval 'hl.config({animations = {enabled = false}})' >/dev/null 2>&1
  hyprctl eval 'hl.config({decoration = {blur = {enabled = false}}})' >/dev/null 2>&1
  hyprctl eval 'hl.config({general = {allow_tearing = true}})' >/dev/null 2>&1
  makoctl mode -a do-not-disturb >/dev/null 2>&1
  pkill -STOP -x hypridle 2>/dev/null
  powerprofilesctl set performance >/dev/null 2>&1
  echo 1 >"$STATE"
  say "Game Mode включён: анимации/blur выкл · DND · performance · tearing"
  notify-send -a "Game Mode" "Игровой режим включён" \
    "анимации/blur выкл · DND · performance · hypridle на паузе" 2>/dev/null
}

gm_off() {
  hyprctl eval 'hl.config({animations = {enabled = true}})' >/dev/null 2>&1
  hyprctl eval 'hl.config({decoration = {blur = {enabled = true}}})' >/dev/null 2>&1
  hyprctl eval 'hl.config({general = {allow_tearing = false}})' >/dev/null 2>&1
  makoctl mode -r do-not-disturb >/dev/null 2>&1
  pkill -CONT -x hypridle 2>/dev/null
  powerprofilesctl set balanced >/dev/null 2>&1
  echo 0 >"$STATE"
  say "Game Mode выключен: всё вернулось"
  notify-send -a "Game Mode" "Игровой режим выключен" "анимации/blur/DND вернулись" 2>/dev/null
}

case "${1:-toggle}" in
  on)  gm_on ;;
  off) gm_off ;;
  toggle)
    if [ "$(cat "$STATE" 2>/dev/null || echo 0)" = "1" ]; then gm_off; else gm_on; fi
    ;;
  *) echo "usage: $0 on|off|toggle" >&2; exit 1 ;;
esac
