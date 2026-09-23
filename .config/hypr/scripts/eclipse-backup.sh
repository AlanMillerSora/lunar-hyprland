#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-backup.sh — бэкап конфигов риса перед обновлением системы.
#
#  Что копируем: ~/.config (hypr, quickshell, kitty, yazi, firefox-тема,
#  mako, hypridle, btop и т.д.), системные конфиги из /etc, список пакетов.
#  Куда:  ~/.local/share/lunar/backups/system-YYYYMMDD-HHMMSS/
#  Формат: tar.zst (архив) + пакеты.txt
#  Ротация: хранится только последние N (по умолчанию 5), старые удаляются.
#
#  Запуск:  eclipse-backup.sh [--keep N] [--quiet]
# ════════════════════════════════════════════════════════════════
set -uo pipefail

BACKUP_ROOT="$HOME/.local/share/lunar/backups"
KEEP=5
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) echo "usage: $0 [--keep N] [--quiet]" >&2; exit 1 ;;
  esac
done

log() { [[ "$QUIET" == 1 ]] || echo "$@"; }

STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$BACKUP_ROOT/system-$STAMP"
mkdir -p "$DEST"

# ── 1. конфиги пользователя (то, что важно рису) ────────────────
log "==> конфиги → $DEST"
TMP="$(mktemp -d)"
mkdir -p "$TMP/home-config"

for d in hypr quickshell kitty yazi mako hypridle btop fastfetch \
         Code gtk-3.0 gtk-4.0 firefox lunar wofi; do
  [[ -e "$HOME/.config/$d" ]] && cp -a "$HOME/.config/$d" "$TMP/home-config/" 2>/dev/null
done
for f in starship.toml kdeglobals .zshrc; do
  [[ -e "$HOME/.config/$f" ]] && cp -a "$HOME/.config/$f" "$TMP/home-config/" 2>/dev/null
done

# ── 2. системные конфиги (требуют root) ─────────────────────────
# sudo -n: если пароль нужен — не висим на приглашении, а пропускаем
# (пользовательские конфиги всё равно сохраняются).
mkdir -p "$TMP/etc"
for f in /etc/pacman.conf /etc/mkinitcpio.conf /etc/fstab \
         /etc/default/grub /etc/modprobe.d /etc/modules-load.d \
         /etc/sudoers.d/lunar-zapret /etc/systemd/system/zapret.service; do
  if [[ -e "$f" ]]; then
    sudo -n cp -a "$f" "$TMP/etc/" 2>/dev/null || true
  fi
done

# ── 3. список установленных пакетов ─────────────────────────────
pacman -Qqe > "$DEST/packages-explicit.txt" 2>/dev/null || true
pacman -Qq  > "$DEST/packages-all.txt" 2>/dev/null || true

# ── 4. сборка архива ────────────────────────────────────────────
if command -v zstd >/dev/null 2>&1; then
  tar -C "$TMP" -cf - . | zstd -q -19 -o "$DEST/lunar-configs.tar.zst" 2>/dev/null \
    || tar -C "$TMP" -czf "$DEST/lunar-configs.tar.gz" . 2>/dev/null
else
  tar -C "$TMP" -czf "$DEST/lunar-configs.tar.gz" . 2>/dev/null
fi
rm -rf "$TMP"

log "    $DEST"

# ── 5. ротация: оставляем только последние KEEP ─────────────────
mapfile -t ALL < <(ls -1d "$BACKUP_ROOT"/system-* 2>/dev/null | sort -r)
if [[ "${#ALL[@]}" -gt "$KEEP" ]]; then
  for old in "${ALL[@]:$KEEP}"; do
    log "==> ротация: удаляю $(basename "$old")"
    rm -rf "$old"
  done
fi

log "==> бэкап готов (${#ALL[@]} всего, храним $KEEP)"
echo "$DEST"
