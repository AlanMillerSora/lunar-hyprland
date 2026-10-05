#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  install/dotfiles.sh — пользовательская часть установщика Lunar Eclipse.
#  Конфиги ~/.config, единая палитра, KDE-схема, Firefox, курсор
#  Bibata, systemd --user, ~/.zshrc, shell, GTK gsettings.
#  Подключается из install.sh (source); каждый шаг — своя функция.
# ════════════════════════════════════════════════════════════════

# ── конфиги ────────────────────────────────────────────────────
dotfiles_configs() {
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
           -not -path "*/.config/systemd/*" \
           -not -path "*/.config/chromium*" \
           -not -path "*/.config/google-chrome*" \
           -not -path "*/.config/BraveSoftware*" \
           -not -path "*/.config/vivaldi*" \
           -not -path "*/.config/mozilla*" \
           -not -path "*/.config/Code/User/globalStorage*" \
           -not -path "*/.config/Code/User/workspaceStorage*" \
           -not -path "*/.config/Code/User/History*" \
           -not -path "*/.config/Code/logs*" \
           -not -path "*/.config/Code/CachedData*" \
           -not -path "*.bak*" \
           -not -path "*/.config/kitty/lunar-theme.conf" \
           -not -path "*/.config/gtk-3.0/lunar-colors.css" \
           -not -path "*/.config/gtk-4.0/lunar-colors.css" \
           -not -path "*/.config/mako/colors.conf" \
           -not -path "*/.config/btop/themes/lunar.theme" \
           -not -path "*/.config/qt6ct/colors/lunar.conf" \
           -not -path "*/.config/yazi/theme.toml" \
           -not -path "*/.config/yazi/flavors/*" \
           -not -path "*/.config/fastfetch/config.jsonc" \
           -size -2M 2>/dev/null)

if [ -n "$LOCAL_DIFF" ]; then
  BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
  warn "в ~/.config есть локальные отличия от репо:"
  printf '%s' "$LOCAL_DIFF" | head -20 || true
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

# ротация бэкапов конфигов: держим 5 свежих
ls -1dt "$HOME"/.config-backup-* 2>/dev/null | tail -n +6 | while IFS= read -r d; do
  rm -rf -- "$d"
done || true

mkdir -p "$HOME/.config"
# аватар — пользовательские данные: install копирует .config поверх, и без
# этого дефолтный avatar.png из репо затирал мой. Прячу и возвращаю обратно.
AV_KEEP=""
if [ -f "$HOME/.config/avatars/avatar.png" ]; then
  AV_KEEP="$(mktemp --suffix=.png)" || AV_KEEP=""
  cp -f "$HOME/.config/avatars/avatar.png" "$AV_KEEP" 2>/dev/null || AV_KEEP=""
fi
cp -r "$REPO/.config/." "$HOME/.config/"
if [ -n "$AV_KEEP" ] && [ -f "$AV_KEEP" ]; then
  cp -f "$AV_KEEP" "$HOME/.config/avatars/avatar.png" 2>/dev/null || true
  rm -f -- "$AV_KEEP"
fi
chmod +x "$HOME"/.config/hypr/scripts/* 2>/dev/null || true

# ── единая палитра: цвета приложений из palette.toml ───────────
# Генератор читает ~/.config/lunar/palette.toml + шаблоны и раскладывает
# цвета в kitty/GTK/qt6ct/mako/btop/yazi и в ~/.cache/lunar/palette.json
# (его читает Theme.qml). Без python3 остаётся палитра по умолчанию.
if command -v python3 >/dev/null 2>&1; then
  if python3 "$HOME/.config/hypr/scripts/eclipse-palette.py" --apply >/dev/null 2>&1; then
    ok "палитра: цвета разложены по приложениям"
  else
    warn "палитра: генератор не отработал — останется палитра по умолчанию"
  fi
fi
ok "конфиги обновлены"

# Hyprland: сразу проверяю, что новый конфиг принят (если работаем в живой сессии)
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  hyprctl reload >/dev/null 2>&1 || true
  cfg_errs="$(hyprctl configerrors 2>/dev/null || true)"
  if [ -n "$cfg_errs" ]; then
    warn "hyprctl configerrors (проверь конфиг):"
    printf '%s\n' "$cfg_errs"
  else
    ok "Hyprland: конфиг принят без ошибок"
  fi
fi
}

# ── KDE: цветовая схема ────────────────────────────────────────
dotfiles_kde() {
step "цветовая схема KDE → ~/.local/share/color-schemes"
mkdir -p "$HOME/.local/share/color-schemes"
cp "$REPO"/color-schemes/*.colors "$HOME/.local/share/color-schemes/" 2>/dev/null || true
ok "kdeglobals + схема"
}

# ── Firefox: тема, стили и префы ───────────────────────────────
dotfiles_firefox() {
step "Firefox: тема, префы, новая вкладка"
if [ -d "$REPO/.config/firefox/chrome" ]; then
  # Firefox держит профиль либо в ~/.mozilla/firefox (классика), либо в
  # XDG-каталоге (~/.config/mozilla/firefox) — проверяем оба.
  FF_PROFS=""
  for r in "$HOME/.mozilla/firefox" "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox"; do
    [ -d "$r" ] || continue
    found="$(find "$r" -maxdepth 2 -name prefs.js -printf '%h\n' 2>/dev/null || true)"
    if [ -n "$found" ]; then FF_PROFS="$FF_PROFS$found"$'\n'; fi
  done
  FF_PROFS="$(printf '%s' "$FF_PROFS" | sed '/^$/d' | sort -u)"

  if [ -z "$FF_PROFS" ]; then
    warn "профиль ещё не создан — запусти Firefox и повтори ./install.sh"
  else
    for P in $FF_PROFS; do
      say "тема → $P"
      mkdir -p "$P/chrome"
      cp "$REPO"/.config/firefox/chrome/*.css "$P/chrome/" 2>/dev/null || true
      sed "s|__LUNAR_HOME__|file://$HOME/.config/lunar/home/firefox-home.html|g" \
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
    if [ -f "$HOME/.config/lunar/home/firefox-home.html" ]; then
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
}

# ── Firefox: иконка и браузер по умолчанию ─────────────────────
dotfiles_firefox_icon() {
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
}

# ── курсор Bibata ──────────────────────────────────────────────
dotfiles_bibata() {
step "курсор Bibata-Modern-Ice"
if [ ! -d "$HOME/.local/share/icons/Bibata-Modern-Ice" ]; then
  mkdir -p "$HOME/.local/share/icons"
  bt="$(mktemp -d)"
  if curl -fsL "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz" \
       -o "$bt/bibata.tar.xz" \
     && tar xJf "$bt/bibata.tar.xz" -C "$bt" 2>/dev/null \
     && [ -d "$bt/Bibata-Modern-Ice" ]; then
    if mv "$bt/Bibata-Modern-Ice" "$HOME/.local/share/icons/" 2>/dev/null; then
      ok "Bibata установлен"
    else
      warn "Bibata не установился — повторю при следующем запуске"
    fi
  else
    warn "Bibata не скачался (будет системный курсор)"
  fi
  rm -rf -- "$bt"
else
  ok "Bibata уже установлен"
fi
}

# ── systemd --user ─────────────────────────────────────────────
dotfiles_systemd_user() {
step "systemd --user: homepage"
if [ -d "$REPO/systemd/user" ]; then
  mkdir -p "$HOME/.config/systemd/user"
  # user-юниты лежат отдельно от системных (systemd/system/), поэтому
  # cpu-performance сюда не попадёт и раскладывать по каталогам не нужно.
  for u in "$REPO"/systemd/user/*.service; do
    cp "$u" "$HOME/.config/systemd/user/"
  done
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now lunar-homepage.service 2>/dev/null || true
  # quickshell НЕ включаем в автозапуск: его стартует hyprland.lua после
  # композитора (иначе юнит поднимется раньше Wayland и будет падать).
  systemctl --user disable lunar-quickshell.service 2>/dev/null || true
  ok "юниты поставлены (quickshell стартует из Hyprland)"
fi
}

# ── shell по умолчанию ─────────────────────────────────────────
dotfiles_shell() {
step "shell по умолчанию"
# zsh читает конфиг из ~/.zshrc (ZDOTDIR не задаём), а в репо он лежит
# в .config/.zshrc — кладём копию в домашний каталог, иначе шелл стартует голым
if [ -f "$REPO/.config/.zshrc" ]; then
  # ~/.zshrc вне ~/.config, общий бэкап его не видит — сохраняем сами
  if [ -f "$HOME/.zshrc" ] && ! cmp -s "$HOME/.zshrc" "$REPO/.config/.zshrc"; then
    BACKUP="${BACKUP:-$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)}"
    mkdir -p "$BACKUP/home"
    cp -a "$HOME/.zshrc" "$BACKUP/home/.zshrc" 2>/dev/null || true
    say "бэкап ~/.zshrc → $BACKUP/home/.zshrc"
  fi
  cp "$REPO/.config/.zshrc" "$HOME/.zshrc"
  ok "~/.zshrc обновлён"
fi
ZSH_BIN="$(command -v zsh 2>/dev/null || true)"
SHELL_TARGET="${SUDO_USER:-$USER}"
if [ -z "$ZSH_BIN" ]; then
  ok "zsh не установлен — пропускаю"
elif [ "$(id -u)" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
  warn "запуск от root без SUDO_USER — shell не меняю; вручную: chsh -s $ZSH_BIN <пользователь>"
elif [ "$(getent passwd "$SHELL_TARGET" | cut -d: -f7)" = "$ZSH_BIN" ]; then
  ok "zsh уже у $SHELL_TARGET"
elif [ ! -t 0 ]; then
  warn "нет tty — shell не меняю; вручную: sudo chsh -s $ZSH_BIN $SHELL_TARGET"
else
  chsh -s "$ZSH_BIN" "$SHELL_TARGET" && ok "zsh у $SHELL_TARGET" || warn "не удалось сменить shell"
fi
}

# ── GTK: тема, иконки, шрифт через gsettings ───────────────────
# GTK3 под Wayland берёт настройки из gsettings, а не из
# ~/.config/gtk-3.0/settings.ini — поэтому дублируем важное здесь.
dotfiles_gtk() {
step "GTK: тёмная тема, иконки, шрифт"
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface font-name 'Roboto Mono 11' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface monospace-font-name 'Roboto Mono 11' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
  # иконки: обычная (цветная) Tela; монохром Tela-lunar больше не собираю.
  # Кастомную иконку Firefox (lunar-eclipse в hicolor) это не трогает.
  gsettings set org.gnome.desktop.interface icon-theme 'Tela-dark' 2>/dev/null || true
  ok "gsettings: prefer-dark, шрифт, курсор, иконки Tela"
else
  warn "gsettings не найден — GTK-настройки пропущены"
fi
}
