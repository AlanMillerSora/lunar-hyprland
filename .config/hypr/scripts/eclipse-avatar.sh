#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-avatar.sh — аватар пользователя Lunar Eclipse.
#
#    без аргументов (от пользователя): выбрать файл через zenity,
#      обрезать в круг → ~/.config/avatars/avatar.png,
#      затем синхронизировать с темой экрана входа SDDM;
#    без аргументов (от root): только синхронизация в тему SDDM
#      (по белому списку sudo идёт без пароля).
#
#  Ручной выбор файла без диалога:  eclipse-avatar.sh /путь/картинка.png
# ════════════════════════════════════════════════════════════════
set -euo pipefail

SDDM_AV="/usr/share/sddm/themes/lunar/assets/avatar.png"

sync_root() {
    local u="${SUDO_USER:-sora}"
    local src="/home/$u/.config/avatars/avatar.png"
    [[ -f "$src" ]] || exit 0
    [[ -d "$(dirname "$SDDM_AV")" ]] || exit 0
    cp -f "$src" "$SDDM_AV"
    chmod 644 "$SDDM_AV"
}

# запуск от root — только синхронизация
if [[ $EUID -eq 0 ]]; then
    sync_root
    exit 0
fi

# ── от пользователя: выбор файла ──
if [[ $# -ge 1 ]]; then
    src="$1"
else
    src="$(zenity --file-selection --title='Выбери аватар' \
        --file-filter='Изображения | *.png *.jpg *.jpeg *.webp *.jfif' 2>/dev/null)" || exit 0
fi
[[ -n "${src:-}" && -f "$src" ]] || { echo "файл не выбран"; exit 0; }

av_dir="$HOME/.config/avatars"
av="$av_dir/avatar.png"
mkdir -p "$av_dir"

# круглая обрезка (как в теме экрана входа)
tmp="$(mktemp --suffix=.png)"
trap 'rm -f -- "$tmp"' EXIT
magick "$src" -resize 512x512^ -gravity center -extent 512x512 \
    \( -size 512x512 xc:black -fill white -draw "circle 256,256 256,2" \) \
    -alpha off -compose CopyOpacity -composite "PNG32:$tmp"
cp -f "$tmp" "$av"
chmod 644 "$av"

# синхронизация с экраном входа (NOPASSWD по белому списку sudo)
sudo -n "$0" 2>/dev/null || true

echo "аватар обновлён"
