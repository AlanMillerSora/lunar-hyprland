#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  install/system.sh — системная часть установщика Lunar Eclipse (root).
#  Root-хелперы, sudoers агента, CPU-performance (system-юниты),
#  cronie, iwd (conf + service), Telegram-прокси (tgproxy.env).
#  Подключается из install.sh (source); каждый шаг — своя функция.
# ════════════════════════════════════════════════════════════════

# ── cronie: расписания (timeshift и т.п.) ──────────────────────
# Пакет ставит get-deps, но включить его должен установщик — иначе снимки
# timeshift по расписанию не создаются.
system_cronie() {
step "cronie: демон расписаний"
if systemctl list-unit-files cronie.service >/dev/null 2>&1; then
  sudo systemctl enable --now cronie.service 2>/dev/null \
    && ok "cronie включён" \
    || warn "cronie не включился (нужен sudo)"
else
  say "cronie не установлен — пропускаю"
fi
}

# ── CPU: всегда performance, без power-profiles-daemon ─────────
# power-profiles-daemon запускается по D-Bus и умеет только balanced/
# power-saver, а на Ryzen «balanced» = governor powersave (просадки).
# Поэтому глушим его навсегда, а CPU держим на performance своим юнитом.
system_cpu_performance() {
step "CPU: performance вместо power-profiles-daemon"
if [ -f "$REPO/systemd/libexec/lunar-cpu-performance.sh" ]; then
  sudo install -d -m 0755 -o root -g root /usr/local/lib/lunar 2>/dev/null \
    && sudo install -m 0755 -o root -g root \
         "$REPO/systemd/libexec/lunar-cpu-performance.sh" \
         /usr/local/lib/lunar/cpu-performance.sh 2>/dev/null \
    && ok "хелпер: /usr/local/lib/lunar/cpu-performance.sh" \
    || warn "хелпер cpu-performance не установлен (нужен sudo)"
fi
for u in lunar-cpu-performance.service lunar-cpu-performance-resume.service; do
  [ -f "$REPO/systemd/system/$u" ] && sudo install -m 0644 -o root -g root \
    "$REPO/systemd/system/$u" "/etc/systemd/system/$u" 2>/dev/null || true
done
sudo systemctl daemon-reload 2>/dev/null || true
sudo systemctl enable --now lunar-cpu-performance.service 2>/dev/null \
  && ok "CPU: governor performance (юнит включён)" \
  || warn "lunar-cpu-performance.service не включился (нужен sudo)"
sudo systemctl enable lunar-cpu-performance-resume.service 2>/dev/null \
  && ok "CPU: performance после сна (resume-юнит)" \
  || warn "lunar-cpu-performance-resume.service не включился (нужен sudo)"
# power-profiles-daemon умеет только balanced/powersave (а на Ryzen
# balanced = powersave): глушим и маскируем безусловно. mask работает
# и для отсутствующего юнита — заглушка не даст демону подняться позже.
sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
sudo systemctl mask power-profiles-daemon.service 2>/dev/null \
  && ok "power-profiles-daemon замаскирован (powersave не вернётся)" \
  || warn "power-profiles-daemon не замаскирован (нужен sudo)"
}

# ── Wi-Fi: iwd (ассоциация) + systemd-networkd (IP) ────────────
# NetworkManager не используем. Ассоциирует iwd; адреса раздаёт
# systemd-networkd. EnableNetworkConfiguration=false — чтобы iwd не лез
# за IP сам (сеть — networkd), PowerSaveDisable=ath12k* — не душим мой
# Qualcomm WCN785x энергосбережением.
system_iwd() {
step "Wi-Fi: iwd"
if [ -f "$REPO/systemd/conf/iwd-main.conf" ]; then
  sudo install -Dm644 "$REPO/systemd/conf/iwd-main.conf" /etc/iwd/main.conf 2>/dev/null \
    && ok "iwd: /etc/iwd/main.conf" \
    || warn "iwd-main.conf не установлен (нужен sudo)"
fi
sudo systemctl enable --now iwd.service 2>/dev/null \
  && ok "iwd включён и запущен" \
  || warn "iwd.service не включился (нужен sudo)"
}

# ── Telegram: локальный MTProto-прокси (tg-ws-proxy) ───────────
# Пакет из AUR, headless, живёт как systemd --user-юнит (sudo не нужен).
# Секрет генерим один раз и держим в env-файле вне репо.
system_tgproxy() {
step "tg-ws-proxy: прокси для Telegram"
if command -v tg-ws-proxy >/dev/null 2>&1; then
  ok "tg-ws-proxy установлен"
elif command -v yay >/dev/null 2>&1; then
  yay -S --needed --noconfirm tg-ws-proxy-cli >/dev/null 2>&1 \
    && ok "tg-ws-proxy-cli установлен" \
    || warn "tg-ws-proxy-cli не поставился (вручную: yay -S tg-ws-proxy-cli)"
elif command -v paru >/dev/null 2>&1; then
  paru -S --needed --noconfirm tg-ws-proxy-cli >/dev/null 2>&1 \
    && ok "tg-ws-proxy-cli установлен" \
    || warn "tg-ws-proxy-cli не поставился (вручную: paru -S tg-ws-proxy-cli)"
else
  warn "нет AUR-помощника — tg-ws-proxy пропущен (yay -S tg-ws-proxy-cli)"
fi

if command -v tg-ws-proxy >/dev/null 2>&1 && [ -f "$REPO/systemd/user/lunar-tgproxy.service" ]; then
  mkdir -p "$HOME/.config/lunar" "$HOME/.cache/lunar" "$HOME/.config/systemd/user"
  TGE="$HOME/.config/lunar/tgproxy.env"
  if [ ! -f "$TGE" ]; then
    sec="$(command -v openssl >/dev/null 2>&1 && openssl rand -hex 16 \
           || head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    printf 'TGWSP_PORT=1443\nTGWSP_SECRET=%s\n' "$sec" > "$TGE"
    chmod 600 "$TGE"
    ok "прокси Telegram: секрет сгенерирован"
  fi
  cp "$REPO/systemd/user/lunar-tgproxy.service" "$HOME/.config/systemd/user/"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now lunar-tgproxy.service 2>/dev/null \
    && ok "прокси Telegram включён и в автозапуске" \
    || warn "не удалось включить lunar-tgproxy.service"
fi
}

# ── sudo: белый список агента (OpenCode) + root-хелперы ────────
system_sudoers() {
step "sudo: белый список агента → /etc/sudoers.d/lunar-agent"
if [ -d "$REPO/systemd/libexec" ]; then
  for h in lunar-avatar-sync.sh lunar-journal-read.sh lunar-journal-vacuum.sh \
           lunar-svc.sh lunar-update.sh; do
    [ -f "$REPO/systemd/libexec/$h" ] || continue
    sudo install -d -m 0755 -o root -g root /usr/local/lib/lunar 2>/dev/null \
      && sudo install -m 0755 -o root -g root \
           "$REPO/systemd/libexec/$h" "/usr/local/lib/lunar/${h#lunar-}" 2>/dev/null \
      && ok "root-хелпер: /usr/local/lib/lunar/${h#lunar-}" \
      || warn "root-хелпер $h не установлен (нужен sudo)"
  done
fi
AGENT_USER="${SUDO_USER:-$(id -un)}"
if [ -f "$REPO/systemd/sudoers/lunar-agent.sudoers" ]; then
  if [[ ! "$AGENT_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    warn "sudoers агента: некорректное имя пользователя — пропускаю"
  else
    # В шаблоне имя прибито к sora — подставляем текущего пользователя,
    # иначе правило уйдёт несуществующему логину, и sudo -n молча вернёт 1.
    agent_tmp="$(mktemp)"
    sed "s/^sora /$AGENT_USER /" "$REPO/systemd/sudoers/lunar-agent.sudoers" > "$agent_tmp"
    if sudo visudo -cf "$agent_tmp" >/dev/null 2>&1; then
      sudo install -m 0440 -o root -g root \
        "$agent_tmp" /etc/sudoers.d/lunar-agent 2>/dev/null \
        && ok "sudoers.d/lunar-agent ($AGENT_USER)" \
        || warn "sudoers не установлен (нужен sudo)"
    else
      warn "sudoers не прошёл visudo -cf — оставляю прежний"
    fi
    rm -f "$agent_tmp"
  fi
fi

# Старое широкое правило zapret (голый systemctl) больше не нужно:
# теперь zapret ходит через /usr/local/lib/lunar/svc.sh (allowlist юнитов).
# Убираю файл, если он остался с прошлых установок, — иначе привилегия
# жила бы поверх нового, узкого списка.
if [ -f /etc/sudoers.d/lunar-zapret ]; then
  sudo rm -f /etc/sudoers.d/lunar-zapret 2>/dev/null \
    && ok "убрал устаревшее правило /etc/sudoers.d/lunar-zapret" \
    || warn "не удалось убрать /etc/sudoers.d/lunar-zapret (нужен sudo)"
fi
}
