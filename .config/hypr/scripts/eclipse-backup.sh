#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-backup.sh — бэкап конфигов риса перед обновлением системы.
#
#  Что копируем: ~/.config (hypr, quickshell, kitty, yazi, firefox-тема,
#  mako, hypridle, btop, avatars и т.д.), системные конфиги из /etc,
#  список пакетов. Code — только настройки, без тяжёлых кэшей/истории.
#  Куда:  ~/.local/share/lunar/backups/system-YYYYMMDD-HHMMSS/
#  Формат: tar.zst (архив) + пакеты.txt
#  Ротация: хранится только последние N (по умолчанию 5), старые удаляются.
#
#  Запуск:  eclipse-backup.sh [--keep N] [--quiet] [--force]
#    --force — сделать бэкап даже в Game Mode (нужен перед обновлением)
# ════════════════════════════════════════════════════════════════
set -euo pipefail

BACKUP_ROOT="$HOME/.local/share/lunar/backups"
KEEP=5
QUIET=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)
      [[ -n "${2:-}" && "${2:-}" =~ ^[0-9]+$ ]] || { echo "usage: $0 [--keep N] [--quiet] [--force]" >&2; exit 1; }
      KEEP="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    --force) FORCE=1; shift ;;
    *) echo "usage: $0 [--keep N] [--quiet] [--force]" >&2; exit 1 ;;
  esac
done

log() { [[ "$QUIET" == 1 ]] || echo "$@"; }

# ── Game Mode: не гоняем бэкап (тяжёлый I/O) во время игры ──────
if [[ "$FORCE" != 1 \
      && "$(cat "$HOME/.cache/lunar/gamemode" 2>/dev/null || echo 0)" == 1 ]]; then
  log "Game Mode включён — бэкап пропущен (--force чтобы всё равно)"
  exit 0
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$BACKUP_ROOT/system-$STAMP"
mkdir -p "$DEST"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT

# ── 1. конфиги пользователя (то, что важно рису) ────────────────
log "==> конфиги → $DEST"
mkdir -p "$TMP/home-config"

CONFIG_DIRS=(hypr quickshell kitty yazi mako hypridle btop fastfetch \
             gtk-3.0 gtk-4.0 firefox lunar avatars)
for d in "${CONFIG_DIRS[@]}"; do
  if [[ -e "$HOME/.config/$d" ]]; then
    cp -a "$HOME/.config/$d" "$TMP/home-config/" 2>/dev/null \
      || log "    не удалось скопировать: $d"
  fi
done
for f in starship.toml kdeglobals .zshrc; do
  if [[ -e "$HOME/.config/$f" ]]; then
    cp -a "$HOME/.config/$f" "$TMP/home-config/" 2>/dev/null \
      || log "    не удалось скопировать: $f"
  fi
done

# Code: берём только настройки/сниппеты — без CachedData/logs/History/workspaceStorage
if [[ -d "$HOME/.config/Code" ]]; then
  mkdir -p "$TMP/home-config/Code"
  if ! tar -C "$HOME/.config/Code" \
        --exclude=./CachedData --exclude=./logs \
        --exclude=./User/History --exclude=./User/workspaceStorage \
        -cf - . 2>/dev/null | tar -C "$TMP/home-config/Code" -xf - 2>/dev/null; then
    log "    не удалось скопировать: Code"
  fi
fi

# ── 2. системные конфиги (требуют root) ─────────────────────────
# sudo -n: если пароль нужен — не висим на приглашении, а пропускаем
# (пользовательские конфиги всё равно сохраняются).
mkdir -p "$TMP/etc"
for f in /etc/pacman.conf /etc/mkinitcpio.conf /etc/fstab \
         /etc/default/grub /etc/modprobe.d /etc/modules-load.d \
         /etc/systemd/system/zapret.service; do
  if [[ -e "$f" ]]; then
    sudo -n cp -a "$f" "$TMP/etc/" 2>/dev/null || true
  fi
done

# ── 3. список установленных пакетов ─────────────────────────────
pacman -Qqe > "$DEST/packages-explicit.txt" 2>/dev/null || true
pacman -Qq  > "$DEST/packages-all.txt" 2>/dev/null || true

# ── 4. сборка архива ────────────────────────────────────────────
ARCHIVE=""
if command -v zstd >/dev/null 2>&1; then
  if tar -C "$TMP" -cf - . 2>/dev/null | zstd -q -19 -o "$DEST/lunar-configs.tar.zst" 2>/dev/null; then
    ARCHIVE="$DEST/lunar-configs.tar.zst"
  fi
fi
if [[ -z "$ARCHIVE" ]]; then
  if tar -C "$TMP" -czf "$DEST/lunar-configs.tar.gz" . 2>/dev/null; then
    ARCHIVE="$DEST/lunar-configs.tar.gz"
  fi
fi

# архив обязан существовать и быть непустым, иначе бэкапа нет
if [[ -z "$ARCHIVE" || ! -s "$ARCHIVE" ]]; then
  echo "eclipse-backup: не удалось создать архив — бэкап не сделан" >&2
  rm -rf "$DEST"
  exit 1
fi

log "    $ARCHIVE"

# ── 5. ротация: оставляем только последние KEEP ─────────────────
mapfile -t ALL < <(ls -1d "$BACKUP_ROOT"/system-* 2>/dev/null | sort -r)
if [[ "${#ALL[@]}" -gt "$KEEP" ]]; then
  for old in "${ALL[@]:$KEEP}"; do
    log "==> ротация: удаляю $(basename "$old")"
    rm -rf "$old" || true
  done
fi

log "==> бэкап готов (${#ALL[@]} всего, храним $KEEP)"
echo "$DEST"
