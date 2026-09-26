#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — тема экрана входа SDDM (монохром, затмение).
#
#    eclipse-sddm.sh install        — поставить тему в /usr/share/sddm/themes/lunar
#    eclipse-sddm.sh enable         — выбрать её в SDDM (с возможностью отката)
#    eclipse-sddm.sh disable        — вернуть штатную тему
#    eclipse-sddm.sh avatar <file>  — поставить аватар пользователя
#    eclipse-sddm.sh status         — что сейчас
#
#  Тему можно безопасно посмотреть без задевания SDDM:
#    sddm-greeter --test-mode --theme /usr/share/sddm/themes/lunar
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
THEME_SRC="$REPO/sddm/lunar"
THEME_DST="/usr/share/sddm/themes/lunar"
CONF_DIR="/etc/sddm.conf.d"
CONF="$CONF_DIR/10-lunar-theme.conf"

msg()  { printf '\033[1;37m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m##\033[0m %s\n' "$*" >&2; exit 1; }
need_root() { [[ $EUID -eq 0 ]] || die "нужен root: sudo $0 $*"; }

cmd_install() {
    need_root install
    [[ -d "$THEME_SRC" ]] || die "нет каталога темы: $THEME_SRC"
    mkdir -p "$THEME_DST"
    cp -rf "$THEME_SRC"/. "$THEME_DST"/
    chmod -R a+rX "$THEME_DST"
    msg "тема установлена в $THEME_DST"
}

cmd_enable() {
    need_root enable
    cmd_install
    mkdir -p "$CONF_DIR"
    printf '[Theme]\nCurrent=lunar\n' > "$CONF"
    msg "SDDM переключён на тему lunar (файл $CONF)"
    warn "проверка: sddm-greeter --test-mode --theme $THEME_DST"
    warn "откат из TTY: sudo $0 disable && sudo systemctl restart sddm"
}

cmd_disable() {
    need_root disable
    rm -f "$CONF"
    msg "тема lunar выключена (вернётся штатная тема SDDM)"
}

cmd_avatar() {
    need_root avatar
    local src="${1:-}"
    [[ -n "$src" && -f "$src" ]] || die "укажи файл: $0 avatar <картинка>"
    cp -f "$src" "$THEME_SRC/assets/avatar.png"
    mkdir -p "$THEME_DST/assets"
    cp -f "$src" "$THEME_DST/assets/avatar.png"
    msg "аватар обновлён (круглый кроп делает сама тема)"
}

cmd_status() {
    echo "тема установлена : $([[ -d $THEME_DST ]] && echo да || echo нет)"
    echo "тема SDDM        : $(grep -h '^Current=' "$CONF" 2>/dev/null | cut -d= -f2 || echo '(штатная)')"
    echo "greeter          : $(command -v sddm-greeter >/dev/null && echo есть || echo нет)"
}

case "${1:-}" in
    install) cmd_install ;;
    enable)  cmd_enable ;;
    disable) cmd_disable ;;
    avatar)  cmd_avatar "${2:-}" ;;
    status)  cmd_status ;;
    *) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
