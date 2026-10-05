#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  doctor.sh — health-check риса Lunar Eclipse.
#
#  Проверяю то, что чаще всего «тихо» ломается: жив ли шелл, чист ли
#  конфиг Hyprland, поднят ли сетевой стек (iwd + systemd-networkd),
#  нет ли дрейфа repo ↔ live и проходит ли ci-гейт.
#
#  Вывод человекочитаемый; exit 1, если провалена хоть одна проверка.
#  Запуск: ./doctor.sh   (или ./lunar doctor)
# ════════════════════════════════════════════════════════════════
set -uo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ui.sh
. "$REPO/ui.sh"

FAIL=0
pass() { ok "$1"; }
fail() { err "$1"; FAIL=1; }

lunar_hr
printf '   %s◐  DOCTOR · состояние риса%s\n' "$C_BOLD$C_FG" "$C_RESET"
lunar_hr

# 1) Quickshell — панель, Hub, сайдбары, polkit, обои
if systemctl --user is-active --quiet lunar-quickshell.service; then
  pass "quickshell: active"
else
  fail "quickshell: НЕ active (systemctl --user status lunar-quickshell.service)"
fi

# 2) Hyprland — конфиг Lua без ошибок
if ! command -v hyprctl >/dev/null 2>&1; then
  fail "hyprctl: не найден (не сессия Hyprland?)"
elif ! errs="$(hyprctl configerrors 2>&1)"; then
  fail "hyprctl configerrors: не ответил (нет сессии Hyprland?)"
elif [ -z "${errs//[[:space:]]/}" ]; then
  pass "hyprctl configerrors: пусто"
else
  fail "hyprctl configerrors: есть ошибки"
  printf '%s\n' "$errs" | sed 's/^/       /'
fi

# 3) Сеть: ассоциация iwd + IP от systemd-networkd
for u in iwd.service systemd-networkd.service; do
  if systemctl is-active --quiet "$u"; then
    pass "$u: active"
  else
    fail "$u: НЕ active"
  fi
done

# 4) Дрейф repo ↔ live (производные палитры не считаются)
if out="$("$REPO/sync.sh" check 2>&1)"; then
  pass "sync: live == repo"
else
  fail "sync: дрейф repo ↔ live"
  printf '%s\n' "$out" | sed 's/^/       /'
fi

# 5) CI-гейт: синтаксис shell/python, токены Theme.qml, палитра
if out="$(bash "$REPO/ci/check.sh" 2>&1)"; then
  pass "ci: гейт пройден"
else
  fail "ci: гейт провален"
  printf '%s\n' "$out" | tail -25 | sed 's/^/       /'
fi

lunar_hr
if [ "$FAIL" = 0 ]; then
  printf '   %s✓ рис в порядке%s\n' "$C_FG" "$C_RESET"
  exit 0
fi
printf '   %s✗ есть проблемы — см. выше%s\n' "$C_DANGER" "$C_RESET"
exit 1
