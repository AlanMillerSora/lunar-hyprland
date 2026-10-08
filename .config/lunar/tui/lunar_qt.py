#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════════════
#  Lunar Player — Qt (PySide6). Тот же вид панелей, что в GTK-версии, но на
#  QWidget + QPainter: настоящие обложки (QPixmap), hover, плавный seek.
#  Бэкенд общий — из lunar_tui.py (mpv JSON IPC, yt-dlp, локальные файлы).
#
#  Перерисовка по событию: в покое CPU ~0 (тик идёт только при воспроизведении).
#  Класс окна — `lunar-tui` (та же привязка SUPER+M и правило Hyprland).
# ════════════════════════════════════════════════════════════════════════
import json
import math
import os
import queue as _queue
import random
import signal
import subprocess
import sys
import threading
import time

from PySide6.QtCore import QFileSystemWatcher, QPointF, QRectF, Qt, QTimer
from PySide6.QtGui import (QColor, QFont, QFontMetrics, QPainter, QPainterPath,
                           QPen, QPixmap)
from PySide6.QtWidgets import QApplication, QWidget

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lunar_tui as core  # noqa: E402

APP_ID = "lunar-tui"
TITLE = "Lunar Player"
STATE = os.path.expanduser("~/.config/lunar/player-state.json")
FAV = os.path.expanduser("~/.config/lunar/player-fav.json")
FONT = os.environ.get("LUNAR_TUI_FONT_FAMILY", "Roboto Mono")
WIN_W = int(os.environ.get("LUNAR_TUI_W", "1800"))
WIN_H = int(os.environ.get("LUNAR_TUI_H", "1060"))
SCALE = float(os.environ.get("LUNAR_TUI_SCALE", "1.18"))
OPACITY = float(os.environ.get("LUNAR_TUI_OPACITY", "0.9"))   # плотность единого фона

DEFAULT_PALETTE = {
    "bg": "#0a0b0f", "bgPanel": "#0f1116", "bgCard": "#151920", "bgTrack": "#1d2129",
    "bgHover": "#262b36", "text": "#e6eaf2", "textSoft": "#c3c9d3", "textDim": "#8b93a7",
    "textMuted": "#6f7787", "textFaint": "#565d6b", "accent": "#c9d2e2",
    "accent2": "#e6eaf2", "danger": "#ff003c", "border": "#ffffff12",
    "borderAccent": "#ffffff20",
}

# монохром (пресет mono): палитра 43PR — чёрный фон, белый акцент
MONO_PALETTE = {
    "bg": "#000000", "bgPanel": "#050505", "bgCard": "#0d0d0d", "bgTrack": "#161616",
    "bgHover": "#242832", "text": "#ffffff", "textSoft": "#e6eaf2", "textDim": "#c2c2c2",
    "textMuted": "#8b93a7", "textFaint": "#4a4a4a", "accent": "#ffffff",
    "accent2": "#ffffff", "danger": "#ff003c", "border": "#151515",
    "borderAccent": "#2a2a2a",
}


def _truthy(v):
    return str(v).strip().lower() not in ("", "0", "false", "no", "off")


def load_palette():
    if _truthy(os.environ.get("LUNAR_TUI_MONO", "0")):
        return dict(MONO_PALETTE)          # принудительный монохром
    p = dict(DEFAULT_PALETTE)
    try:
        with open(os.path.expanduser("~/.cache/lunar/palette.json"), encoding="utf-8") as f:
            p.update(json.load(f))
    except (OSError, ValueError):
        pass
    return p


P = load_palette()


def qcol(key, a=1.0):
    """#RRGGBB или #RRGGBBAA (как в палитре риса) → QColor."""
    h = str(P.get(key, "#ffffff")).lstrip("#")
    try:
        r = int(h[0:2], 16)
        g = int(h[2:4], 16)
        b = int(h[4:6], 16)
        if len(h) >= 8:
            a = a * int(h[6:8], 16) / 255.0
    except (ValueError, IndexError):
        r = g = b = 255
    c = QColor(r, g, b)
    c.setAlphaF(max(0.0, min(1.0, a)))
    return c


C = {k: qcol(k) for k in DEFAULT_PALETTE}
C["bg"] = qcol("bg")
# семантические цвета: чёткие акцентные тона поверх единого стекла
ACC = C["accent"]
BORDER = qcol("accent", 0.20)      # рамки панелей
SEP = qcol("accent", 0.12)         # разделители внутри панелей
ACC_TAB = qcol("accent", 0.22)     # активная вкладка
ACC_SOFT = qcol("accent", 0.14)    # выделенная строка
ACC_HOVER = qcol("accent", 0.08)   # наведение
TRACK_OFF = qcol("textFaint", 0.5)


def reload_palette():
    """Перечитать палитру риса (смена темы в Hub) и пересобрать цвета."""
    global P, C, ACC, BORDER, SEP, ACC_TAB, ACC_SOFT, ACC_HOVER, TRACK_OFF
    P = load_palette()
    C = {k: qcol(k) for k in DEFAULT_PALETTE}
    C["bg"] = qcol("bg")
    ACC = C["accent"]
    BORDER = qcol("accent", 0.20)
    SEP = qcol("accent", 0.12)
    ACC_TAB = qcol("accent", 0.22)
    ACC_SOFT = qcol("accent", 0.14)
    ACC_HOVER = qcol("accent", 0.08)
    TRACK_OFF = qcol("textFaint", 0.5)


def rpath(x, y, w, h, r):
    r = max(0.0, min(r, w / 2, h / 2))
    path = QPainterPath()
    path.addRoundedRect(QRectF(x, y, w, h), r, r)
    return path


def border_path(x, y, w, h, r, gx, gw):
    """Рамка скруглённого прямоугольника с разрывом [gx, gx+gw] в верхней кромке
    (под подпись) — без «затирания», чтобы фон оставался единым."""
    r = max(0.0, min(r, w / 2, h / 2))
    d = 2 * r
    path = QPainterPath()
    path.moveTo(gx + gw, y)
    path.lineTo(x + w - r, y)
    path.arcTo(QRectF(x + w - d, y, d, d), 90, -90)
    path.lineTo(x + w, y + h - r)
    path.arcTo(QRectF(x + w - d, y + h - d, d, d), 0, -90)
    path.lineTo(x + r, y + h)
    path.arcTo(QRectF(x, y + h - d, d, d), 270, -90)
    path.lineTo(x, y + r)
    path.arcTo(QRectF(x, y, d, d), 180, -90)
    path.lineTo(gx, y)
    return path


def font_for(size, bold=False):
    f = QFont(FONT)
    f.setPixelSize(max(6, int(round(size * SCALE))))
    f.setBold(bold)
    return f


def T(p, x, y, s, size=12, color=None, bold=False, width=None, align="left"):
    f = font_for(size, bold)
    p.setFont(f)
    p.setPen(color if color is not None else C["text"])
    fm = QFontMetrics(f)
    if width is not None:
        s = fm.elidedText(s, Qt.ElideRight, int(width))
    tw = fm.horizontalAdvance(s)
    if width is not None and align == "center":
        x += (width - tw) / 2
    elif width is not None and align == "right":
        x += width - tw
    p.drawText(QPointF(x, y + fm.ascent()), s)
    return tw, fm.height()


def TW(p, s, size=12, bold=False):
    return QFontMetrics(font_for(size, bold)).horizontalAdvance(s)


_pm_cache = {}


def scaled_pm(pm, w, h):
    key = (id(pm), w, h)
    if key in _pm_cache:
        return _pm_cache[key]
    s = pm.scaled(max(1, w), max(1, h), Qt.KeepAspectRatioByExpanding,
                  Qt.SmoothTransformation)
    if len(_pm_cache) > 400:
        _pm_cache.clear()
    _pm_cache[key] = s
    return s


def inrect(pt, r):
    x, y = pt
    return r[0] <= x <= r[0] + r[2] and r[1] <= y <= r[1] + r[3]


class Player:
    def __init__(self):
        self.mpv = core.Mpv(f"/tmp/lunar-qt-{os.getpid()}.sock")
        self._mpv_started = False
        self.lib_local = core.scan_local(core.load_config())
        self.queue = []
        self.search_results = []
        self.tabs = ["ОЧЕРЕДЬ", "ПОИСК", "ЛОКАЛЬНЫЕ", "ИЗБРАННОЕ"]
        self.tab = 0
        self.sel = [0, 0, 0, 0]
        self.focus = "list"
        self.query = ""
        self.searching = False
        self.status = ""
        self.status_t = 0.0
        self.shuffle = False
        self.repeat = 0
        self.qindex = -1
        self.playing_track = None
        self.tick = 0
        self.out = _queue.Queue()
        self.covers = {}
        self.pending = set()
        self.cava = []
        self._cava = None
        self.mouse = (-1, -1)
        self.hit = {}
        self.drag_src = None
        self.drag_dst = None
        self.dragging = False
        self._vol0 = None
        self.favorites = []
        self.playlists = []
        self.load_state()
        self.load_fav()

    def load_state(self):
        try:
            with open(STATE) as f:
                d = json.load(f)
            self.queue = d.get("queue") or []
            self.qindex = int(d.get("qindex", -1))
            self.tab = int(d.get("tab", 0)) % len(self.tabs)
            self.shuffle = bool(d.get("shuffle", False))
            self.repeat = int(d.get("repeat", 0)) % 3
            if d.get("volume") is not None:
                self._vol0 = int(d["volume"])
        except Exception:
            pass

    def save_state(self):
        try:
            vol = self.vol() if self._mpv_started else (self._vol0 if self._vol0 is not None else 100)
            os.makedirs(os.path.dirname(STATE), exist_ok=True)
            with open(STATE, "w") as f:
                json.dump({"queue": self.queue, "qindex": self.qindex,
                           "tab": self.tab, "shuffle": self.shuffle,
                           "repeat": self.repeat, "volume": vol}, f)
        except Exception:
            pass

    def load_fav(self):
        try:
            with open(FAV) as f:
                d = json.load(f)
            self.favorites = d.get("favorites") or []
            self.playlists = d.get("playlists") or []
        except Exception:
            pass

    def save_fav(self):
        try:
            os.makedirs(os.path.dirname(FAV), exist_ok=True)
            with open(FAV, "w") as f:
                json.dump({"favorites": self.favorites, "playlists": self.playlists}, f)
        except Exception:
            pass

    def is_fav(self, track):
        tid = track.get("id") if track else None
        return bool(tid) and any(t.get("id") == tid for t in self.favorites)

    def toggle_fav(self, track):
        if not track or not track.get("id"):
            self.status_set("нечего добавлять в избранное")
            return
        if self.is_fav(track):
            self.favorites = [t for t in self.favorites if t.get("id") != track.get("id")]
            self.status_set("убрал из избранного")
        else:
            self.favorites.append(track)
            self.status_set("в избранное: " + track.get("title", "")[:30])
        self.save_fav()

    def save_playlist(self):
        if not self.queue:
            self.status_set("очередь пуста — нечего сохранять")
            return
        name = "Плейлист " + str(len(self.playlists) + 1)
        self.playlists.append({"name": name, "tracks": list(self.queue)})
        self.save_fav()
        self.status_set("сохранил: " + name)

    def load_playlist(self, i):
        if 0 <= i < len(self.playlists):
            pl = self.playlists[i]
            self.queue = list(pl.get("tracks") or [])
            self.qindex = -1
            self.tab = 0
            self.status_set("загрузил: " + pl.get("name", ""))

    def lists(self):
        return [self.queue, self.search_results, self.lib_local, self.favorites]

    def current(self):
        return self.lists()[self.tab], self.tab

    def status_set(self, s):
        self.status = s
        self.status_t = time.time()

    def ensure_mpv(self):
        if not self._mpv_started:
            try:
                self.mpv.start()
                self._mpv_started = True
                if self._vol0 is not None:
                    self.mpv.set_volume(max(0, min(100, self._vol0)))
            except Exception:
                pass

    def start_track(self, track, source=None):
        self.ensure_mpv()
        self.start_cava()
        if source is not None:
            self.queue = list(source)
            try:
                self.qindex = self.queue.index(track)
            except ValueError:
                self.qindex = 0
        self.playing_track = track
        self.mpv.load(track["url"])
        self.status_set("играю: " + track.get("title", "")[:40])
        self.want_cover(track)

    def next_track(self, fwd=True):
        if not self.queue:
            return
        if self.repeat == 2 and fwd and self.qindex >= 0:      # повтор одного
            self.start_track(self.queue[self.qindex])
            return
        if self.shuffle:
            self.qindex = random.randrange(len(self.queue))
        else:
            nxt = self.qindex + (1 if fwd else -1)
            if self.repeat == 0 and fwd and nxt >= len(self.queue):   # конец без повтора
                self.status_set("очередь закончилась")
                return
            self.qindex = nxt % len(self.queue)
        self.start_track(self.queue[self.qindex])

    def move_in_queue(self, src, dst):
        if src is None or dst is None:
            return
        if not (0 <= src < len(self.queue)):
            return
        dst = max(0, min(len(self.queue) - 1, dst))
        if src == dst:
            return
        tr = self.queue.pop(src)
        self.queue.insert(dst, tr)
        if self.qindex == src:
            self.qindex = dst
        elif src < self.qindex <= dst:
            self.qindex -= 1
        elif dst <= self.qindex < src:
            self.qindex += 1
        self.status_set("переставил: " + tr.get("title", "")[:30])

    def _local_cover(self, track):
        d = os.path.dirname(track.get("url", ""))
        for n in ("cover.jpg", "cover.png", "folder.jpg", "folder.png",
                  "front.jpg", "album.jpg"):
            if os.path.exists(os.path.join(d, n)):
                return os.path.join(d, n)
        return None

    def want_cover(self, track):
        if not track:
            return
        tid = track.get("id")
        if not tid or tid in self.covers or tid in self.pending:
            return
        if track.get("source") == "yt":
            self.pending.add(tid)
            core.yt_thumbnail(track, self.out)
        else:
            path = self._local_cover(track)
            if path:
                self._load_cover(tid, path)

    def _load_cover(self, tid, path):
        if path and os.path.exists(path):
            pm = QPixmap(path)
            if not pm.isNull():
                self.covers[tid] = pm
        self.pending.discard(tid)

    def pump(self):
        fresh = False
        try:
            while True:
                item = self.out.get_nowait()
                fresh = True
                if item[0] == "search":
                    _, res, err = item
                    self.searching = False
                    if res:
                        self.search_results = res
                        self.tab = 1
                        self.sel[1] = 0
                        self.status_set(f"найдено: {len(res)}")
                    else:
                        self.status_set("поиск: " + (err or "пусто"))
                elif item[0] == "art":
                    _, tid, path = item
                    self._load_cover(tid, path)
        except _queue.Empty:
            pass
        for ev, reason in self.mpv.drain_events():
            if ev == "end-file" and reason == "eof" and self.queue:
                self.next_track(True)
                fresh = True
        return fresh

    def playing(self):
        return self.playing_track is not None and self.mpv.get("pause") is False

    def vol(self):
        return int(self.mpv.get("volume", 100) or 100)

    def set_vol(self, v):
        self.ensure_mpv()
        self.mpv.set_volume(max(0, min(100, v)))

    def start_cava(self):
        if self._cava is not None:
            return
        conf = os.path.expanduser("~/.config/lunar/tui/cava.conf")
        if not os.path.exists(conf):
            return
        try:
            self._cava = subprocess.Popen(
                ["cava", "-p", conf], stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
        except Exception:
            self._cava = None
            return
        threading.Thread(target=self._cava_read, args=(self._cava,), daemon=True).start()

    def _cava_read(self, proc):
        try:
            for line in proc.stdout:
                vals = [int(v) for v in line.split() if v.isdigit()]
                if vals:
                    self.cava = vals
        except Exception:
            pass

    def stop_cava(self):
        proc, self._cava = self._cava, None
        if proc and proc.poll() is None:
            try:
                proc.terminate()
                proc.wait(timeout=1)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass

    def do_search(self):
        q = self.query.strip()
        self.focus = "list"
        if not q:
            return
        self.searching = True
        self.search_results = []
        self.status_set("ищу: " + q[:30] + "…")
        core.yt_search(q, self.out)

    def key(self, name):
        if self.focus == "search":
            if name in ("Return", "Enter"):
                self.do_search()
            elif name == "Escape":
                self.focus = "list"
            elif name == "Backspace":
                self.query = self.query[:-1]
            elif name == "space":
                self.query += " "
            elif len(name) == 1 and name.isprintable():
                self.query += name
            return
        if name == "Escape":
            QApplication.quit()
        elif name == "q":
            QApplication.quit()
        elif name == "Tab":
            self.tab = (self.tab + 1) % len(self.tabs)
        elif name in ("slash", "/"):
            self.focus = "search"
            self.query = ""
        elif name in ("Up", "Down"):
            lst, ti = self.current()
            if lst:
                self.sel[ti] = max(0, min(len(lst) - 1, self.sel[ti] + (1 if name == "Down" else -1)))
        elif name in ("Return", "Enter"):
            lst, ti = self.current()
            if lst and self.sel[ti] < len(lst):
                self.start_track(lst[self.sel[ti]], lst)
        elif name == "space":
            self.ensure_mpv()
            self.mpv.play_pause()
        elif name == "Left":
            self.mpv.seek_rel(-5)
        elif name == "Right":
            self.mpv.seek_rel(5)
        elif name == "n":
            self.next_track(True)
        elif name == "p":
            self.next_track(False)
        elif name == "s":
            self.shuffle = not self.shuffle
        elif name == "r":
            self.repeat = (self.repeat + 1) % 3
            self.status_set("повтор: " + ("выкл", "все", "один")[self.repeat])
        elif name == "f":
            lst, ti = self.current()
            tr = lst[self.sel[ti]] if (lst and self.sel[ti] < len(lst)) else self.playing_track
            self.toggle_fav(tr)
        elif name == "S":
            self.save_playlist()
        elif name == "m":
            self.ensure_mpv()
            self.mpv.set_mute(not self.mpv.get("mute", False))
        elif name in ("plus", "equal"):
            self.set_vol(self.vol() + 5)
        elif name == "minus":
            self.set_vol(self.vol() - 5)
        elif name == "a":
            lst, ti = self.current()
            if self.tab != 0 and lst and self.sel[ti] < len(lst):
                tr = lst[self.sel[ti]]
                if tr not in self.queue:
                    self.queue.append(tr)
                    self.status_set("в очередь: " + tr.get("title", "")[:30])

    def click(self, x, y):
        h = self.hit
        for key, r in h.get("nav", {}).items():
            if inrect((x, y), r):
                if key == "home":
                    self.tab = 0
                    self.focus = "list"
                    self.query = ""
                elif key == "prev":
                    self.tab = (self.tab - 1) % len(self.tabs)
                else:
                    self.tab = (self.tab + 1) % len(self.tabs)
                return
        if "lib_add" in h and inrect((x, y), h["lib_add"]):
            self.lib_local = core.scan_local(core.load_config())
            self.status_set("обновил фонотеку: " + str(len(self.lib_local)))
            return
        for i, r in enumerate(h.get("librows", [])):
            if inrect((x, y), r):
                if 0 <= i < len(self.queue):
                    self.qindex = i
                    self.start_track(self.queue[i])
                return
        for r, idx in h.get("pl", []):
            if inrect((x, y), r):
                self.load_playlist(idx)
                return
        if "search" in h and inrect((x, y), h["search"]):
            self.focus = "search"
            return
        for i, r in enumerate(h.get("tabs", [])):
            if inrect((x, y), r):
                self.tab = i
                return
        for row in h.get("rows", []):
            if inrect((x, y), row[0]):
                self.sel[self.tab] = row[1]
                self.start_track(row[2], self.current()[0])
                return
        for i, r in enumerate(h.get("lib", [])):
            if inrect((x, y), r):
                self.tab = i
                return
        for name, r in h.get("btn", {}).items():
            if inrect((x, y), r):
                if name == "prev":
                    self.next_track(False)
                elif name == "next":
                    self.next_track(True)
                elif name == "play":
                    self.ensure_mpv()
                    self.mpv.play_pause()
                elif name == "shuffle":
                    self.shuffle = not self.shuffle
                elif name == "repeat":
                    self.repeat = (self.repeat + 1) % 3
                elif name == "fav":
                    self.toggle_fav(self.playing_track)
                return
        if "seek" in h and inrect((x, y), h["seek"]):
            dur = self.mpv.get("duration") or 0
            if dur:
                rx, ry, rw, rh = h["seek"]
                self.mpv.seek_abs(max(0.0, min(1.0, (x - rx) / max(1, rw))) * dur)
            return
        if "vol" in h and inrect((x, y), h["vol"]):
            rx, ry, rw, rh = h["vol"]
            self.set_vol(int(100 * max(0.0, min(1.0, (x - rx) / max(1, rw)))))


class Lunar(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(TITLE)
        self.setWindowFlags(Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_TranslucentBackground, True)   # фон — один прозрачный слой
        self.setAttribute(Qt.WA_NoSystemBackground, True)
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.StrongFocus)
        self.resize(WIN_W, WIN_H)
        self.p = Player()
        self._anim = QTimer(self)
        self._anim.timeout.connect(self._tick)
        self._anim.start(90)
        self._poll = QTimer(self)
        self._poll.timeout.connect(self._pump)
        self._poll.start(150)
        self._hover = None
        self._press = None
        # слежу за палитрой риса: смена темы в Hub перекрашивает плеер на лету
        self._pal_path = os.path.expanduser("~/.cache/lunar/palette.json")
        self._pal_watch = QFileSystemWatcher([self._pal_path])
        self._pal_watch.fileChanged.connect(self._pal_changed)

    def _pal_changed(self, _p):
        reload_palette()
        try:
            self._pal_watch.addPath(self._pal_path)
        except Exception:
            pass
        self.update()

    def _pump(self):
        if self.p.pump():
            self.update()

    def _tick(self):
        self.p.tick += 1
        if self.p.playing() or self.p.searching or self.p.cava:
            self.update()

    # ── геометрия (логические единицы; отрисовка масштабируется) ──
    def onscreen(self):
        self._logical = [self.width() / SCALE, self.height() / SCALE]
        return self._logical

    def geometry_(self):
        W, H = self.width() / SCALE, self.height() / SCALE
        m, gap = 12, 10
        nav = (m, m, W - 2 * m, 50)
        ph = 156
        play = (m, H - m - ph, W - 2 * m, ph)
        midy = m + 50 + gap
        midh = play[1] - gap - midy
        lib = (m, midy, 316, midh)
        side = (W - m - 356, midy, 356, midh)
        main = (lib[0] + lib[2] + gap, midy, side[0] - gap - (lib[0] + lib[2] + gap), midh)
        return {"nav": nav, "lib": lib, "main": main, "side": side, "play": play}

    def paintEvent(self, _e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing, True)
        p.setRenderHint(QPainter.TextAntialiasing, True)
        p.setRenderHint(QPainter.SmoothPixmapTransform, True)
        self.p.hit = {}
        p.fillRect(self.rect(), qcol("bg", OPACITY))
        p.scale(SCALE, SCALE)
        g = self.geometry_()
        self.draw_nav(p, g)
        self.draw_library(p, g)
        self.draw_main(p, g)
        self.draw_sidebar(p, g)
        self.draw_playing(p, g)
        p.end()

    def panel(self, p, r, label):
        x, y, w, h = r
        gx = x + 18
        gw = (TW(p, label, 10, True) + 8) if label else 0
        p.setPen(QPen(BORDER, 1))
        p.setBrush(Qt.NoBrush)              # без собственной заливки — фон единый
        p.drawPath(border_path(x, y, w, h, 14, gx, gw))
        if label:
            T(p, gx + 4, y - 8, label, size=10, color=C["textFaint"], bold=True)

    def draw_nav(self, p, g):
        x, y, w, h = g["nav"]
        self.panel(p, g["nav"], "[ NAV ]")
        cy = y + h / 2 - 9
        # навигация — живые кнопки: ‹ › листают вкладки, ⌂ возвращает к очереди
        self.p.hit["nav"] = {}
        for key, gl, dx in (("prev", "‹", 0), ("next", "›", 26), ("home", "⌂", 54)):
            box = (x + 18 + dx, y + h / 2 - 15, 22, 30)
            self.p.hit["nav"][key] = box
            hov = inrect(self.p.mouse, box)
            T(p, box[0] + 3, cy, gl, size=13,
              color=C["accent"] if hov else C["textFaint"])
        T(p, x + 96, cy - 1, "LUNAR PLAYER", size=14, color=C["accent"], bold=True)
        sw = max(120, min(560, w - 560))
        sx = x + (w - sw) / 2
        sh, sy = 30, y + (h - 30) / 2
        p.setPen(QPen(C["borderAccent"] if self.p.focus == "search" else C["border"], 1))
        p.setBrush(C["bgCard"])
        p.drawPath(rpath(sx, sy, sw, sh, 8))
        ph = self.p.query if (self.p.focus == "search" or self.p.query) else "что хочешь послушать?"
        T(p, sx + 14, sy + sh / 2 - 8, "⌕", size=12, color=C["textDim"])
        T(p, sx + 34, sy + sh / 2 - 8, ph, size=12,
          color=C["text"] if (self.p.focus == "search" or self.p.query) else C["textFaint"],
          width=sw - 48)
        self.p.hit["search"] = (sx, sy, sw, sh)
        pause = self.p.mpv.get("pause")
        if self.p.playing_track and pause is False:
            st, sc = "играет", C["accent"]
        elif self.p.playing_track:
            st, sc = "пауза", C["textDim"]
        else:
            st, sc = "стоп", C["textFaint"]
        T(p, x + w - 130, cy, st, size=12, color=sc)
        T(p, x + w - 56, cy, time.strftime("%H:%M"), size=12, color=C["textDim"])

    def draw_library(self, p, g):
        x, y, w, h = g["lib"]
        self.panel(p, g["lib"], "[ LIBRARY ]")
        px, py = x + 18, y + 18
        T(p, px, py, "[ ТВОЯ ФОНОТЕКА ]", size=12, color=C["textDim"], bold=True)
        add_box = (x + w - 44, py - 6, 26, 26)
        self.p.hit["lib_add"] = add_box
        T(p, x + w - 30, py - 2, "+", size=16,
          color=C["accent"] if inrect(self.p.mouse, add_box) else C["textDim"])
        py += 30
        p.setPen(QPen(SEP, 1))
        p.drawLine(QPointF(px, py), QPointF(x + w - 18, py))
        py += 8
        items = [("♪", "ОЧЕРЕДЬ", len(self.p.queue)),
                 ("⌕", "РЕЗУЛЬТАТЫ", len(self.p.search_results)),
                 ("▤", "ЛОКАЛЬНЫЕ", len(self.p.lib_local)),
                 ("★", "ИЗБРАННОЕ", len(self.p.favorites))]
        self.p.hit["lib"] = []
        for i, (ic, nm, cnt) in enumerate(items):
            rr = (px, py, w - 36, 30)
            self.p.hit["lib"].append(rr)
            sel = self.p.tab == i
            hov = inrect(self.p.mouse, rr)
            if sel or hov:
                p.setPen(Qt.NoPen)
                p.setBrush(ACC_SOFT if sel else ACC_HOVER)
                p.drawPath(rpath(*rr, 8))
            if sel:
                p.setPen(Qt.NoPen)
                p.setBrush(C["accent"])
                p.drawPath(rpath(px, py + 7, 3, 16, 1.5))
            T(p, px + 12, py + 6, ic + "  " + nm, size=12,
              color=C["accent"] if sel else C["textDim"], bold=sel)
            T(p, x + w - 44, py + 6, str(cnt), size=12,
              color=C["accent"] if sel else C["textFaint"], align="right", width=28)
            py += 34
        py += 12
        T(p, px, py, "[ В ОЧЕРЕДИ ]", size=11, color=C["textFaint"])
        py += 22
        hint_y = y + h - 96
        pl_n = min(len(self.p.playlists), 4) if self.p.playlists else 0
        q_bottom = hint_y - (18 * pl_n + 24 if pl_n else 0)
        avail = max(0, int((q_bottom - py) / 26))
        self.p.hit["librows"] = []
        for i, tr in enumerate(self.p.queue[:avail]):
            cur = i == self.p.qindex
            rr = (px, py, w - 36, 24)
            self.p.hit["librows"].append(rr)
            hov = inrect(self.p.mouse, rr)
            if hov and not cur:
                p.setPen(Qt.NoPen)
                p.setBrush(ACC_HOVER)
                p.drawPath(rpath(*rr, 6))
            star = "★ " if self.p.is_fav(tr) else ""
            txt = (f"{'♪ ' if cur else ''}{star}[{i + 1:02d}]  {tr.get('title', '')}")
            T(p, px + 4, py, txt, size=11, color=C["accent"] if cur else C["textDim"], width=w - 40)
            py += 26
        self.p.hit["pl"] = []
        if pl_n:
            py2 = q_bottom + 6
            T(p, px, py2, "[ ПЛЕЙЛИСТЫ ] · S сохранить", size=11, color=C["textFaint"])
            yy = py2 + 20
            for i in range(len(self.p.playlists) - pl_n, len(self.p.playlists)):
                pl = self.p.playlists[i]
                rr = (px, yy, w - 36, 18)
                self.p.hit["pl"].append((rr, i))
                hov = inrect(self.p.mouse, rr)
                T(p, px + 4, yy, "▸ " + pl.get("name", ""), size=10,
                  color=C["accent"] if hov else C["textDim"], width=w - 40)
                yy += 18
        p.setPen(QPen(SEP, 1))
        p.drawLine(QPointF(px, hint_y), QPointF(x + w - 18, hint_y))
        for i, hh in enumerate(["space пауза · n/p трек · r повтор", "←/→ ±5с · s шаффл",
                                "клик — играть · drag — переставить", "f избранное · S плейлист"]):
            T(p, px, hint_y + 10 + i * 18, hh, size=10, color=C["textFaint"])

    def draw_main(self, p, g):
        x, y, w, h = g["main"]
        self.panel(p, g["main"], "[ MAIN ]")
        px, py = x + 18, y + 16
        self.p.hit["tabs"] = []
        cx = px
        for i, nm in enumerate(self.p.tabs):
            act = i == self.p.tab
            tw = TW(p, nm, 11, True) + 26
            rr = (cx, py, tw, 26)
            self.p.hit["tabs"].append(rr)
            hov = inrect(self.p.mouse, rr)
            if act or hov:
                p.setPen(Qt.NoPen)
                p.setBrush(ACC_TAB if act else ACC_HOVER)
                p.drawPath(rpath(*rr, 8))
            T(p, cx + 13, py + 4, nm, size=11, color=C["accent"] if act else C["textDim"], bold=act)
            cx += tw + 8
        py += 38
        p.setPen(QPen(SEP, 1))
        p.drawLine(QPointF(px, py), QPointF(x + w - 18, py))
        py += 8

        list_, ti = self.p.current()
        right = x + w - 18
        dur_w, art_w, th = 52, (200 if w > 500 else 0), 24
        num_x, title_x = px + 34, px + 76
        dur_x = right - dur_w
        art_x = (dur_x - art_w - 14) if art_w else dur_x
        T(p, num_x, py, "№", size=10, color=C["textDim"])
        T(p, title_x, py, "НАЗВАНИЕ", size=10, color=C["textDim"])
        if art_w:
            T(p, art_x, py, "ИСПОЛНИТЕЛЬ", size=10, color=C["textDim"])
        T(p, dur_x, py, "ДЛИТ", size=10, color=C["textDim"], align="right", width=dur_w)
        py += 22
        p.setPen(QPen(SEP, 1))
        p.drawLine(QPointF(px, py), QPointF(x + w - 18, py))
        py += 6

        if self.p.tab == 1 and self.p.searching:
            T(p, px, py + 6, "⌕  ищу в YouTube…", size=12, color=C["accent"])
            list_ = []
        if not list_:
            msg = ("нажми / и введи запрос" if self.p.tab == 1
                   else ("очередь пуста — найди трек в ПОИСКЕ" if self.p.tab == 0
                         else "нет локальных файлов"))
            T(p, px, py + 6, msg, size=12, color=C["textFaint"])
            return

        row_h = 36
        avail = int((y + h - 16 - py) / row_h)
        sel = self.p.sel[ti]
        start = max(0, sel - avail + 1) if avail > 0 else 0
        self.p.hit["rows"] = []
        for i in range(start, min(len(list_), start + avail)):
            tr = list_[i]
            ry = py + (i - start) * row_h
            rr = (px, ry, w - 36, row_h - 4)
            self.p.hit["rows"].append((rr, i, tr))
            selected = i == sel and self.p.focus != "search"
            hov = inrect(self.p.mouse, rr)
            now = self.p.playing_track and tr.get("id") == self.p.playing_track.get("id")
            if self.p.dragging and i == self.p.drag_src:
                p.setPen(QPen(C["accent"], 1, Qt.DashLine))
                p.setBrush(Qt.NoBrush)
                p.drawPath(rpath(*rr, 8))
            if self.p.dragging and self.p.drag_dst is not None \
                    and i == self.p.drag_dst and self.p.drag_dst != self.p.drag_src:
                ly = (ry - 2) if self.p.drag_dst > self.p.drag_src else (ry + row_h - 2)
                p.setPen(QPen(C["accent"], 2))
                p.drawLine(QPointF(px, ly), QPointF(x + w - 18, ly))
            if selected or hov:
                p.setPen(Qt.NoPen)
                p.setBrush(ACC_SOFT if selected else ACC_HOVER)
                p.drawPath(rpath(*rr, 8))
            if selected:
                p.setPen(Qt.NoPen)
                p.setBrush(C["accent"])
                p.drawPath(rpath(px, ry + 6, 3, row_h - 16, 1.5))
            self.cover(p, px + 8, ry + 4, th, th, 6, self.p.covers.get(tr.get("id")), small=True)
            mid = ry + (row_h - 4) / 2 - 9
            T(p, num_x, mid, f"[{i + 1:02d}]", size=11, color=C["textFaint"])
            tcol = C["accent"] if now else (C["text"] if selected else C["textDim"])
            star = "★ " if self.p.is_fav(tr) else ""
            T(p, title_x, mid, star + tr.get("title", ""), size=12, color=tcol, bold=bool(now or selected),
              width=max(40, (art_x if art_w else dur_x) - 14 - title_x))
            if art_w:
                T(p, art_x, mid, tr.get("artist", ""), size=11, color=C["textFaint"], width=art_w)
            T(p, dur_x, mid, core.fmt_time(tr.get("duration")), size=11,
              color=C["textFaint"], align="right", width=dur_w)
            if i - start < 12:
                self.p.want_cover(tr)

    def draw_sidebar(self, p, g):
        x, y, w, h = g["side"]
        self.panel(p, g["side"], "[ SIDEBAR ]")
        px, py = x + 18, y + 18
        T(p, px, py, "[ СЕЙЧАС ИГРАЕТ ]", size=11, color=C["textFaint"])
        tr = self.p.playing_track
        py += 20
        strip_h = 26
        if not self.draw_cava(p, px, py, w - 36, strip_h, C["accent"]) and tr and self.p.playing():
            self.eq(p, x + w - 64, py, C["accent"])
        py += strip_h + 12
        cs = min(w - 36, 300)
        self.cover(p, x + (w - cs) / 2, py, cs, cs, 12, self.p.covers.get(tr.get("id")) if tr else None)
        py += cs + 16
        if tr:
            T(p, px, py, tr.get("title", ""), size=14, color=C["accent"], bold=True, width=w - 36)
            py += 24
            T(p, px, py, tr.get("artist", ""), size=12, color=C["textDim"], width=w - 36)
            py += 22
            T(p, px, py, "YouTube · стрим" if tr.get("source") == "yt" else "Локальный файл",
              size=11, color=C["textFaint"])
            py += 26
        else:
            T(p, px, py, "ничего не играет", size=12, color=C["textFaint"])
            py += 26
        p.setPen(QPen(SEP, 1))
        p.drawLine(QPointF(px, py), QPointF(x + w - 18, py))
        py += 10
        T(p, px, py, "[ ДЕТАЛИ ]", size=11, color=C["textFaint"])
        py += 22
        if tr:
            rows = [("Источник", "YouTube" if tr.get("source") == "yt" else "файл"),
                    ("В очереди", f"{self.p.qindex + 1} / {len(self.p.queue)}" if self.p.queue else "—"),
                    ("Длительность", core.fmt_time(tr.get("duration"))),
                    ("Состояние", "играет" if self.p.playing() else "пауза")]
            for k, v in rows:
                T(p, px, py, k, size=11, color=C["textFaint"])
                T(p, px + 120, py, v, size=11, color=C["textDim"], width=w - 36 - 120)
                py += 22

    def draw_playing(self, p, g):
        x, y, w, h = g["play"]
        self.panel(p, g["play"], "[ PLAYING ]")
        px, py = x + 18, y + 18
        tr = self.p.playing_track
        playing = self.p.playing()
        cov = 84
        self.cover(p, px, py, cov, cov, 8, self.p.covers.get(tr.get("id")) if tr else None)
        tx = px + cov + 18
        T(p, tx, py + 8, tr.get("title", "") if tr else "ничего не играет", size=15,
          color=C["accent"], bold=True, width=w * 0.4)
        if tr:
            T(p, tx, py + 34, tr.get("artist", ""), size=12, color=C["textDim"], width=w * 0.4)
            T(p, tx, py + 56, "YouTube" if tr.get("source") == "yt" else "файл",
              size=11, color=C["textFaint"])
        self.p.hit["btn"] = {}
        ccx = x + w / 2

        def centred(box, glyph, size, color):
            bx_, by_, bw_, bh_ = box
            gw = TW(p, glyph, size)
            T(p, bx_ + (bw_ - gw) / 2, by_ + bh_ / 2 - size * 0.72, glyph, size=size, color=color)

        # play/pause — залитый акцентом круг
        play_box = (ccx - 24, py + 10, 48, 48)
        self.p.hit["btn"]["play"] = play_box
        p.setPen(Qt.NoPen)
        p.setBrush(C["accent"])
        p.drawEllipse(QRectF(*play_box))
        centred(play_box, "▮▮" if playing else "▶", 20, qcol("bg"))
        for name, gl, dx, size in (("prev", "⇤", -86, 20), ("next", "⇥", 50, 20),
                                   ("shuffle", "⇄", 92, 18), ("repeat", "↻", 132, 18)):
            box = (ccx + dx - 14, py + 22, 28, 28)
            self.p.hit["btn"][name] = box
            hov = inrect(self.p.mouse, box)
            on = (name == "shuffle" and self.p.shuffle) or \
                 (name == "repeat" and self.p.repeat)
            c = C["accent"] if (hov or on) else C["textFaint"]
            centred(box, gl, size, c)
        fav_box = (ccx + 172 - 14, py + 22, 28, 28)
        self.p.hit["btn"]["fav"] = fav_box
        isf = self.p.is_fav(tr)
        centred(fav_box, "★" if isf else "☆", 18,
                C["accent"] if (isf or inrect(self.p.mouse, fav_box)) else C["textFaint"])
        vw = 160
        vx = x + w - 36 - vw
        vol = self.p.vol()
        muted = self.p.mpv.get("mute", False)
        p.setPen(Qt.NoPen)
        p.setBrush(TRACK_OFF)
        p.drawPath(rpath(vx, py + 33, vw, 4, 2))
        p.setBrush(C["textFaint"] if muted else C["accent"])
        p.drawPath(rpath(vx, py + 33, vw * ((0 if muted else vol) / 100.0), 4, 2))
        self.p.hit["vol"] = (vx, py + 24, vw, 22)
        T(p, vx, py + 8, "MUTE" if muted else f"VOL {vol}%", size=10,
          color=C["textFaint"], align="right", width=vw)
        ry = py + cov + 22
        dur = self.p.mpv.get("duration") or (tr.get("duration") if tr else 0)
        pos = self.p.mpv.get("time-pos") or 0
        lt, rt = f"[ {core.fmt_time(pos)} ]", f"[ {core.fmt_time(dur)} ]"
        lw = 66
        bar_x, bar_w = px + lw, w - 36 - 2 * lw
        T(p, px, ry - 8, lt, size=11, color=C["textFaint"])
        T(p, x + w - 36 - lw, ry - 8, rt, size=11, color=C["textFaint"], align="right", width=lw)
        p.setPen(Qt.NoPen)
        p.setBrush(TRACK_OFF)
        p.drawPath(rpath(bar_x, ry + 1, bar_w, 4, 2))
        frac = min(1.0, (pos / dur) if dur else 0.0)
        p.setBrush(C["accent"])
        p.drawPath(rpath(bar_x, ry + 1, max(0.0, bar_w * frac), 4, 2))
        # риски шкалы — язык «чертёж»
        p.setPen(QPen(SEP, 1))
        for i in range(1, 10):
            tx = bar_x + bar_w * i / 10.0
            p.drawLine(QPointF(tx, ry + 7), QPointF(tx, ry + 11))
        # бегунок: акцентный кружок с тёмной сердцевиной
        p.drawEllipse(QPointF(bar_x + bar_w * frac, ry + 3), 6, 6)
        p.setBrush(C["bg"])
        p.drawEllipse(QPointF(bar_x + bar_w * frac, ry + 3), 2.5, 2.5)
        self.p.hit["seek"] = (bar_x, ry - 8, bar_w, 20)
        msg = self.p.status if (self.p.status and time.time() - self.p.status_t < 5) else \
            "q выход · / поиск · space пауза · n/p трек · s шаффл · r повтор · f избранное"
        T(p, px, y + h - 20, msg, size=10,
          color=C["textDim"] if self.p.status and time.time() - self.p.status_t < 5 else C["textFaint"],
          width=w - 36)

    def cover(self, p, x, y, w, h, r, pm, small=False):
        path = rpath(x, y, w, h, r)
        p.save()
        p.setClipPath(path)
        drawn = False
        if pm is not None and not pm.isNull():
            s = scaled_pm(pm, int(round(w * SCALE)), int(round(h * SCALE)))
            p.save()
            p.resetTransform()
            p.drawPixmap(QRectF(x * SCALE, y * SCALE, w * SCALE, h * SCALE), s,
                         QRectF(0, 0, s.width(), s.height()))
            p.restore()
            drawn = True
        if not drawn:
            p.setPen(Qt.NoPen)
            p.setBrush(C["bgCard"])
            p.drawRect(QRectF(x, y, w, h))
        p.restore()
        if not drawn:
            T(p, x, y + h / 2 - (7 if small else 12), "♪", size=12 if small else 26,
              color=C["textMuted"], align="center", width=w)
        p.setPen(QPen(SEP, 1))
        p.setBrush(Qt.NoBrush)
        p.drawPath(path)

    def draw_cava(self, p, x, y, w, h, color):
        vals = self.p.cava
        if not vals:
            return False
        n = len(vals)
        gap = 2
        bw = max(1.0, (w - gap * (n - 1)) / n)
        p.setPen(Qt.NoPen)
        p.setBrush(color)
        for i, v in enumerate(vals):
            bh = max(1.0, h * min(1.0, v / 1000.0))
            p.drawRect(QRectF(x + i * (bw + gap), y + h - bh, bw, bh))
        return True

    def eq(self, p, x, y, color):
        frames = [[6, 12, 8], [12, 8, 14], [8, 14, 6], [14, 6, 10]]
        f = frames[self.p.tick // 3 % len(frames)]
        p.setPen(Qt.NoPen)
        p.setBrush(color)
        for i, bh in enumerate(f):
            p.drawRect(QRectF(x + i * 5, y + 14 - bh, 3, bh))

    # ── события ──
    def mouseMoveEvent(self, e):
        pos = (e.position().x() / SCALE, e.position().y() / SCALE)
        self.p.mouse = pos
        if self._press is not None and self.p.drag_src is not None:
            dx, dy = pos[0] - self._press[0], pos[1] - self._press[1]
            if not self.p.dragging and (dx * dx + dy * dy) > 36:
                self.p.dragging = True
            if self.p.dragging:
                self.p.drag_dst = self._row_at(pos)
        self.update()

    def _row_at(self, pos):
        for row in self.p.hit.get("rows", []):
            rr = row[0]
            if rr[0] <= pos[0] <= rr[0] + rr[2] and rr[1] - 6 <= pos[1] <= rr[1] + rr[3] + 6:
                return row[1]
        return None

    def mousePressEvent(self, e):
        pos = (e.position().x() / SCALE, e.position().y() / SCALE)
        self._press = pos
        self.p.drag_src = self._row_at(pos) if self.p.tab == 0 else None
        self.p.drag_dst = self.p.drag_src
        self.p.dragging = False
        self.update()

    def mouseReleaseEvent(self, e):
        pos = (e.position().x() / SCALE, e.position().y() / SCALE)
        if self.p.dragging:
            self.p.move_in_queue(self.p.drag_src, self.p.drag_dst)
        else:
            self.p.click(pos[0], pos[1])
        self._press = None
        self.p.drag_src = None
        self.p.drag_dst = None
        self.p.dragging = False
        self.update()

    def wheelEvent(self, e):
        self.p.key("Up" if e.angleDelta().y() > 0 else "Down")
        self.update()

    def keyPressEvent(self, e):
        name = e.key()
        mapping = {
            Qt.Key_Escape: "Escape", Qt.Key_Tab: "Tab", Qt.Key_Return: "Return",
            Qt.Key_Enter: "Return", Qt.Key_Backspace: "Backspace",
            Qt.Key_Up: "Up", Qt.Key_Down: "Down", Qt.Key_Left: "Left", Qt.Key_Right: "Right",
            Qt.Key_Space: "space", Qt.Key_Slash: "slash",
            Qt.Key_Plus: "plus", Qt.Key_Equal: "equal", Qt.Key_Minus: "minus",
        }
        nm = mapping.get(name)
        if nm is None:
            t = e.text()
            nm = t if (len(t) == 1 and t.isprintable()) else ""
        if nm:
            self.p.key(nm)
        self.update()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName(APP_ID)
    app.setDesktopFileName(APP_ID)     # → app_id окна на Wayland (для window_rule)
    app.setQuitOnLastWindowClosed(True)
    w = Lunar()
    w.show()
    w.setFocus()

    # чтобы Python-обработчики сигналов срабатывали при живом Qt-loop
    sig_timer = QTimer()
    sig_timer.timeout.connect(lambda: None)
    sig_timer.start(200)
    signal.signal(signal.SIGINT, lambda *_: app.quit())
    signal.signal(signal.SIGTERM, lambda *_: app.quit())

    def bye():
        try:
            w.p.save_state()
        except Exception:
            pass
        try:
            w.p.save_fav()
        except Exception:
            pass
        try:
            w.p.stop_cava()
        except Exception:
            pass
        try:
            w.p.mpv.stop()
        except Exception:
            pass
    app.aboutToQuit.connect(bye)
    app.exec()


if __name__ == "__main__":
    main()
