#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════
#  eclipse-wifi-guard.py — сторож Wi-Fi (страховка от «умирания»).
#
#  Сеть «умирала» из-за рандомизации MAC при сканировании и ручного
#  подключения без профиля. Лечение: сохранённый профиль с постоянным
#  MAC и отключённым power-save. Этот сторож — последняя линия:
#  если активное Wi-Fi-соединение пропало (радио включено) — поднимает
#  его заново (профиль из LUNAR_WIFI_PROFILE, файла wifi-profile или
#  первый сохранённый).
#
#  Радио сторож НЕ включает: если пользователь выключил Wi-Fi сам
#  (авиарежим/экономия) — это его выбор, состояние запоминаем в
#  ~/.cache/lunar/wifi-guard.state и не воюем с ним.
#
#  Запуск: systemd --user (unit lunar-wifi-guard.service).
# ════════════════════════════════════════════════════════════════
import os
import subprocess
import time

INTERVAL = 15
NOTIFY = ["notify-send", "-a", "Wi-Fi"]

STATE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache"),
    "lunar")
STATE_FILE = os.path.join(STATE_DIR, "wifi-guard.state")


def _profile_from_file():
    """Профиль из ${XDG_CONFIG_HOME:-~/.config}/lunar/wifi-profile.

    Первая значащая строка, формат `LUNAR_WIFI_PROFILE=SSID` или просто SSID.
    """
    cfg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    try:
        with open(os.path.join(cfg, "lunar", "wifi-profile"), "r", encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    line = line.split("=", 1)[1]
                return line.strip().strip('"').strip("'")
    except OSError:
        pass
    return ""


PROFILE = os.environ.get("LUNAR_WIFI_PROFILE", "").strip() or _profile_from_file()


def sh(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    except Exception:
        return None


def radio_on():
    r = sh("nmcli", "-t", "-f", "WIFI", "general", "status")
    return bool(r and r.stdout.strip() == "enabled")


def read_state():
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def write_state(value):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            f.write(value)
    except OSError:
        pass


def terse_split(line):
    """Разбор terse-вывода nmcli с учётом экранирования `\\:` и `\\\\`."""
    parts, cur, esc = [], [], False
    for ch in line:
        if esc:
            cur.append(ch)
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur))
    return parts


def wifi_connections():
    """[(name, active_bool)] для 802-11-wireless."""
    out = []
    r = sh("nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show")
    if not r:
        return out
    for line in r.stdout.splitlines():
        parts = terse_split(line)
        if len(parts) >= 2 and parts[1] == "802-11-wireless":
            dev = parts[2] if len(parts) > 2 else ""
            out.append((parts[0], bool(dev)))
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
            prev = read_state()
            if not radio_on():
                # радио выключено — считаем это намерением пользователя
                # (авиа/экономия) и не включаем обратно, только запоминаем
                if prev != "off":
                    write_state("off")
            else:
                if prev != "on":
                    write_state("on")
                conns = wifi_connections()
                active = [n for n, a in conns if a]
                if not active:
                    # радио включено, но связи нет — чиним
                    profile = PROFILE or (conns[0][0] if conns else "")
                    if profile:
                        try_connect(profile)
                    else:
                        sh("nmcli", "device", "wifi", "rescan")
        except Exception:
            pass
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
