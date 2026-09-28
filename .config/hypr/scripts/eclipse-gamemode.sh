#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-gamemode.sh — игровой режим одним действием.
#
#  Вкл:  без анимаций и blur, DND, пауза hypridle (не лочится),
#        профиль performance, разрешён tearing (меньше задержка).
#  Выкл: всё возвращается к значениям, что были до включения.
#
#  Запуск:  eclipse-gamemode.sh on|off|toggle
# ════════════════════════════════════════════════════════════════
set -uo pipefail

STATE="$HOME/.cache/lunar/gamemode"
PAUSE_CONF="$HOME/.config/lunar/gamemode-pause.conf"
PAUSED_STATE="$HOME/.cache/lunar/gamemode-paused"
PREV_STATE="$HOME/.cache/lunar/gamemode-prev"
mkdir -p "$(dirname "$STATE")"

say() { printf '\033[97m==>\033[0m %s\n' "$*"; }

# ── снимок/восстановление булевых опций Hyprland ───────────────
# gm_off должен вернуть то, что реально было (а не угаданный дефолт).
# В Hyprland 0.56 у булевых опций в JSON поле .bool, а не .int — со старым
# парсером снимок не снимался вовсе и возвращались догадки.
opt_bool() { hyprctl -j getoption "$1" 2>/dev/null | jq -r '.bool' 2>/dev/null; }

snapshot_hypr() {
  command -v jq >/dev/null 2>&1 || return 0
  local a b t
  a="$(opt_bool animations:enabled)"
  b="$(opt_bool decoration:blur:enabled)"
  t="$(opt_bool general:allow_tearing)"
  [[ "$a" == true || "$a" == false ]] || return 0
  [[ "$b" == true || "$b" == false ]] || return 0
  [[ "$t" == true || "$t" == false ]] || return 0
  printf 'animations=%s\nblur=%s\ntearing=%s\n' "$a" "$b" "$t" >"$PREV_STATE"
}

restore_hypr() {
  local a b t
  a="$(sed -n 's/^animations=//p' "$PREV_STATE" 2>/dev/null | head -1)"
  b="$(sed -n 's/^blur=//p' "$PREV_STATE" 2>/dev/null | head -1)"
  t="$(sed -n 's/^tearing=//p' "$PREV_STATE" 2>/dev/null | head -1)"
  [[ "$a" == true || "$a" == false ]] || a=true
  [[ "$b" == true || "$b" == false ]] || b=true
  [[ "$t" == true || "$t" == false ]] || t=false
  hyprctl eval "hl.config({animations = {enabled = $a}})" >/dev/null 2>&1
  hyprctl eval "hl.config({decoration = {blur = {enabled = $b}}})" >/dev/null 2>&1
  hyprctl eval "hl.config({general = {allow_tearing = $t}})" >/dev/null 2>&1
}

# ── выгрузка фоновых сервисов по списку ────────────────────────
# Формат строки: [user:|system:]unit.service (по умолчанию user).
# Останавливаем только активные и запоминаем, какие именно, — чтобы
# при выключении поднять обратно ровно их (а не всё подряд).
# PAUSED_STATE не обнуляем: новые записи мержим со старыми (sort -u),
# иначе повторный gm_on «забудет» уже приостановленные сервисы.
svc_pause() {
  [[ -f "$PAUSE_CONF" ]] || return 0
  local tmp out raw unit scope
  tmp="$(mktemp "${PAUSED_STATE}.XXXXXX")" || return 0
  out="$(mktemp "${PAUSED_STATE}.XXXXXX")" || { rm -f "$tmp"; return 0; }
  [[ -s "$PAUSED_STATE" ]] && cat "$PAUSED_STATE" >"$tmp"
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
        && echo "$unit" >>"$tmp"
    else
      if systemctl is-active --quiet "$unit"; then
        if sudo -n systemctl stop "$unit" 2>/dev/null; then
          echo "system:$unit" >>"$tmp"
        else
          say "Game Mode: нет прав на $unit (sudo -n) — пропускаю"
        fi
      fi
    fi
  done <"$PAUSE_CONF"
  # склейка: старые + новые без дублей, затем атомарно на место
  if [[ -s "$tmp" ]]; then
    sort -u "$tmp" >"$out" && mv "$out" "$PAUSED_STATE"
  else
    : >"$PAUSED_STATE"
    rm -f "$out"
  fi
  rm -f "$tmp"
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
  [[ "$(cat "$STATE" 2>/dev/null || echo 0)" == 1 ]] && return 0
  # если что-то упадёт до конца — не оставляем hypridle в SIGSTOP
  trap '[[ "$(cat "$STATE" 2>/dev/null || echo 0)" == 1 ]] || pkill -CONT -x hypridle 2>/dev/null' EXIT
  snapshot_hypr
  hyprctl eval 'hl.config({animations = {enabled = false}})' >/dev/null 2>&1
  hyprctl eval 'hl.config({decoration = {blur = {enabled = false}}})' >/dev/null 2>&1
  hyprctl eval 'hl.config({general = {allow_tearing = true}})' >/dev/null 2>&1
  makoctl mode -a do-not-disturb >/dev/null 2>&1
  pkill -STOP -x hypridle 2>/dev/null
  powerprofilesctl set performance >/dev/null 2>&1
  svc_pause
  echo 1 >"$STATE"
  trap - EXIT
  say "Game Mode включён: анимации/blur выкл · DND · performance · tearing"
  notify-send -a "Game Mode" "Игровой режим включён" \
    "анимации/blur выкл · DND · performance · hypridle на паузе" 2>/dev/null
}

gm_off() {
  # если Game Mode не включали — ничего не трогаем. hyprctl reload зовёт
  # gm_off «на всякий случай», и без этого guard'а сбрасывались DND/профиль.
  if [[ "$(cat "$STATE" 2>/dev/null || echo 0)" != 1 && ! -f "$PREV_STATE" ]]; then
    return 0
  fi
  restore_hypr
  rm -f "$PREV_STATE"
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
