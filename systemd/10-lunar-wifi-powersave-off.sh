#!/bin/sh
# ════════════════════════════════════════════════════════════
#  Lunar Eclipse — энергосбережение Wi-Fi выключено всегда.
#
#  Ноут всегда на зарядке, десктопу powersave тем более не нужен.
#  NetworkManager с backend iwd игнорирует настройку соединения
#  802-11-wireless.powersave, поэтому глушим на уровне
#  драйвера при каждом поднятии интерфейса.
#
#  Ставится в /etc/NetworkManager/dispatcher.d/ (см. install.sh).
# ════════════════════════════════════════════════════════════
IFACE="$1"
ACTION="$2"

# только беспроводные интерфейсы
case "$IFACE" in
  wl*) ;;
  *) exit 0 ;;
esac

# только момент поднятия
[ "$ACTION" = "up" ] || exit 0

[ -x /usr/bin/iw ] || exit 0
/usr/bin/iw dev "$IFACE" set power_save off 2>/dev/null || true
exit 0
