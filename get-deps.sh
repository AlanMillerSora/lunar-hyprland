#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — зависимости (Arch / производные).
#  Списки пакетов живут в deps/packages.txt (официальные) и
#  deps/aur.txt (AUR): правим там, скрипт только читает.
#  Обычно вызывает ./install.sh; отдельно: ./get-deps.sh
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ui.sh
source "$REPO/ui.sh"

# ── манифест пакетов ───────────────────────────────────────────
# deps/packages.txt: секции [имя], по одному пакету в строке;
# пустые строки и # игнорируются. pkgs <секция> печатает её пакеты.
PKG_MANIFEST="$REPO/deps/packages.txt"
AUR_MANIFEST="$REPO/deps/aur.txt"
pkgs() {
  awk -v want="[$1]" '
    /^[[:space:]]*\[/ { inb = ($1 == want); next }
    inb && $0 !~ /^[[:space:]]*(#|$)/ { print $1 }
  ' "$PKG_MANIFEST"
}
aur_pkgs() {
  grep -vE '^[[:space:]]*(#|$)' "$AUR_MANIFEST"
}

if [ "${LUNAR_EMBEDDED:-0}" != 1 ]; then
  lunar_banner
  say "зависимости · Arch   (pacman · AUR: VS Code, Vencord)"
  lunar_hr
fi

# ── новости Arch (informant) ───────────────────────────────────
# Хук 00-informant.hook работает от root и блокирует ЛЮБУЮ транзакцию pacman,
# пока есть непрочитанные новости. Читать надо тоже от root (пользовательский
# informant read возвращает 255) — иначе установка падает на hooks.
if command -v informant >/dev/null 2>&1; then
  if ! sudo informant check >/dev/null 2>&1; then
    warn "есть непрочитанные новости Arch — показываю и отмечаю прочитанными:"
    sudo informant list --unread 2>/dev/null | head -10 || true
    sudo informant read --all >/dev/null 2>&1 \
      && ok "новости отмечены прочитанными" \
      || warn "не удалось отметить — вручную: sudo informant read --all"
  fi
fi

# ── multilib: нужен для steam ──────────────────────────────────
# На чистой Arch секция [multilib] закомментирована — без неё steam не
# поставится. Раскомментируем идемпотентно.
if ! pacman-conf --repo-list 2>/dev/null | grep -qx multilib; then
  say "multilib: включаю репозиторий (для steam)"
  # бэкап перед правкой: sed может не совпасть с форматом файла — откатимся.
  # M-находка: делаем бэкап один раз с постоянным именем, чтобы повторные запуски
  # не плодили россыпь /etc/pacman.conf.bak.*
  BAK="/etc/pacman.conf.lunar.bak"
  [ -f "$BAK" ] || sudo cp -p /etc/pacman.conf "$BAK"
  sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
  # проверяем, что правка реально сработала — иначе steam не поставится
  if pacman-conf --repo-list 2>/dev/null | grep -qx multilib; then
    # -Syu, а не -Sy: -Sy без -u — partial upgrade, ломает систему
    sudo pacman -Syu --noconfirm >/dev/null 2>&1 || true
    ok "multilib включён"
  else
    warn "multilib не включился — правь /etc/pacman.conf вручную (бэкап: $BAK)"
  fi
else
  say "multilib уже включён"
fi

# ── Vulkan-провайдер по GPU ────────────────────────────────────
# Без явного провайдера pacman для steam может выбрать nvidia-провайдер
# даже на AMD/Intel. Список — секции [gpu-amd]/[gpu-intel] манифеста.
VULKAN_SECTION=""
if grep -qi '0x1002' /sys/class/drm/card*/device/vendor 2>/dev/null; then
  VULKAN_SECTION="gpu-amd"
elif grep -qi '0x8086' /sys/class/drm/card*/device/vendor 2>/dev/null; then
  VULKAN_SECTION="gpu-intel"
fi
VULKAN_PKGS=()
if [ -n "$VULKAN_SECTION" ]; then
  mapfile -t VULKAN_PKGS < <(pkgs "$VULKAN_SECTION")
fi

# ── базовые пакеты ─────────────────────────────────────────────
BASE_PKGS=()
mapfile -t BASE_PKGS < <(pkgs base)

say "pacman: базовые пакеты"
# Vulkan-провайдер ставим в одной транзакции с базой (как было раньше).
if sudo pacman -S --needed --noconfirm "${BASE_PKGS[@]}" "${VULKAN_PKGS[@]}"; then
  ok "базовые пакеты"
else
  warn "часть базовых пакетов не поставилась — см. вывод"
fi
# python3 — бинарь пакета python (выше); psutil/gobject — для скриптов
# статуса и GTK-виджетов (шпаргалка, календарь).

# ── обновления (Hub → Update, eclipse-update.sh) ───────────────
# Список — секция [updates] манифеста. informant — блокирует обновление,
# пока не прочитаны новости Arch; translate-shell (trans) — перевод новостей;
# timeshift — снимки для отката; fwupd — прошивки.
say "pacman: обновления, откат, прошивки"
UPD_PKGS=()
mapfile -t UPD_PKGS < <(pkgs updates)
sudo pacman -S --needed --noconfirm "${UPD_PKGS[@]}" \
  && ok "informant · timeshift · cronie · fwupd" \
  || warn "часть пакетов обновлений не поставилась — см. вывод"

# ── игры и медиа (стол 01 — игры) ──────────────────────────────
# Список — секция [games] манифеста. Steam тянет Proton; gamescope/mangohud —
# композитинг и оверлеи; gamemode — профиль производительности;
# lutris/эмуляторы/obs — по README.
say "pacman: игры и медиа"
GAME_PKGS=()
mapfile -t GAME_PKGS < <(pkgs games)
sudo pacman -S --needed --noconfirm "${GAME_PKGS[@]}" \
  && ok "gamescope · mangohud · gamemode · lutris · obs" \
  || warn "часть игровых пакетов не поставилась — см. вывод"

# ── NVIDIA ─────────────────────────────────────────────────────
# Ставим только если в системе реально есть карта NVIDIA (по sysfs).
# На AMD/Intel блок пропускается. Пакеты — секция [gpu-nvidia] манифеста;
# заголовки ядра добавляем сами (у linux — linux-headers, у linux-zen —
# linux-zen-headers). Проприетарного nvidia/nvidia-dkms в Arch 615 больше
# нет — официальная замена nvidia-open-dkms (не nouveau).
if grep -qi '0x10de' /sys/class/drm/card*/device/vendor 2>/dev/null; then
  KERNEL_PKG="$(cat "/usr/lib/modules/$(uname -r)/pkgbase" 2>/dev/null || echo linux)"
  NVIDIA_PKGS=()
  mapfile -t NVIDIA_PKGS < <(pkgs gpu-nvidia)
  say "NVIDIA: nvidia-open-dkms $KERNEL_PKG-headers + nvidia-utils, libva-nvidia-driver, lib32-nvidia-utils"
  sudo pacman -S --needed --noconfirm \
    "$KERNEL_PKG-headers" "${NVIDIA_PKGS[@]}" \
    && ok "NVIDIA-драйверы (после установки — перезагрузись)" \
    || warn "NVIDIA-пакеты не поставились — см. вывод"
  # lib32-nvidia-utils — 32-битные GL/Vulkan для Steam/Proton (нужен multilib).
else
  say "NVIDIA не найдена — драйверы NVIDIA пропущены (VAAPI через mesa)"
  MESA_PKGS=()
  mapfile -t MESA_PKGS < <(pkgs gpu-mesa)
  sudo pacman -S --needed --noconfirm "${MESA_PKGS[@]}" 2>/dev/null || true
fi

# ── zapret: обход DPI (Discord / YouTube) ──────────────────────
# Список — секция [zapret] манифеста. Сам zapret ставится из исходников
# через ./install.sh --zapret; тут — зависимости сборки (gcc/make) и работы
# (netfilter/nftables). systemd-libs отдельно не ставим — точечное
# обновление ломает systemd.
say "pacman: зависимости zapret (сборка nfqws + netfilter)"
ZAPRET_PKGS=()
mapfile -t ZAPRET_PKGS < <(pkgs zapret)
sudo pacman -S --needed --noconfirm "${ZAPRET_PKGS[@]}" \
  && ok "zapret: зависимости" \
  || warn "зависимости zapret не поставились — см. вывод"

# ── yay (AUR-помощник) ─────────────────────────────────────────
# Ставим сами, если нет ни yay, ни paru: иначе AUR-пакеты из deps/aur.txt
# на чистой системе просто пропустятся. base-devel — в списке выше.
if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
  say "AUR: ставлю yay (помощник для AUR)"
  if [ "$(id -u)" -eq 0 ]; then
    warn "запущено от root — makepkg от root не работает; поставь yay вручную (makepkg -si)"
  else
  _tmp="$(mktemp -d)"
  if git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$_tmp/yay-bin" >/dev/null 2>&1 \
     && (cd "$_tmp/yay-bin" && makepkg -si --noconfirm); then
    ok "yay установлен"
  else
    warn "yay не установился — AUR-пакеты пропущены (вручную: makepkg -si)"
  fi
  rm -rf "$_tmp"
  fi
else
  say "AUR-помощник уже есть: $(command -v yay >/dev/null 2>&1 && echo yay || echo paru)"
fi

# ── AUR-пакеты (deps/aur.txt) ──────────────────────────────────
# Все AUR-пакеты одним проходом: VS Code, Vencord, Tela. Ставим через
# yay или paru, чем богаты.
say "обои: живые — QML-сцена в Quickshell (LunarWallpaper.qml)"
AUR_HELPER=""
if command -v yay >/dev/null 2>&1; then
  AUR_HELPER="yay"
elif command -v paru >/dev/null 2>&1; then
  AUR_HELPER="paru"
fi
if [ -n "$AUR_HELPER" ]; then
  while IFS= read -r _pkg; do
    [ -n "$_pkg" ] || continue
    say "AUR: $_pkg"
    "$AUR_HELPER" -S --needed --noconfirm "$_pkg" \
      && ok "$_pkg" || warn "$_pkg не установился — вручную: $AUR_HELPER -S $_pkg"
  done < <(aur_pkgs)
else
  warn "yay/paru не найден — AUR-пакеты пропущены (вручную: makepkg -si)"
fi

if [ "${LUNAR_EMBEDDED:-0}" != 1 ]; then
  say "дальше: ./install.sh (конфиги) или ./install.sh --deps-only"
  lunar_done
fi
