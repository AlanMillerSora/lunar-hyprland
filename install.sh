#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — установка конфигов
#  Копирует .config/* в ~/.config, обои в ~/Pictures/EclipseWalls,
#  ставит systemd-юнит и делает zsh шеллом по умолчанию.
#  Зависимости: см. ./get-deps.sh
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
say() { printf '\033[38;5;15m==>\033[0m %s\n' "$*"; }

# ── конфиги ────────────────────────────────────────────────────
say "Конфиги → ~/.config"
mkdir -p "$HOME/.config"
cp -r "$REPO/.config/." "$HOME/.config/"
chmod +x "$HOME"/.config/hypr/scripts/* 2>/dev/null || true

# ── обои ───────────────────────────────────────────────────────
say "Обои → ~/Pictures/EclipseWalls"
mkdir -p "$HOME/Pictures/EclipseWalls"
cp "$REPO"/wallpapers/*.png "$HOME/Pictures/EclipseWalls/" 2>/dev/null || true

# ── KDE: цветовая схема (kdeglobals идут через .config) ────────
say "Цветовая схема KDE → ~/.local/share/color-schemes"
mkdir -p "$HOME/.local/share/color-schemes"
cp "$REPO"/color-schemes/*.colors "$HOME/.local/share/color-schemes/" 2>/dev/null || true

# ── Firefox: тема, стили и префы ───────────────────────────────
# Firefox сам выбирает профиль через свою секцию [Install…] в
# profiles.ini, поэтому применяем тему ко ВСЕМ реальным профилям
# (где уже есть prefs.js). Если профилей ещё нет — запусти Firefox
# один раз и повтори ./install.sh.
if [ -d "$REPO/.config/firefox/chrome" ]; then
  FF_ROOT="$HOME/.mozilla/firefox"
  FF_PROFS="$(find "$FF_ROOT" -maxdepth 2 -name prefs.js -printf '%h\n' 2>/dev/null || true)"

  if [ -z "$FF_PROFS" ]; then
    say "Firefox: профиль ещё не создан — запусти Firefox и повтори ./install.sh"
  else
    for P in $FF_PROFS; do
      say "Firefox: тема → $P"
      mkdir -p "$P/chrome"
      cp "$REPO"/.config/firefox/chrome/*.css "$P/chrome/" 2>/dev/null || true
      sed "s|__LUNAR_HOME__|file://$HOME/.config/lunar/firefox-home.html|g" \
        "$REPO/.config/firefox/user.js" > "$P/user.js"
    done
  fi
fi

# ── курсор Bibata (монохромный, в тему) ────────────────────────
if [ ! -d "$HOME/.local/share/icons/Bibata-Modern-Ice" ]; then
  say "Курсор Bibata → ~/.local/share/icons"
  mkdir -p "$HOME/.local/share/icons"
  curl -sL "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz" \
    | tar xJ -C "$HOME/.local/share/icons/" 2>/dev/null \
    && say "Bibata установлен" \
    || say "Bibata не скачался (не критично — будет системный курсор)"
fi

# ── systemd --user (wifi-guard) ────────────────────────────────
if [ -f "$REPO/systemd/lunar-wifi-guard.service" ]; then
  say "systemd --user → lunar-wifi-guard"
  mkdir -p "$HOME/.config/systemd/user"
  cp "$REPO"/systemd/*.service "$HOME/.config/systemd/user/"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now lunar-wifi-guard.service 2>/dev/null || true
fi

# ── shell по умолчанию ─────────────────────────────────────────
if command -v zsh >/dev/null 2>&1 && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  say "zsh как шелл по умолчанию"
  chsh -s "$(command -v zsh)" || true
fi

say "Готово. Перезайди в Hyprland: hyprctl reload (или перелогинься)"
