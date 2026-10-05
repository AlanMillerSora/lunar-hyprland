#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  ui.sh — общий стиль установщика Lunar Eclipse.
#  Подключается из install.sh и get-deps.sh: banner, step, ok, warn…
#
#  Палитра темы: #ffffff · #888888 · #4a4a4a · #ff003c.
#  Цвет только в терминале: в пайпе/логе (| tee) выводится чистый текст.
# ════════════════════════════════════════════════════════════════

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_FG=$'\033[38;2;255;255;255m'
  C_DIM=$'\033[38;2;136;136;136m'
  C_FAINT=$'\033[38;2;74;74;74m'
  C_DANGER=$'\033[38;2;255;0;60m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_FG=; C_DIM=; C_FAINT=; C_DANGER=; C_BOLD=; C_RESET=
fi

LUNAR_STEP=0
LUNAR_TOTAL=${LUNAR_TOTAL:-1}

# HUD-рамка в стиле риса (радиус 6 → скруглённые углы)
lunar_banner() {
  printf '%s' "$C_DIM"
  cat <<'EOF'
╭──────────────────────────────────────────────╮
│                                              │
│   ◐  L U N A R   E C L I P S E               │
│      hyprland · quickshell · monochrome       │
│                                              │
╰──────────────────────────────────────────────╯
EOF
  printf '%s' "$C_RESET"
}

lunar_hr() {
  printf '%s──────────────────────────────────────────────%s\n' "$C_FAINT" "$C_RESET"
}

# заголовок шага: step "текст"
step() {
  LUNAR_STEP=$((LUNAR_STEP + 1))
  printf '\n%s[%d/%d]%s %s%s%s\n' \
    "$C_FAINT" "$LUNAR_STEP" "$LUNAR_TOTAL" "$C_RESET" \
    "$C_BOLD$C_FG" "$1" "$C_RESET"
}

ok()   { printf '   %s✓%s %s\n' "$C_FG"     "$C_RESET" "$1"; }
warn() { printf '   %s!%s %s\n' "$C_DANGER" "$C_RESET" "$1"; }
err()  { printf '   %s✗%s %s\n' "$C_DANGER" "$C_RESET" "$1"; }
say()  { printf '   %s%s%s\n'    "$C_DIM"    "$1"       "$C_RESET"; }

lunar_done() {
  lunar_hr
  printf '   %s%sГОТОВО%s  %sперезайди в Hyprland: hyprctl reload%s\n' \
    "$C_BOLD" "$C_FG" "$C_RESET" "$C_DIM" "$C_RESET"
  lunar_hr
}

# ── root в установщике: спросить один раз ──────────────────────
# Системные команды ходят через `sudo -n`: пароль спрашиваем ровно один раз
# здесь (в интерактиве — приглашение sudo, в headless — SUDO_ASKPASS),
# дальше таймстемп только продлеваем. Без root системную часть аккуратно
# пропускаем ОДНИМ предупреждением — без россыпи ошибок и без риска
# словить faillock повторными неудачными попытками.
_LUNAR_ROOT_STATE=""
ensure_root() {
  # уже root — sudo не нужен вовсе
  if [ "$(id -u)" -eq 0 ]; then
    _LUNAR_ROOT_STATE=ok
    return 0
  fi
  # вердикт уже вынесен: не спрашиваем и не предупреждаем повторно
  case "$_LUNAR_ROOT_STATE" in
    ok) _root_keepalive; return 0 ;;
    no) return 1 ;;
  esac
  # пароль ещё в кэше — приглашение не нужно
  if sudo -n true 2>/dev/null; then
    _LUNAR_ROOT_STATE=ok
    _root_keepalive
    return 0
  fi
  # один раз спрашиваем (headless возьмёт SUDO_ASKPASS); приглашение
  # sudo идёт в /dev/tty, поэтому stderr прятать безопасно
  if sudo -v 2>/dev/null; then
    _LUNAR_ROOT_STATE=ok
    _root_keepalive
    return 0
  fi
  _LUNAR_ROOT_STATE=no
  warn "системные шаги пропущены (нужен root)"
  return 1
}

# Длинный прогон может пережить таймстемп sudo (по умолчанию ~15 мин) —
# тихо продлеваем его фоном, пока жив родительский установщик.
_root_keepalive() {
  [ -n "${_LUNAR_KEEPALIVE_PID:-}" ] && return 0
  ( while sleep 50; do
      kill -0 "$PPID" 2>/dev/null || exit 0
      sudo -n true 2>/dev/null || exit 0
    done ) &
  _LUNAR_KEEPALIVE_PID=$!
}
