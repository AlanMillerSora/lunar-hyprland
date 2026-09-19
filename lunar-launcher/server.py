#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════
#  lunar-launcher/server.py — локальный сервер лаунчера.
#  Слушает ТОЛЬКО 127.0.0.1 (никакой сети наружу), отдаёт статику
#  из web/ и выполняет системные действия из браузера.
#
#  Зависимости: только stdlib. Порт: 47781 (LUNAR_LAUNCHER_PORT).
# ════════════════════════════════════════════════════════════════
import json
import os
import re
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = int(os.environ.get("LUNAR_LAUNCHER_PORT", "47781"))
WEB = Path(__file__).resolve().parent / "web"
HOME = Path.home()
STATE_FILE = HOME / ".config/lunar/transparency"       # "0.92 0.87" (active inactive)
ASKPASS = HOME / ".config/hypr/scripts/eclipse-askpass.py"
BRIGHTNESS = Path("/sys/class/backlight/amdgpu_bl1")

MIME = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "application/javascript; charset=utf-8",
    ".svg": "image/svg+xml",
    ".png": "image/png",
}


def sh(cmd, timeout=8, **kw):
    """Запустить команду, вернуть объект CompletedProcess или None."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **kw)
    except Exception:
        return None


def sh_bg(cmd):
    """Запустить в фоне без ожидания."""
    try:
        return subprocess.Popen(
            cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception:
        return None


# ─────────────────────────── Состояние ──────────────────────────

def volume_state():
    r = sh(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
    m = re.search(r"(\d+\.\d+)", r.stdout) if r else None
    muted = bool(r and "MUTED" in r.stdout)
    return {"volume": int(round(float(m.group(1)) * 100)) if m else 0, "muted": muted}


def brightness_state():
    try:
        maxv = int((BRIGHTNESS / "max_brightness").read_text().strip())
        cur = int((BRIGHTNESS / "actual_brightness").read_text().strip())
        return {"brightness": round(cur / maxv * 100), "ok": True}
    except Exception:
        return {"brightness": -1, "ok": False}


def opacity_state():
    try:
        a, b = STATE_FILE.read_text().strip().split()
        return {"opacity": int(round(float(a) * 100)), "opacityInactive": int(round(float(b) * 100))}
    except Exception:
        return {"opacity": 100, "opacityInactive": 95}


def wifi_state():
    r = sh(["nmcli", "-t", "-f", "WIFI", "general", "status"])
    on = bool(r and r.stdout.strip() == "enabled")
    ssid = ""
    r2 = sh(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if r2:
        for line in r2.stdout.splitlines():
            name, typ = line.split(":", 1)
            if typ == "802-11-wireless":
                ssid = name
                break
    return {"wifi": on, "ssid": ssid}


def state():
    return {
        **volume_state(), **brightness_state(), **opacity_state(), **wifi_state(),
        "time": __import__("datetime").datetime.now().strftime("%H:%M"),
        "date": __import__("datetime").datetime.now().strftime("%A, %d %B").capitalize(),
    }


# ─────────────────────────── Действия ───────────────────────────

def apply_opacity(active, inactive):
    """Применить прозрачность окон; вернуть (ok, message)."""
    active = max(0.30, min(1.0, float(active)))
    inactive = max(0.25, min(1.0, float(inactive)))
    # 0.56: hyprctl eval — lua; keyword как запасной вариант.
    r = sh(["hyprctl", "eval",
            f"hl.config({{decoration={{active_opacity={active},inactive_opacity={inactive}}}}})"])
    if not r or r.returncode != 0:
        sh(["hyprctl", "keyword", "decoration:active_opacity", str(active)])
        sh(["hyprctl", "keyword", "decoration:inactive_opacity", str(inactive)])
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(f"{active} {inactive}\n")
    return active, inactive


def set_brightness(value):
    value = max(1, min(100, int(value)))
    try:
        maxv = int((BRIGHTNESS / "max_brightness").read_text().strip())
        target = max(1, round(maxv * value / 100))
        try:
            (BRIGHTNESS / "brightness").write_text(str(target))
            return True
        except PermissionError:
            # прямой записи нет — sudo -A с нашим askpass
            r = sh(["sudo", "-A", "-p", "", "tee", str(BRIGHTNESS / "brightness")],
                   input=f"{target}\n") if ASKPASS.exists() else None
            return bool(r and r.returncode == 0)
    except Exception:
        return False


def run_action(payload):
    cmd = payload.get("cmd")
    ok, msg = False, ""

    if cmd == "volume":
        sh(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{int(payload.get('value',0))}%"])
        ok = True
    elif cmd == "mute":
        sh(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        ok = True
    elif cmd == "brightness":
        ok = set_brightness(payload.get("value", 50))
        msg = "яркость" if ok else "нет доступа к подсветке"
    elif cmd == "opacity":
        a, b = apply_opacity(payload.get("value", 100) / 100, payload.get("value", 100) / 100 - 0.05)
        ok, msg = True, f"{a:.2f}"
    elif cmd == "app":
        app = payload.get("id", "")
        if app == "terminal":
            sh_bg(["kitty"])
        elif app == "files":
            sh_bg(["dolphin"])
        elif app == "browser":
            sh_bg(["firefox"])
        elif app == "chromium":
            sh_bg(["chromium"])
        elif app == "btop":
            sh_bg(["kitty", "-e", "btop"])
        elif app == "audio":
            sh_bg(["pavucontrol"])
        elif app == "bluetooth":
            sh_bg(["blueman-manager"])
        elif app == "network":
            sh_bg(["nm-connection-editor"])
        elif app == "mpv":
            sh_bg(["mpv"])
        elif app == "vim":
            sh_bg(["kitty", "-e", "vim"])
        elif app == "thunar":
            sh_bg(["thunar"])
        else:
            msg = "нет такого приложения"
        ok = not msg
    elif cmd == "wifi":
        sh(["nmcli", "radio", "wifi", "on" if payload.get("on") else "off"])
        ok = True
    elif cmd == "netmenu":
        sh_bg([str(HOME / ".config/hypr/scripts/eclipse-network.sh"), "menu"])
        ok = True
    elif cmd == "media":
        action = payload.get("action", "play-pause")
        sh(["playerctl", action])
        ok = True
    elif cmd == "power":
        action = payload.get("action", "")
        if action == "lock":
            sh_bg(["hyprlock"])
            ok = True
        elif action == "logout":
            sh(["hyprctl", "dispatch", "exit"])
            ok = True
        elif action == "suspend":
            sh_bg(["loginctl", "suspend"])
            ok = True
        elif action in ("reboot", "shutdown"):
            sh_bg(["systemctl", action])
            ok = True
        else:
            msg = "нет такого действия питания"
    elif cmd == "close":
        # закрыть именно окно лаунчера (0.56: dispatch — Lua)
        r = sh(["hyprctl", "-j", "clients"])
        if r:
            try:
                for w in json.loads(r.stdout):
                    if w.get("title") == "Lunar Launcher" and w.get("address"):
                        addr = w["address"]
                        sh(["hyprctl", "dispatch",
                            "hl.dsp.window.close({ window = 'address:%s' })" % addr])
                        ok = True
                        break
            except Exception:
                pass
        if not ok:
            msg = "окно лаунчера не найдено"
    else:
        msg = f"неизвестная команда: {cmd}"

    return {"ok": ok, "msg": msg}


# ─────────────────────────── HTTP ────────────────────────────────

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _file(self, rel):
        path = (WEB / rel.lstrip("/")).resolve()
        if not str(path).startswith(str(WEB)) or not path.is_file():
            self._json({"ok": False}, 404)
            return
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", MIME.get(path.suffix, "application/octet-stream"))
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/api/state":
            self._json(state())
        elif self.path.startswith("/quit"):
            self._json({"ok": True})
        elif self.path in ("/", "/index.html", "/style.css", "/app.js"):
            self._file("index.html" if self.path in ("/", "/index.html") else self.path)
        else:
            self._json({"ok": False}, 404)

    def do_POST(self):
        if self.path != "/api/action":
            self._json({"ok": False}, 404)
            return
        try:
            payload = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0)) or 0))
        except Exception:
            payload = {}
        self._json(run_action(payload))

    def do_OPTIONS(self):
        self._json({"ok": True})


def main():
    # фоновый прогон: сервер молчит, состояние обновляется на лету — поток не нужен
    httpd = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    httpd.serve_forever()


if __name__ == "__main__":
    main()