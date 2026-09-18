#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════
#  eclipse-calendar.py — календарь-попап в стиле райса.
#  Клик по waybar-часам открывает; клик по дню копирует дату.
#
#  Клавиши: ←/→ день, ↑/↓ неделя, PgUp/PgDn месяц,
#           Home сегодня, Enter скопировать, Esc закрыть.
# ════════════════════════════════════════════════════════════
import calendar
import datetime as dt
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

GLib.set_prgname("eclipse-calendar")

RU_MONTHS = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
             "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
RU_WEEK = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

CSS = b"""
window {
    background: rgba(10, 10, 10, 0.97);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 16px;
}
.month {
    font-family: "Inter", sans-serif;
    font-size: 15px;
    font-weight: 600;
    color: #ffffff;
    letter-spacing: 0.4px;
}
.week {
    font-family: "JetBrains Mono", monospace;
    font-size: 10px;
    color: #6f6f6f;
}
.nav {
    background: transparent;
    border: none;
    color: #9f9f9f;
    font-size: 15px;
    padding: 2px 9px;
    border-radius: 9px;
    min-height: 0;
}
.nav:hover { background: rgba(255, 255, 255, 0.08); color: #ffffff; }
.day {
    background: transparent;
    border: none;
    color: #cdcdcd;
    font-family: "JetBrains Mono", monospace;
    font-size: 12px;
    border-radius: 9px;
    padding: 5px 0;
    min-width: 36px;
    min-height: 0;
}
.day:hover { background: rgba(255, 255, 255, 0.08); color: #ffffff; }
.day.weekend { color: #8a8a8a; }
.day.other   { color: #454545; }
.day.today   { color: #7ea6ff; box-shadow: inset 0 0 0 1px rgba(126, 166, 255, 0.55); }
.day.sel     { background: rgba(126, 166, 255, 0.20); color: #ffffff; }
.hint {
    font-family: "Inter", sans-serif;
    font-size: 10px;
    color: #6f6f6f;
    padding: 4px 4px 2px 4px;
}
"""


class CalendarWindow(Gtk.Window):
    def __init__(self) -> None:
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.today = dt.date.today()
        self.sel = self.today
        self.view = self.today.replace(day=1)

        self.set_decorated(False)
        self.set_resizable(False)
        self.set_skip_taskbar_hint(True)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.box)

        self._build_header()
        self.grid = Gtk.Grid(row_spacing=1, column_spacing=1)
        self.grid.set_margin_start(12)
        self.grid.set_margin_end(12)
        self.grid.set_margin_bottom(8)
        self.box.pack_start(self.grid, False, False, 0)

        hint = Gtk.Label(label="клик — скопировать дату · Esc — закрыть")
        hint.get_style_context().add_class("hint")
        self.box.pack_start(hint, False, False, 0)

        self.connect("key-press-event", self._on_key)
        self.connect("focus-out-event", lambda *_: Gtk.main_quit())
        self._render()

    # ── шапка ────────────────────────────────────────────────
    def _build_header(self) -> None:
        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        head.set_margin_top(12)
        head.set_margin_bottom(6)
        head.set_margin_start(12)
        head.set_margin_end(12)

        prev = self._nav_btn("‹", lambda *_: self._shift_month(-1))
        self.month_label = Gtk.Label()
        self.month_label.get_style_context().add_class("month")
        nxt = self._nav_btn("›", lambda *_: self._shift_month(1))

        head.pack_start(prev, False, False, 0)
        head.pack_start(self.month_label, True, True, 0)
        head.pack_start(nxt, False, False, 0)
        self.box.pack_start(head, False, False, 0)

    def _nav_btn(self, label: str, cb) -> Gtk.Button:
        b = Gtk.Button(label=label)
        b.get_style_context().add_class("nav")
        b.connect("clicked", cb)
        return b

    # ── отрисовка ────────────────────────────────────────────
    def _render(self) -> None:
        for child in self.grid.get_children():
            self.grid.remove(child)

        self.month_label.set_text(f"{RU_MONTHS[self.view.month - 1]} {self.view.year}")

        for col, name in enumerate(RU_WEEK):
            lbl = Gtk.Label(label=name)
            lbl.get_style_context().add_class("week")
            self.grid.attach(lbl, col, 0, 1, 1)

        weeks = calendar.Calendar(firstweekday=0).monthdatescalendar(
            self.view.year, self.view.month)
        for r, week in enumerate(weeks, start=1):
            for c, day in enumerate(week):
                btn = Gtk.Button(label=str(day.day))
                ctx = btn.get_style_context()
                ctx.add_class("day")
                if day.month != self.view.month:
                    ctx.add_class("other")
                if day.weekday() >= 5:
                    ctx.add_class("weekend")
                if day == self.today:
                    ctx.add_class("today")
                if day == self.sel:
                    ctx.add_class("sel")
                btn.connect("clicked", lambda _b, d=day: self._pick(d))
                self.grid.attach(btn, c, r, 1, 1)

        self.show_all()

    # ── действия ─────────────────────────────────────────────
    def _shift_month(self, delta: int) -> None:
        m = self.view.month - 1 + delta
        y = self.view.year + m // 12
        self.view = dt.date(y, m % 12 + 1, 1)
        self._render()

    def _move(self, days: int) -> None:
        self.sel = self.sel + dt.timedelta(days=days)
        if (self.sel.year, self.sel.month) != (self.view.year, self.view.month):
            self.view = self.sel.replace(day=1)
        self._render()

    def _pick(self, day: dt.date) -> None:
        text = day.isoformat()
        clip = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        clip.set_text(text, -1)
        clip.store()
        subprocess.Popen(
            ["notify-send", "-a", "Календарь", "Дата скопирована", text],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        Gtk.main_quit()

    def _on_key(self, _w, event) -> bool:
        k = event.keyval
        if k == Gdk.KEY_Escape:
            Gtk.main_quit()
        elif k in (Gdk.KEY_Left, Gdk.KEY_h):
            self._move(-1)
        elif k in (Gdk.KEY_Right, Gdk.KEY_l):
            self._move(1)
        elif k in (Gdk.KEY_Up, Gdk.KEY_k):
            self._move(-7)
        elif k in (Gdk.KEY_Down, Gdk.KEY_j):
            self._move(7)
        elif k == Gdk.KEY_Page_Up:
            self._shift_month(-1)
        elif k == Gdk.KEY_Page_Down:
            self._shift_month(1)
        elif k == Gdk.KEY_Home:
            self.sel = self.today
            self.view = self.today.replace(day=1)
            self._render()
        elif k in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            self._pick(self.sel)
        elif k == Gdk.KEY_q:
            Gtk.main_quit()
        else:
            return False
        return True


def main() -> int:
    win = CalendarWindow()
    win.show_all()
    win.present()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
