#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  install/optional.sh — необязательные части установщика Lunar Eclipse.
#  Ставятся ТОЛЬКО по явному флагу: SDDM, Plymouth (меняет загрузку),
#  zapret (обход DPI). Здесь же --status / --disable-* и их функции.
#  Подключается из install.sh (source).
# ════════════════════════════════════════════════════════════════

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

# Plymouth рисуется только через KMS. Если монитор на NVIDIA, в initramfs
# нужны её модули, иначе заставка уйдёт в текст/чёрный экран (simpledrm не тянет).
ply_nvidia_kms() {
  # NVIDIA есть только если её видит ядро (по PCI-вендору 0x10de)
  grep -q '^0x10de' /sys/bus/pci/devices/*/vendor 2>/dev/null || return 0
  local mods="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
  if ! grep -qE '^MODULES=\(.*\bnvidia_drm\b' /etc/mkinitcpio.conf; then
    ply_backup /etc/mkinitcpio.conf
    if grep -qE '^MODULES=\(\)' /etc/mkinitcpio.conf; then
      sudo sed -i -E "s/^MODULES=\(\)/MODULES=($mods)/" /etc/mkinitcpio.conf
    else
      sudo sed -i -E "s/^MODULES=\(([^)]*)\)/MODULES=($mods \1)/" /etc/mkinitcpio.conf
    fi
    say "MODULES: + $mods (KMS NVIDIA для Plymouth)"
    ply_state_add nvidia-kms
  fi
  local f; f="$(ply_cmdline_file)"
  if ! grep -qw 'nvidia_drm.modeset=1' "$f" 2>/dev/null; then
    ply_param_raw 'nvidia_drm.modeset=1'
  fi
}

ply_nvidia_kms_del() {
  ply_state_has nvidia-kms || return 0
  sudo sed -i -E 's/\bnvidia //; s/ nvidia\b//; s/\bnvidia_modeset //; s/ nvidia_modeset\b//; s/\bnvidia_uvm //; s/ nvidia_uvm\b//; s/\bnvidia_drm //; s/ nvidia_drm\b//' /etc/mkinitcpio.conf
  sudo sed -i -E 's/^MODULES=\(\)$/MODULES=()/' /etc/mkinitcpio.conf
  say "MODULES: убраны nvidia-модули"
  ply_param_raw_del 'nvidia_drm.modeset=1'
}

# произвольный параметр cmdline (не splash/quiet)
ply_param_raw() {
  local p="$1" f; f="$(ply_cmdline_file)"
  grep -qw -- "$p" "$f" 2>/dev/null && return 0
  ply_backup "$f"
  if ply_is_uki; then
    sudo sed -i "s/\$/ $p/" "$f"
  else
    sudo sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 $p\"/" "$f"
  fi
  say "cmdline: + $p"
  ply_state_add "$p"
}

ply_param_raw_del() {
  local p="$1" f; f="$(ply_cmdline_file)"
  ply_state_has "$p" || return 0
  ply_backup "$f"
  sudo sed -i -E "s/ *\b$p\b//g" "$f"
  ply_state_del "$p"
  say "cmdline: - $p"
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
  if command -v mkinitcpio >/dev/null; then
    say "пересборка initramfs/UKI"
    if ! sudo mkinitcpio -P; then
      warn "mkinitcpio -P завершился с ошибкой — образ мог не собраться"
    fi
  fi
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
  # пакет не в get-deps (нужен только с флагом) — ставим его здесь
  if ! command -v plymouthd >/dev/null; then
    say "Plymouth: пакета нет — ставлю plymouth"
    sudo pacman -S --needed --noconfirm plymouth \
      || { warn "пакет plymouth не поставился (вручную: sudo pacman -S plymouth; если блокирует хук informant — sudo informant read --all)"; return 1; }
  fi
  ply_install
  ply_hooks_add
  ply_param_add quiet
  ply_param_add splash
  ply_nvidia_kms
  ply_rebuild
}

ply_disable() {
  ply_hooks_del
  ply_param_del splash
  ply_param_del quiet
  ply_nvidia_kms_del
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
--filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-discord={F}/ACTIVE_DISCORD_UDP.bin --dpi-desync-fake-stun={F}/ACTIVE_DISCORD_UDP.bin
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

  # wait-online иначе ждёт неактивный wlan0 все 2 минуты, и zapret (After=
  # network-online.target) стартует только после таймаута.
  local wo="/etc/systemd/system/systemd-networkd-wait-online.service.d"
  sudo mkdir -p "$wo"
  sudo install -m 0644 "$ZAPRET_DIR/wait-online-any.conf" "$wo/any.conf"
  say "сеть: wait-online → любой интерфейс ($wo/any.conf)"

  sudo systemctl daemon-reload

  # Управление zapret идёт через root-хелпер /usr/local/lib/lunar/svc.sh
  # (allowlist юнитов внутри; голый systemctl в sudoers не выставляем).
  # Хелпер ставит базовый system_sudoers из install/system.sh; отдельного
  # правила /etc/sudoers.d/lunar-zapret больше нет.
  say "zapret: управление — через /usr/local/lib/lunar/svc.sh"
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
#  Опциональные шаги установки (вызываются по флагам)
# ════════════════════════════════════════════════════════════════

# ── опционально: SDDM ──────────────────────────────────────────
optional_sddm() {
  step "SDDM: тема экрана входа lunar"
  if sddm_enable; then
    ok "тема lunar включена"
    say "предпросмотр: sddm-greeter --test-mode --theme $SDDM_THEME_DST"
  else
    warn "SDDM: не удалось поставить тему"
  fi
}

# ── опционально: Plymouth (меняет загрузку) ────────────────────
optional_plymouth() {
  step "Plymouth: заставка загрузки (HOOKS/cmdline/UKI)"
  warn "Plymouth меняет загрузку: HOOKS, параметры ядра, пересборка initramfs"
  if ply_enable; then
    ok "заставка включена"
    say "откат: ./install.sh --disable-plymouth"
  else
    warn "Plymouth: не удалось включить"
  fi
}

# ── опционально: zapret ────────────────────────────────────────
optional_zapret() {
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
}
