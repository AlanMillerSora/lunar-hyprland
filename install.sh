#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — единая установка.
#
#  1) зависимости (get-deps.sh): pacman + AUR (VS Code, Vencord);
#  2) конфиги .config/* → ~/.config, обои, цвета KDE, Firefox;
#  3) systemd --user, ddcutil (i2c), Wi-Fi (powersave/ASPM), sudoers, zsh.
#
#  Запуск:  ./install.sh [--no-deps] [--deps-only]
#    без флагов   — всё: зависимости + конфиги
#    --no-deps    — только конфиги (зависимости уже стоят)
#    --deps-only  — только зависимости
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
for a in "$@"; do
  case "$a" in
    --no-deps)   WITH_DEPS=0 ;;
    --deps-only) DEPS_ONLY=1 ;;
    -h|--help)   sed -n '2,18p' "$0"; exit 0 ;;
    *) printf 'usage: %s [--no-deps|--deps-only]\n' "$0" >&2; exit 1 ;;
  esac
done

LUNAR_TOTAL=14
[ "$WITH_DEPS" = 1 ] || LUNAR_TOTAL=13

lunar_banner

# ── 1. зависимости ─────────────────────────────────────────────
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

# ── 2. конфиги ─────────────────────────────────────────────────
step "конфиги → ~/.config"

# Безопасный повторный запуск: если в ~/.config есть файлы, которых нет в
# репо (или которые отличаются), — не затираем молча. Показываем список и
# делаем бэкап этих файлов в ~/.config-backup-<дата>/ перед копированием.
LOCAL_DIFF=""
while IFS= read -r f; do
  rel="${f#"$HOME"/.config/}"
  if [ ! -e "$REPO/.config/$rel" ]; then
    LOCAL_DIFF="${LOCAL_DIFF}${rel} (нет в репо)"$'\n'
  elif ! cmp -s "$f" "$REPO/.config/$rel"; then
    LOCAL_DIFF="${LOCAL_DIFF}${rel} (изменён локально)"$'\n'
  fi
done < <(find "$HOME/.config" -type f \
           -not -path "*/.config/lunar/sait/*" \
           -not -path "*/.config/systemd/*" 2>/dev/null)

if [ -n "$LOCAL_DIFF" ]; then
  BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
  warn "в ~/.config есть локальные отличия от репо:"
  printf '%s' "$LOCAL_DIFF" | head -20
  say "бэкап этих файлов → $BACKUP"
  mkdir -p "$BACKUP"
  printf '%s' "$LOCAL_DIFF" | sed 's/ (.*//' | while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -e "$HOME/.config/$rel" ] || continue
    mkdir -p "$BACKUP/$(dirname "$rel")"
    cp -a "$HOME/.config/$rel" "$BACKUP/$rel" 2>/dev/null || true
  done
  say "продолжаю: конфиги будут перезаписаны из репо (бэкап сохранён)"
fi

mkdir -p "$HOME/.config"
cp -r "$REPO/.config/." "$HOME/.config/"
chmod +x "$HOME"/.config/hypr/scripts/* 2>/dev/null || true
ok "конфиги обновлены"

# ── 3. сайт-превью (генератор обоев под любое разрешение) ───────
step "превью-сайт → ~/.config/lunar/sait"
mkdir -p "$HOME/.config/lunar/sait"
cp "$REPO"/sait/* "$HOME/.config/lunar/sait/" 2>/dev/null || true
ok "sait скопирован"

# ── 4. обои ────────────────────────────────────────────────────
step "обои → ~/Pictures/EclipseWalls"
mkdir -p "$HOME/Pictures/EclipseWalls"
cp "$REPO"/wallpapers/*.png "$HOME/Pictures/EclipseWalls/" 2>/dev/null || true
ok "обои на месте"

# ── 5. KDE: цветовая схема ─────────────────────────────────────
step "цветовая схема KDE → ~/.local/share/color-schemes"
mkdir -p "$HOME/.local/share/color-schemes"
cp "$REPO"/color-schemes/*.colors "$HOME/.local/share/color-schemes/" 2>/dev/null || true
ok "kdeglobals + схема"

# ── 6. Firefox: тема, стили и префы ────────────────────────────
step "Firefox: тема, префы, новая вкладка"
if [ -d "$REPO/.config/firefox/chrome" ]; then
  FF_ROOT="$HOME/.mozilla/firefox"
  FF_PROFS="$(find "$FF_ROOT" -maxdepth 2 -name prefs.js -printf '%h\n' 2>/dev/null || true)"

  if [ -z "$FF_PROFS" ]; then
    warn "профиль ещё не создан — запусти Firefox и повтори ./install.sh"
  else
    for P in $FF_PROFS; do
      say "тема → $P"
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
          2>/dev/null || warn "New Tab Override не скачался (не критично)"
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
      ok "новая вкладка → lunar (managed storage)"
    fi
  fi
fi

# ── 7. Firefox: иконка и браузер по умолчанию ──────────────────
step "Firefox: иконка приложения и браузер по умолчанию"
if command -v rsvg-convert >/dev/null 2>&1 && [ -f "$REPO/assets/lunar-icon.svg" ]; then
  for s in 512 256 128 64 48 32; do
    d="$HOME/.local/share/icons/hicolor/${s}x${s}/apps"
    mkdir -p "$d"
    rsvg-convert -w "$s" -h "$s" -o "$d/lunar-eclipse.png" "$REPO/assets/lunar-icon.svg" 2>/dev/null || true
  done
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
  ok "иконка lunar-eclipse"
fi
if [ -f /usr/share/applications/firefox.desktop ]; then
  mkdir -p "$HOME/.local/share/applications"
  sed 's|^Icon=firefox$|Icon=lunar-eclipse|' /usr/share/applications/firefox.desktop \
    > "$HOME/.local/share/applications/firefox.desktop"
  ok "desktop-файл Firefox"
fi
if command -v xdg-settings >/dev/null 2>&1; then
  xdg-settings set default-web-browser firefox.desktop 2>/dev/null \
    && ok "Firefox — браузер по умолчанию" \
    || warn "не удалось назначить браузером по умолчанию (не критично)"
fi

# ── 8. курсор Bibata ───────────────────────────────────────────
step "курсор Bibata-Modern-Ice"
if [ ! -d "$HOME/.local/share/icons/Bibata-Modern-Ice" ]; then
  mkdir -p "$HOME/.local/share/icons"
  curl -sL "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz" \
    | tar xJ -C "$HOME/.local/share/icons/" 2>/dev/null \
    && ok "Bibata установлен" \
    || warn "Bibata не скачался (будет системный курсор)"
else
  ok "Bibata уже установлен"
fi

# ── 9. zapret ──────────────────────────────────────────────────
step "zapret → /opt/zapret (обход DPI: Discord/YouTube)"
if [ -x "$REPO/zapret/install-zapret.sh" ]; then
  "$REPO/zapret/install-zapret.sh" install && ok "zapret.service" \
    || warn "zapret не установился — см. вывод выше"
else
  say "установщик zapret не найден (не критично)"
fi

# ── 10. systemd --user ─────────────────────────────────────────
step "systemd --user: wifi-guard, homepage"
if [ -d "$REPO/systemd" ]; then
  mkdir -p "$HOME/.config/systemd/user"
  cp "$REPO"/systemd/*.service "$HOME/.config/systemd/user/"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now lunar-wifi-guard.service 2>/dev/null || true
  systemctl --user enable --now lunar-homepage.service 2>/dev/null || true
  # quickshell НЕ включаем в автозапуск: его стартует hyprland.lua после
  # композитора (иначе юнит поднимется раньше Wayland и будет падать).
  systemctl --user disable lunar-quickshell.service 2>/dev/null || true
  ok "юниты поставлены (quickshell стартует из Hyprland)"
fi

# ── 11. i2c-dev: внешние мониторы через ddcutil ────────────────
step "i2c-dev → /etc/modules-load.d (ddcutil, яркость DDC/CI)"
if command -v ddcutil >/dev/null 2>&1; then
  if [ ! -f /etc/modules-load.d/i2c-dev.conf ]; then
    printf 'i2c-dev\n' | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null 2>&1 || true
    ok "модуль i2c-dev в автозагрузке"
  else
    ok "i2c-dev уже в автозагрузке"
  fi
  sudo modprobe i2c-dev 2>/dev/null || true
  if ! id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx i2c; then
    sudo usermod -aG i2c "$USER" 2>/dev/null || true
    warn "пользователь добавлен в группу i2c (нужен перелогин)"
  else
    ok "группа i2c уже есть"
  fi
else
  say "ddcutil нет — шаг пропущен"
fi

# ── 12. Wi-Fi: powersave off + ASPM ────────────────────────────
step "Wi-Fi: powersave off + mt7921e ASPM"
if [ -f "$REPO/systemd/10-lunar-wifi-powersave-off.sh" ]; then
  sudo install -m 0755 -o root -g root \
    "$REPO/systemd/10-lunar-wifi-powersave-off.sh" \
    /etc/NetworkManager/dispatcher.d/10-lunar-wifi-powersave-off.sh 2>/dev/null \
    && ok "dispatcher: powersave выключен навсегда" \
    || warn "dispatcher не установлен (нужен sudo)"
fi
if [ -f "$REPO/systemd/mt7921e-no-aspm.conf" ]; then
  sudo install -m 0644 -o root -g root \
    "$REPO/systemd/mt7921e-no-aspm.conf" \
    /etc/modprobe.d/mt7921e-no-aspm.conf 2>/dev/null \
    && ok "mt7921e: disable_aspm=1" \
    || warn "modprobe-конфиг не установлен (нужен sudo)"
fi

# ── 13. sudo: белый список агента (OpenCode) ───────────────────
step "sudo: белый список агента → /etc/sudoers.d/lunar-agent"
if [ -f "$REPO/systemd/lunar-agent.sudoers" ]; then
  sudo install -m 0440 -o root -g root \
    "$REPO/systemd/lunar-agent.sudoers" /etc/sudoers.d/lunar-agent 2>/dev/null \
    && ok "sudoers.d/lunar-agent" \
    || warn "sudoers не установлен (нужен sudo)"
fi

# ── 14. shell по умолчанию ─────────────────────────────────────
step "shell по умолчанию"
if command -v zsh >/dev/null 2>&1 && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)" && ok "zsh" || warn "не удалось сменить shell"
else
  ok "zsh уже (или не установлен)"
fi

lunar_done
