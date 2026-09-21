#!/usr/bin/env bash
# ═══ now-playing для hyprlock · Lunar ═══
# «▶ Title — Artist» пока что-то играет, иначе — пусто (время в подписи).

MAX_CHARS=34

text=""

while IFS=: read -r l p; do
    if [ "$l" = "NowPlaying" ] || [ "$l" = "Playing" ]; then
        PLAYER="$p"
        break
    fi
done < <(playerctl -l 2>/dev/null | sed 's/^/:/')

# Либо просто первый играющий
if [ -z "$PLAYER" ]; then
    for p in $(playerctl -l 2>/dev/null); do
        if [ "$(playerctl --player="$p" status 2>/dev/null)" = "Playing" ]; then
            PLAYER="$p"
            break
        fi
    done
fi

if [ -n "$PLAYER" ]; then
    out="$(playerctl --player="$PLAYER" metadata --format '{{ title }} — {{ artist }}' 2>/dev/null)"
    if [ "${#out}" -gt "$MAX_CHARS" ]; then
        out="${out:0:$((MAX_CHARS - 1))}…"
    fi
    text="󰎈  $out"
fi

echo "$text"
