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
RU_WEEK = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

CSS = """
/* Никаких градиентов и светлых подложек Adwaita */
window.background {
    background: rgba(10, 10, 10, 0.97);
    border: 1px solid rgba(255, 255, 255, 0.09);
    border-radius: 18px;
}
button, button:hover, button:active, button:focus {
    background-image: none;
    box-shadow: none;
    text-shadow: none;
}

.month {
    font-family: "Inter", sans-serif;
    font-size: 15px;
    font-weight: 600;
    color: #ffffff;
    letter-spacing: 0.3px;
}
.year {
    font-family: "JetBrains Mono", monospace;
    font-size: 10px;
    color: #7ea6ff;
    letter-spacing: 2px;
}
.nav {
    background: transparent;
    border: none;
    color: #8a8a8a;
    font-size: 16px;
    padding: 2px 10px;
    border-radius: 10px;
    min-height: 0;
    min-width: 0;
}
.nav:hover { background: rgba(255, 255, 255, 0.07); color: #ffffff; }

.week {
    font-family: "JetBrains Mono", monospace;
    font-size: 10px;
    color: #5f5f5f;
    padding: 2px 0 6px 0;
}

.day {
    background: transparent;
    border: none;
    color: #cfcfcf;
    font-family: "JetBrains Mono", monospace;
    font-size: 12px;
    border-radius: 10px;
    padding: 7px 0;
    min-width: 40px;
    min-height: 0;
}
.day:hover { background: rgba(255, 255, 255, 0.08); color: #ffffff; }
.day.weekend { color: #909090; }
.day.other   { color: #4a4a4a; }
.day.other:hover { color: #8a8a8a; }
.day.today {
    color: #7ea6ff;
    box-shadow: inset 0 0 0 1.5px rgba(126, 166, 255, 0.65);
}
.day.sel {
    background: #7ea6ff;
    color: #05060a;
    font-weight: 700;
}
.day.sel:hover { background: #9fbcff; color: #05060a; }

.footer {
    font-family: "Inter", sans-serif;
    font-size: 10px;
    color: #6f6f6f;
    padding: 10px 2px 2px 2px;
}
.footer-day {
    font-family: "JetBrains Mono", monospace;
    font-size: 10px;
    color: #b7ccff;
    padding: 10px 2px 2px 2px;
}
"""


class CalendarWindow(Gtk.Window):
    def __init__(self) -> None:
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.today = dt.date.today()
        self.sel = self.today
        self.view = self.today.replace(day=1)

        settings = Gtk.Settings.get_default()
        if settings is not None:
            settings.set_property("gtk-application-prefer-dark-theme", True)

        self.set_decorated(False)
        self.set_resizable(False)
        self.set_skip_taskbar_hint(True)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_name("eclipse-calendar")

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        box.set_margin_top(14)
        box.set_margin_bottom(10)
        box.set_margin_start(16)
        box.set_margin_end(16)
        self.add(box)

        self._build_header(box)
        self._build_weekdays(box)
        self.days = Gtk.Grid(column_homogeneous=True, row_spacing=1, column_spacing=1)
        self.days.set_margin_top(2)
        box.pack_start(self.days, False, False, 0)
        self._build_footer(box)

        self.connect("key-press-event", self._on_key)
        self.connect("focus-out-event", lambda *_: Gtk.main_quit())
        self._render()

    # ── шапка ────────────────────────────────────────────────
    def _build_header(self, box: Gtk.Box) -> None:
        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        head.set_margin_bottom(10)

        prev = self._nav("‹", lambda *_: self._shift_month(-1))
        center = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        center.set_hexpand(True)
        self.month_label = Gtk.Label()
        self.month_label.get_style_context().add_class("month")
        self.year_label = Gtk.Label()
        self.year_label.get_style_context().add_class("year")
        center.pack_start(self.month_label, False, False, 0)
        center.pack_start(self.year_label, False, False, 0)
        nxt = self._nav("›", lambda *_: self._shift_month(1))

        head.pack_start(prev, False, False, 0)
        head.pack_start(center, True, True, 0)
        head.pack_start(nxt, False, False, 0)
        box.pack_start(head, False, False, 0)

    def _nav(self, label: str, cb) -> Gtk.Button:
        b = Gtk.Button(label=label)
        b.get_style_context().add_class("nav")
        b.connect("clicked", cb)
        return b

    def _build_weekdays(self, box: Gtk.Box) -> None:
        grid = Gtk.Grid(column_homogeneous=True)
        for col, name in enumerate(RU_WEEK):
            lbl = Gtk.Label(label=name)
            lbl.set_size_request(40, -1)
            lbl.get_style_context().add_class("week")
            grid.attach(lbl, col, 0, 1, 1)
        box.pack_start(grid, False, False, 0)

    def _build_footer(self, box: Gtk.Box) -> None:
        foot = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.footer_day = Gtk.Label(label=self.sel.isoformat())
        self.footer_day.get_style_context().add_class("footer-day")
        self.footer_day.set_xalign(0.0)
        hint = Gtk.Label(label="клик — копировать · Esc — закрыть")
        hint.get_style_context().add_class("footer")
        hint.set_xalign(1.0)
        hint.set_hexpand(True)
        foot.pack_start(self.footer_day, False, False, 0)
        foot.pack_start(hint, True, True, 0)
        box.pack_start(foot, False, False, 0)

    # ── отрисовка ────────────────────────────────────────────
    def _render(self) -> None:
        for child in self.days.get_children():
            self.days.remove(child)

        self.month_label.set_text(RU_MONTHS[self.view.month - 1])
        self.year_label.set_text(str(self.view.year))
        self.footer_day.set_text(self.sel.isoformat())

        weeks = calendar.Calendar(firstweekday=0).monthdatescalendar(
            self.view.year, self.view.month)
        for r, week in enumerate(weeks):
            for c, day in enumerate(week):
                btn = Gtk.Button(label=str(day.day))
                btn.set_size_request(40, 34)
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
                self.days.attach(btn, c, r, 1, 1)

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
