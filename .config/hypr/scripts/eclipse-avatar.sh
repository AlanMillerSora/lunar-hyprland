#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-avatar.sh — аватар пользователя Lunar Eclipse.
#
#    pick                  — выбрать файл через zenity → ~/.config/avatars/source
#    apply <cs> <cx> <cy>  — обрезать source в квадрат cs на (cx,cy), скруглить
#                            в круг → ~/.config/avatars/avatar.png и синкнуться с SDDM
#    /путь/картинка.png    — поставить готовый файл (авто-кроп по центру)
#    без аргументов (root) — только синхронизация в тему SDDM (NOPASSWD)
# ════════════════════════════════════════════════════════════════
set -euo pipefail

SDDM_AV="/usr/share/sddm/themes/lunar/assets/avatar.png"
AV_DIR="$HOME/.config/avatars"
AV="$AV_DIR/avatar.png"
CACHE_DIR="$HOME/.cache/lunar"
SRC="$CACHE_DIR/avatar-source"

sync_root() {
    local u="${SUDO_USER:-sora}"
    local src="/home/$u/.config/avatars/avatar.png"
    [[ -f "$src" ]] || exit 0
    [[ -d "$(dirname "$SDDM_AV")" ]] || exit 0
    cp -f "$src" "$SDDM_AV"
    chmod 644 "$SDDM_AV"
}

# квадрат → 512 → круглая маска
round_mask() {  # round_mask <in> <out>
    magick "$1" -resize 512x512 \
        \( -size 512x512 xc:black -fill white -draw "circle 256,256 256,2" \) \
        -alpha off -compose CopyOpacity -composite "PNG32:$2"
}

# обрезанное из source → круглый аватар + синк
commit() {  # commit <infile>
    local tmp
    tmp="$(mktemp --suffix=.png)"
    round_mask "$1" "$tmp"
    mkdir -p "$AV_DIR"
    cp -f "$tmp" "$AV"
    chmod 644 "$AV"
    rm -f -- "$tmp"
    sudo -n "$0" 2>/dev/null || true
}

if [[ $EUID -eq 0 ]]; then
    sync_root
    exit 0
fi

mode="${1:-pick}"

case "$mode" in
    pick)
        f="$(zenity --file-selection --title='Выбери аватар' \
            --file-filter='Изображения | *.png *.jpg *.jpeg *.webp *.jfif *.bmp' 2>/dev/null)" || exit 1
        [[ -n "$f" && -f "$f" ]] || exit 1
        mkdir -p "$CACHE_DIR"
        cp -f "$f" "$SRC"
        exit 0
        ;;
    apply)
        cs="${2:?нужен размер}"; cx="${3:?нужен X}"; cy="${4:?нужен Y}"
        [[ -f "$SRC" ]] || { echo "нет исходника ($SRC)"; exit 1; }
        crop="$(mktemp --suffix=.png)"
        trap 'rm -f -- "$crop"' EXIT
        magick "$SRC" -crop "${cs}x${cs}+${cx}+${cy}" +repage "$crop"
        commit "$crop"
        echo "аватар обновлён"
        ;;
    *)
        [[ -f "$mode" ]] || { echo "нет файла: $mode"; exit 1; }
        sq="$(mktemp --suffix=.png)"
        trap 'rm -f -- "$sq"' EXIT
        magick "$mode" -resize 512x512^ -gravity center -extent 512x512 "$sq"
        commit "$sq"
        echo "аватар обновлён"
        ;;
esac
