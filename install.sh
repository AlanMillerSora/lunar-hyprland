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
