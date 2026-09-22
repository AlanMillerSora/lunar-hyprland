#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-brightness.sh — яркость экрана для Hub → Monitors.
#
#    get        → текущая яркость в процентах (0..100)
#    set <N>    → выставить N процентов
#
#  Встроенная панель (ноут): brightnessctl.
#  Внешний монитор (десктоп): ddcutil (DDC/CI).
#  Для ddcutil нужен модуль i2c-dev и доступ к /dev/i2c-* (группа i2c).
# ════════════════════════════════════════════════════════════════
set -euo pipefail

# ── встроенная панель ──────────────────────────────────────────
have_internal() {
  command -v brightnessctl >/dev/null 2>&1 || return 1
  brightnessctl -m 2>/dev/null | awk -F, '$2=="backlight"{found=1} END{exit !found}'
}

get_internal() {
  brightnessctl -m 2>/dev/null \
    | awk -F, '$2=="backlight"{gsub(/%/,"",$4); print $4; exit}'
}

set_internal() {
  brightnessctl set "${1}%" >/dev/null 2>&1
}

# ── внешний монитор (DDC/CI) ───────────────────────────────────
get_external() {
  command -v ddcutil >/dev/null 2>&1 || return 1
  local out cur max
  out="$(ddcutil getvcp 10 --brief 2>/dev/null | head -1)"
  cur="$(awk '{print $4}' <<<"$out")"
  max="$(awk '{print $5}' <<<"$out")"
  if [ -n "${cur:-}" ] && [ -n "${max:-}" ] && [ "$max" -gt 0 ]; then
    echo $(( 100 * cur / max ))
  else
    return 1
  fi
}

set_external() {
  command -v ddcutil >/dev/null 2>&1 || return 1
  local n
  while read -r n; do
    [ -n "$n" ] || continue
    ddcutil --display "$n" setvcp 10 "$1" >/dev/null 2>&1 || true
  done < <(ddcutil detect --brief 2>/dev/null | awk '/^Display [0-9]+/{print $2}')
}

# ── разбор аргументов ──────────────────────────────────────────
case "${1:-get}" in
  get)
    if have_internal; then
      get_internal
    else
      get_external
    fi
    ;;
  set)
    pct="${2:-50}"
    if have_internal; then
      set_internal "$pct"
    else
      set_external "$pct"
    fi
    ;;
  *)
    echo "usage: $0 get | set <0..100>" >&2
    exit 2
    ;;
esac
