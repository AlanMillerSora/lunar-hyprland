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

# ── сайт-превью (генератор обоев под любое разрешение) ─────────
say "Превью-сайт → ~/.config/lunar/sait"
mkdir -p "$HOME/.config/lunar/sait"
cp "$REPO"/sait/* "$HOME/.config/lunar/sait/" 2>/dev/null || true

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

      # New Tab Override: новая вкладка = наша страница (URL задаётся
      # через managed-storage ниже; тут только ставим само расширение)
      if [ ! -f "$P/extensions/newtaboverride@agenedia.com.xpi" ]; then
        mkdir -p "$P/extensions"
        curl -sL -o "$P/extensions/newtaboverride@agenedia.com.xpi" \
          "https://addons.mozilla.org/firefox/downloads/latest/new-tab-override/latest.xpi" \
          2>/dev/null || say "New Tab Override не скачался (не критично)"
      fi
    done

    # настройка расширения: новая вкладка = наша страница.
    # Формат native-manifest: {name, type:"storage", data:{…}};
    # путь для пользователя — ~/.mozilla/managed-storage/<id>.json
    if [ -f "$HOME/.config/lunar/firefox-home.html" ]; then
      mkdir -p "$HOME/.mozilla/managed-storage"
      cat > "$HOME/.mozilla/managed-storage/newtaboverride@agenedia.com.json" <<JSON
{
  "name": "newtaboverride@agenedia.com",
  "description": "Lunar Eclipse — новая вкладка",
  "type": "storage",
  "data": {
    "type": "custom_url",
    "url": "http://127.0.0.1:8787/firefox-home.html",
    "focus_website": true,
    "background_color": "#050505"
  }
}
JSON
      say "Firefox: новая вкладка → lunar (managed storage)"
    fi
  fi
fi

# ── Firefox: иконка приложения (наш logo) ──────────────────────
if command -v rsvg-convert >/dev/null 2>&1 && [ -f "$REPO/assets/lunar-icon.svg" ]; then
  say "Иконка приложений → ~/.local/share/icons (lunar-eclipse)"
  for s in 512 256 128 64 48 32; do
    d="$HOME/.local/share/icons/hicolor/${s}x${s}/apps"
    mkdir -p "$d"
    rsvg-convert -w "$s" -h "$s" -o "$d/lunar-eclipse.png" "$REPO/assets/lunar-icon.svg" 2>/dev/null || true
  done
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi
# desktop-файл Firefox с нашей иконкой (перекрывает системный)
if [ -f /usr/share/applications/firefox.desktop ]; then
  mkdir -p "$HOME/.local/share/applications"
  sed 's|^Icon=firefox$|Icon=lunar-eclipse|' /usr/share/applications/firefox.desktop \
    > "$HOME/.local/share/applications/firefox.desktop"
fi

# ── Firefox: браузер по умолчанию ──────────────────────────────
if command -v xdg-settings >/dev/null 2>&1; then
  xdg-settings set default-web-browser firefox.desktop 2>/dev/null \
    && say "Firefox: браузер по умолчанию" \
    || say "Firefox: не удалось назначить браузером по умолчанию (не критично)"
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

# ── zapret: обход DPI (Discord / YouTube) ──────────────────────
# Ставит оригинальный zapret (bol-van) в /opt/zapret и поднимает
# systemd-юнит zapret.service. Идемпотентно: повторный запуск не ломает.
if [ -x "$REPO/zapret/install-zapret.sh" ]; then
  say "zapret → /opt/zapret (обход DPI: Discord/YouTube)"
  "$REPO/zapret/install-zapret.sh" install || say "zapret не установился — см. вывод выше"
fi

# ── systemd --user (wifi-guard, локальная страница Firefox) ────
if [ -d "$REPO/systemd" ]; then
  say "systemd --user → lunar-wifi-guard, lunar-homepage, lunar-quickshell"
  mkdir -p "$HOME/.config/systemd/user"
  cp "$REPO"/systemd/*.service "$HOME/.config/systemd/user/"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now lunar-wifi-guard.service 2>/dev/null || true
  systemctl --user enable --now lunar-homepage.service 2>/dev/null || true
  # quickshell НЕ включаем в автозапуск: его стартует hyprland.lua после
  # композитора (иначе юнит поднимется раньше Wayland и будет падать).
  systemctl --user disable lunar-quickshell.service 2>/dev/null || true
fi

# ── i2c-dev: внешние мониторы через ddcutil (яркость DDC/CI) ───
# Нужно только там, где есть внешний монитор; на ноуте безвредно.
# Ставим модуль в автозагрузку и добавляем пользователя в группу i2c,
# иначе ddcutil не видит шину (см. README → «Яркость»).
if command -v ddcutil >/dev/null 2>&1; then
  if [ ! -f /etc/modules-load.d/i2c-dev.conf ]; then
    say "i2c-dev → автозагрузка модуля"
    printf 'i2c-dev\n' | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null 2>&1 || true
  fi
  sudo modprobe i2c-dev 2>/dev/null || true
  if ! id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx i2c; then
    say "i2c: пользователь → группа i2c (нужен перелогин)"
    sudo usermod -aG i2c "$USER" 2>/dev/null || true
  fi
fi

# ── shell по умолчанию ─────────────────────────────────────────
if command -v zsh >/dev/null 2>&1 && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  say "zsh как шелл по умолчанию"
  chsh -s "$(command -v zsh)" || true
fi

say "Готово. Перезайди в Hyprland: hyprctl reload (или перелогинься)"
