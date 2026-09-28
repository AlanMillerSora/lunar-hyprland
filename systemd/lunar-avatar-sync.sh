#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  lunar-avatar-sync.sh — root-хелпер: копирует аватар в тему SDDM.
#
#  Ставится install.sh в /usr/local/lib/lunar/avatar-sync.sh
#  (0755, root:root). В sudoers — единственная разрешённая команда
#  из пользовательских каталогов, без аргументов и масок.
#
#  Источник — аватар пользователя, вызвавшего sudo (SUDO_USER),
#  а не произвольный путь: подставить чужой файл нельзя.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

SDDM_AV="/usr/share/sddm/themes/lunar/assets/avatar.png"

user="${SUDO_USER:-${USER:-sora}}"
[[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "некорректный пользователь: $user" >&2; exit 1; }

home="/home/$user"
src="$home/.config/avatars/avatar.png"
# симлинк — типичная попытка скормить root-хелперу чужой файл (/etc/shadow и т.п.)
[[ -L "$src" ]] && { echo "источник — симлинк, отказ" >&2; exit 1; }
real="$(readlink -f -- "$src" 2>/dev/null || true)"
[[ -n "$real" && "$real" == "$home/.config/avatars/"* && -f "$real" ]] \
  || { echo "источник вне каталога аватаров: $src" >&2; exit 1; }
[[ -d "$(dirname "$SDDM_AV")" ]] || { echo "нет темы SDDM: $(dirname "$SDDM_AV")" >&2; exit 1; }

install -m 0644 -o root -g root "$real" "$SDDM_AV"
echo "аватар синхронизирован в SDDM"
