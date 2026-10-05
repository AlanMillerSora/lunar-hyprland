#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  doctor.sh — health-check риса Lunar Eclipse.
#
#  Проверяю то, что чаще всего «тихо» ломается: жив ли шелл, чист ли
#  конфиг Hyprland, поднят ли сетевой стек (iwd + systemd-networkd),
#  демоны сессии (mako/hypridle/cliphist) и tgproxy, на месте ли палитра,
#  есть ли правило sudo -n, не в restart-loop ли quickshell, нет ли дрейфа
#  repo ↔ live и проходит ли ci-гейт.
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

# 5) Демоны сессии: mako/hypridle/cliphist «тихо» отваливаются.
# Нет утилиты в системе — это не провал риса, помечаю пропуском (не падаю).
check_daemon() { # <команда> <имя процесса> <подпись>
  local cmd="$1" proc="$2" label="$3"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    say "$label: пропущено ($cmd не установлен)"
  elif pgrep -x "$proc" >/dev/null 2>&1; then
    pass "$label: активен"
  else
    fail "$label: НЕ активен ($proc)"
  fi
}
check_daemon mako     mako     "mako (уведомления)"
check_daemon hypridle hypridle "hypridle (простой/лок)"
# у cliphist нет демона — буфер держат вотчеры wl-paste (text/image)
check_daemon cliphist wl-paste "cliphist (вотчеры wl-paste)"

# 6) Telegram-прокси: необязателен — нужны tg-ws-proxy и env-файл
if ! command -v tg-ws-proxy >/dev/null 2>&1; then
  say "lunar-tgproxy: пропущено (tg-ws-proxy не установлен)"
elif ! systemctl --user cat lunar-tgproxy.service >/dev/null 2>&1; then
  say "lunar-tgproxy: пропущено (юнит не установлен)"
elif systemctl --user is-active --quiet lunar-tgproxy.service; then
  pass "lunar-tgproxy: active"
else
  fail "lunar-tgproxy: НЕ active"
fi

# 7) Палитра: JSON для Theme.qml (его пишет eclipse-palette.py --apply)
if [ -f "$HOME/.cache/lunar/palette.json" ]; then
  pass "palette.json: есть"
else
  fail "palette.json: нет (~/.cache/lunar/palette.json) — прогони eclipse-palette.py --apply"
fi

# 8) sudo без пароля: есть ли правило (install/reload ходят через sudo -n).
# Без правила это не поломка риса — предупреждаю, не валю doctor.
if ! command -v sudo >/dev/null 2>&1; then
  say "sudo -n: пропущено (sudo не установлен)"
elif sudo -n -l >/dev/null 2>&1; then
  pass "sudo -n -l: правило есть"
else
  warn "sudo -n -l: без правила (пароль спросят)"
fi

# 9) restart-loop quickshell: failed-юнит или свежие падения в логе.
# Лог пишет lunar-quickshell-failure.service (OnFailure у юнита).
QS_FAIL_LOG="$HOME/.cache/lunar/quickshell-failure.log"
if systemctl --user is-failed --quiet lunar-quickshell.service 2>/dev/null; then
  fail "quickshell: в failed (restart-loop) — systemctl --user reset-failed lunar-quickshell.service"
elif [ -f "$QS_FAIL_LOG" ]; then
  last_ts="$(tail -n1 "$QS_FAIL_LOG" 2>/dev/null | cut -d' ' -f1-2)"
  last_epoch="$(date -d "$last_ts" +%s 2>/dev/null || echo 0)"
  now_epoch="$(date +%s)"
  if [ "$last_epoch" -gt 0 ] && [ $((now_epoch - last_epoch)) -lt 300 ]; then
    warn "quickshell: падал недавно ($last_ts) — см. $QS_FAIL_LOG"
  else
    pass "quickshell: не в restart-loop"
  fi
else
  pass "quickshell: не в restart-loop"
fi

# 10) CI-гейт: синтаксис shell/python, shellcheck, токены Theme.qml, палитра
if out="$(bash "$REPO/ci/check.sh" 2>&1)"; then
  pass "ci: гейт пройден"
else
  fail "ci: гейт провален"
  printf '%s\n' "$out" | tail -25 | sed 's/^/       /'
fi

# 11) Дрейф версий: VERSION ушёл вперёд последнего тега v* больше чем на
# минор — значит, релизы не выпускались и release.yml «висит» непроверенным.
# Это предупреждение, а не провал: тег ставит release.sh, когда автор готов.
if [ -f "$REPO/VERSION" ] && git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  ver="$(tr -d '[:space:]' < "$REPO/VERSION")"
  tag="$(git -C "$REPO" tag --list 'v*' --sort=-v:refname 2>/dev/null | head -n1)"
  if [ -z "$tag" ]; then
    warn "релиз: тегов v* нет — VERSION $ver ещё не выпускался"
  elif [[ "$ver" =~ ^[0-9]+\.[0-9]+ ]] && [[ "${tag#v}" =~ ^[0-9]+\.[0-9]+ ]]; then
    tv="${tag#v}"
    vmaj="${ver%%.*}"; vmin="${ver#*.}"; vmin="${vmin%%.*}"
    tmaj="${tv%%.*}";  tmin="${tv#*.}";  tmin="${tmin%%.*}"
    if [ "$vmaj" -gt "$tmaj" ] || [ "$vmin" -gt $((tmin + 1)) ]; then
      warn "релиз: VERSION $ver впереди тега $tag (>1 минора) — релизы не выпускались"
    else
      pass "релиз: VERSION $ver рядом с тегом $tag"
    fi
  else
    say "релиз: не разобрал VERSION/тег ($ver / $tag)"
  fi
fi

lunar_hr
if [ "$FAIL" = 0 ]; then
  printf '   %s✓ рис в порядке%s\n' "$C_FG" "$C_RESET"
  exit 0
fi
printf '   %s✗ есть проблемы — см. выше%s\n' "$C_DANGER" "$C_RESET"
exit 1
