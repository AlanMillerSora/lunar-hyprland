#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — заставка Plymouth (монохромное затмение).
#
#  Системный уровень, поэтому всё делается явной командой, а не
#  молча при установке риса. Скрипт идемпотентен и сам делает бэкапы.
#
#    eclipse-plymouth.sh install   — положить тему в /usr/share/plymouth/themes/lunar
#    eclipse-plymouth.sh enable    — включить заставку при загрузке
#    eclipse-plymouth.sh disable   — выключить и вернуть обычную загрузку
#    eclipse-plymouth.sh rescue    — резервный пункт меню без заставки (GRUB)
#    eclipse-plymouth.sh status    — что сейчас настроено
#
#  Работает в двух режимах загрузки:
#    * UKI (mkinitcpio preset с *_uki=, GRUB-команда uki) → cmdline в /etc/kernel/cmdline;
#    * классический GRUB → cmdline в GRUB_CMDLINE_LINUX_DEFAULT.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
THEME_SRC="$REPO/plymouth/lunar"
THEME_DST="/usr/share/plymouth/themes/lunar"
RESCUE_UKI="/boot/EFI/rescue/arch-linux-rescue.efi"
RESCUE_CONF="/etc/mkinitcpio-rescue.conf"
RESCUE_CMDLINE="/etc/kernel/cmdline.rescue"
GRUB_CUSTOM="/etc/grub.d/40_custom"

msg()  { printf '\033[1;37m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m##\033[0m %s\n' "$*" >&2; exit 1; }

need_root() { [[ $EUID -eq 0 ]] || die "нужен root: sudo $0 $*"; }

# ── определение режима загрузки ────────────────────────────────
is_uki() {
    grep -rqsE '^[A-Za-z]+_uki=' /etc/mkinitcpio.d/ 2>/dev/null
}

cmdline_file() {  # куда писать параметры ядра
    if is_uki; then echo /etc/kernel/cmdline; else echo /etc/default/grub; fi
}

# ── работа с HOOKS ─────────────────────────────────────────────
hooks_has_plymouth() { grep -qE '^HOOKS=\(.*\bplymouth\b.*\)' /etc/mkinitcpio.conf; }

hooks_add() {
    hooks_has_plymouth && return 0
    cp -n /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak 2>/dev/null || true
    if grep -qE '^HOOKS=\([^)]*\budev\b' /etc/mkinitcpio.conf; then
        sed -i -E 's/^(HOOKS=\([^)]*\budev\b)/\1 plymouth/' /etc/mkinitcpio.conf
    elif grep -qE '^HOOKS=\([^)]*\bsystemd\b' /etc/mkinitcpio.conf; then
        sed -i -E 's/^(HOOKS=\([^)]*\bsystemd\b)/\1 plymouth/' /etc/mkinitcpio.conf
    else
        sed -i -E 's/^(HOOKS=\()/\1plymouth /' /etc/mkinitcpio.conf
    fi
    msg "HOOKS: добавлен plymouth"
}

hooks_del() {
    hooks_has_plymouth || return 0
    sed -i -E 's/\bplymouth //; s/ plymouth\b//' /etc/mkinitcpio.conf
    msg "HOOKS: убран plymouth"
}

# ── работа с параметрами ядра ──────────────────────────────────
param_add() {  # param_add splash|quiet
    local p="$1" f; f="$(cmdline_file)"
    if is_uki; then
        grep -qw -- "$p" "$f" 2>/dev/null || { sed -i "s/\$/ $p/" "$f"; msg "cmdline: + $p"; }
    else
        grep -qE "^GRUB_CMDLINE_LINUX_DEFAULT=.*\b$p\b" "$f" || {
            sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 $p\"/" "$f"; msg "grub: + $p"; }
    fi
}

param_del() {  # param_del splash|quiet
    local p="$1" f; f="$(cmdline_file)"
    if is_uki; then
        sed -i -E "s/ *\b$p\b//g" "$f"
    else
        sed -i -E "s/(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*) *\b$p\b/\1/" "$f"
    fi
    msg "cmdline: - $p"
}

# На UKI-машине классический 10_linux делает первым пункт без initramfs
# (только amd-ucode) — это паника ядра. Отключаем его, грузимся через uki.
grub_guard() {
    command -v grub-mkconfig >/dev/null || return 0
    [[ -d /boot/grub ]] || return 0
    is_uki || return 0
    if [[ -x /etc/grub.d/10_linux ]] && ! compgen -G '/boot/initramfs-linux*.img' >/dev/null; then
        chmod -x /etc/grub.d/10_linux
        warn "10_linux отключён: на UKI его пункт по умолчанию нерабочий (нет initramfs)"
    fi
}

rebuild() {
    command -v mkinitcpio >/dev/null && { msg "пересборка initramfs/UKI"; mkinitcpio -P; }
    grub_guard
    if command -v grub-mkconfig >/dev/null && [[ -d /boot/grub ]]; then
        msg "пересборка grub.cfg"; grub-mkconfig -o /boot/grub/grub.cfg
    fi
}

# ── команды ────────────────────────────────────────────────────
cmd_install() {
    need_root install
    [[ -d "$THEME_SRC" ]] || die "нет каталога темы: $THEME_SRC"
    mkdir -p "$THEME_DST"
    cp -f "$THEME_SRC"/* "$THEME_DST"/
    plymouth-set-default-theme lunar
    msg "тема lunar установлена в $THEME_DST и выбрана по умолчанию"
}

cmd_enable() {
    need_root enable
    command -v plymouthd >/dev/null || die "не установлен пакет plymouth"
    cmd_install
    hooks_add
    param_add quiet
    param_add splash
    rebuild
    msg "готово. Проверка:"
    cmd_status
}

cmd_disable() {
    need_root disable
    hooks_del
    param_del splash
    param_del quiet
    rebuild
    msg "заставка выключена, загрузка вернулась к обычной"
}

cmd_rescue() {
    need_root rescue
    is_uki || die "резервный образ рассчитан на режим UKI"
    grep -rqs '^GRUB_TIMEOUT' /etc/default/grub || warn "GRUB не обнаружен — пункт меню не добавится"
    cp -f /etc/mkinitcpio.conf "$RESCUE_CONF"
    cp -f /etc/kernel/cmdline "$RESCUE_CMDLINE"
    sed -i -E 's/ *\bsplash\b//g; s/ *\bquiet\b//g' "$RESCUE_CMDLINE"
    mkdir -p "$(dirname "$RESCUE_UKI")"
    mkinitcpio -c "$RESCUE_CONF" -k /boot/vmlinuz-linux -U "$RESCUE_UKI" \
        --cmdline "$RESCUE_CMDLINE"
    local uuid; uuid="$(blkid -s UUID -o value "$(findmnt -no SOURCE /boot)")"
    if ! grep -q 'lunar-rescue' "$GRUB_CUSTOM"; then
        cp -n "$GRUB_CUSTOM" "$GRUB_CUSTOM.bak" 2>/dev/null || true
        cat >> "$GRUB_CUSTOM" <<EOF

menuentry 'Lunar Eclipse (без заставки)' --id lunar-rescue {
    insmod part_gpt
    insmod fat
    insmod chain
    search --no-floppy --set=root --fs-uuid $uuid
    chainloader /EFI/rescue/arch-linux-rescue.efi
}
EOF
        msg "в меню GRUB добавлен пункт «Lunar Eclipse (без заставки)»"
    fi
    command -v grub-mkconfig >/dev/null && grub-mkconfig -o /boot/grub/grub.cfg
}

cmd_status() {
    echo "режим загрузки : $(is_uki && echo UKI || echo 'GRUB (классический)')"
    echo "тема plymouth  : $(plymouth-set-default-theme 2>/dev/null || echo '—')"
    echo "HOOKS          : $(grep -oE '^HOOKS=.*' /etc/mkinitcpio.conf)"
    if is_uki; then
        echo "cmdline        : $(cat /etc/kernel/cmdline 2>/dev/null)"
        grep -q 'lunar-rescue' "$GRUB_CUSTOM" 2>/dev/null && echo "резервный пункт: есть" || echo "резервный пункт: нет"
    else
        echo "grub cmdline   : $(grep -oE '^GRUB_CMDLINE_LINUX_DEFAULT=.*' /etc/default/grub)"
    fi
}

case "${1:-}" in
    install) cmd_install ;;
    enable)  cmd_enable ;;
    disable) cmd_disable ;;
    rescue)  cmd_rescue ;;
    status)  cmd_status ;;
    *) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
