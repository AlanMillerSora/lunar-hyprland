#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════
#  eclipse-wifi-guard.py — сторож Wi-Fi (страховка от «умирания»).
#
#  Сеть «умирала» из-за рандомизации MAC при сканировании и ручного
#  подключения без профиля. Лечение: сохранённый профиль с постоянным
#  MAC и отключённым power-save. Этот сторож — последняя линия:
#  если активное Wi-Fi-соединение пропало — поднимает его заново
#  (профиль из LUNAR_WIFI_PROFILE или первый сохранённый).
#
#  Запуск: systemd --user (unit lunar-wifi-guard.service).
# ════════════════════════════════════════════════════════════════
import os
import subprocess
import time

INTERVAL = 15
PROFILE = os.environ.get("LUNAR_WIFI_PROFILE", "").strip()
NOTIFY = ["notify-send", "-a", "Wi-Fi"]


def sh(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    except Exception:
        return None


def radio_on():
    r = sh("nmcli", "-t", "-f", "WIFI", "general", "status")
    return bool(r and r.stdout.strip() == "enabled")


def wifi_connections():
    """[(name, active_bool)] для 802-11-wireless."""
    out = []
    r = sh("nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show")
    if not r:
        return out
    for line in r.stdout.splitlines():
        parts = line.split(":")
        if len(parts) >= 2 and parts[1] == "802-11-wireless":
            out.append((parts[0], bool(parts[2])))
    return out


def try_connect(profile):
    r = sh("nmcli", "connection", "up", profile)
    if r and r.returncode == 0:
        subprocess.run(NOTIFY + ["Wi-Fi восстановлен", f"подключено: {profile}"],
                       capture_output=True)
        return True
    return False


def main():
    while True:
        try:
            conns = wifi_connections()
            active = [n for n, a in conns if a]
            if active:
                # всё ок; заодно возвращаем радио, если его кто-то выключил
                if not radio_on():
                    sh("nmcli", "radio", "wifi", "on")
            elif radio_on():
                # радио включено, но связи нет — чиним
                profile = PROFILE or (conns[0][0] if conns else "")
                if profile:
                    try_connect(profile)
                else:
                    sh("nmcli", "device", "wifi", "rescan")
            else:
                # радио выключено совсем — включаем и даём NM секунду
                sh("nmcli", "radio", "wifi", "on")
        except Exception:
            pass
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()