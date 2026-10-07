#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════════════
#  Lunar TUI Player — плеер прямо в терминале, в стиле 43PR/btop:
#  панели Nav / Library / Main / Sidebar / Playing с подписями прямо
#  в рамке (скруглённые углы), монохром, один акцент.
#
#  Звук — mpv через JSON IPC (--input-ipc-server). Поиск — yt-dlp.
#  Обложка — chafa (монохром), если установлен.
#
#  Запуск:  lunar-tui  (или python3 lunar_tui.py)
#  Клавиши: ←/→ seek · ↑/↓ выбор · Enter играть · Space пауза ·
#           n/p трек · a в очередь · s шафл · / поиск · Tab вкладка · q выход
# ════════════════════════════════════════════════════════════════════════
import argparse
import atexit
import json
import locale
import os
import queue as _queue
import random
import re
import shutil
import socket
import subprocess
import sys
import threading
import time

try:
    import curses
except ImportError:
    print("нужен python3 с модулем curses", file=sys.stderr)
    sys.exit(1)

APP = "LUNAR PLAYER"
CONFIG = os.path.expanduser("~/.config/lunar/tui.json")
AUDIO_EXT = {".mp3", ".flac", ".ogg", ".opus", ".m4a", ".wav", ".aac", ".wma", ".mka", ".mp4"}

# ── палитра Lunar Eclipse (из palette.toml) ─────────────────────────────
#  Терминал уже в этих цветах (kitty lunar-theme), поэтому фон не трогаю —
#  беру только текст/акцент/приглушённые тона. Индексы xterm-256.
P_TEXT, P_DIM, P_FAINT = 1, 2, 3
P_ACCENT, P_DANGER, P_BORDER = 4, 5, 6
P_SEL, P_CARD, P_HEAD = 7, 8, 9
P_SEL_ACC, P_SEL_DIM, P_SEL_FAINT, P_SEL_TXT = 10, 11, 12, 13
COLOR_INIT = [
    (P_TEXT, -1, -1),          # текст: терминальный fg
    (P_DIM, 103, -1),          # textDim  #8b93a7
    (P_FAINT, 240, -1),        # textFaint #565d6b
    (P_ACCENT, 188, -1),       # accent   #c9d2e2
    (P_DANGER, 197, -1),       # danger   #ff003c
    (P_BORDER, 59, -1),        # рамки
    (P_SEL, 153, 235),         # выбранная строка (заливка пробелов)
    (P_CARD, 103, 234),        # карточка
    (P_HEAD, 146, -1),         # заголовки таблицы
    (P_SEL_ACC, 188, 235),     # акцент на выделении
    (P_SEL_DIM, 103, 235),     # приглушённый текст на выделении
    (P_SEL_FAINT, 240, 235),   # служебное на выделении
    (P_SEL_TXT, 255, 235),     # яркий текст на выделении
]

# ── глифы (только хорошо поддерживаемые юникод-символы, без nerd PUA) ──
G_PREV, G_NEXT = "⇤", "⇥"
G_PLAY, G_PAUSE = "▶", "▮▮"
G_SHUFFLE = "⇄"
G_NOTE, G_SEARCH = "♪", "/"
G_MARK = "▶"
G_DOT = "·"
G_OK, G_NO = "✓", "✕"


# ════════════════════════════════════════════════════════════════════════
#  Утилиты
# ════════════════════════════════════════════════════════════════════════
def sanitize(s, width=None):
    """Убираю широкие/эмодзи-символы — иначе строки плывут по ширине."""
    if s is None:
        return ""
    out = []
    for ch in str(s):
        if ch == "\t":
            ch = " "
        if "\u0300" <= ch <= "\u036f":     # комбинирующие
            continue
        w = _wcwidth(ch)
        out.append(ch if w == 1 else ("" if w <= 0 else "?"))
    t = "".join(out)
    if width is not None:
        if len(t) > width:
            t = t[:max(0, width - 1)] + "…"
        t = t + " " * (width - len(t))
    return t


def _wcwidth(ch):
    import unicodedata
    if unicodedata.combining(ch):
        return 0
    eaw = unicodedata.east_asian_width(ch)
    if eaw in ("W", "F"):
        return 2
    if ord(ch) < 32:
        return -1
    return 1


def fmt_time(sec):
    if sec is None:
        return "--:--"
    try:
        sec = int(sec)
    except (TypeError, ValueError):
        return "--:--"
    if sec < 0:
        sec = 0
    m, s = divmod(sec, 60)
    h, m = divmod(m, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def parse_sec(v):
    if v in (None, "", "NA", "None"):
        return 0
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return 0


def note(*a):
    print(*a, file=sys.stderr)


# ════════════════════════════════════════════════════════════════════════
#  mpv через JSON IPC
# ════════════════════════════════════════════════════════════════════════
class Mpv:
    OBSERVE = ["time-pos", "duration", "pause", "volume", "mute", "eof-reached",
               "media-title", "metadata", "idle-active", "path"]

    def __init__(self, sock_path):
        self.sock_path = sock_path
        self.proc = None
        self.sock = None
        self._lock = threading.Lock()
        self._rid = 0
        self.props = {}
        self.events = []          # очередь событий (eof и т.п.) для UI
        self.ready = False
        self._running = False

    def start(self):
        if os.path.exists(self.sock_path):
            try:
                os.unlink(self.sock_path)
            except OSError:
                pass
        args = [
            "mpv", "--no-video", "--idle=yes",
            f"--input-ipc-server={self.sock_path}",
            "--ytdl-format=bestaudio/best",
            "--no-osc", "--force-window=no",
            "--really-quiet", "--no-input-terminal",
            "--demuxer-max-bytes=24M", "--demuxer-max-back-bytes=8M",
        ]
        self.proc = subprocess.Popen(args, stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL,
                                     stdin=subprocess.DEVNULL)
        for _ in range(200):
            if os.path.exists(self.sock_path):
                break
            if self.proc.poll() is not None:
                raise RuntimeError("mpv не стартанул")
            time.sleep(0.05)
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(self.sock_path)
        self._running = True
        threading.Thread(target=self._read_loop, daemon=True).start()
        for name in self.OBSERVE:
            self.send("observe_property", self._next_id(), name)
        self.ready = True
        atexit.register(self.stop)

    def _next_id(self):
        self._rid += 1
        return self._rid

    def send(self, *cmd):
        with self._lock:
            if not self.sock:
                return
            self._rid += 1
            payload = json.dumps({"command": list(cmd), "request_id": self._rid}) + "\n"
            try:
                self.sock.sendall(payload.encode("utf-8", "replace"))
            except OSError:
                pass

    def _read_loop(self):
        buf = b""
        while self._running:
            try:
                data = self.sock.recv(65536)
            except OSError:
                break
            if not data:
                break
            buf += data
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except ValueError:
                    continue
                self._handle(msg)

    def _handle(self, msg):
        if "event" in msg and msg["event"] == "property-change":
            name = msg.get("name")
            if name:
                self.props[name] = msg.get("data")
        elif "event" in msg and msg["event"] in ("end-file", "playback-restart", "idle"):
            self.events.append((msg["event"], msg.get("reason")))

    # ── доступ к свойствам (потокобезопасно) ──
    def get(self, name, default=None):
        return self.props.get(name, default)

    def drain_events(self):
        ev, self.events = self.events, []
        return ev

    # ── команды ──
    def load(self, url):
        self.send("loadfile", url, "replace")

    def play_pause(self):
        self.send("cycle", "pause")

    def pause(self, val):
        self.send("set_property", "pause", bool(val))

    def next(self):
        self.send("playlist-next", "force")

    def prev(self):
        self.send("playlist-prev", "force")

    def seek_rel(self, sec):
        self.send("seek", sec, "relative")

    def seek_abs(self, sec):
        self.send("seek", max(0.0, float(sec)), "absolute")

    def set_volume(self, v):
        self.send("set_property", "volume", max(0.0, min(100.0, float(v))))

    def set_mute(self, m):
        self.send("set_property", "mute", bool(m))

    def stop(self):
        self._running = False
        try:
            if self.sock:
                self.sock.close()
        except OSError:
            pass
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        try:
            if os.path.exists(self.sock_path):
                os.unlink(self.sock_path)
        except OSError:
            pass


# ════════════════════════════════════════════════════════════════════════
#  yt-dlp поиск и обложки
# ════════════════════════════════════════════════════════════════════════
def yt_search(query, out):
    def run():
        args = ["yt-dlp", "--flat-playlist", "--quiet", "--no-warnings",
                "--ignore-config", "--socket-timeout", "8",
                "--playlist-end", "25", "--print",
                "%(id)s\t%(title)s\t%(duration)s\t%(uploader)s\t%(ie_key)s",
                f"ytsearch25:{query}"]
        res, err = [], ""
        try:
            p = subprocess.run(args, capture_output=True, text=True, timeout=60)
            for line in p.stdout.splitlines():
                parts = (line.split("\t") + ["", "", "", "", ""])[:5]
                ie = parts[4].strip()
                if ie == "YoutubeTab":
                    continue
                vid = parts[0].strip()
                if not vid:
                    continue
                res.append({
                    "id": vid,
                    "title": parts[1].strip() or "—",
                    "artist": parts[3].strip() or "YouTube",
                    "duration": parse_sec(parts[2]),
                    "url": f"https://www.youtube.com/watch?v={vid}",
                    "source": "yt",
                })
            if not res:
                err = "ничего не найдено"
        except subprocess.TimeoutExpired:
            err = "таймаут yt-dlp"
        except Exception as e:                       # noqa: BLE001
            err = str(e)
        out.put(("search", res, err))

    threading.Thread(target=run, daemon=True).start()


def yt_thumbnail(track, out):
    def run():
        try:
            p = subprocess.run(
                ["yt-dlp", "--quiet", "--no-warnings", "--ignore-config",
                 "--skip-download", "--print", "thumbnail",
                 "--socket-timeout", "8", track["url"]],
                capture_output=True, text=True, timeout=25)
            url = (p.stdout.strip().splitlines() or [""])[0]
        except Exception:                            # noqa: BLE001
            url = ""
        if not url and track.get("id") and track.get("source") == "yt":
            url = f"https://i.ytimg.com/vi/{track['id']}/hqdefault.jpg"
        path = ""
        if url:
            try:
                import urllib.request
                tmp = f"/tmp/lunar-tui-art-{track['id']}.jpg"
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=15) as r, open(tmp, "wb") as f:
                    f.write(r.read())
                path = tmp
            except Exception:                        # noqa: BLE001
                path = ""
        out.put(("art", track.get("id"), path))

    threading.Thread(target=run, daemon=True).start()


_ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def chafa_lines(path, w, h):
    """Монохромная ASCII-обложка (chafa). Возвращает список строк или None."""
    if not path or not shutil.which("chafa") or not os.path.exists(path):
        return None
    try:
        p = subprocess.run(
            ["chafa", "--format", "symbols", "--colors", "none",
             "--symbols", "block+border+space", "--size", f"{w}x{h}",
             "--stretch", path],
            capture_output=True, text=True, timeout=6)
        if p.returncode != 0 or not p.stdout.strip():
            return None
        txt = _ANSI.sub("", p.stdout)
        lines = [ln.rstrip() for ln in txt.splitlines() if ln.strip()]
        return lines if lines else None
    except Exception:                                # noqa: BLE001
        return None


def scan_local(dirs):
    out = []
    for d in dirs:
        d = os.path.expanduser(d)
        if not os.path.isdir(d):
            continue
        for root, _dirs, files in os.walk(d):
            for fn in sorted(files):
                if os.path.splitext(fn)[1].lower() in AUDIO_EXT:
                    path = os.path.join(root, fn)
                    out.append({
                        "id": path,
                        "title": os.path.splitext(fn)[0],
                        "artist": os.path.basename(root) or "Локальные",
                        "duration": 0,
                        "url": path,
                        "source": "local",
                    })
    return out


# ════════════════════════════════════════════════════════════════════════
#  Приложение
# ════════════════════════════════════════════════════════════════════════
class App:
    def __init__(self, stdscr, music_dirs):
        self.scr = stdscr
        self.music_dirs = music_dirs
        self.mpv = Mpv(f"/tmp/lunar-tui-{os.getpid()}.sock")
        self.tracks = []          # текущий список Main
        self.lib_local = scan_local(music_dirs)
        self.search_results = []
        self.out = _queue.Queue()
        self.tab = 0              # 0 очередь, 1 поиск, 2 локальные
        self.tabs = ["ОЧЕРЕДЬ", "ПОИСК", "ЛОКАЛЬНЫЕ"]
        self.sel = [0, 0, 0]      # выбор по вкладкам
        self.focus = "list"       # list | search
        self.query = ""
        self.searching = False
        self.status = ""
        self.status_t = 0.0
        self.shuffle = False
        self.qindex = -1
        self.queue = []           # очередь воспроизведения (индексы в self.tracks)
        self.playing_track = None
        self.art_lines = None
        self.art_for = None
        self.art_pending = None
        self._quit = False
        self._auto_cool = 0.0
        self.tick = 0

    # ── инфраструктура ──
    def set_status(self, msg):
        self.status = msg
        self.status_t = time.time()

    def current_list(self):
        if self.tab == 0:
            return self.queue, 0
        if self.tab == 1:
            return self.search_results, 1
        return self.lib_local, 2

    def start(self):
        self.mpv.start()
        self.set_status("готов · нажми / чтобы искать")

    # ── запуск трека ──
    def play(self, track, source_list=None):
        if source_list is not None:
            self.queue = list(source_list)
            try:
                self.qindex = self.queue.index(track)
            except ValueError:
                self.qindex = 0
        self.playing_track = track
        self.art_lines = None
        self.art_for = None
        self.mpv.load(track["url"])
        self.mpv.set_volume(self.cfg_volume())
        title = sanitize(track["title"], 40)
        self.set_status(f"играю: {title}")
        if track.get("source") == "yt":
            self.art_pending = track.get("id")
            yt_thumbnail(track, self.out)

    def cfg_volume(self):
        return self.mpv.get("volume", 100) or 100

    def next_track(self, forward=True):
        if not self.queue:
            return
        if self.shuffle:
            self.qindex = random.randrange(len(self.queue))
        else:
            self.qindex = (self.qindex + (1 if forward else -1)) % len(self.queue)
        self.play(self.queue[self.qindex])

    # ── обработка асинхронных результатов ──
    def pump(self):
        while True:
            try:
                item = self.out.get_nowait()
            except Exception:                        # queue.Empty
                break
            if item[0] == "search":
                _, res, err = item
                self.searching = False
                if res:
                    self.search_results = res
                    self.tab = 1
                    self.sel[1] = 0
                    self.set_status(f"найдено: {len(res)}")
                else:
                    self.set_status(f"поиск: {err or 'пусто'}")
            elif item[0] == "art":
                _, tid, path = item
                if tid == self.art_pending:
                    self.art_lines = chafa_lines(path, 26, 12)
                    self.art_for = tid
        for ev, reason in self.mpv.drain_events():
            # файл доиграл до конца — тяну следующий из очереди
            if ev == "end-file" and reason == "eof" and self.queue:
                self.next_track(True)

    def maybe_auto_next(self):
        # подстраховка, если событие eof потерялось: позиция у конца
        d = self.mpv.get("duration")
        t = self.mpv.get("time-pos")
        if (self.queue and d and t and d > 0 and t >= d - 0.35
                and time.time() - self._auto_cool > 1.5):
            self._auto_cool = time.time()
            self.next_track(True)

    # ── ввод ──
    def handle_key(self, ch):
        if ch == -1:
            return
        # режим ввода поиска: почти всё печатается в строку
        if self.focus == "search":
            if ch in (curses.KEY_ENTER, 10, 13):
                self.do_search()
            elif ch == 27:                     # Esc — выйти из поиска
                self.focus = "list"
            elif ch in (curses.KEY_BACKSPACE, 127):
                self.query = self.query[:-1]
            elif 32 <= ch < 0x110000:
                try:
                    self.query += chr(ch)
                except ValueError:
                    pass
            return

        if ch in (ord("q"), 27):
            self._quit = True
        elif ch == ord("\t"):
            self.tab = (self.tab + 1) % len(self.tabs)
        elif ch == ord("/"):
            self.focus = "search"
        elif ch == curses.KEY_UP:
            self.move_sel(-1)
        elif ch == curses.KEY_DOWN:
            self.move_sel(1)
        elif ch in (curses.KEY_ENTER, 10, 13):
            lst, _ = self.current_list()
            if lst and self.sel[self.tab] < len(lst):
                self.play(lst[self.sel[self.tab]], lst)
        elif ch == ord(" "):
            self.mpv.play_pause()
        elif ch == curses.KEY_LEFT:
            self.mpv.seek_rel(-5)
        elif ch == curses.KEY_RIGHT:
            self.mpv.seek_rel(5)
        elif ch in (ord("n"), ord("N")):
            self.next_track(True)
        elif ch in (ord("p"), ord("P")):
            self.next_track(False)
        elif ch in (ord("s"), ord("S")):
            self.shuffle = not self.shuffle
            self.set_status("шафл: вкл" if self.shuffle else "шафл: выкл")
        elif ch in (ord("a"), ord("A")):
            lst, _ = self.current_list()
            if self.tab != 0 and lst and self.sel[self.tab] < len(lst):
                tr = lst[self.sel[self.tab]]
                if tr not in self.queue:
                    self.queue.append(tr)
                    self.set_status(f"в очередь: {sanitize(tr['title'], 30)}")
        elif ch in (ord("+"), ord("=")):
            self.mpv.set_volume((self.cfg_volume() or 0) + 5)
        elif ch in (ord("-"), ord("_")):
            self.mpv.set_volume((self.cfg_volume() or 0) - 5)
        elif ch == ord("m"):
            self.mpv.set_mute(not self.mpv.get("mute", False))
        elif ch == ord("["):
            if self.tab == 0 and self.queue:
                self.qindex = max(0, self.qindex - 1)
                self.play(self.queue[self.qindex])
        elif ch == ord("]"):
            if self.tab == 0 and self.queue:
                self.qindex = min(len(self.queue) - 1, self.qindex + 1)
                self.play(self.queue[self.qindex])
        if ch == curses.KEY_RESIZE:
            self.scr.clear()

    def move_sel(self, d):
        if self.focus == "search":
            return
        lst, ti = self.current_list()
        if not lst:
            return
        self.sel[ti] = max(0, min(len(lst) - 1, self.sel[ti] + d))

    def do_search(self):
        q = self.query.strip()
        self.focus = "list"
        if not q:
            return
        self.searching = True
        self.search_results = []
        self.set_status(f"ищу: {sanitize(q, 30)}…")
        yt_search(q, self.out)

    # ══════════════════════════════════════════════════════════════
    #  Отрисовка
    # ══════════════════════════════════════════════════════════════
    def add(self, y, x, s, attr=0):
        H, W = self.scr.getmaxyx()
        if y < 0 or y >= H or x >= W or not s:
            return
        if x < 0:
            s = s[-x:]
            x = 0
        s = s[:W - x]
        try:
            self.scr.addstr(y, x, s, attr)
        except curses.error:
            pass

    def fill(self, y, x, h, w, attr):
        if h <= 0 or w <= 0:
            return
        blank = " " * w
        for r in range(h):
            self.add(y + r, x, blank, attr)

    def panel(self, y, x, h, w, label=""):
        if h < 2 or w < 2:
            return
        b, l = curses.color_pair(P_BORDER), curses.color_pair(P_FAINT)
        self.add(y, x, "╭", b)
        self.add(y, x + w - 1, "╮", b)
        self.add(y + h - 1, x, "╰", b)
        self.add(y + h - 1, x + w - 1, "╯", b)
        self.add(y, x + 1, "─" * max(0, w - 2), b)
        self.add(y + h - 1, x + 1, "─" * max(0, w - 2), b)
        for r in range(1, h - 1):
            self.add(y + r, x, "│", b)
            self.add(y + r, x + w - 1, "│", b)
        if label:
            self.add(y, x + 2, f" {label} ", l)

    def bar(self, y, x, w, frac, attr_track=None, attr_fill=None):
        frac = 0.0 if frac is None else max(0.0, min(1.0, frac))
        w = max(1, w)
        pos = int(round(frac * (w - 1)))
        track = attr_track if attr_track is not None else curses.color_pair(P_FAINT)
        fillc = attr_fill if attr_fill is not None else curses.color_pair(P_ACCENT)
        self.add(y, x, "━" * pos, fillc)
        self.add(y, x + pos, "●", fillc)
        if pos + 1 < w:
            self.add(y, x + pos + 1, "━" * (w - pos - 1), track)

    # кадры «эквалайзера» — анимирую по тику, чтобы «сейчас играет» жил
    EQ_FRAMES = ["▁▃▅▂", "▃▅▂▄", "▅▂▄▃", "▂▄▃▅"]

    def eqframe(self):
        if self.playing_track and self.mpv.get("pause") is False:
            return self.EQ_FRAMES[self.tick % len(self.EQ_FRAMES)]
        return "▁▁▁▁"

    def draw(self):
        self.scr.erase()
        H, W = self.scr.getmaxyx()
        if H < 20 or W < 76:
            self.add(H // 2, 2, "терминал слишком мал — нужно хотя бы 76×20", curses.color_pair(P_DANGER))
            self.scr.refresh()
            return
        left = 2
        right = W - 2
        top = 1
        nav_h = 3
        play_h = 7
        mid_y = top + nav_h + 1
        play_y = H - 1 - play_h
        mid_h = play_y - 1 - mid_y
        gap = 1
        lib_w = 30
        side_w = 34
        main_x = left + lib_w + gap
        main_w = right - main_x - gap - side_w
        side_x = right - side_w

        self.draw_nav(top, left, nav_h, right - left)
        self.draw_library(mid_y, left, mid_h, lib_w)
        self.draw_main(mid_y, main_x, mid_h, main_w)
        self.draw_sidebar(mid_y, side_x, mid_h, side_w)
        self.draw_playing(play_y, left, play_h, right - left)
        self.scr.refresh()

    # ── Nav ──
    def draw_nav(self, y, x, h, w):
        self.panel(y, x, h, w, "Nav")
        cy = y + 1
        acc, dim, faint = (curses.color_pair(P_ACCENT), curses.color_pair(P_DIM),
                           curses.color_pair(P_FAINT))
        self.add(cy, x + 2, "‹  ›  ⌂", faint)
        self.add(cy, x + 10, APP, acc | curses.A_BOLD)
        # поиск по центру
        sw = min(54, max(26, w - 52))
        sx = x + max(20, (w - sw) // 2)
        active = self.focus == "search"
        self.add(cy, sx, "[", acc if active else faint)
        inner = sw - 2
        if active:
            shown = sanitize("⌕ " + self.query + "▌", inner)
        elif self.query:
            shown = sanitize("⌕ " + self.query, inner)
        else:
            shown = sanitize("⌕ что хочешь послушать?", inner)
        self.add(cy, sx + 1, shown, acc if (active or self.query) else faint)
        self.add(cy, sx + sw - 1, "]", acc if active else faint)
        # справа: состояние воспроизведения и часы
        pause = self.mpv.get("pause")
        if self.playing_track and pause is False:
            state, sattr = "играет", acc
        elif self.playing_track:
            state, sattr = "пауза", dim
        else:
            state, sattr = "стоп", faint
        self.add(cy, x + w - 18, state, sattr)
        self.add(cy, x + w - 7, time.strftime("%H:%M"), dim)

    # ── Library ──
    def draw_library(self, y, x, h, w):
        self.panel(y, x, h, w, "Library")
        dim, faint, acc = (curses.color_pair(P_DIM), curses.color_pair(P_FAINT),
                           curses.color_pair(P_ACCENT))
        selbg = curses.color_pair(P_SEL)
        cy = y + 1
        self.add(cy, x + 2, "ТВОЯ ФОНОТЕКА", dim | curses.A_BOLD)
        self.add(cy, x + w - 3, "+", acc)
        cy += 1
        self.add(cy, x + 2, "─" * (w - 4), faint)
        cy += 1

        items = [
            (G_NOTE, "ОЧЕРЕДЬ", len(self.queue), 0),
            (G_SEARCH, "РЕЗУЛЬТАТЫ", len(self.search_results), 1),
            ("▤", "ЛОКАЛЬНЫЕ", len(self.lib_local), 2),
        ]
        for icon, name, cnt, tab in items:
            selrow = (self.tab == tab)
            if selrow:
                self.add(cy, x + 2, " " * (w - 4), selbg)
                self.add(cy, x + 2, "▸", curses.color_pair(P_SEL_ACC))
                self.add(cy, x + 4, sanitize(f"{icon} {name}", w - 12),
                         curses.color_pair(P_SEL_ACC) | curses.A_BOLD)
                self.add(cy, x + w - 6, str(cnt).rjust(3), curses.color_pair(P_SEL_ACC))
            else:
                self.add(cy, x + 2, " ")
                self.add(cy, x + 4, sanitize(f"{icon} {name}", w - 12), dim)
                self.add(cy, x + w - 6, str(cnt).rjust(3), faint)
            cy += 1

        # очередь: список треков
        cy += 1
        if self.queue:
            self.add(cy, x + 2, "В ОЧЕРЕДИ", faint)
            cy += 1
            avail = (y + h - 6) - cy
            for i, tr in enumerate(self.queue[:max(0, avail)]):
                cur = (i == self.qindex)
                mark = "♪" if cur else " "
                line = sanitize(f"{mark} {i + 1:02d} {tr['title']}", w - 4)
                self.add(cy, x + 2, line, acc if cur else dim)
                cy += 1

        # подсказки снизу
        hy = y + h - 6
        self.add(hy, x + 2, "─" * (w - 4), faint)
        for i, hint in enumerate([
            "space пауза · n/p трек",
            "←/→ ±5с · a очередь",
            "/ поиск · Tab вкладка",
            "q выход · s шафл",
        ]):
            self.add(hy + 1 + i, x + 2, sanitize(hint, w - 4), faint)

    # ── Main ──
    def draw_main(self, y, x, h, w):
        self.panel(y, x, h, w, "Main")
        dim, faint, acc, head = (curses.color_pair(P_DIM), curses.color_pair(P_FAINT),
                                 curses.color_pair(P_ACCENT), curses.color_pair(P_HEAD))
        selbg = curses.color_pair(P_SEL)
        cy = y + 1
        # чипы-вкладки: активная — в скобках и акцентом, прочие приглушены
        cx = x + 2
        for i, name in enumerate(self.tabs):
            act = (i == self.tab)
            label = f"[ {name} ]" if act else f"  {name}  "
            self.add(cy, cx, label, (acc | curses.A_BOLD) if act else faint)
            cx += len(label) + 1
        cy += 1
        self.add(cy, x + 2, "─" * (w - 4), faint)
        cy += 1

        lst, ti = self.current_list()
        # колонки: N | НАЗВАНИЕ | ИСПОЛНИТЕЛЬ | ДЛИТ
        durw = 6
        dur_x = x + w - durw - 1
        artw = min(20, max(0, w - 54))
        art_x = dur_x - artw - 2 if artw > 0 else dur_x
        title_x = x + 8
        title_w = max(10, (art_x if artw > 0 else dur_x) - title_x - 2)
        self.add(cy, x + 2, "№", head)
        self.add(cy, title_x, "НАЗВАНИЕ", head)
        if artw > 0:
            self.add(cy, art_x, sanitize("ИСПОЛНИТЕЛЬ", artw), head)
        self.add(cy, dur_x, "ДЛИТ", head)
        cy += 1
        self.add(cy, x + 2, "─" * (w - 4), faint)
        cy += 1

        if self.tab == 1 and self.searching:
            self.add(cy, x + 2, "⌕ ищу в YouTube…", acc)
            lst = []
        if not lst:
            msg = ("нажми / и введи запрос" if self.tab == 1
                   else ("очередь пуста · найди трек в ПОИСКЕ" if self.tab == 0
                         else "нет локальных файлов"))
            self.add(cy, x + 2, msg, faint)
            return

        avail = (y + h - 1) - cy
        start = 0
        sel = self.sel[ti]
        if sel >= avail and avail > 0:
            start = sel - avail + 1
        for i in range(start, min(len(lst), start + avail)):
            tr = lst[i]
            rowy = cy + (i - start)
            selected = (i == sel and self.focus != "search")
            now = self.playing_track is not None and tr.get("id") == self.playing_track.get("id")
            selacc = curses.color_pair(P_SEL_ACC)
            seldim = curses.color_pair(P_SEL_DIM)
            selfaint = curses.color_pair(P_SEL_FAINT)
            if selected:
                self.add(rowy, x + 2, " " * (w - 4), selbg)
            # маркер «играет» / курсор выбора
            if now:
                self.add(rowy, x + 2, "♪", selacc if selected else acc | curses.A_BOLD)
            elif selected:
                self.add(rowy, x + 2, "▸", selacc)
            else:
                self.add(rowy, x + 2, " ")
            self.add(rowy, x + 4, f"{i + 1:02d}", seldim if selected else faint)
            if selected:
                tattr = selacc | curses.A_BOLD
            elif now:
                tattr = acc | curses.A_BOLD
            else:
                tattr = dim
            self.add(rowy, title_x, sanitize(tr["title"], title_w), tattr)
            if artw > 0:
                self.add(rowy, art_x, sanitize(tr["artist"], artw), selfaint if selected else faint)
            self.add(rowy, dur_x, fmt_time(tr.get("duration")).rjust(durw), selfaint if selected else faint)

    # ── Sidebar ──
    def draw_sidebar(self, y, x, h, w):
        self.panel(y, x, h, w, "Sidebar")
        dim, faint, acc = (curses.color_pair(P_DIM), curses.color_pair(P_FAINT),
                           curses.color_pair(P_ACCENT))
        cy = y + 1
        self.add(cy, x + 2, "СЕЙЧАС ИГРАЕТ", faint)
        if self.playing_track and self.mpv.get("pause") is False:
            self.add(cy, x + w - 6, self.eqframe(), acc)
        cy += 2

        tr = self.playing_track
        cover_w = min(w - 6, 30)
        cover_h = 10
        cx = x + (w - cover_w) // 2
        if tr and self.art_lines:
            for i, ln in enumerate(self.art_lines[:cover_h]):
                self.add(cy + i, cx, sanitize(ln, cover_w), acc)
            cy += min(len(self.art_lines), cover_h)
        else:
            for i in range(cover_h):
                self.add(cy + i, cx, " " * cover_w, curses.color_pair(P_CARD))
            self.add(cy + cover_h // 2, cx + cover_w // 2 - 1, "♪", faint)
            cy += cover_h
        cy += 1
        if tr:
            self.add(cy, x + 2, sanitize(tr["title"], w - 4), acc | curses.A_BOLD)
            cy += 1
            self.add(cy, x + 2, sanitize(tr["artist"], w - 4), dim)
            cy += 1
            self.add(cy, x + 2, "YouTube · стрим" if tr.get("source") == "yt"
                     else "Локальный файл", faint)
            cy += 1
        else:
            self.add(cy, x + 2, "ничего не играет", faint)
            cy += 1
        cy += 1

        self.add(cy, x + 2, "─" * (w - 4), faint)
        cy += 1
        self.add(cy, x + 2, "ДЕТАЛИ", faint)
        cy += 1
        if tr:
            pos = self.qindex + 1 if self.queue else 0
            total = len(self.queue)
            rows = [
                ("Источник", "YouTube" if tr.get("source") == "yt" else "файл"),
                ("В очереди", f"{pos} / {total}" if total else "—"),
                ("Длительность", fmt_time(tr.get("duration"))),
                ("Состояние", "играет" if self.mpv.get("pause") is False else "пауза"),
            ]
            for k, v in rows:
                if cy >= y + h - 2:
                    break
                self.add(cy, x + 2, sanitize(k, 12), faint)
                self.add(cy, x + 15, sanitize(v, w - 17), dim)
                cy += 1

    # ── Playing ──
    def draw_playing(self, y, x, h, w):
        self.panel(y, x, h, w, "Playing")
        dim, faint, acc = (curses.color_pair(P_DIM), curses.color_pair(P_FAINT),
                           curses.color_pair(P_ACCENT))
        cy = y + 1
        tr = self.playing_track
        pause = self.mpv.get("pause")
        playing = (tr is not None and pause is False)
        vol = int(self.mpv.get("volume", 100) or 0)
        muted = self.mpv.get("mute", False)
        # обложка-миниатюра (3 строки) с эквалайзером
        cw = 7
        for i in range(3):
            self.add(cy + i, x + 2, " " * cw, curses.color_pair(P_CARD))
        self.add(cy + 1, x + 2 + 1, self.eqframe()[:3] if playing else "♪", acc)
        # название — артист — источник
        c0 = x + (w - 25) // 2
        tx = x + 2 + cw + 2
        title_w = max(10, c0 - tx - 2)
        self.add(cy, tx, sanitize(tr["title"] if tr else "ничего не играет", title_w),
                 acc | curses.A_BOLD)
        if tr:
            self.add(cy + 1, tx, sanitize(tr["artist"], title_w), dim)
            self.add(cy + 2, tx, "YouTube" if tr.get("source") == "yt" else "файл", faint)
        # транспорт по центру
        self.add(cy, c0, G_PREV, dim)
        self.add(cy, c0 + 6, G_PAUSE if playing else G_PLAY, acc | curses.A_BOLD)
        self.add(cy, c0 + 12, G_NEXT, dim)
        self.add(cy, c0 + 18, G_SHUFFLE, acc if self.shuffle else faint)
        # громкость справа
        vtxt = "MUTE" if muted else f"VOL {vol:3d}%"
        self.add(cy, x + w - 2 - len(vtxt), vtxt, faint)

        # прогресс во всю ширину
        ry = y + h - 3
        dur = self.mpv.get("duration") or (tr.get("duration") if tr else 0)
        pos = self.mpv.get("time-pos") or 0
        lt, rt = fmt_time(pos), fmt_time(dur)
        bw = w - 6 - len(lt) - len(rt) - 2
        self.add(ry, x + 2, lt, faint)
        self.bar(ry, x + 2 + len(lt) + 1, max(4, bw), (pos / dur) if dur else 0.0)
        self.add(ry, x + w - 2 - len(rt), rt, faint)

        # строка статуса / подсказки
        by = y + h - 2
        if self.status and time.time() - self.status_t < 5:
            self.add(by, x + 3, sanitize(self.status, w - 6), dim)
        else:
            hint = "q выход · / поиск · enter играть · space пауза · n/p трек · a в очередь"
            self.add(by, x + 3, sanitize(hint, w - 6), faint)

    # ── цикл ──
    def run(self):
        self.scr.nodelay(False)
        self.scr.timeout(100)
        curses.curs_set(0)
        import signal
        signal.signal(signal.SIGTERM, lambda *_: setattr(self, "_quit", True))
        while not self._quit:
            self.pump()
            self.draw()
            self.tick += 1
            ch = self.scr.getch()
            self.handle_key(ch)
        self.mpv.stop()


# ════════════════════════════════════════════════════════════════════════
def init_colors():
    curses.start_color()
    try:
        curses.use_default_colors()
    except curses.error:
        pass
    for idx, fg, bg in COLOR_INIT:
        try:
            curses.init_pair(idx, fg, bg)
        except curses.error:
            pass


def load_config():
    dirs = ["~/Music"]
    try:
        with open(CONFIG, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        if isinstance(cfg.get("music_dirs"), list):
            dirs = cfg["music_dirs"]
    except (OSError, ValueError):
        pass
    return dirs


def main_cli(stdscr, args):
    locale.setlocale(locale.LC_ALL, "")
    init_colors()
    dirs = args.music or load_config()
    app = App(stdscr, dirs)
    try:
        app.start()
    except Exception as e:                            # noqa: BLE001
        stdscr.clear()
        stdscr.addstr(2, 2, f"не удалось запустить mpv: {e}")
        stdscr.addstr(4, 2, "нажми любую клавишу")
        stdscr.nodelay(False)
        stdscr.timeout(-1)
        stdscr.getch()
        return
    app.run()


def main():
    ap = argparse.ArgumentParser(description="Lunar TUI Player")
    ap.add_argument("--music", nargs="*", help="каталоги с музыкой")
    ap.add_argument("--ascii", action="store_true", help="только ASCII-контролы")
    args = ap.parse_args()
    if args.ascii:
        global G_PREV, G_NEXT, G_PLAY, G_PAUSE, G_SHUFFLE, G_MARK, G_SEARCH, G_NOTE
        G_PREV, G_NEXT, G_PLAY, G_PAUSE = "|<", ">|", ">", "||"
        G_SHUFFLE, G_MARK, G_SEARCH, G_NOTE = "~", ">", "?", "o"
    curses.wrapper(main_cli, args)


if __name__ == "__main__":
    main()
