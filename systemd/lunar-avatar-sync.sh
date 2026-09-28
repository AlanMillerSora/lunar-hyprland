#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  lunar-avatar-sync.sh — root-хелпер: копирует аватар в тему SDDM.
#
#  Ставится install.sh в /usr/local/lib/lunar/avatar-sync.sh
#  (0755, root:root). В sudoers — единственная разрешённая команда
#  из пользовательских каталогов, без аргументов и масок.
#
#  Источник — аватар пользователя, вызвавшего sudo (SUDO_USER).
#  Симлинки и путь вне каталога аватаров отвергаются; файл читается
#  через O_NOFOLLOW и уже из открытого дескриптора (защита от подмены
#  пути между проверкой и чтением).
# ════════════════════════════════════════════════════════════════
set -euo pipefail

SDDM_AV="/usr/share/sddm/themes/lunar/assets/avatar.png"

user="${SUDO_USER:-${USER:-sora}}"
[[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "некорректный пользователь: $user" >&2; exit 1; }

home="/home/$user"
src="$home/.config/avatars/avatar.png"
[[ -L "$src" ]] && { echo "источник — симлинк, отказ" >&2; exit 1; }
real="$(readlink -f -- "$src" 2>/dev/null || true)"
[[ -n "$real" && "$real" == "$home/.config/avatars/"* && -f "$real" ]] \
  || { echo "источник вне каталога аватаров: $src" >&2; exit 1; }
[[ -d "$(dirname "$SDDM_AV")" ]] || { echo "нет темы SDDM: $(dirname "$SDDM_AV")" >&2; exit 1; }
uid="$(id -u "$user")"

python3 - "$real" "$SDDM_AV" "$uid" <<'PY'
import os, stat, sys
src, dst, uid = sys.argv[1], sys.argv[2], int(sys.argv[3])
fd = os.open(src, os.O_RDONLY | os.O_NOFOLLOW)
st = os.fstat(fd)
if not stat.S_ISREG(st.st_mode):
    sys.exit("источник — не регулярный файл")
if st.st_uid != uid:
    sys.exit("источник не принадлежит пользователю")
with os.fdopen(fd, "rb") as fsrc, open(dst, "wb") as fdst:
    while True:
        chunk = fsrc.read(65536)
        if not chunk:
            break
        fdst.write(chunk)
os.chmod(dst, 0o644)
os.chown(dst, 0, 0)
PY

echo "аватар синхронизирован в SDDM"
