#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-media.sh <play-pause|next|previous> — медиа-клавиши.
#
#  Кем управлять, решаю сам, по приоритету:
#    1) наш mpv (Lunar TUI, playerctl --player=mpv*), если играет;
#    2) иначе — тот, кто реально играет (Firefox, Spotify и т.п.);
#    3) иначе — наш mpv, даже на паузе (чтобы вернуть его);
#    4) иначе — просто первый плеер в списке.
#  Так «наши» клавиши не уводят управление к молчащему mpv, когда
#  параллельно играет что-то другое.
#
#  Зовётся из hyprland.lua на XF86AudioPlay/Next/Prev.
# ════════════════════════════════════════════════════════════════
set -u

action="${1:-}"
case "$action" in
  play-pause|next|previous) ;;
  *) echo "usage: eclipse-media.sh play-pause|next|previous" >&2; exit 2 ;;
esac

command -v playerctl >/dev/null 2>&1 || exit 0

players="$(playerctl --list-all 2>/dev/null || true)"
# ничего не играет/не зарегистрировано — молча выходим (клавиша не должна шуметь)
[ -n "$players" ] || exit 0

# «наш» плеер: mpv Lunar TUI (имя в playerctl начинается с mpv)
own="$(printf '%s\n' "$players" | grep -m1 '^mpv' || true)"

# статус чужого плеера читаю построчно: первое «Playing» и есть текущий
is_playing() {
  [ "$(playerctl --player="$1" status 2>/dev/null || true)" = "Playing" ]
}

target=""
if [ -n "$own" ] && is_playing "$own"; then
  target="$own"
fi
if [ -z "$target" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if is_playing "$p"; then target="$p"; break; fi
  done <<< "$players"
fi
# никто не играет: возвращаю управление нашему mpv, иначе — первому в списке
[ -n "$target" ] || target="${own:-$(printf '%s\n' "$players" | head -1)}"
[ -n "$target" ] || exit 0

case "$action" in
  play-pause) playerctl --player="$target" play-pause ;;
  next)       playerctl --player="$target" next ;;
  previous)   playerctl --player="$target" previous ;;
esac
