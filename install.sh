#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — единый установщик.
#
#  База (без флагов): зависимости + конфиги ~/.config + системные
#  мелочи (Wi-Fi, sudoers агента, shell). Системные темы и сервисы
#  (SDDM, Plymouth, zapret) ставятся ТОЛЬКО по явному флагу.
#
#  Запуск:  ./install.sh [флаги]
#    --no-deps           только конфиги (зависимости уже стоят)
#    --deps-only         только зависимости
#    --sddm              тема экрана входа SDDM (lunar)
#    --plymouth          заставка Plymouth; меняет загрузку (HOOKS/UKI/GRUB)
#    --zapret            обход DPI: Discord/YouTube (/opt/zapret)
#    --status            состояние SDDM / Plymouth / zapret
#    --disable-sddm      вернуть штатную тему входа
#    --disable-plymouth  выключить заставку и вернуть загрузку
#    --plymouth-rescue   (UKI) пункт меню GRUB «без заставки»
#    -h, --help
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
DO_SDDM=0
DO_PLYMOUTH=0
DO_ZAPRET=0
ACTION=""

for a in "$@"; do
  case "$a" in
    --no-deps)          WITH_DEPS=0 ;;
    --deps-only)        DEPS_ONLY=1 ;;
    --sddm)             DO_SDDM=1 ;;
    --plymouth)         DO_PLYMOUTH=1 ;;
    --zapret)           DO_ZAPRET=1 ;;
    --status)           ACTION=status ;;
    --disable-sddm)     ACTION=disable-sddm ;;
    --disable-plymouth) ACTION=disable-plymouth ;;
    --plymouth-rescue)  ACTION=plymouth-rescue ;;
    -h|--help)          sed -n '2,23p' "$0"; exit 0 ;;
    *) printf 'usage: %s [--no-deps|--deps-only|--sddm|--plymouth|--zapret|--status|--disable-sddm|--disable-plymouth|--plymouth-rescue]\n' "$0" >&2; exit 1 ;;
  esac
done

# ════════════════════════════════════════════════════════════════
#  SDDM — тема экрана входа (lunar)
# ════════════════════════════════════════════════════════════════
SDDM_THEME_SRC="$REPO/sddm/lunar"
SDDM_THEME_DST="/usr/share/sddm/themes/lunar"
SDDM_CONF="/etc/sddm.conf.d/10-lunar-theme.conf"

sddm_install() {
  sudo mkdir -p "$SDDM_THEME_DST"
  sudo cp -rf "$SDDM_THEME_SRC"/. "$SDDM_THEME_DST"/
  sudo chmod -R a+rX "$SDDM_THEME_DST"
}
sddm_enable() {
  sddm_install
  sudo mkdir -p "$(dirname "$SDDM_CONF")"
  printf '[Theme]\nCurrent=lunar\n' | sudo tee "$SDDM_CONF" >/dev/null
}
sddm_disable() { sudo rm -f "$SDDM_CONF"; }
sddm_status() {
  echo "── SDDM ──"
  echo "тема установлена : $([ -d "$SDDM_THEME_DST" ] && echo да || echo нет)"
  echo "тема выбрана     : $(grep -h '^Current=' "$SDDM_CONF" 2>/dev/null | cut -d= -f2 || echo '(штатная)')"
  echo "предпросмотр     : sddm-greeter --test-mode --theme $SDDM_THEME_DST"
}

# ════════════════════════════════════════════════════════════════
#  Plymouth — заставка загрузки (lunar), меняет HOOKS/cmdline/UKI
# ════════════════════════════════════════════════════════════════
PLY_THEME_SRC="$REPO/plymouth/lunar"
PLY_THEME_DST="/usr/share/plymouth/themes/lunar"
PLY_RESCUE_UKI="/boot/EFI/rescue/arch-linux-rescue.efi"
PLY_RESCUE_CONF="/etc/mkinitcpio-rescue.conf"
PLY_RESCUE_CMDLINE="/etc/kernel/cmdline.rescue"
PLY_GRUB_CUSTOM="/etc/grub.d/40_custom"
PLY_PARAMS="/etc/lunar-plymouth.params"

ply_is_uki() { grep -rqsE '^[A-Za-z]+_uki=' /etc/mkinitcpio.d/ 2>/dev/null; }
ply_cmdline_file() { if ply_is_uki; then echo /etc/kernel/cmdline; else echo /etc/default/grub; fi; }
ply_hooks_has() { grep -qE '^HOOKS=\(.*\bplymouth\b.*\)' /etc/mkinitcpio.conf; }

# какие параметры ядра добавил именно рис (чтобы --disable убирал только свои)
ply_state_has() { sudo grep -qxF -- "$1" "$PLY_PARAMS" 2>/dev/null; }
ply_state_add() { sudo touch "$PLY_PARAMS"; sudo grep -qxF -- "$1" "$PLY_PARAMS" 2>/dev/null || echo "$1" | sudo tee -a "$PLY_PARAMS" >/dev/null; }
ply_state_del() { sudo sed -i "/^$1\$/d" "$PLY_PARAMS" 2>/dev/null || true; }

# одноразовый бэкап файла перед правкой (прежний .bak не затираем)
ply_backup() { sudo cp -n "$1" "$1.lunar.bak" 2>/dev/null || true; }

ply_hooks_add() {
  ply_hooks_has && return 0
  sudo cp -n /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak 2>/dev/null || true
  if grep -qE '^HOOKS=\([^)]*\budev\b' /etc/mkinitcpio.conf; then
    sudo sed -i -E 's/^(HOOKS=\([^)]*\budev\b)/\1 plymouth/' /etc/mkinitcpio.conf
  elif grep -qE '^HOOKS=\([^)]*\bsystemd\b' /etc/mkinitcpio.conf; then
    sudo sed -i -E 's/^(HOOKS=\([^)]*\bsystemd\b)/\1 plymouth/' /etc/mkinitcpio.conf
  else
    sudo sed -i -E 's/^(HOOKS=\()/\1plymouth /' /etc/mkinitcpio.conf
  fi
  say "HOOKS: добавлен plymouth"
}

ply_hooks_del() {
  ply_hooks_has || return 0
  sudo sed -i -E 's/\bplymouth //; s/ plymouth\b//' /etc/mkinitcpio.conf
  say "HOOKS: убран plymouth"
}

ply_param_add() {  # splash|quiet — добавляю и запоминаю ТОЛЬКО фактически добавленное
  local p="$1" f; f="$(ply_cmdline_file)"
  ply_backup "$f"
  if ply_is_uki; then
    if ! grep -qw -- "$p" "$f" 2>/dev/null; then
      sudo sed -i "s/\$/ $p/" "$f"; say "cmdline: + $p"; ply_state_add "$p"
    fi
  else
    if ! grep -qE "^GRUB_CMDLINE_LINUX_DEFAULT=.*\b$p\b" "$f"; then
      sudo sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 $p\"/" "$f"
      say "grub: + $p"; ply_state_add "$p"
    fi
  fi
}

ply_param_del() {  # splash|quiet — убираю, только если добавлял рис
  local p="$1" f; f="$(ply_cmdline_file)"
  if ! ply_state_has "$p"; then
    say "cmdline: $p добавлял не рис — не трогаю"
    return 0
  fi
  ply_backup "$f"
  if ply_is_uki; then
    sudo sed -i -E "s/ *\b$p\b//g" "$f"
  else
    sudo sed -i -E "s/(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*) *\b$p\b/\1/" "$f"
  fi
  ply_state_del "$p"
  say "cmdline: - $p"
}

# На UKI классический 10_linux делает первым пункт без initramfs (паника).
ply_grub_guard() {
  command -v grub-mkconfig >/dev/null || return 0
  [ -d /boot/grub ] || return 0
  ply_is_uki || return 0
  if [ -x /etc/grub.d/10_linux ] && ! compgen -G '/boot/initramfs-linux*.img' >/dev/null; then
    sudo chmod -x /etc/grub.d/10_linux
    warn "10_linux отключён: на UKI его пункт по умолчанию нерабочий (нет initramfs)"
  fi
}

ply_rebuild() {
  command -v mkinitcpio >/dev/null && { say "пересборка initramfs/UKI"; sudo mkinitcpio -P; }
  ply_grub_guard
  if command -v grub-mkconfig >/dev/null && [ -d /boot/grub ]; then
    say "пересборка grub.cfg"; sudo grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

ply_install() {
  [ -d "$PLY_THEME_SRC" ] || { warn "нет каталога темы: $PLY_THEME_SRC"; return 1; }
  sudo mkdir -p "$PLY_THEME_DST"
  sudo cp -rf "$PLY_THEME_SRC"/. "$PLY_THEME_DST"/
  sudo plymouth-set-default-theme lunar
  say "тема lunar → $PLY_THEME_DST"
}

ply_enable() {
  command -v plymouthd >/dev/null || { warn "не установлен пакет plymouth"; return 1; }
  ply_install
  ply_hooks_add
  ply_param_add quiet
  ply_param_add splash
  ply_rebuild
}

ply_disable() {
  ply_hooks_del
  ply_param_del splash
  ply_param_del quiet
  ply_rebuild
}

ply_rescue() {
  ply_is_uki || { warn "резервный образ рассчитан на режим UKI"; return 1; }

  # предпроверки ДО любых изменений: иначе падаем после сборки и оставляем мусор
  sudo test -f /etc/kernel/cmdline || { warn "нет /etc/kernel/cmdline — rescue не собираю"; return 1; }
  sudo test -f /boot/vmlinuz-linux || { warn "нет /boot/vmlinuz-linux — rescue не собираю"; return 1; }
  local boot_src uuid
  boot_src="$(findmnt -no SOURCE /boot 2>/dev/null || true)"
  [ -n "$boot_src" ] || { warn "не вижу загрузочный раздел /boot (findmnt пуст)"; return 1; }
  uuid="$(sudo blkid -s UUID -o value "$boot_src" 2>/dev/null || true)"
  [ -n "$uuid" ] || { warn "не определил UUID раздела $boot_src"; return 1; }

  sudo cp -f /etc/mkinitcpio.conf "$PLY_RESCUE_CONF"
  sudo cp -f /etc/kernel/cmdline "$PLY_RESCUE_CMDLINE"
  sudo sed -i -E 's/ *\bsplash\b//g; s/ *\bquiet\b//g' "$PLY_RESCUE_CMDLINE"
  sudo mkdir -p "$(dirname "$PLY_RESCUE_UKI")"
  if ! sudo mkinitcpio -c "$PLY_RESCUE_CONF" -k /boot/vmlinuz-linux -U "$PLY_RESCUE_UKI" \
       --cmdline "$PLY_RESCUE_CMDLINE"; then
    warn "сборка резервного UKI не удалась — убираю артефакты"
    sudo rm -f "$PLY_RESCUE_UKI" "$PLY_RESCUE_CONF" "$PLY_RESCUE_CMDLINE"
    return 1
  fi

  if ! grep -q 'lunar-rescue' "$PLY_GRUB_CUSTOM" 2>/dev/null; then
    sudo cp -n "$PLY_GRUB_CUSTOM" "$PLY_GRUB_CUSTOM.bak" 2>/dev/null || true
    sudo tee -a "$PLY_GRUB_CUSTOM" >/dev/null <<EOF

menuentry 'Lunar Eclipse (без заставки)' --id lunar-rescue {
    insmod part_gpt
    insmod fat
    insmod chain
    search --no-floppy --set=root --fs-uuid $uuid
    chainloader /EFI/rescue/arch-linux-rescue.efi
}
EOF
    say "в меню GRUB добавлен пункт «Lunar Eclipse (без заставки)»"
  fi
  command -v grub-mkconfig >/dev/null && sudo grub-mkconfig -o /boot/grub/grub.cfg
}

ply_status() {
  echo "── Plymouth ──"
  echo "режим загрузки : $(ply_is_uki && echo UKI || echo 'GRUB (классический)')"
  echo "тема plymouth  : $(plymouth-set-default-theme 2>/dev/null || echo '—')"
  echo "HOOKS          : $(grep -oE '^HOOKS=.*' /etc/mkinitcpio.conf)"
  if ply_is_uki; then
    echo "cmdline        : $(cat /etc/kernel/cmdline 2>/dev/null)"
    if grep -q 'lunar-rescue' "$PLY_GRUB_CUSTOM" 2>/dev/null; then
      echo "резервный пункт: есть"
    else
      echo "резервный пункт: нет"
    fi
  else
    echo "grub cmdline   : $(grep -oE '^GRUB_CMDLINE_LINUX_DEFAULT=.*' /etc/default/grub)"
  fi
}

# ════════════════════════════════════════════════════════════════
#  zapret — обход DPI (Discord / YouTube), /opt/zapret
# ════════════════════════════════════════════════════════════════
ZAPRET_DIR="$REPO/zapret"
ZAPRET_DST=/opt/zapret
ZAPRET_UNIT=zapret.service
ZAPRET_SUDOERS=/etc/sudoers.d/lunar-zapret
ZAPRET_USER="${SUDO_USER:-$(id -un)}"
# имя подставляется прямо в sudoers — принимаем только безопасную форму
if [[ ! "$ZAPRET_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  warn "zapret: некорректное имя пользователя — sudoers-правило пропускаю"
  ZAPRET_USER=""
fi

zapret_deps() {
  say "zapret: зависимости (gcc/make, netfilter, nftables)"
  # systemd-libs отдельно не ставим: точечное обновление ломает связку с systemd.
  sudo pacman -S --needed --noconfirm \
    gcc make zlib libcap libnetfilter_queue libmnl nftables curl
}

zapret_sources() {
  if [ -d "$ZAPRET_DST/.git" ]; then
    say "zapret: git pull — $ZAPRET_DST"
    sudo git -C "$ZAPRET_DST" pull --ff-only || warn "pull не удался, оставляю текущую версию"
  else
    say "zapret: клонирую bol-van/zapret → $ZAPRET_DST"
    sudo mkdir -p "$ZAPRET_DST"
    sudo git clone --depth=1 https://github.com/bol-van/zapret.git "$ZAPRET_DST"
  fi
}

zapret_build() {
  say "zapret: сборка (make systemd -j$(nproc))"
  sudo make -C "$ZAPRET_DST" systemd -j"$(nproc)"
}

zapret_fake() {
  [ -d "$ZAPRET_DIR/files/fake" ] || return 0
  say "zapret: fake-пакеты → $ZAPRET_DST/files/fake"
  sudo mkdir -p "$ZAPRET_DST/files/fake"
  sudo install -m 0644 "$ZAPRET_DIR"/files/fake/*.bin "$ZAPRET_DST/files/fake/"
}

# Конфиг генерируется из апстримного config.default, наши значения — поверх.
zapret_config() {
  say "zapret: хостлист → $ZAPRET_DST/ipset/zapret-hosts-user.txt"
  sudo mkdir -p "$ZAPRET_DST/ipset"
  sudo install -m 0644 "$ZAPRET_DIR/zapret-hosts-user.txt" "$ZAPRET_DST/ipset/zapret-hosts-user.txt"

  local tmp; tmp="$(mktemp)"
  if ! python3 - "$ZAPRET_DST" "$tmp" <<'PY'
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
for pat, rep in [
    (r'^MODE_FILTER=.*$', 'MODE_FILTER=autohostlist'),
    (r'^NFQWS_ENABLE=.*$', 'NFQWS_ENABLE=1'),
    (r'^#FWTYPE=iptables.*$', 'FWTYPE=nftables'),
    (r'^NFQWS_PORTS_TCP=.*$', 'NFQWS_PORTS_TCP=80,443,2053,2083,2087,2096,8443'),
    (r'^NFQWS_PORTS_UDP=.*$', 'NFQWS_PORTS_UDP=443,19294-19344,50000-50100'),
]:
    s, n = re.subn(pat, rep, s, count=1, flags=re.M)
    assert n == 1, f'не найден шаблон {pat!r} в config.default'
open(out, 'w', encoding='utf-8').write(s)
PY
  then
    warn "zapret: не собрал конфиг (upstream изменился?) — старый config не трогаю"
    rm -f "$tmp"
    return 1
  fi
  say "zapret: конфиг → $ZAPRET_DST/config"
  sudo install -m 0644 "$tmp" "$ZAPRET_DST/config"
  rm -f "$tmp"
}

zapret_service() {
  say "zapret: systemd-юнит $ZAPRET_UNIT"
  sudo install -m 0644 "$ZAPRET_DIR/zapret.service" "/etc/systemd/system/$ZAPRET_UNIT"
  sudo systemctl daemon-reload

  # Узкое NOPASSWD-правило: только systemctl сервиса (переключатель в Hub).
  if [ -z "$ZAPRET_USER" ]; then
    warn "zapret: имя пользователя не определено — sudoers-правило не ставлю"
    return 0
  fi
  local tmp; tmp="$(mktemp)"
  cat > "$tmp" <<EOF
# Lunar Eclipse: управление zapret без пароля (только systemctl сервиса)
$ZAPRET_USER ALL=(root) NOPASSWD: /usr/bin/systemctl start $ZAPRET_UNIT, /usr/bin/systemctl stop $ZAPRET_UNIT, /usr/bin/systemctl restart $ZAPRET_UNIT, /usr/bin/systemctl enable $ZAPRET_UNIT, /usr/bin/systemctl disable $ZAPRET_UNIT, /usr/bin/systemctl enable --now $ZAPRET_UNIT, /usr/bin/systemctl disable --now $ZAPRET_UNIT
EOF
  if visudo -cf "$tmp" >/dev/null 2>&1; then
    sudo install -m 0440 -o root -g root "$tmp" "$ZAPRET_SUDOERS"
    say "zapret: sudoers-правило → $ZAPRET_SUDOERS"
  else
    warn "sudoers-правило не прошло проверку — пропускаю (Hub будет спрашивать пароль)"
  fi
  rm -f "$tmp"
}

zapret_health() {
  local okc=0 code
  for u in https://discord.com/api/v9/gateway https://www.youtube.com; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$u" || true)"
    printf '  %-42s %s\n' "$u" "${code:-FAIL}"
    [ "$code" = "200" ] && okc=$((okc + 1))
  done
  if [ "$okc" -ge 2 ]; then
    say "проверка: Discord и YouTube доступны"
  else
    warn "проверка: не все цели открылись (сменилась стратегия DPI?)"
  fi
}

zapret_status() {
  echo "── zapret ──"
  echo "сервис:  $(systemctl is-active "$ZAPRET_UNIT" 2>/dev/null || true) / $(systemctl is-enabled "$ZAPRET_UNIT" 2>/dev/null || true)"
  echo "версия:  $(git -C "$ZAPRET_DST" -c safe.directory="$ZAPRET_DST" log -1 --format='%h %cs' 2>/dev/null || echo 'нет исходников')"
  echo "каталог: $ZAPRET_DST"
}

# ════════════════════════════════════════════════════════════════
#  Действия без установки: --status / --disable-* / --plymouth-rescue
# ════════════════════════════════════════════════════════════════
case "$ACTION" in
  status)
    sddm_status; echo
    ply_status; echo
    zapret_status
    exit 0 ;;
  disable-sddm)
    sddm_disable; ok "SDDM: возвращена штатная тема"; exit 0 ;;
  disable-plymouth)
    ply_disable; ok "Plymouth: заставка выключена, загрузка обычная"; exit 0 ;;
  plymouth-rescue)
    ply_rescue; exit 0 ;;
esac

# количество шагов для счётчика [n/total]
LUNAR_TOTAL=9
[ "$WITH_DEPS" = 1 ] && LUNAR_TOTAL=$((LUNAR_TOTAL + 1))
[ "$DO_SDDM" = 1 ] && LUNAR_TOTAL=$((LUNAR_TOTAL + 1))
[ "$DO_PLYMOUTH" = 1 ] && LUNAR_TOTAL=$((LUNAR_TOTAL + 1))
[ "$DO_ZAPRET" = 1 ] && LUNAR_TOTAL=$((LUNAR_TOTAL + 1))

lunar_banner

# ── зависимости ────────────────────────────────────────────────
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

# ── конфиги ────────────────────────────────────────────────────
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
cp -r "$REPO/.config/." "$HOME/.config/"
chmod +x "$HOME"/.config/hypr/scripts/* 2>/dev/null || true
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

# ── KDE: цветовая схема ────────────────────────────────────────
step "цветовая схема KDE → ~/.local/share/color-schemes"
mkdir -p "$HOME/.local/share/color-schemes"
cp "$REPO"/color-schemes/*.colors "$HOME/.local/share/color-schemes/" 2>/dev/null || true
ok "kdeglobals + схема"

# ── Firefox: тема, стили и префы ───────────────────────────────
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

# ── Firefox: иконка и браузер по умолчанию ─────────────────────
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

# ── курсор Bibata ──────────────────────────────────────────────
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

# ── systemd --user ─────────────────────────────────────────────
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

# ── Wi-Fi: powersave off + ASPM ────────────────────────────────
step "Wi-Fi: powersave off + mt7921e ASPM"
if [ -f "$REPO/systemd/10-lunar-wifi-powersave-off.sh" ]; then
  sudo install -m 0755 -o root -g root \
    "$REPO/systemd/10-lunar-wifi-powersave-off.sh" \
    /etc/NetworkManager/dispatcher.d/10-lunar-wifi-powersave-off.sh 2>/dev/null \
    && ok "dispatcher: powersave выключен навсегда" \
    || warn "dispatcher не установлен (нужен sudo)"
fi
if [ -f "$REPO/systemd/mt7921e-no-aspm.conf" ]; then
  # только для адаптеров MediaTek mt7921e: на другом чипе файл — мёртвый груз
  # не modinfo: модуль mt7921e in-tree и есть на любом ядре Arch, поэтому
  # проверяем само железо — PCI-вендор MediaTek (0x14c3)
  if grep -qi '^0x14c3' /sys/bus/pci/devices/*/vendor 2>/dev/null; then
    sudo install -m 0644 -o root -g root \
      "$REPO/systemd/mt7921e-no-aspm.conf" \
      /etc/modprobe.d/mt7921e-no-aspm.conf 2>/dev/null \
      && ok "mt7921e: disable_aspm=1" \
      || warn "modprobe-конфиг не установлен (нужен sudo)"
  else
    say "mt7921e в системе нет — modprobe-конфиг пропущен (другой Wi-Fi адаптер)"
  fi
fi

# ── sudo: белый список агента (OpenCode) + root-хелперы ────────
step "sudo: белый список агента → /etc/sudoers.d/lunar-agent"
if [ -d "$REPO/systemd" ]; then
  for h in lunar-avatar-sync.sh lunar-journal-read.sh lunar-journal-vacuum.sh; do
    [ -f "$REPO/systemd/$h" ] || continue
    sudo install -d -m 0755 -o root -g root /usr/local/lib/lunar 2>/dev/null \
      && sudo install -m 0755 -o root -g root \
           "$REPO/systemd/$h" "/usr/local/lib/lunar/${h#lunar-}" 2>/dev/null \
      && ok "root-хелпер: /usr/local/lib/lunar/${h#lunar-}" \
      || warn "root-хелпер $h не установлен (нужен sudo)"
  done
fi
AGENT_USER="${SUDO_USER:-$(id -un)}"
if [ -f "$REPO/systemd/lunar-agent.sudoers" ]; then
  if [[ ! "$AGENT_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    warn "sudoers агента: некорректное имя пользователя — пропускаю"
  else
    # В шаблоне имя прибито к sora — подставляем текущего пользователя,
    # иначе правило уйдёт несуществующему логину, и sudo -n молча вернёт 1.
    agent_tmp="$(mktemp)"
    sed "s/^sora /$AGENT_USER /" "$REPO/systemd/lunar-agent.sudoers" > "$agent_tmp"
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

# ── shell по умолчанию ─────────────────────────────────────────
step "shell по умолчанию"
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

# ── опционально: SDDM ──────────────────────────────────────────
if [ "$DO_SDDM" = 1 ]; then
  step "SDDM: тема экрана входа lunar"
  if sddm_enable; then
    ok "тема lunar включена"
    say "предпросмотр: sddm-greeter --test-mode --theme $SDDM_THEME_DST"
  else
    warn "SDDM: не удалось поставить тему"
  fi
fi

# ── опционально: Plymouth (меняет загрузку) ────────────────────
if [ "$DO_PLYMOUTH" = 1 ]; then
  step "Plymouth: заставка загрузки (HOOKS/cmdline/UKI)"
  warn "Plymouth меняет загрузку: HOOKS, параметры ядра, пересборка initramfs"
  if ply_enable; then
    ok "заставка включена"
    say "откат: ./install.sh --disable-plymouth"
  else
    warn "Plymouth: не удалось включить"
  fi
fi

# ── опционально: zapret ────────────────────────────────────────
if [ "$DO_ZAPRET" = 1 ]; then
  step "zapret → /opt/zapret (обход DPI: Discord/YouTube)"
  if [ -f "$ZAPRET_DIR/zapret.service" ]; then
    zapret_deps
    zapret_sources
    zapret_fake
    zapret_build
    if zapret_config; then
      zapret_service
      sudo systemctl enable "$ZAPRET_UNIT"
      # именно restart: конфиг мог измениться, а enable --now уже запущенный не перезапускает
      sudo systemctl restart "$ZAPRET_UNIT"
      ok "zapret установлен и включён в автозапуск"
      zapret_health
    else
      warn "zapret: конфиг не собран — сервис не трогаю (прежний config остался)"
    fi
  else
    warn "нет $ZAPRET_DIR/zapret.service — пропускаю"
  fi
fi

lunar_done
