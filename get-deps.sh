#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  Lunar Eclipse — зависимости (Arch / производные).
#  Всё из официальных репозиториев; AUR — только VS Code и Vencord.
#  Обычно вызывает ./install.sh; отдельно: ./get-deps.sh
# ════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=ui.sh
source "$REPO/ui.sh"

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
  sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
  sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true
  ok "multilib включён"
else
  say "multilib уже включён"
fi

# ── базовые пакеты ─────────────────────────────────────────────
# Vulkan-провайдер по GPU: без него pacman для steam может выбрать
# nvidia-провайдер даже на AMD/Intel.
VULKAN_PKGS=""
if grep -qi '0x1002' /sys/class/drm/card*/device/vendor 2>/dev/null; then
  VULKAN_PKGS="vulkan-radeon lib32-vulkan-radeon"
elif grep -qi '0x8086' /sys/class/drm/card*/device/vendor 2>/dev/null; then
  VULKAN_PKGS="vulkan-intel lib32-vulkan-intel"
fi

say "pacman: базовые пакеты"
if sudo pacman -S --needed --noconfirm \
  git base-devel \
  $VULKAN_PKGS \
  hyprland hypridle \
  quickshell \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  kitty fastfetch chafa \
  zsh starship eza zsh-autosuggestions zsh-syntax-highlighting \
  mako firefox discord steam \
  yazi bat ffmpeg 7zip jq fd ripgrep zoxide fzf \
  poppler imagemagick fontconfig \
  playerctl brightnessctl ddcutil iw jq cliphist wl-clipboard \
  grim slurp wf-recorder \
  pipewire pipewire-pulse wireplumber pavucontrol cava \
  power-profiles-daemon polkit polkit-kde-agent \
  networkmanager iwd bluez bluez-utils nm-connection-editor blueman \
  gammastep \
  python python-psutil python-gobject \
  pciutils dmidecode pacman-contrib \
  librsvg curl \
  ttf-jetbrains-mono-nerd ttf-iosevka-nerd
then
  ok "базовые пакеты"
else
  warn "часть базовых пакетов не поставилась — см. вывод"
fi
# python3 — бинарь пакета python (выше); psutil/gobject — для скриптов
# статуса и GTK-виджетов (шпаргалка, календарь).

# ── обновления (Hub → Update, eclipse-update.sh) ───────────────
# informant — блокирует обновление, пока не прочитаны новости Arch;
# translate-shell (trans) — перевод новостей; timeshift — снимки для отката;
# fwupd — прошивки (отдельного fwupd-dummy-device в Arch нет).
say "pacman: обновления, откат, прошивки"
sudo pacman -S --needed --noconfirm \
  informant translate-shell timeshift cronie fwupd \
  && ok "informant · timeshift · cronie · fwupd" \
  || warn "часть пакетов обновлений не поставилась — см. вывод"

# ── игры и медиа (стол 01 — игры) ──────────────────────────────
# Steam тянет Proton; gamescope/mangohud — композитинг и оверлеи;
# gamemode — профиль производительности; lutris/эмуляторы/obs — по README.
say "pacman: игры и медиа"
sudo pacman -S --needed --noconfirm \
  gamescope mangohud lib32-mangohud gamemode \
  lutris \
  retroarch dolphin-emu \
  obs-studio mpv \
  && ok "gamescope · mangohud · gamemode · lutris · obs" \
  || warn "часть игровых пакетов не поставилась — см. вывод"

# ── NVIDIA ─────────────────────────────────────────────────────
# Ставим только если в системе реально есть карта NVIDIA (по sysfs).
# На AMD/Intel блок пропускается. Пакета nvidia/nvidia-dkms в Arch 615
# больше нет — официальная замена nvidia-open-dkms (не nouveau).
if grep -qi '0x10de' /sys/class/drm/card*/device/vendor 2>/dev/null; then
  # Заголовки ядра под DKMS: у linux — linux-headers, у linux-zen — linux-zen-headers.
  KERNEL_PKG="$(cat "/usr/lib/modules/$(uname -r)/pkgbase" 2>/dev/null || echo linux)"
  say "NVIDIA: nvidia-open-dkms $KERNEL_PKG-headers + nvidia-utils, libva-nvidia-driver, lib32-nvidia-utils"
  sudo pacman -S --needed --noconfirm \
    nvidia-open-dkms "$KERNEL_PKG-headers" \
    nvidia-utils nvidia-settings libva-nvidia-driver \
    lib32-nvidia-utils libva-utils \
    && ok "NVIDIA-драйверы (после установки — перезагрузись)" \
    || warn "NVIDIA-пакеты не поставились — см. вывод"
  # lib32-nvidia-utils — 32-битные GL/Vulkan для Steam/Proton (нужен multilib).
else
  say "NVIDIA не найдена — драйверы NVIDIA пропущены (VAAPI через mesa)"
  sudo pacman -S --needed --noconfirm libva-utils mesa-vdpau 2>/dev/null || true
fi

# ── zapret: обход DPI (Discord / YouTube) ──────────────────────
# Сам zapret ставится из исходников через ./install.sh (zapret/install-zapret.sh);
# тут — зависимости сборки (gcc/make) и работы (netfilter/nftables).
say "pacman: зависимости zapret (сборка nfqws + netfilter)"
# systemd-libs отдельно не ставим — точечное обновление ломает systemd.
sudo pacman -S --needed --noconfirm \
  gcc make zlib libcap libnetfilter_queue libmnl nftables \
  && ok "zapret: зависимости" \
  || warn "зависимости zapret не поставились — см. вывод"

# ── yay (AUR-помощник) ─────────────────────────────────────────
# Ставим сами, если нет ни yay, ни paru: иначе VS Code и Vencord (оба из
# AUR) на чистой системе просто пропустятся. base-devel — в списке выше.
if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
  say "AUR: ставлю yay (помощник для AUR)"
  _tmp="$(mktemp -d)"
  if git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$_tmp/yay-bin" >/dev/null 2>&1 \
     && (cd "$_tmp/yay-bin" && makepkg -si --noconfirm); then
    ok "yay установлен"
  else
    warn "yay не установился — AUR-пакеты пропущены (вручную: makepkg -si)"
  fi
  rm -rf "$_tmp"
else
  say "AUR-помощник уже есть: $(command -v yay >/dev/null 2>&1 && echo yay || echo paru)"
fi

# ── VS Code (AUR) ──────────────────────────────────────────────
# В репах только code (OSS). Официальный билд Microsoft — visual-studio-code-bin.
if command -v yay >/dev/null 2>&1; then
  say "AUR: visual-studio-code-bin"
  yay -S --needed --noconfirm visual-studio-code-bin \
    && ok "VS Code" || warn "VS Code не установился — вручную: yay -S visual-studio-code-bin"
elif command -v paru >/dev/null 2>&1; then
  say "AUR: visual-studio-code-bin"
  paru -S --needed --noconfirm visual-studio-code-bin \
    && ok "VS Code" || warn "VS Code не установился — вручную: paru -S visual-studio-code-bin"
else
  warn "yay/paru не найден — VS Code пропущен (yay -S visual-studio-code-bin)"
fi

say "обои: живые — QML-сцена в Quickshell (LunarWallpaper.qml); статику генерит eclipse-walls-gen.sh"

# ── Vencord (AUR) ──────────────────────────────────────────────
# Мод Discord: патчит app.asar; после обновления Discord патч накатывается заново.
if command -v yay >/dev/null 2>&1; then
  say "AUR: vencord-installer-bin"
  yay -S --needed --noconfirm vencord-installer-bin \
    && ok "Vencord" || warn "Vencord не установился — вручную: yay -S vencord-installer-bin"
elif command -v paru >/dev/null 2>&1; then
  say "AUR: vencord-installer-bin"
  paru -S --needed --noconfirm vencord-installer-bin \
    && ok "Vencord" || warn "Vencord не установился — вручную: paru -S vencord-installer-bin"
else
  warn "yay/paru не найден — Vencord пропущен (yay -S vencord-installer-bin)"
fi

if [ "${LUNAR_EMBEDDED:-0}" != 1 ]; then
  say "дальше: ./install.sh (конфиги) или ./install.sh --deps-only"
  lunar_done
fi
