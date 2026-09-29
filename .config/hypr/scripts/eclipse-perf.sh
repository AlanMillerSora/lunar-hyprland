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
#  Пользовательские blur size/passes не теряются: перед первым
#  пресетом снимаем текущие значения (hyprctl getoption) в
#  ~/.cache/lunar/perf-prev, а normal возвращает их обратно.
#
#  Использование:  eclipse-perf.sh normal|optimize
# ════════════════════════════════════════════════════════════
set -uo pipefail

PERF_STATE="$HOME/.cache/lunar/perf-prev"
mkdir -p "$(dirname "$PERF_STATE")"

# сырое значение опции Hyprland (через jq). У булевых опций в JSON поле
# .bool, а не .int — иначе снимок popups выходил пустым (та же ловушка,
# что была в Game Mode).
get_int()   { hyprctl -j getoption "$1" 2>/dev/null | jq -r '.int // empty' 2>/dev/null; }
get_float() { hyprctl -j getoption "$1" 2>/dev/null | jq -r '.float // empty' 2>/dev/null; }
get_bool()  { hyprctl -j getoption "$1" 2>/dev/null | jq -r '.bool' 2>/dev/null; }
read_state() { sed -n "s/^$1=//p" "$PERF_STATE" 2>/dev/null | head -1; }

# снимаем пользовательский блюр ДО того, как его перезапишет пресет
snapshot() {
  command -v jq >/dev/null 2>&1 || return 0
  [[ -s "$PERF_STATE" ]] && return 0   # уже снят — не перезатираем оригинал
  local size passes vib pop
  size="$(get_int decoration:blur:size)"
  passes="$(get_int decoration:blur:passes)"
  vib="$(get_float decoration:blur:vibrancy)"
  pop="$(get_bool decoration:blur:popups)"
  [[ "$size" =~ ^[0-9]+$ && "$passes" =~ ^[0-9]+$ && -n "$vib" ]] || return 0
  [[ "$pop" == true || "$pop" == false ]] || pop=true
  printf 'size=%s\npasses=%s\nvibrancy=%s\npopups=%s\n' \
    "$size" "$passes" "$vib" "$pop" >"$PERF_STATE"
}

apply_normal() {
  local sz ps vb pu
  if [[ -s "$PERF_STATE" ]]; then
    # возвращаем то, что было у пользователя, а не хардкод-дефолт
    sz="$(read_state size)"; ps="$(read_state passes)"
    vb="$(read_state vibrancy)"; pu="$(read_state popups)"
    [[ "$sz" =~ ^[0-9]+$ ]]                 || sz=6
    [[ "$ps" =~ ^[0-9]+$ ]]                 || ps=3
    [[ "$vb" =~ ^[0-9]+([.][0-9]+)?$ ]]     || vb=0.25
    [[ "$pu" == true || "$pu" == false ]]   || pu=true
    hyprctl eval "hl.config({ decoration = { blur = { passes = $ps, size = $sz, vibrancy = $vb, popups = $pu }, dim_inactive = true, shadow = { range = 18 } } })" >/dev/null 2>&1
    rm -f "$PERF_STATE"
  else
    hyprctl eval 'hl.config({ decoration = { blur = { passes = 3, size = 6, vibrancy = 0.25, popups = true }, dim_inactive = true, shadow = { range = 18 } } })' >/dev/null 2>&1
  fi
}

case "${1:-normal}" in
  optimize)
    snapshot
    hyprctl eval 'hl.config({ decoration = { blur = { passes = 2, size = 5, vibrancy = 0.0, popups = false }, dim_inactive = false, shadow = { range = 14 } } })' >/dev/null 2>&1
    ;;
  normal)
    apply_normal
    ;;
  *)
    echo "usage: $0 normal|optimize" >&2
    exit 1
    ;;
esac
