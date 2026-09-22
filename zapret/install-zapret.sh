#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — zapret (обход DPI: Discord / YouTube)
#
#  Ставит и настраивает оригинальный zapret (bol-van) из исходников
#  в /opt/zapret: сборка nfqws, конфиг, хостлист, systemd-юнит.
#  Управление в рантайме — ~/.config/hypr/scripts/eclipse-zapret.sh
#
#  Использование:
#    install-zapret.sh          # установить/доустановить (идемпотентно)
#    install-zapret.sh update   # обновить из git и пересобрать
#    install-zapret.sh status   # показать состояние
#
#  Обновления: это обычный git-клон апстрима. config и ipset/ лежат
#  в .gitignore, поэтому «update» их не трогает — правки не теряются.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ZDIR=/opt/zapret
UNIT=zapret.service
SUDOERS=/etc/sudoers.d/lunar-zapret
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"
MODE="${1:-install}"

say() { printf '\033[38;5;15m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[38;5;9m!!\033[0m %s\n' "$*"; }

have_bin() { [ -x "$ZDIR/nfq/nfqws" ] || [ -x "$ZDIR/binaries/my/nfqws" ]; }

# ── зависимости сборки и работы ────────────────────────────────
install_deps() {
  say "zapret: зависимости (gcc/make, netfilter, nftables)"
  sudo pacman -S --needed --noconfirm \
    gcc make zlib libcap libnetfilter_queue libmnl systemd-libs \
    nftables curl
}

# ── исходники ──────────────────────────────────────────────────
get_sources() {
  if [ -d "$ZDIR/.git" ]; then
    say "zapret: git pull — ${ZDIR}"
    sudo git -C "$ZDIR" pull --ff-only || warn "pull не удался, оставляю текущую версию"
  else
    say "zapret: клонирую bol-van/zapret → ${ZDIR}"
    sudo mkdir -p "$ZDIR"
    sudo git clone --depth=1 https://github.com/bol-van/zapret.git "$ZDIR"
  fi
}

# ── сборка nfqws/tpws ──────────────────────────────────────────
build() {
  say "zapret: сборка (make systemd -j$(nproc))"
  sudo make -C "$ZDIR" systemd -j"$(nproc)"
}

# ── fake-пакеты ────────────────────────────────────────────────
# Небольшие payload'ы для nfqws --dpi-desync-fake-*. ACTIVE_DISCORD_UDP.bin —
# реальный медиапакет Discord: важен именно он, IP-discovery пакет заставляет
# сервер ответить чужим SSRC и голос падает в NO_ROUTE («не установлен маршрут»).
install_fake_files() {
  [ -d "$HERE/files/fake" ] || return 0
  say "zapret: fake-пакеты → ${ZDIR}/files/fake"
  sudo mkdir -p "$ZDIR/files/fake"
  sudo install -m 0644 "$HERE"/files/fake/*.bin "$ZDIR/files/fake/"
}

# ── конфиг ─────────────────────────────────────────────────────
# Генерируется из апстримного config.default, чтобы его обновления
# подхватывались, а наши значения накатывались поверх.
write_config() {
  say "zapret: хостлист → ${ZDIR}/ipset/zapret-hosts-user.txt"
  sudo mkdir -p "$ZDIR/ipset"
  sudo install -m 0644 "$HERE/zapret-hosts-user.txt" "$ZDIR/ipset/zapret-hosts-user.txt"

  local tmp; tmp="$(mktemp)"
  python3 - "$ZDIR" "$tmp" <<'PY'
import re, sys
zdir, out = sys.argv[1], sys.argv[2]
s = open(zdir + '/config.default', encoding='utf-8').read()
F = zdir + '/files/fake'

# Рабочая стратегия (проверена на DPI провайдера, порт с flowseal ALT):
# fake+fakedsplit + fooling=ts. Порт 80 — fake+multisplit, UDP 443 —
# fake QUIC, плюс голос Discord (discord.media TCP и STUN/Discord UDP).
opt = f'''NFQWS_OPT="
--filter-tcp=80 --dpi-desync=fake,multisplit --dpi-desync-split-pos=method+2 --dpi-desync-fooling=md5sig <HOSTLIST> --new
--filter-tcp=443 --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls={F}/tls_clienthello_www_google_com.bin <HOSTLIST> --new
--filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls={F}/tls_clienthello_www_google_com.bin --new
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic={F}/quic_initial_www_google_com.bin <HOSTLIST_NOAUTO> --new
--filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fooling=badsum --dpi-desync-fake-discord={F}/ACTIVE_DISCORD_UDP.bin --dpi-desync-fake-stun={F}/ACTIVE_DISCORD_UDP.bin
"'''

s, n = re.subn(r'NFQWS_OPT="\n.*?\n"', opt, s, count=1, flags=re.S)
assert n == 1, 'не найден NFQWS_OPT в config.default'
s, _ = re.subn(r'^MODE_FILTER=.*$', 'MODE_FILTER=autohostlist', s, count=1, flags=re.M)
s, _ = re.subn(r'^NFQWS_ENABLE=.*$', 'NFQWS_ENABLE=1', s, count=1, flags=re.M)
s, _ = re.subn(r'^#FWTYPE=iptables.*$', 'FWTYPE=nftables', s, count=1, flags=re.M)
s, _ = re.subn(r'^NFQWS_PORTS_TCP=.*$', 'NFQWS_PORTS_TCP=80,443,2053,2083,2087,2096,8443', s, count=1, flags=re.M)
s, _ = re.subn(r'^NFQWS_PORTS_UDP=.*$', 'NFQWS_PORTS_UDP=443,19294-19344,50000-50100', s, count=1, flags=re.M)
open(out, 'w', encoding='utf-8').write(s)
PY
  say "zapret: конфиг → ${ZDIR}/config"
  sudo install -m 0644 "$tmp" "$ZDIR/config"
  rm -f "$tmp"
}

# ── systemd + sudoers ──────────────────────────────────────────
install_service() {
  say "zapret: systemd-юнит ${UNIT}"
  sudo install -m 0644 "$HERE/zapret.service" "/etc/systemd/system/$UNIT"
  sudo systemctl daemon-reload

  # Узкое NOPASSWD-правило: только старт/стоп/рестарт/статус сервиса,
  # чтобы переключатель в Hub не спрашивал пароль.
  local tmp; tmp="$(mktemp)"
  cat > "$tmp" <<EOF
# Lunar Eclipse: управление zapret без пароля (только systemctl сервиса)
$TARGET_USER ALL=(root) NOPASSWD: /usr/bin/systemctl start $UNIT, /usr/bin/systemctl stop $UNIT, /usr/bin/systemctl restart $UNIT, /usr/bin/systemctl enable $UNIT, /usr/bin/systemctl disable $UNIT
EOF
  if visudo -cf "$tmp" >/dev/null 2>&1; then
    sudo install -m 0440 -o root -g root "$tmp" "$SUDOERS"
    say "zapret: sudoers-правило → $SUDOERS (без пароля: start/stop/restart)"
  else
    warn "sudoers-правило не прошло проверку — пропускаю (Hub будет спрашивать пароль)"
  fi
  rm -f "$tmp"
}

healthcheck() {
  local ok=0
  for u in https://discord.com/api/v9/gateway https://www.youtube.com; do
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$u" || true)"
    printf '  %-42s %s\n' "$u" "${code:-FAIL}"
    [ "$code" = "200" ] && ok=$((ok + 1))
  done
  [ "$ok" -ge 2 ] && say "проверка: Discord и YouTube доступны" \
                  || warn "проверка: не все цели открылись (сменилась стратегия DPI?)"
}

status() {
  echo "сервис:  $(systemctl is-active "$UNIT" 2>/dev/null || true) / $(systemctl is-enabled "$UNIT" 2>/dev/null || true)"
  echo "версия:  $(git -C "$ZDIR" -c safe.directory="$ZDIR" log -1 --format='%h %cs' 2>/dev/null || echo 'нет исходников')"
  echo "каталог: $ZDIR"
}

# ── точка входа ────────────────────────────────────────────────
case "$MODE" in
  status)
    status
    ;;
  update)
    install_deps
    get_sources
    install_fake_files
    build
    sudo systemctl restart "$UNIT" 2>/dev/null || true
    say "zapret обновлён и перезапущен"
    healthcheck
    ;;
  install|"")
    install_deps
    get_sources
    install_fake_files
    have_bin || build
    write_config
    install_service
    sudo systemctl enable "$UNIT"
    # именно restart: конфиг мог измениться, а enable --now уже запущенный не перезапускает
    sudo systemctl restart "$UNIT"
    say "zapret установлен и включён в автозапуск"
    healthcheck
    ;;
  *)
    echo "usage: $0 [install|update|status]" >&2
    exit 2
    ;;
esac
