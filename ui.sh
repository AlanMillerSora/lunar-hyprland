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
