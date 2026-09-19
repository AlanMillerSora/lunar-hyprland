#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Lunar Eclipse rice — установщик
#  Копирует конфиги в ~/.config, обои в ~/Pictures/EclipseWalls,
#  скрипт в ~/.local/bin, подставляет пути в hyprlock.conf.
#
#  Запуск:  ./install.sh
# ════════════════════════════════════════════════════════════
set -euo pipefail

DOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HOME/.config"
WALL="$HOME/Pictures/EclipseWalls"
BIN="$HOME/.local/bin"

mkdir -p "$CONF"/{hypr/scripts,waybar,wofi,kitty,mako,hyprlock,fastfetch,lunar}
mkdir -p "$WALL" "$BIN" "$HOME/.local/share/color-schemes"

echo "== Lunar Eclipse rice: установка конфигов =="

cp -r "$DOTDIR/wallpapers/." "$WALL/"

# Живые обои: animated GIF из фаз (нужны rsvg-convert + ffmpeg).
# ECLIPSE_ANIM=0 — пропустить, останутся статичные PNG.
# ECLIPSE_VIDEO=1 — видео 60fps для mpvpaper (нужен mpvpaper).
# ECLIPSE_LIVE=1  — видео СНЯТЬ с живой CSS-сцены сайта (вид 1-в-1, нужен chromium).
if [ "${ECLIPSE_ANIM:-1}" = "1" ] && command -v ffmpeg >/dev/null 2>&1; then
  if [ "${ECLIPSE_VIDEO:-0}" = "1" ]; then
    if [ "${ECLIPSE_LIVE:-0}" = "1" ] && command -v chromium >/dev/null 2>&1; then
      echo "== Живые обои 1-в-1 с сайтом (съёмка CSS через chromium) — ~15 минут =="
      if "$DOTDIR/hypr/scripts/eclipse-live-gen.py" --out "$WALL" \
           --jobs "$(nproc 2>/dev/null || echo 4)"; then
        echo "   видео готово: $WALL/eclipse_01..08.webm (вид как на сайте)"
      else
        echo "   генерация не удалась — eclipse-walls.sh возьмёт GIF/PNG"
      fi
    elif command -v rsvg-convert >/dev/null 2>&1; then
      echo "== Генерация живых обоев (видео 60fps для mpvpaper) — ~15 минут =="
      if "$DOTDIR/hypr/scripts/eclipse-anim-gen.py" --out "$WALL" \
           --jobs "$(nproc 2>/dev/null || echo 4)" --fps 60 --no-gif --video; then
        echo "   видео готово: $WALL/eclipse_01..08.webm"
      else
        echo "   генерация не удалась — eclipse-walls.sh возьмёт GIF/PNG"
      fi
    else
      echo "   chromium/rsvg-convert не найдены — видео пропущено (останутся PNG)"
    fi
  elif command -v rsvg-convert >/dev/null 2>&1; then
    echo "== Генерация живых обоев (animated GIF, ~5s петля) — пара минут =="
    if "$DOTDIR/hypr/scripts/eclipse-anim-gen.py" --out "$WALL" --jobs "$(nproc 2>/dev/null || echo 4)"; then
      echo "   живые обои готовы: $WALL/eclipse_01..08.gif"
    else
      echo "   генерация не удалась — eclipse-walls.sh возьмёт статичные PNG"
    fi
  else
    echo "   rsvg-convert не найден — живые обои пропущены (останутся PNG)"
  fi
elif [ "${ECLIPSE_ANIM:-1}" = "1" ]; then
  echo "   ffmpeg не найден — живые обои пропущены (останутся PNG)"
fi

cp "$DOTDIR/hypr/hyprland.lua" "$CONF/hypr/"
cp "$DOTDIR/hypr/scripts/eclipse-walls.sh" "$CONF/hypr/scripts/"
cp "$DOTDIR/hypr/scripts/eclipse-walls.sh" "$BIN/"
chmod +x "$CONF/hypr/scripts/eclipse-walls.sh"
chmod +x "$BIN/eclipse-walls.sh"
cp "$DOTDIR/hypr/scripts/eclipse-anim-gen.py" "$CONF/hypr/scripts/"
cp "$DOTDIR/hypr/scripts/eclipse-anim-gen.py" "$BIN/"
cp "$DOTDIR/hypr/scripts/eclipse-live-gen.py" "$CONF/hypr/scripts/"
cp "$DOTDIR/hypr/scripts/eclipse-live-gen.py" "$BIN/"
chmod +x "$CONF/hypr/scripts/eclipse-anim-gen.py"
chmod +x "$BIN/eclipse-anim-gen.py"
chmod +x "$CONF/hypr/scripts/eclipse-live-gen.py"
chmod +x "$BIN/eclipse-live-gen.py"

# Панель-попапы: Wi-Fi меню, календарь, шпаргалка хоткеев, ввод пароля
for s in eclipse-network.sh eclipse-calendar.py eclipse-cheatsheet.py eclipse-askpass.py; do
  cp "$DOTDIR/hypr/scripts/$s" "$CONF/hypr/scripts/"
  chmod +x "$CONF/hypr/scripts/$s"
done

# Прозрачность окон (ползунок лаунчера) и сторож Wi-Fi
cp "$DOTDIR/hypr/scripts/eclipse-transparency.sh" "$CONF/hypr/scripts/"
chmod +x "$CONF/hypr/scripts/eclipse-transparency.sh"
cp "$DOTDIR/hypr/scripts/eclipse-wifi-guard.py" "$BIN/"
chmod +x "$BIN/eclipse-wifi-guard.py"
mkdir -p "$HOME/.config/systemd/user"
cp "$DOTDIR/systemd/lunar-wifi-guard.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user enable --now lunar-wifi-guard.service >/dev/null 2>&1 || true

# Lunar Launcher: сервер + веб-интерфейс + скрипт управления
LAUNCHER="$HOME/.local/share/lunar-launcher"
mkdir -p "$LAUNCHER"
cp -r "$DOTDIR/lunar-launcher/server.py" "$LAUNCHER/"
cp -r "$DOTDIR/lunar-launcher/web/." "$LAUNCHER/web/"
cp "$DOTDIR/lunar-launcher/lunar-launcher.sh" "$BIN/"
chmod +x "$BIN/lunar-launcher.sh"

# Зачистка от старых раскладок: с 0.55 конфиг — hyprland.lua,
# а hypridle.conf лежит в hypr/, а не в hypridle/
rm -f "$CONF/hypr/hyprland.conf"
rm -f "$CONF/hypridle/hypridle.conf"

cp "$DOTDIR/waybar/config.jsonc" "$DOTDIR/waybar/style.css" "$CONF/waybar/"
cp "$DOTDIR/wofi/config" "$DOTDIR/wofi/style.css" "$CONF/wofi/"
cp "$DOTDIR/kitty/kitty.conf" "$CONF/kitty/"
cp "$DOTDIR/mako/config" "$CONF/mako/"
cp "$DOTDIR/fastfetch/config.jsonc" "$DOTDIR/fastfetch/eclipse.png" "$CONF/fastfetch/"
cp "$DOTDIR/kde/kdeglobals" "$DOTDIR/kde/dolphinrc" "$CONF/"
cp "$DOTDIR/kde/color-schemes/LunarEclipse.colors" "$HOME/.local/share/color-schemes/"
cp "$DOTDIR/shell/lunar.bash" "$CONF/lunar/lunar.bash"

# Интерактивная оболочка (fastfetch + PS1): подключаем из ~/.bashrc
LUNAR_LINE='[ -f ~/.config/lunar/lunar.bash ] && . ~/.config/lunar/lunar.bash'
if [ -f "$HOME/.bashrc" ]; then
  grep -qF "$LUNAR_LINE" "$HOME/.bashrc" || printf '\n%s\n' "$LUNAR_LINE" >> "$HOME/.bashrc"
else
  printf '%s\n' "$LUNAR_LINE" > "$HOME/.bashrc"
fi

# hypridle 0.1.8 ищет конфиг в ~/.config/hypr/, а не в ~/.config/hypridle/!
cp "$DOTDIR/hypridle/hypridle.conf" "$CONF/hypr/hypridle.conf"

sed "s|{ECLIPSE_DIR}|$WALL|g" "$DOTDIR/hyprlock/hyprlock.conf" > "$CONF/hyprlock/hyprlock.conf"

echo
echo "Готово."
echo "  1. Проверка конфига:  hyprctl configerrors"
echo "  2. Перезапуск:        hyprctl reload"
echo "  3. Путь до демона:    awww-daemon запустится сам при входе"