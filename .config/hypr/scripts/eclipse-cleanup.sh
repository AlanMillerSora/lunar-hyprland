#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-cleanup.sh — очистка системы Lunar Eclipse.
#
#  Убирает:
#    --orphans   пакеты-сироты (pacman -Qtdq)
#    --pkgcache  старые версии в /var/cache/pacman/pkg (paccache)
#    --journal   старые записи journald
#    --tmpfiles  systemd-tmpfiles --clean
#    --yay       кэш сборок yay (~/.cache/yay)
#    --thumbs    кэш эскизов (~/.cache/thumbnails, fontconfig)
#    --browser   кэш браузеров (chromium/mozilla) — по умолчанию ВЫКЛ
#
#  Без флагов — безопасный набор (всё, кроме браузеров).
#  --all — вообще всё.  --dry-run — только показать, ничего не удалять.
#
#  Запуск из Hub (кнопка «ОЧИСТИТЬ») либо вручную:
#     sudo ~/.config/hypr/scripts/eclipse-cleanup.sh
# ════════════════════════════════════════════════════════════════
set -uo pipefail

# ── кто мы и чей это дом ───────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
  TARGET_USER="$(getent passwd "${PKEXEC_UID:-${SUDO_UID:-0}}" | cut -d: -f1)"
  [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ] && TARGET_USER="$(logname 2>/dev/null || echo sora)"
else
  TARGET_USER="$(id -un)"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -d "$TARGET_HOME" ] || TARGET_HOME="$HOME"
ROOT=0; [ "$(id -u)" -eq 0 ] && ROOT=1

# ── флаги ──────────────────────────────────────────────────────
DO_ORPHANS=0 DO_PKGCACHE=0 DO_PKGCACHE_ALL=0 DO_JOURNAL=0 DO_TMPFILES=0 DO_YAY=0 DO_THUMBS=0 DO_BROWSER=0
DRY_RUN=0 SELECTED=0
for a in "$@"; do
  case "$a" in
    --orphans)  DO_ORPHANS=1;  SELECTED=1 ;;
    --pkgcache) DO_PKGCACHE=1; SELECTED=1 ;;
    --pkgcache-all) DO_PKGCACHE=1; DO_PKGCACHE_ALL=1; SELECTED=1 ;;
    --journal)  DO_JOURNAL=1;  SELECTED=1 ;;
    --tmpfiles) DO_TMPFILES=1; SELECTED=1 ;;
    --yay)      DO_YAY=1;      SELECTED=1 ;;
    --thumbs)   DO_THUMBS=1;   SELECTED=1 ;;
    --browser)  DO_BROWSER=1;  SELECTED=1 ;;
    --all)      DO_ORPHANS=1 DO_PKGCACHE=1 DO_JOURNAL=1 DO_TMPFILES=1 DO_YAY=1 DO_THUMBS=1 DO_BROWSER=1; SELECTED=1 ;;
    --dry-run)  DRY_RUN=1 ;;
    -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
  esac
done
if [ "$SELECTED" -eq 0 ]; then
  # безопасный набор по умолчанию
  DO_ORPHANS=1 DO_PKGCACHE=1 DO_JOURNAL=1 DO_TMPFILES=1 DO_YAY=1 DO_THUMBS=1
fi

# ── вывод ──────────────────────────────────────────────────────
say()  { printf '\033[97m==>\033[0m %s\n' "$*"; }
ok()   { printf '   \033[92m✓\033[0m %s\n' "$*"; }
warn() { printf '   \033[93m!\033[0m %s\n' "$*"; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf '   \033[90m[dry]\033[0m %s\n' "$*"; else "$@"; fi; }
runsh() { if [ "$DRY_RUN" = 1 ]; then printf '   \033[90m[dry]\033[0m %s\n' "$1"; else bash -c "$1"; fi; }
need_root() { [ "$ROOT" -eq 1 ] && return 0; warn "нужен root — пропускаю: $*"; return 1; }

T0="$(df -B1 / | awk 'NR==2{print $4}')"
say "Lunar cleanup  ·  пользователь: $TARGET_USER  ·  $( [ $DRY_RUN = 1 ] && echo 'СУХОЙ ПРОГОН' || echo 'режим удаления' )"

# ── 1. пакеты-сироты ───────────────────────────────────────────
if [ "$DO_ORPHANS" = 1 ] && need_root "сироты"; then
  say "Пакеты-сироты"
  mapfile -t orphans < <(pacman -Qtdq 2>/dev/null)
  if [ "${#orphans[@]}" -eq 0 ]; then
    ok "сирот нет"
  else
    ok "${#orphans[@]} шт.: ${orphans[*]}"
    if [ "$DRY_RUN" = 1 ]; then
      printf '   \033[90m[dry]\033[0m pacman -Rns --noconfirm %s\n' "${orphans[*]}"
    elif pacman -Rns --noconfirm "${orphans[@]}" >/dev/null 2>&1; then
      ok "удалены"
    else
      warn "не удалось удалить сироты"
    fi
  fi
fi

# ── 2. кэш пакетов ─────────────────────────────────────────────
if [ "$DO_PKGCACHE" = 1 ] && need_root "кэш пакетов"; then
  say "Кэш пакетов (/var/cache/pacman/pkg)"
  before="$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"
  if [ "$DO_PKGCACHE_ALL" = 1 ]; then
    # агрессивно: вычистить кэш целиком (пакеты потом качаются заново)
    run pacman -Scc --noconfirm >/dev/null 2>&1
  elif command -v paccache >/dev/null 2>&1; then
    run paccache -rk1 >/dev/null 2>&1
    run paccache -ruk0 >/dev/null 2>&1
  else
    # без pacman-contrib: убираем всё, кроме текущих версий установленного
    if [ "$DRY_RUN" = 1 ]; then
      printf '   \033[90m[dry]\033[0m обрезать кэш вручную (оставить только установленные версии)\n'
    else
      declare -A keep
      while read -r name ver; do keep["$name-$ver"]=1; done < <(pacman -Q)
      for f in /var/cache/pacman/pkg/*.pkg.tar.*; do
        [ -e "$f" ] || continue
        case "$f" in *.sig) continue ;; esac
        base="$(basename "$f")"; matched=0
        for k in "${!keep[@]}"; do case "$base" in "$k"-*) matched=1; break ;; esac; done
        [ "$matched" = 0 ] && rm -f -- "$f" "$f.sig"
      done
    fi
  fi
  after="$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"
  ok "было: ${before:-?} → стало: ${after:-?}"
fi

# ── 3. журнал ──────────────────────────────────────────────────
if [ "$DO_JOURNAL" = 1 ] && need_root "journal"; then
  say "Журнал systemd"
  before="$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[MG]' | head -1)"
  run journalctl --vacuum-time=14d >/dev/null 2>&1
  run journalctl --vacuum-size=100M >/dev/null 2>&1
  after="$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[MG]' | head -1)"
  ok "было: ${before:-?} → стало: ${after:-?}"
fi

# ── 4. tmpfiles ────────────────────────────────────────────────
if [ "$DO_TMPFILES" = 1 ] && need_root "tmpfiles"; then
  say "Временные файлы (systemd-tmpfiles)"
  run systemd-tmpfiles --clean >/dev/null 2>&1 && ok "подчищено"
fi

# ── 5. кэш сборок yay ──────────────────────────────────────────
if [ "$DO_YAY" = 1 ]; then
  say "Кэш сборок yay"
  ydir="$TARGET_HOME/.cache/yay"
  if [ -d "$ydir" ]; then
    before="$(du -sh "$ydir" 2>/dev/null | cut -f1)"
    runsh "rm -rf '$ydir'/*"
    ok "было: ${before:-?} → стало: $(du -sh "$ydir" 2>/dev/null | cut -f1)"
  else
    ok "нет кэша yay"
  fi
fi

# ── 6. эскизы / шрифтовый кэш ──────────────────────────────────
if [ "$DO_THUMBS" = 1 ]; then
  say "Эскизы и кэш шрифтов"
  for d in "$TARGET_HOME/.cache/thumbnails" "$TARGET_HOME/.cache/fontconfig"; do
    [ -d "$d" ] && { runsh "rm -rf '$d'/*"; ok "$(basename "$d")"; }
  done
fi

# ── 7. кэш браузеров (опционально) ─────────────────────────────
if [ "$DO_BROWSER" = 1 ]; then
  say "Кэш браузеров"
  for d in "$TARGET_HOME/.cache/chromium" "$TARGET_HOME/.cache/mozilla"; do
    [ -d "$d" ] && { runsh "rm -rf '$d'/*"; ok "$(basename "$d")"; }
  done
fi

# ── отчёт ──────────────────────────────────────────────────────
T1="$(df -B1 / | awk 'NR==2{print $4}')"
say "Свободно на /: $(numfmt --to=iec "$T0" 2>/dev/null || echo "$T0") → $(numfmt --to=iec "$T1" 2>/dev/null || echo "$T1")"
if [ "$DRY_RUN" != 1 ]; then
  sroot="$(df -h / | awk 'NR==2{print $3}')/$(df -h / | awk 'NR==2{print $2}')"
  shome="$(df -h /home | awk 'NR==2{print $3}')/$(df -h /home | awk 'NR==2{print $2}')"
  say "Занято: / = $sroot   /home = $shome"
fi
say "Готово."
