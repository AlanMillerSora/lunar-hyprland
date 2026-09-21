#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-transparency.sh — применить сохранённую прозрачность
#  окон (ползунок лаунчера). Вызывается при старте сессии.
#
#  Файл ~/.config/lunar/transparency:  "<active> <inactive>" (0.30–1.0)
# ════════════════════════════════════════════════════════════════
F="$HOME/.config/lunar/transparency"
[ -f "$F" ] || exit 0
read -r ACTIVE INACTIVE < "$F"
case "$ACTIVE" in
  ''|*[!0-9.]*) exit 0 ;;
esac
hyprctl -q eval "hl.config({decoration={active_opacity=${ACTIVE},inactive_opacity=${INACTIVE}}})" 2>/dev/null