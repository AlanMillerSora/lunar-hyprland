#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  reload.sh — перезагрузить рис БЕЗ приложений.
#
#  Приложения (kitty/firefox/discord/steam/игры) не трогаю: окна живут
#  в Hyprland, а quickshell перезапускаю под KillMode=process — юнит
#  завершает только сам шелл, не процессы из Hub. Перезапускаю ровно
#  те демоны сессии, что поднимает hyprland.lua в hl.on("hyprland.start"):
#    • Hyprland   — hyprctl reload (конфиг Lua);
#    • quickshell — lunar-quickshell.service (панель, Hub, polkit, обои, OSD,
#      уведомления — демон внутри NotifModel.qml);
#    • hypridle   — отдельный процесс (hl.exec_cmd("hypridle"));
#    • cliphist   — два вотчера wl-paste (text/image).
#
#  Запуск: ./reload.sh   (или ./lunar reload)
# ════════════════════════════════════════════════════════════════
set -uo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ui.sh
. "$REPO/ui.sh"
LUNAR_TOTAL=5

lunar_hr
printf '   %s◐  RELOAD · рис без приложений%s\n' "$C_BOLD$C_FG" "$C_RESET"
lunar_hr

# ── 1. Hyprland: перечитать конфиг Lua на лету ──────────────────
step "Hyprland: hyprctl reload"
if command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1; then
  errs="$(hyprctl configerrors 2>/dev/null || true)"
  if [ -z "${errs//[[:space:]]/}" ]; then
    ok "конфиг перечитан, configerrors пусто"
  else
    err "конфиг перечитан, но есть configerrors:"
    printf '%s\n' "$errs" | sed 's/^/       /'
  fi
else
  err "hyprctl reload не удался (нет сессии Hyprland?)"
fi

# ── 2. Quickshell: панель, Hub, polkit, обои, OSD ───────────────
step "Quickshell: lunar-quickshell.service"
systemctl --user reset-failed lunar-quickshell.service 2>/dev/null || true
if systemctl --user restart lunar-quickshell.service 2>/dev/null; then
  ok "шелл перезапущен (KillMode=process — окна не тронуты)"
else
  err "не удалось перезапустить юнит"
fi

# ── 3. уведомления: демон внутри Quickshell ────────────────────
step "уведомления: внутри Quickshell (NotifModel)"
# Отдельного демона нет: тосты/история живут в quickshell и перезапустились
# строкой выше. mako замаскирован (для отката: systemctl --user unmask mako).
if systemctl --user is-active --quiet mako.service 2>/dev/null; then
  warn "mako.service всё ещё активен — уведомления может перехватывать он"
else
  ok "mako не запущен, уведомления ведёт Quickshell"
fi

# ── 4. hypridle: простой/лок — отдельный процесс ────────────────
step "hypridle: простой/лок"
if pkill -x hypridle 2>/dev/null; then say "старый hypridle остановлен"; fi
if command -v hypridle >/dev/null 2>&1; then
  setsid -f hypridle >/dev/null 2>&1 && ok "hypridle поднят заново"
else
  err "hypridle не найден"
fi

# ── 5. cliphist: вотчеры буфера (text + image) ──────────────────
step "cliphist: вотчеры буфера (wl-paste text/image)"
if pkill -x wl-paste 2>/dev/null; then say "старые wl-paste остановлены"; fi
for t in text image; do
  setsid -f sh -c "wl-paste --type $t --watch cliphist store" >/dev/null 2>&1 || true
done
ok "вотчеры text/image запущены"

lunar_hr
printf '   %s✓ рис перезагружен, приложения на месте%s\n' "$C_FG" "$C_RESET"
lunar_hr
