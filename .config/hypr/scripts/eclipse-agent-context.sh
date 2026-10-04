#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-agent-context.sh [1|0] — справка для оверлея-агента.
#    Печатает память агента (agent-memory.md) и, если аргумент = 1,
#    контекст системы: активное окно, стол, раскладка, сеть, звук,
#    Game Mode, запись, уведомления, GPU, медиа, сервисы райса.
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

echo "Активный стол: $(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // "?"' 2>/dev/null)"

# статус райса одной строкой (поля разделены 0x1f)
st=$(~/.config/hypr/scripts/eclipse-status.sh 2>/dev/null)
field() { printf '%s' "$st" | tr '\037' '\n' | sed -n "s/^$1=//p"; }

echo "Раскладка: $(field kb)   Сеть: $(field net)"

vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
if [ -n "$vol" ]; then
    v=$(printf '%s' "$vol" | awk '{printf "%d", $2*100}')
    case "$vol" in *MUTED*) v="$v% (выкл)";; *) v="$v%";; esac
    echo "Звук: $v"
fi

gm=$(field gm); [ "${gm:-0}" = "1" ] && gm=вкл || gm=выкл
rec=$(field rec); [ "${rec:-0}" = "1" ] && rec=идёт || rec=нет
echo "Game Mode: $gm   Запись экрана: $rec"

dnd=$(field dnd); [ "${dnd:-0}" = "1" ] && dnd=вкл || dnd=выкл
notif=$(field notif)
echo "Уведомления: ${notif:-0} (DND: $dnd)   GPU: $(field gpu)% $(field gput)°C"

if command -v playerctl >/dev/null 2>&1; then
    pst=$(playerctl status 2>/dev/null)
    if [ -n "$pst" ]; then
        meta=$(playerctl metadata --format '{{artist}} — {{title}}' 2>/dev/null)
        case "$pst" in
            Playing) pst="играет" ;;
            Paused)  pst="пауза" ;;
            Stopped) pst="стоп" ;;
        esac
        echo "Медиа: ${pst}${meta:+ — $meta}"
    fi
fi

svc=""
for s in lunar-quickshell lunar-homepage lunar-tgproxy; do
    a=$(systemctl --user is-active "$s" 2>/dev/null)
    svc="${svc}${s#lunar-}=${a} "
done
echo "Сервисы райса: ${svc% }"

# обновления: список из репозиториев (checkupdates). Кэш 10 минут, чтобы не
# дёргать сеть на каждый вопрос агенту.
UPD="${XDG_CACHE_HOME:-$HOME/.cache}/lunar/updates.txt"
mkdir -p "$(dirname "$UPD")"
if [ ! -f "$UPD" ] || [ $(( $(date +%s) - $(stat -c %Y "$UPD" 2>/dev/null || echo 0) )) -ge 600 ]; then
    if command -v checkupdates >/dev/null 2>&1; then
        checkupdates > "$UPD.tmp" 2>/dev/null && mv "$UPD.tmp" "$UPD"
    fi
fi
if [ -s "$UPD" ]; then
    echo "Обновления (репозитории, $(wc -l < "$UPD" | tr -d ' ') пакетов):"
    sed 's/^/  - /' "$UPD"
else
    echo "Обновления: нет данных (checkupdates недоступен или сеть)"
fi

echo "Время: $(date '+%d.%m.%Y %H:%M')"
