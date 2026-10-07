#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════════════
#  Lunar Player — GUI. Тот же вид панелей (Nav/Library/Main/Sidebar/Playing),
#  но нарисованный по-настоящему: настоящие обложки, hover, плавный seek.
#  Бэкенд общий с TUI — беру Mpv/yt-dlp/локальные из lunar_tui.py.
#
#  Класс окна — `lunar-tui` (та же привязка SUPER+M и то же правило Hyprland).
# ════════════════════════════════════════════════════════════════════════
import json
import math
import os
import queue as _queue
import random
import sys
import time

import faulthandler
faulthandler.enable()

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
gi.require_version("GdkPixbuf", "2.0")

from gi.repository import Gdk, GdkPixbuf, GLib, Gtk, Pango, PangoCairo  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lunar_tui as core  # noqa: E402  (Mpv, yt_search, yt_thumbnail, scan_local)

APP_ID = "lunar-tui"
TITLE = "Lunar Player"
FONT = os.environ.get("LUNAR_TUI_FONT_FAMILY", "Roboto Mono")
WIN_W = int(os.environ.get("LUNAR_TUI_W", "1800"))
WIN_H = int(os.environ.get("LUNAR_TUI_H", "1060"))
SCALE = float(os.environ.get("LUNAR_TUI_SCALE", "1.35"))   # масштаб всей отрисовки

# ── палитра: читаю живой кэш риса, иначе дефолт lunar ────────────────────
DEFAULT_PALETTE = {
    "bg": "#0a0b0f", "bgPanel": "#0f1116", "bgCard": "#151920", "bgTrack": "#1d2129",
    "bgHover": "#262b36", "text": "#e6eaf2", "textSoft": "#c3c9d3", "textDim": "#8b93a7",
    "textMuted": "#6f7787", "textFaint": "#565d6b", "accent": "#c9d2e2",
    "accent2": "#e6eaf2", "danger": "#ff003c", "border": "#ffffff12",
    "borderAccent": "#ffffff20",
}


def load_palette():
    p = dict(DEFAULT_PALETTE)
    try:
        with open(os.path.expanduser("~/.cache/lunar/palette.json"), encoding="utf-8") as f:
            p.update(json.load(f))
    except (OSError, ValueError):
        pass
    return p


P = load_palette()


def col(key, a=1.0):
    h = str(P.get(key, "#ffffff")).lstrip("#")
    try:
        r = int(h[0:2], 16) / 255.0
        g = int(h[2:4], 16) / 255.0
        b = int(h[4:6], 16) / 255.0
        if len(h) >= 8:                       # #RRGGBBAA
            a = a * int(h[6:8], 16) / 255.0
    except (ValueError, IndexError):
        r = g = b = 1.0
    return (r, g, b, a)


# ── рисование ────────────────────────────────────────────────────────────
def rrect(cr, x, y, w, h, r):
    r = max(0, min(r, w / 2, h / 2))
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


def layout_for(cr, s, size, bold=False, width=None, align="left", ellipsize=True):
    lay = PangoCairo.create_layout(cr)
    d = Pango.FontDescription()
    d.set_family(FONT)
    d.set_absolute_size(size * Pango.SCALE)
    d.set_weight(Pango.Weight.BOLD if bold else Pango.Weight.NORMAL)
    lay.set_font_description(d)
    lay.set_text(s, -1)
    if width is not None:
        lay.set_width(int(width * Pango.SCALE))
        if ellipsize:
            lay.set_ellipsize(Pango.EllipsizeMode.END)
        lay.set_alignment({"left": Pango.Alignment.LEFT, "center": Pango.Alignment.CENTER,
                           "right": Pango.Alignment.RIGHT}[align])
    return lay


def text(cr, x, y, s, size=12, color=None, bold=False, width=None,
         align="left", ellipsize=True):
    lay = layout_for(cr, s, size, bold, width, align, ellipsize)
    if width is not None and align in ("center", "right"):
        pass
    cr.set_source_rgba(*(color if color else col("text")))
    cr.move_to(x, y)
    PangoCairo.show_layout(cr, lay)
    return lay.get_pixel_size()


def textw(cr, s, size=12, bold=False):
    lay = layout_for(cr, s, size, bold)
    w, h = lay.get_pixel_size()
    return w


# ── кэш обложек ──────────────────────────────────────────────────────────
_scaled = {}


def scaled_cover(pb, w, h):
    key = (pb, w, h)
    if key in _scaled:
        return _scaled[key]
    sw, sh = pb.get_width(), pb.get_height()
    if sw <= 0 or sh <= 0:
        return None
    k = max(w / sw, h / sh)
    nw, nh = max(w, int(sw * k + 0.5)), max(h, int(sh * k + 0.5))
    s = pb.scale_simple(nw, nh, GdkPixbuf.InterpType.BILINEAR)
    ox, oy = (nw - w) // 2, (nh - h) // 2
    s = s.new_subpixbuf(ox, oy, w, h)
    if len(_scaled) > 400:
        _scaled.clear()
    _scaled[key] = s
    return s


class Player:
    def __init__(self, area):
        self.area = area
        self.mpv = core.Mpv(f"/tmp/lunar-gui-{os.getpid()}.sock")
        self._mpv_started = False        # mpv поднимаю лениво — только когда включаю трек
        self.lib_local = core.scan_local(core.load_config())
        self.queue = []
        self.search_results = []
        self.tabs = ["ОЧЕРЕДЬ", "ПОИСК", "ЛОКАЛЬНЫЕ"]
        self.tab = 0
        self.sel = [0, 0, 0]
        self.focus = "list"
        self.query = ""
        self.searching = False
        self.status = ""
        self.status_t = 0.0
        self.shuffle = False
        self.qindex = -1
        self.playing_track = None
        self.tick = 0
        self.out = _queue.Queue()
        self.covers = {}          # id -> pixbuf
        self.pending = set()
        self.art_pending = None
        self.mouse = (-1, -1)
        self.hover = None
        self.hit = {}             # rects для мыши (заполняется при отрисовке)
        self.clock = 0.0

    # ── данные ──
    def all_tabs_lists(self):
        return [self.queue, self.search_results, self.lib_local]

    def current(self):
        return self.all_tabs_lists()[self.tab], self.tab

    def status_set(self, s):
        self.status = s
        self.status_t = time.time()

    def ensure_mpv(self):
        if not self._mpv_started:
            try:
                self.mpv.start()
                self._mpv_started = True
            except Exception:
                pass

    def start_track(self, track, source=None):
        self.ensure_mpv()
        if source is not None:
            self.queue = list(source)
            try:
                self.qindex = self.queue.index(track)
            except ValueError:
                self.qindex = 0
        self.playing_track = track
        self.art_pending = track.get("id")
        self.mpv.load(track["url"])
        self.status_set("играю: " + track.get("title", "")[:40])
        self.want_cover(track)

    def next_track(self, fwd=True):
        if not self.queue:
            return
        if self.shuffle:
            self.qindex = random.randrange(len(self.queue))
        else:
            self.qindex = (self.qindex + (1 if fwd else -1)) % len(self.queue)
        self.start_track(self.queue[self.qindex])

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

    @staticmethod
    def _local_cover(track):
        d = os.path.dirname(track.get("url", ""))
        for n in ("cover.jpg", "cover.png", "folder.jpg", "folder.png",
                  "front.jpg", "album.jpg", "AlbumArt.jpg"):
            p = os.path.join(d, n)
            if os.path.exists(p):
                return p
        return None

    def _load_cover(self, tid, path):
        try:
            if path and os.path.exists(path):
                self.covers[tid] = GdkPixbuf.Pixbuf.new_from_file(path)
        except GLib.Error:
            pass
        self.pending.discard(tid)

    def pump(self):
        try:
            while True:
                item = self.out.get_nowait()
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
                    self.area.queue_draw()
        except _queue.Empty:
            pass
        for ev, reason in self.mpv.drain_events():
            if ev == "end-file" and reason == "eof" and self.queue:
                self.next_track(True)
        return True

    def tick_anim(self):
        self.tick += 1
        self.area.queue_draw()
        return True

    # ── события ──
    def do_search(self):
        q = self.query.strip()
        self.focus = "list"
        if not q:
            return
        self.searching = True
        self.search_results = []
        self.status_set("ищу: " + q[:30] + "…")
        core.yt_search(q, self.out)

    def vol(self):
        return int(self.mpv.get("volume", 100) or 100)

    def set_vol(self, v):
        self.mpv.set_volume(max(0, min(100, v)))

    def key(self, k):
        if self.focus == "search":
            if k in ("Return", "KP_Enter"):
                self.do_search()
            elif k == "Escape":
                self.focus = "list"
            elif k == "BackSpace":
                self.query = self.query[:-1]
            elif len(k) == 1 and k.isprintable():
                self.query += k
            return True
        if k == "Escape":
            Gtk.main_quit()
        elif k == "Tab":
            self.tab = (self.tab + 1) % len(self.tabs)
        elif k == "slash":
            self.focus = "search"
            self.query = ""
        elif k == "Up":
            lst, ti = self.current()
            self.sel[ti] = max(0, self.sel[ti] - 1)
        elif k == "Down":
            lst, ti = self.current()
            if lst:
                self.sel[ti] = min(len(lst) - 1, self.sel[ti] + 1)
        elif k in ("Return", "KP_Enter"):
            lst, ti = self.current()
            if lst and self.sel[ti] < len(lst):
                self.start_track(lst[self.sel[ti]], lst)
        elif k == "space":
            self.mpv.play_pause()
        elif k == "Left":
            self.mpv.seek_rel(-5)
        elif k == "Right":
            self.mpv.seek_rel(5)
        elif k == "n":
            self.next_track(True)
        elif k == "p":
            self.next_track(False)
        elif k == "s":
            self.shuffle = not self.shuffle
        elif k == "m":
            self.mpv.set_mute(not self.mpv.get("mute", False))
        elif k in ("equal", "plus"):
            self.set_vol(self.vol() + 5)
        elif k == "minus":
            self.set_vol(self.vol() - 5)
        elif k == "a":
            lst, ti = self.current()
            if self.tab != 0 and lst and self.sel[ti] < len(lst):
                tr = lst[self.sel[ti]]
                if tr not in self.queue:
                    self.queue.append(tr)
                    self.status_set("в очередь: " + tr.get("title", "")[:30])
        return True

    def click(self, x, y):
        h = self.hit
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
                    self.mpv.play_pause()
                elif name == "shuffle":
                    self.shuffle = not self.shuffle
                return
        if "seek" in h and inrect((x, y), h["seek"]):
            rx, ry, rw, rh = h["seek"]
            frac = max(0.0, min(1.0, (x - rx) / max(1, rw)))
            dur = self.mpv.get("duration") or 0
            if dur:
                self.mpv.seek_abs(frac * dur)
            return
        if "vol" in h and inrect((x, y), h["vol"]):
            rx, ry, rw, rh = h["vol"]
            self.set_vol(int(100 * max(0.0, min(1.0, (x - rx) / max(1, rw)))))
            return


def inrect(p, r):
    x, y = p
    return r[0] <= x <= r[0] + r[2] and r[1] <= y <= r[1] + r[3]


# ── окно ─────────────────────────────────────────────────────────────────
class Window(Gtk.Window):
    def __init__(self):
        super().__init__(title=TITLE)
        self.set_wmclass(APP_ID, APP_ID)
        self.set_role(APP_ID)
        self.set_decorated(False)
        self.set_default_size(WIN_W, WIN_H)
        self.set_app_paintable(True)

        css = Gtk.CssProvider()
        css.load_from_data(("window{background:%s;}" % P.get("bg", "#0a0b0f")).encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.area = Gtk.DrawingArea()
        self.area.set_can_focus(True)
        self.area.add_events(Gdk.EventMask.POINTER_MOTION_MASK
                             | Gdk.EventMask.BUTTON_PRESS_MASK
                             | Gdk.EventMask.SCROLL_MASK
                             | Gdk.EventMask.LEAVE_NOTIFY_MASK)
        self.area.connect("draw", self.on_draw)
        self.area.connect("motion-notify-event", self.on_motion)
        self.area.connect("leave-notify-event", self.on_leave)
        self.area.connect("button-press-event", self.on_click)
        self.area.connect("scroll-event", self.on_scroll)
        self.add(self.area)

        self.p = Player(self.area)
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key)

        GLib.timeout_add(120, self.p.pump)
        GLib.timeout_add(80, self.p.tick_anim)

    # ── ввод ──
    def on_key(self, _w, e):
        name = Gdk.keyval_name(e.keyval) or ""
        if name == "slash":
            name = "slash"
        return self.p.key(name)

    def on_motion(self, _w, e):
        self.p.mouse = (e.x / SCALE, e.y / SCALE)
        return False

    def on_leave(self, *_a):
        self.p.mouse = (-1, -1)
        return False

    def on_click(self, _w, e):
        self.area.grab_focus()
        self.p.click(e.x / SCALE, e.y / SCALE)
        self.area.queue_draw()
        return True

    def on_scroll(self, _w, e):
        p = self.p
        if e.direction == Gdk.ScrollDirection.UP:
            p.key("Up")
        elif e.direction == Gdk.ScrollDirection.DOWN:
            p.key("Down")
        self.area.queue_draw()
        return True

    # ── разметка ──
    def geometry(self):
        a = self.area.get_allocation()
        W, H = a.width / SCALE, a.height / SCALE
        m, gap = 12, 10
        nav = (m, m, W - 2 * m, 50)
        ph = 156
        play = (m, H - m - ph, W - 2 * m, ph)
        midy = m + 50 + gap
        midh = play[1] - gap - midy
        lib = (m, midy, 316, midh)
        side = (W - m - 356, midy, 356, midh)
        main = (lib[0] + lib[2] + gap, midy, side[0] - gap - (lib[0] + lib[2] + gap), midh)
        return {"W": W, "H": H, "nav": nav, "lib": lib, "main": main,
                "side": side, "play": play}

    # ── отрисовка ──
    def on_draw(self, _w, cr):
        try:
            g = self.geometry()
            self.p.hit = {}
            cr.set_source_rgba(*col("bg"))
            cr.paint()
            cr.scale(SCALE, SCALE)
            self.draw_nav(cr, g)
            self.draw_library(cr, g)
            self.draw_main(cr, g)
            self.draw_sidebar(cr, g)
            self.draw_playing(cr, g)
        except Exception:
            import traceback
            traceback.print_exc()
        return False

    def panel(self, cr, r, label):
        x, y, w, h = r
        rrect(cr, x, y, w, h, 12)
        cr.set_source_rgba(*col("bgPanel", 0.92))
        cr.fill_preserve()
        cr.set_source_rgba(*col("border"))
        cr.set_line_width(1)
        cr.stroke()
        if label:
            ly = y - 7
            tw = textw(cr, label, 10, True)
            cr.set_source_rgba(*col("bg"))
            cr.rectangle(x + 18, y - 1, tw + 10, 2.5)
            cr.fill()
            text(cr, x + 23, ly, label, size=10, color=col("textFaint"), bold=True)

    # Nav
    def draw_nav(self, cr, g):
        x, y, w, h = g["nav"]
        self.panel(cr, g["nav"], "Nav")
        cy = y + h / 2 - 9
        text(cr, x + 20, cy, "‹   ›   ⌂", size=13, color=col("textFaint"))
        text(cr, x + 96, cy - 1, "LUNAR PLAYER", size=14, color=col("accent"), bold=True)
        # поиск
        sw = min(560, w - 560)
        sx = x + (w - sw) / 2
        sh = 30
        sy = y + (h - sh) / 2
        rrect(cr, sx, sy, sw, sh, 8)
        cr.set_source_rgba(*col("bgCard"))
        cr.fill_preserve()
        cr.set_source_rgba(*(col("borderAccent") if self.p.focus == "search" else col("border")))
        cr.set_line_width(1)
        cr.stroke()
        ph = self.p.query if (self.p.focus == "search" or self.p.query) else "что хочешь послушать?"
        text(cr, sx + 14, sy + sh / 2 - 8, "⌕ ", size=12,
             color=col("textDim"))
        text(cr, sx + 34, sy + sh / 2 - 8, ph, size=12,
             color=col("text") if (self.p.focus == "search" or self.p.query) else col("textFaint"),
             width=sw - 48)
        self.p.hit["search"] = (sx, sy, sw, sh)
        # справа
        pause = self.p.mpv.get("pause")
        if self.p.playing_track and pause is False:
            st, sc = "играет", col("accent")
        elif self.p.playing_track:
            st, sc = "пауза", col("textDim")
        else:
            st, sc = "стоп", col("textFaint")
        text(cr, x + w - 130, cy, st, size=12, color=sc)
        text(cr, x + w - 56, cy, time.strftime("%H:%M"), size=12, color=col("textDim"))

    # Library
    def draw_library(self, cr, g):
        x, y, w, h = g["lib"]
        self.panel(cr, g["lib"], "Library")
        px, py = x + 18, y + 18
        text(cr, px, py, "ТВОЯ ФОНОТЕКА", size=12, color=col("textDim"), bold=True)
        text(cr, x + w - 30, py - 2, "+", size=16, color=col("accent"))
        py += 30
        cr.set_source_rgba(*col("border"))
        cr.rectangle(px, py, w - 36, 1)
        cr.fill()
        py += 8
        items = [("♪", "ОЧЕРЕДЬ", len(self.p.queue)),
                 ("⌕", "РЕЗУЛЬТАТЫ", len(self.p.search_results)),
                 ("▤", "ЛОКАЛЬНЫЕ", len(self.p.lib_local))]
        self.p.hit["lib"] = []
        for i, (ic, nm, cnt) in enumerate(items):
            rr = (px, py, w - 36, 30)
            self.p.hit["lib"].append(rr)
            sel = self.p.tab == i
            hov = inrect(self.p.mouse, rr)
            if sel or hov:
                rrect(cr, *rr, 8)
                cr.set_source_rgba(*(col("bgTrack", 0.9) if sel else col("bgHover", 0.5)))
                cr.fill()
            if sel:
                cr.set_source_rgba(*col("accent"))
                cr.rectangle(px, py + 6, 3, 18)
                cr.fill()
            text(cr, px + 12, py + 6, ic + "  " + nm, size=12,
                 color=col("accent") if sel else col("textDim"), bold=sel)
            text(cr, x + w - 44, py + 6, str(cnt), size=12,
                 color=col("accent") if sel else col("textFaint"), align="right", width=28)
            py += 34
        # очередь списком
        py += 12
        text(cr, px, py, "В ОЧЕРЕДИ", size=11, color=col("textFaint"))
        py += 22
        hint_y = y + h - 96
        avail = int((hint_y - py) / 26)
        for i, tr in enumerate(self.p.queue[:max(0, avail)]):
            cur = i == self.p.qindex
            txt = f"{'♪ ' if cur else ''}{i + 1:02d}  {tr.get('title', '')}"
            text(cr, px, py, txt, size=11, color=col("accent") if cur else col("textDim"),
                 width=w - 40)
            py += 26
        # подсказки
        cr.set_source_rgba(*col("border"))
        cr.rectangle(px, hint_y, w - 36, 1)
        cr.fill()
        hints = ["space пауза · n/p трек", "←/→ ±5с · a очередь",
                 "клик по строке — играть", "q выход · / поиск"]
        for i, hh in enumerate(hints):
            text(cr, px, hint_y + 10 + i * 18, hh, size=10, color=col("textFaint"))

    # Main
    def draw_main(self, cr, g):
        x, y, w, h = g["main"]
        self.panel(cr, g["main"], "Main")
        px = x + 18
        py = y + 16
        self.p.hit["tabs"] = []
        cx = px
        for i, nm in enumerate(self.p.tabs):
            act = i == self.p.tab
            tw = textw(cr, nm, 11, True) + 26
            rr = (cx, py, tw, 26)
            self.p.hit["tabs"].append(rr)
            hov = inrect(self.p.mouse, rr)
            if act or hov:
                rrect(cr, *rr, 8)
                cr.set_source_rgba(*(col("bgTrack", 0.95) if act else col("bgHover", 0.5)))
                cr.fill()
            text(cr, cx + 13, py + 4, nm, size=11,
                 color=col("accent") if act else col("textFaint"), bold=act)
            cx += tw + 8
        py += 38
        cr.set_source_rgba(*col("border"))
        cr.rectangle(px, py, w - 36, 1)
        cr.fill()
        py += 8

        list_, ti = self.p.current()
        right = x + w - 18
        dur_w = 52
        art_w = 200 if w > 500 else 0
        th = 24
        num_x = px + 40
        title_x = px + 64
        dur_x = right - dur_w
        art_x = (dur_x - art_w - 14) if art_w else dur_x
        head = col("textMuted")
        text(cr, num_x, py, "№", size=10, color=head)
        text(cr, title_x, py, "НАЗВАНИЕ", size=10, color=head)
        if art_w:
            text(cr, art_x, py, "ИСПОЛНИТЕЛЬ", size=10, color=head)
        text(cr, dur_x, py, "ДЛИТ", size=10, color=head, align="right", width=dur_w)
        py += 22
        cr.set_source_rgba(*col("border"))
        cr.rectangle(px, py, w - 36, 1)
        cr.fill()
        py += 6

        if self.p.tab == 1 and self.p.searching:
            text(cr, px, py + 6, "⌕  ищу в YouTube…", size=12, color=col("accent"))
            list_ = []
        if not list_:
            msg = ("нажми / и введи запрос" if self.p.tab == 1
                   else ("очередь пуста — найди трек в ПОИСКЕ" if self.p.tab == 0
                         else "нет локальных файлов"))
            text(cr, px, py + 6, msg, size=12, color=col("textFaint"))
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
            selected = (i == sel and self.p.focus != "search")
            hov = inrect(self.p.mouse, rr)
            now = self.p.playing_track and tr.get("id") == self.p.playing_track.get("id")
            if selected or hov:
                rrect(cr, *rr, 8)
                cr.set_source_rgba(*(col("bgTrack", 0.95) if selected else col("bgHover", 0.5)))
                cr.fill()
            if selected:
                cr.set_source_rgba(*col("accent"))
                cr.rectangle(px, ry + 4, 3, row_h - 12)
                cr.fill()
            self.cover(cr, px + 8, ry + 4, th, th, 6, self.p.covers.get(tr.get("id")), small=True)
            mid = ry + (row_h - 4) / 2 - 9
            text(cr, num_x, mid, f"{i + 1:02d}", size=11, color=col("textFaint"))
            tcol = col("accent") if now else (col("text") if selected else col("textDim"))
            text(cr, title_x, mid, tr.get("title", ""), size=12, color=tcol,
                 bold=bool(now or selected),
                 width=max(40, (art_x if art_w else dur_x) - 14 - title_x))
            if art_w:
                text(cr, art_x, mid, tr.get("artist", ""), size=11,
                     color=col("textFaint"), width=art_w)
            text(cr, dur_x, mid, core.fmt_time(tr.get("duration")), size=11,
                 color=col("textFaint"), align="right", width=dur_w)
            if i - start < 12:
                self.p.want_cover(tr)

    # Sidebar
    def draw_sidebar(self, cr, g):
        x, y, w, h = g["side"]
        self.panel(cr, g["side"], "Sidebar")
        px, py = x + 18, y + 18
        text(cr, px, py, "СЕЙЧАС ИГРАЕТ", size=11, color=col("textFaint"))
        tr = self.p.playing_track
        if tr and self.p.mpv.get("pause") is False:
            self.eq(cr, x + w - 64, py - 4, col("accent"))
        py += 24
        cs = min(w - 36, 300)
        cx = x + (w - cs) / 2
        self.cover(cr, cx, py, cs, cs, 12, self.p.covers.get(tr.get("id")) if tr else None)
        py += cs + 16
        if tr:
            text(cr, px, py, tr.get("title", ""), size=14, color=col("accent"), bold=True,
                 width=w - 36)
            py += 24
            text(cr, px, py, tr.get("artist", ""), size=12, color=col("textDim"), width=w - 36)
            py += 22
            text(cr, px, py, "YouTube · стрим" if tr.get("source") == "yt" else "Локальный файл",
                 size=11, color=col("textFaint"))
            py += 26
        else:
            text(cr, px, py, "ничего не играет", size=12, color=col("textFaint"))
            py += 26
        cr.set_source_rgba(*col("border"))
        cr.rectangle(px, py, w - 36, 1)
        cr.fill()
        py += 10
        text(cr, px, py, "ДЕТАЛИ", size=11, color=col("textFaint"))
        py += 22
        if tr:
            rows = [("Источник", "YouTube" if tr.get("source") == "yt" else "файл"),
                    ("В очереди", f"{self.p.qindex + 1} / {len(self.p.queue)}" if self.p.queue else "—"),
                    ("Длительность", core.fmt_time(tr.get("duration"))),
                    ("Состояние", "играет" if self.p.mpv.get("pause") is False else "пауза")]
            for k, v in rows:
                text(cr, px, py, k, size=11, color=col("textFaint"))
                text(cr, px + 120, py, v, size=11, color=col("textDim"), width=w - 36 - 120)
                py += 22

    # Playing
    def draw_playing(self, cr, g):
        x, y, w, h = g["play"]
        self.panel(cr, g["play"], "Playing")
        px, py = x + 18, y + 18
        tr = self.p.playing_track
        pause = self.p.mpv.get("pause")
        playing = tr is not None and pause is False
        cov = 84
        self.cover(cr, px, py, cov, cov, 8, self.p.covers.get(tr.get("id")) if tr else None)
        tx = px + cov + 18
        text(cr, tx, py + 8, tr.get("title", "") if tr else "ничего не играет", size=15,
             color=col("accent"), bold=True, width=w * 0.4)
        if tr:
            text(cr, tx, py + 34, tr.get("artist", ""), size=12, color=col("textDim"), width=w * 0.4)
            text(cr, tx, py + 56, "YouTube" if tr.get("source") == "yt" else "файл",
                 size=11, color=col("textFaint"))
        # транспорт по центру
        bx = x + w / 2 - 90
        self.p.hit["btn"] = {}
        for name, gl, size in (("prev", "⇤", 20), ("play", "▮▮" if playing else "▶", 24),
                               ("next", "⇥", 20), ("shuffle", "⇄", 18)):
            bw = 40
            rr = (bx, py + 16, bw, 40)
            self.p.hit["btn"][name] = rr
            hov = inrect(self.p.mouse, rr)
            if name == "shuffle":
                c = col("accent") if (self.p.shuffle or hov) else col("textFaint")
            elif name == "play":
                c = col("accent")
            else:
                c = col("accent") if hov else col("textFaint")
            text(cr, bx + 12, py + 24, gl, size=size, color=c)
            bx += 48
        # громкость справа
        vw = 160
        vx = x + w - 36 - vw
        vol = self.p.vol()
        muted = self.p.mpv.get("mute", False)
        cr.set_source_rgba(*col("bgCard"))
        cr.rectangle(vx, py + 34, vw, 2)
        cr.fill()
        cr.set_source_rgba(*(col("textFaint") if muted else col("accent")))
        cr.rectangle(vx, py + 34, vw * ((0 if muted else vol) / 100.0), 2)
        cr.fill()
        self.p.hit["vol"] = (vx, py + 24, vw, 22)
        text(cr, vx, py + 8, "MUTE" if muted else f"VOL {vol}%", size=10,
             color=col("textFaint"), align="right", width=vw)
        # seek
        ry = py + cov + 22
        dur = self.p.mpv.get("duration") or (tr.get("duration") if tr else 0)
        pos = self.p.mpv.get("time-pos") or 0
        lt, rt = core.fmt_time(pos), core.fmt_time(dur)
        lw = 46
        bar_x = px + lw
        bar_w = w - 36 - lw - lw
        text(cr, px, ry - 8, lt, size=11, color=col("textFaint"))
        text(cr, x + w - 36 - lw, ry - 8, rt, size=11, color=col("textFaint"), align="right", width=lw)
        cr.set_source_rgba(*col("bgTrack"))
        cr.rectangle(bar_x, ry + 2, bar_w, 3)
        cr.fill()
        frac = min(1.0, (pos / dur) if dur else 0.0)
        cr.set_source_rgba(*col("accent"))
        cr.rectangle(bar_x, ry + 2, bar_w * frac, 3)
        cr.fill()
        cr.arc(bar_x + bar_w * frac, ry + 3.5, 5, 0, 2 * math.pi)
        cr.fill()
        self.p.hit["seek"] = (bar_x, ry - 8, bar_w, 20)
        # статус/подсказка
        msg = self.p.status if (self.p.status and time.time() - self.p.status_t < 5) else \
            "q выход · / поиск · space пауза · n/p трек · клик по строке — играть"
        text(cr, px, y + h - 20, msg, size=10,
             color=col("textDim") if self.p.status and time.time() - self.p.status_t < 5 else col("textFaint"),
             width=w - 36)

    # обложка с закруглением
    def cover(self, cr, x, y, w, h, r, pb, small=False):
        rrect(cr, x, y, w, h, r)
        cr.save()
        cr.clip()
        s = None
        if pb is not None:
            s = scaled_cover(pb, int(round(w * SCALE)), int(round(h * SCALE)))
        if s is not None:
            cr.save()
            cr.identity_matrix()           # рисуем картинку в пикселях 1:1
            Gdk.cairo_set_source_pixbuf(cr, s, x * SCALE, y * SCALE)
            cr.paint()
            cr.restore()
        else:
            cr.set_source_rgba(*col("bgCard"))
            cr.paint()
        cr.restore()
        if pb is None:
            text(cr, x, y + h / 2 - (7 if small else 12), "♪",
                 size=12 if small else 26, color=col("textMuted"),
                 align="center", width=w)
        rrect(cr, x, y, w, h, r)
        cr.set_source_rgba(*col("border"))
        cr.set_line_width(1)
        cr.stroke()

    # эквалайзер
    def eq(self, cr, x, y, color):
        frames = [[6, 12, 8], [12, 8, 14], [8, 14, 6], [14, 6, 10]]
        f = frames[self.p.tick // 3 % len(frames)]
        cr.set_source_rgba(*color)
        for i, bh in enumerate(f):
            cr.rectangle(x + i * 5, y + 14 - bh, 3, bh)
        cr.fill()


def main():
    import signal
    GLib.set_prgname(APP_ID)
    Gtk.init(None)
    win = Window()
    for _sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(_sig, lambda *_: Gtk.main_quit())
    win.show_all()
    win.present()
    win.area.grab_focus()
    try:
        Gtk.main()
    finally:
        try:
            win.p.mpv.stop()          # не оставляю mpv-сирот
        except Exception:
            pass


if __name__ == "__main__":
    main()
