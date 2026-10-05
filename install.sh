#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — единый установщик.
#
#  База (без флагов): зависимости + конфиги ~/.config + системные
#  мелочи (sudoers агента, shell). Системные темы и сервисы
#  (SDDM, Plymouth, zapret) ставятся ТОЛЬКО по явному флагу.
#
#  Запуск:  ./install.sh [флаги]
#    --no-deps           только конфиги (зависимости уже стоят)
#    --deps-only         только зависимости
#    --sddm              тема экрана входа SDDM (lunar)
#    --plymouth          заставка Plymouth; меняет загрузку (HOOKS/UKI/GRUB)
#    --zapret            обход DPI: Discord/YouTube (/opt/zapret)
#    --status            состояние SDDM / Plymouth / zapret
#    --disable-sddm      вернуть штатную тему входа
#    --disable-plymouth  выключить заставку и вернуть загрузку
#    --plymouth-rescue   (UKI) пункт меню GRUB «без заставки»
#    -h, --help
#
#  Повторный запуск безопасен: локальные правки в ~/.config складываются
#  в ~/.config-backup-<дата>/.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ui.sh
source "$REPO/ui.sh"

WITH_DEPS=1
DEPS_ONLY=0
DO_SDDM=0
DO_PLYMOUTH=0
DO_ZAPRET=0
ACTION=""

for a in "$@"; do
  case "$a" in
    --no-deps)          WITH_DEPS=0 ;;
    --deps-only)        DEPS_ONLY=1 ;;
    --sddm)             DO_SDDM=1 ;;
    --plymouth)         DO_PLYMOUTH=1 ;;
    --zapret)           DO_ZAPRET=1 ;;
    --status)           ACTION=status ;;
    --disable-sddm)     ACTION=disable-sddm ;;
    --disable-plymouth) ACTION=disable-plymouth ;;
    --plymouth-rescue)  ACTION=plymouth-rescue ;;
    -h|--help)          sed -n '2,23p' "$0"; exit 0 ;;
    *) printf 'usage: %s [--no-deps|--deps-only|--sddm|--plymouth|--zapret|--status|--disable-sddm|--disable-plymouth|--plymouth-rescue]\n' "$0" >&2; exit 1 ;;
  esac
done

# --deps-only самодостаточен: он всегда тянет зависимости, даже если рядом
# указан --no-deps. Иначе не выполнилось бы ни одного шага [n/total].
if [ "$DEPS_ONLY" = 1 ]; then
  WITH_DEPS=1
fi

# части установщика: пользовательское / системное / опциональное.
# Подключаю после разбора флагов (как в прежнем монолите, где функции
# определялись ниже парсинга), чтобы -h и неверный флаг выходили раньше
# побочных проверок. Порядок вызовов внизу сохранён — шаги [n/total] не меняются.
# shellcheck source=install/dotfiles.sh
source "$REPO/install/dotfiles.sh"
# shellcheck source=install/system.sh
source "$REPO/install/system.sh"
# shellcheck source=install/optional.sh
source "$REPO/install/optional.sh"

# ════════════════════════════════════════════════════════════════
#  Действия без установки: --status / --disable-* / --plymouth-rescue
# ════════════════════════════════════════════════════════════════
case "$ACTION" in
  status)
    sddm_status; echo
    ply_status; echo
    zapret_status
    exit 0 ;;
  disable-sddm)
    ensure_root || exit 1
    sddm_disable; ok "SDDM: возвращена штатная тема"; exit 0 ;;
  disable-plymouth)
    ensure_root || exit 1
    ply_disable; ok "Plymouth: заставка выключена, загрузка обычная"; exit 0 ;;
  plymouth-rescue)
    ensure_root || exit 1
    ply_rescue; exit 0 ;;
esac

# количество шагов для счётчика [n/total]
LUNAR_TOTAL=14
[ "$WITH_DEPS" = 1 ] && LUNAR_TOTAL=$((LUNAR_TOTAL + 1))
[ "$DO_SDDM" = 1 ] && LUNAR_TOTAL=$((LUNAR_TOTAL + 1))
[ "$DO_PLYMOUTH" = 1 ] && LUNAR_TOTAL=$((LUNAR_TOTAL + 1))
[ "$DO_ZAPRET" = 1 ] && LUNAR_TOTAL=$((LUNAR_TOTAL + 1))
[ "$DEPS_ONLY" = 1 ] && LUNAR_TOTAL=1   # deps-only выполняет только один шаг

lunar_banner

# ── зависимости ────────────────────────────────────────────────
if [ "$WITH_DEPS" = 1 ]; then
  step "зависимости (pacman + AUR)"
  if LUNAR_EMBEDDED=1 "$REPO/get-deps.sh"; then
    ok "зависимости установлены"
  else
    warn "часть зависимостей не поставилась — см. вывод, потом ./install.sh"
  fi
fi

if [ "$DEPS_ONLY" = 1 ]; then
  lunar_done
  exit 0
fi

# ── пользовательское: конфиги и оформление ─────────────────────
dotfiles_configs
dotfiles_kde
dotfiles_firefox
dotfiles_firefox_icon
dotfiles_bibata
dotfiles_systemd_user

# ── системное (root): сервисы и хелперы ────────────────────────
# Root спрашиваю один раз здесь: ensure_root кэширует таймстемп sudo,
# дальше системные команды идут через `sudo -n` без повторных приглашений.
# Нет root — одно предупреждение, системная часть аккуратно пропускается.
if ensure_root; then
  system_cronie
  system_helpers
  system_cpu_performance
  system_iwd
  system_tgproxy
  system_sudoers
fi

# ── пользовательское: shell и GTK ──────────────────────────────
dotfiles_shell
dotfiles_gtk

# ── опционально (по флагам) ────────────────────────────────────
if [ "$DO_SDDM" = 1 ]; then
  optional_sddm
fi
if [ "$DO_PLYMOUTH" = 1 ]; then
  optional_plymouth
fi
if [ "$DO_ZAPRET" = 1 ]; then
  optional_zapret
fi

lunar_done
