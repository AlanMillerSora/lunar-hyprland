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
PAUSE_CONF="$HOME/.config/lunar/gamemode-pause.conf"
PAUSED_STATE="$HOME/.cache/lunar/gamemode-paused"
mkdir -p "$(dirname "$STATE")"

say() { printf '\033[97m==>\033[0m %s\n' "$*"; }

# ── выгрузка фоновых сервисов по списку ────────────────────────
# Формат строки: [user:|system:]unit.service (по умолчанию user).
# Останавливаем только активные и запоминаем, какие именно, — чтобы
# при выключении поднять обратно ровно их (а не всё подряд).
svc_pause() {
  [[ -f "$PAUSE_CONF" ]] || return 0
  : >"$PAUSED_STATE"
  local raw unit scope
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    raw="${raw%%#*}"
    read -r unit _ <<<"$raw"
    [[ -z "$unit" ]] && continue
    scope=user
    case "$unit" in
      system:*) scope=system; unit="${unit#system:}" ;;
      user:*)   scope=user;   unit="${unit#user:}" ;;
    esac
    if [[ "$scope" == user ]]; then
      systemctl --user is-active --quiet "$unit" \
        && systemctl --user stop "$unit" 2>/dev/null \
        && echo "$unit" >>"$PAUSED_STATE"
    else
      systemctl is-active --quiet "$unit" \
        && sudo -n systemctl stop "$unit" 2>/dev/null \
        && echo "system:$unit" >>"$PAUSED_STATE"
    fi
  done <"$PAUSE_CONF"
  if [[ -s "$PAUSED_STATE" ]]; then
    say "Game Mode: приостановлены сервисы ($(tr '\n' ' ' <"$PAUSED_STATE"))"
  fi
  return 0
}

svc_restore() {
  if [[ ! -s "$PAUSED_STATE" ]]; then
    rm -f "$PAUSED_STATE"
    return 0
  fi
  local unit
  while IFS= read -r unit || [[ -n "$unit" ]]; do
    case "$unit" in
      system:*) sudo -n systemctl start "${unit#system:}" 2>/dev/null ;;
      *)        systemctl --user start "$unit" 2>/dev/null ;;
    esac
  done <"$PAUSED_STATE"
  say "Game Mode: сервисы возвращены"
  rm -f "$PAUSED_STATE"
  return 0
}

gm_on() {
  hyprctl eval 'hl.config({animations = {enabled = false}})' >/dev/null 2>&1
  hyprctl eval 'hl.config({decoration = {blur = {enabled = false}}})' >/dev/null 2>&1
  hyprctl eval 'hl.config({general = {allow_tearing = true}})' >/dev/null 2>&1
  makoctl mode -a do-not-disturb >/dev/null 2>&1
  pkill -STOP -x hypridle 2>/dev/null
  powerprofilesctl set performance >/dev/null 2>&1
  svc_pause
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
  svc_restore
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
