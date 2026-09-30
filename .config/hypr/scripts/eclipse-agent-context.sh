#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-agent-context.sh [1|0] — справка для оверлея-агента.
#    Печатает память агента (agent-memory.md) и, если аргумент = 1,
#    контекст системы: активное окно, стол, Game Mode, время.
#    Оверлей подмешивает это в начало запроса к OpenCode.
#    Секретов не читает: только локальное состояние райса.
# ════════════════════════════════════════════════════════════════
set -u

with_system="${1:-1}"
MEM="${XDG_STATE_HOME:-$HOME/.local/state}/lunar/agent-memory.md"

echo "## Память агента"
if [ -s "$MEM" ]; then
    cat "$MEM"
else
    echo "(пусто)"
fi

if [ "$with_system" != "1" ]; then
    exit 0
fi

echo
echo "## Контекст системы"
echo "Райс: Lunar Eclipse (Arch + Hyprland Lua + Quickshell)."

win=$(hyprctl activewindow -j 2>/dev/null)
if [ -n "$win" ] && [ "$win" != "{}" ] && [ "$win" != "null" ]; then
    cls=$(printf '%s' "$win" | jq -r '.class // .initialClass // "?"' 2>/dev/null)
    title=$(printf '%s' "$win" | jq -r '.title // ""' 2>/dev/null)
    if [ -n "$title" ]; then
        echo "Активное окно: ${cls} — «${title}»"
    else
        echo "Активное окно: ${cls}"
    fi
else
    echo "Активное окно: нет"
fi

ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // "?"' 2>/dev/null)
echo "Активный стол: ${ws:-?}"

gm=$(~/.config/hypr/scripts/eclipse-status.sh 2>/dev/null | tr ' ' '\n' | sed -n 's/^gm=//p')
echo "Game Mode: $([ "${gm:-0}" = "1" ] && echo вкл || echo выкл)"
echo "Время: $(date '+%d.%m.%Y %H:%M')"
