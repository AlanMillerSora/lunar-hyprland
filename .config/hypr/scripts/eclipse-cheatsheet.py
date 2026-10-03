#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════
#  eclipse-cheatsheet.py — оверлей горячих клавиш в стиле райса.
#  Открывается по SUPER + /, из правого сайдбара, Esc или клик — закрыть.
#  Оформление — как у карточки Hub: монохром, Roboto Mono,
#  рамка 1px, радиус 6, HUD-скобки по углам.
# ════════════════════════════════════════════════════════════
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

GLib.set_prgname("eclipse-cheatsheet")

SECTIONS = [
    ("Приложения", [
        ("SUPER + RETURN", "терминал"),
        ("SUPER + G", "Hub: лаунчер и настройки"),
        ("SUPER + B", "подбор обоев"),
        ("SUPER + E", "файлы (Thunar)"),
        ("SUPER + V", "буфер обмена"),
        ("SUPER + M", "плеер"),
        ("SUPER + A", "агент (OpenCode)"),
        ("SUPER + SHIFT + E", "панель слева"),
        ("SUPER + SHIFT + N", "панель справа"),
        ("SUPER + SHIFT + D", "раздел «Разработка»"),
        ("SUPER + /", "горячие клавиши"),
        ("SUPER + ESC", "меню питания"),
    ]),
    ("Панель бара", [
        ("SUPER + C", "пульт (действия/звук)"),
        ("SUPER + X", "медиа"),
        ("SUPER + D", "поиск"),
        ("SUPER + N", "уведомления"),
        ("SUPER + I", "телеметрия"),
        ("SUPER + O", "обзор столов"),
    ]),
    ("Окна", [
        ("SUPER + Q", "закрыть"),
        ("SUPER + W", "максимизировать"),
        ("SUPER + SHIFT + W", "фуллскрин"),
        ("SUPER + F", "плавающее"),
        ("SUPER + P", "псевдотайлинг"),
        ("SUPER + SHIFT + P", "закрепить поверх"),
        ("SUPER + TAB", "следующее окно"),
        ("SUPER + SHIFT + TAB", "обзор столов"),
        ("SUPER + T", "группа (вкладки)"),
        ("SUPER + SHIFT + T", "закрепить вкладку"),
        ("SUPER + SPACE", "следующее окно"),
    ]),
    ("Фокус и перенос", [
        ("SUPER + HJKL", "фокус"),
        ("SUPER + стрелки", "фокус"),
        ("SUPER + SHIFT + стрелки", "перенести окно"),
        ("SUPER + ЛКМ", "перетащить окно"),
        ("SUPER + ПКМ", "изменить размер"),
    ]),
    ("Столы = фазы", [
        ("SUPER + 1..9", "перейти на фазу"),
        ("SUPER + SHIFT + 1..9", "перенести окно"),
        ("SUPER + S", "скретчпад"),
        ("SUPER + SHIFT + S", "окно в скретчпад"),
    ]),
    ("Система", [
        ("SUPER + SHIFT + R", "запись экрана (вкл/выкл)"),
        ("SUPER + SHIFT + G", "Game Mode (вкл/выкл)"),
        ("SUPER + R", "перечитать конфиг"),
        ("PRINT", "скриншот области"),
        ("SUPER + PRINT", "скриншот в буфер"),
        ("SUPER + SHIFT + PRINT", "скриншот в файл"),
    ]),
    ("Мышь и звук", [
        ("клик по громкости", "пульт (ползунок звука)"),
        ("правый клик по громкости", "микшер (pavucontrol)"),
        ("колесо над часами", "громкость"),
        ("клик по треку", "медиа-панель"),
        ("клик по систем-острову", "телеметрия"),
        ("клик по погоде", "панель погоды"),
        ("клик по колоколу", "уведомления"),
        ("клик по сети", "Hub: сеть"),
        ("XF86 Audio ±", "громкость"),
    ]),
]

# палитра Lunar Eclipse: фон #08090d, текст #e8ecf2, dim #98a1ac, рамки #23262d
CSS = b"""
window.background {
    background: #08090d;
    border: 1px solid #e8ecf2;
    border-radius: 6px;
}
.title {
    font-family: "Roboto Mono", monospace;
    font-size: 20px;
    font-weight: bold;
    color: #e8ecf2;
    letter-spacing: 4px;
}
.subtitle {
    font-family: "Roboto Mono", monospace;
    font-size: 10px;
    color: #5b636d;
    letter-spacing: 2px;
}
.sec {
    font-family: "Roboto Mono", monospace;
    font-size: 13px;
    font-weight: bold;
    color: #e8ecf2;
    letter-spacing: 2px;
}
.key {
    font-family: "Roboto Mono", monospace;
    font-size: 12px;
    color: #e8ecf2;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: 6px;
    padding: 4px 9px;
}
.desc {
    font-family: "Roboto Mono", monospace;
    font-size: 12px;
    color: #98a1ac;
}
.hint {
    font-family: "Roboto Mono", monospace;
    font-size: 10px;
    color: #5b636d;
    letter-spacing: 1px;
}
.sep {
    background: #23262d;
}
"""

CORNER = 26      # длина луча HUD-скобки
THICK = 2        # толщина
CMARGIN = 12     # отступ от края


class Cheatsheet(Gtk.Window):
    def __init__(self) -> None:
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_skip_taskbar_hint(True)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)

        settings = Gtk.Settings.get_default()
        if settings is not None:
            settings.set_property("gtk-application-prefer-dark-theme", True)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        overlay = Gtk.Overlay()
        self.add(overlay)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        root.set_margin_top(20)
        root.set_margin_bottom(14)
        root.set_margin_start(24)
        root.set_margin_end(24)
        overlay.add(root)

        # ── шапка ──────────────────────────────────────────────
        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        title = Gtk.Label(label="ГОРЯЧИЕ КЛАВИШИ")
        title.set_xalign(0.0)
        title.get_style_context().add_class("title")
        head.pack_start(title, False, False, 0)

        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        head.pack_start(spacer, True, True, 0)

        sub = Gtk.Label(label="LUNAR ECLIPSE")
        sub.set_xalign(1.0)
        sub.get_style_context().add_class("subtitle")
        head.pack_end(sub, False, False, 0)

        root.pack_start(head, False, False, 0)

        sep = self._sep()
        sep.set_margin_top(14)
        root.pack_start(sep, False, False, 0)

        # ── секции: две колонки, построчно ─────────────────────
        grid = Gtk.Grid(column_spacing=48, row_spacing=16)
        grid.set_margin_top(16)
        root.pack_start(grid, False, False, 0)

        for i, (name, binds) in enumerate(SECTIONS):
            grid.attach(self._section(name, binds), i % 2, i // 2, 1, 1)

        hint = Gtk.Label(label="ESC — ЗАКРЫТЬ")
        hint.get_style_context().add_class("hint")
        hint.set_margin_top(14)
        root.pack_start(hint, False, False, 0)

        # ── HUD-скобки по углам ────────────────────────────────
        for hx, vy in (("l", "t"), ("r", "t"), ("l", "b"), ("r", "b")):
            overlay.add_overlay(self._corner(hx, vy))

        self.connect("key-press-event", self._on_key)
        self.connect("button-press-event", lambda *_: Gtk.main_quit())
        self.connect("focus-out-event", lambda *_: Gtk.main_quit())

    def _sep(self) -> Gtk.Box:
        box = Gtk.Box()
        box.get_style_context().add_class("sep")
        box.set_size_request(-1, 1)
        return box

    def _section(self, name: str, binds) -> Gtk.Box:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)

        head = Gtk.Label(label=name.upper())
        head.set_xalign(0.0)
        head.get_style_context().add_class("sec")
        box.pack_start(head, False, False, 0)

        for keys, desc in binds:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            key = Gtk.Label(label=keys)
            key.set_xalign(0.0)
            key.get_style_context().add_class("key")
            key.set_size_request(200, -1)
            d = Gtk.Label(label=desc)
            d.set_xalign(0.0)
            d.get_style_context().add_class("desc")
            row.pack_start(key, False, False, 0)
            row.pack_start(d, False, False, 0)
            box.pack_start(row, False, False, 0)
        return box

    def _corner(self, hx: str, vy: str) -> Gtk.DrawingArea:
        da = Gtk.DrawingArea()
        da.set_size_request(CORNER, CORNER)

        def draw(_w, cr):
            cr.set_source_rgb(1, 1, 1)
            cr.set_line_width(THICK)
            cr.set_line_cap(1)  # rectangular caps — острые углы, как в Hub
            if hx == "l" and vy == "t":
                cr.move_to(0, CORNER)
                cr.line_to(0, 0)
                cr.line_to(CORNER, 0)
            elif hx == "r" and vy == "t":
                cr.move_to(0, 0)
                cr.line_to(CORNER, 0)
                cr.line_to(CORNER, CORNER)
            elif hx == "l" and vy == "b":
                cr.move_to(0, 0)
                cr.line_to(0, CORNER)
                cr.line_to(CORNER, CORNER)
            else:
                cr.move_to(CORNER, 0)
                cr.line_to(CORNER, CORNER)
                cr.line_to(0, CORNER)
            cr.stroke()

        da.connect("draw", draw)

        if hx == "l":
            da.set_halign(Gtk.Align.START)
            da.set_margin_start(CMARGIN)
        else:
            da.set_halign(Gtk.Align.END)
            da.set_margin_end(CMARGIN)

        if vy == "t":
            da.set_valign(Gtk.Align.START)
            da.set_margin_top(CMARGIN)
        else:
            da.set_valign(Gtk.Align.END)
            da.set_margin_bottom(CMARGIN)

        return da

    def _on_key(self, _w, event) -> bool:
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY_q, Gdk.KEY_slash):
            Gtk.main_quit()
            return True
        return False


def main() -> int:
    win = Cheatsheet()
    win.show_all()
    win.present()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
