#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════
#  eclipse-cheatsheet.py — оверлей горячих клавиш в стиле райса.
#  Открывается по SUPER + /, закрывается Esc или кликом.
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
        ("SUPER + D", "лаунчер"),
        ("SUPER + A", "запуск команды"),
        ("SUPER + E", "файлы (Dolphin)"),
        ("SUPER + V", "буфер обмена"),
        ("SUPER + SHIFT + E", "панель слева"),
        ("SUPER + SHIFT + R", "панель справа"),
        ("SUPER + /", "горячие клавиши"),
        ("SUPER + SHIFT + L", "блокировка"),
    ]),
    ("Окна", [
        ("SUPER + Q", "закрыть"),
        ("SUPER + W", "максимизировать"),
        ("SUPER + SHIFT + W", "фуллскрин"),
        ("SUPER + F", "плавающее"),
        ("SUPER + P", "псевдотайлинг"),
        ("SUPER + T", "группа (вкладки)"),
        ("SUPER + SPACE", "следующее окно"),
    ]),
    ("Фокус и перенос", [
        ("SUPER + HJKL", "фокус"),
        ("SUPER + стрелки", "фокус"),
        ("SUPER + SHIFT + стрелки", "перенести окно"),
    ]),
    ("Столы = фазы", [
        ("SUPER + 1..8", "перейти на фазу"),
        ("SUPER + SHIFT + 1..8", "перенести окно"),
        ("SUPER + S", "скретчпад"),
        ("SUPER + SHIFT + S", "окно в скретчпад"),
    ]),
    ("Система", [
        ("SUPER + R", "перечитать конфиг"),
        ("SUPER + C", "выход из Hyprland"),
        ("PRINT", "скриншот области"),
        ("SUPER + PRINT", "скриншот экрана"),
    ]),
    ("Мышь и звук", [
        ("клик по 󰕾", "громкость (ползунок)"),
        ("правый клик 󰕾", "микшер (pavucontrol)"),
        ("клик по 󰻠", "btop (монитор)"),
        ("клик по 󰖩", "список Wi-Fi"),
        ("клик по часам", "календарь"),
        ("XF86 Audio ±", "громкость"),
    ]),
]

CSS = b"""
window.background {
    background: rgba(10, 10, 10, 0.97);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 18px;
}
button, button:hover, button:active, button:focus {
    background-image: none;
    box-shadow: none;
    text-shadow: none;
}
.title {
    font-family: "Inter", sans-serif;
    font-size: 17px;
    font-weight: 600;
    color: #ffffff;
}
.subtitle {
    font-family: "JetBrains Mono", monospace;
    font-size: 10px;
    color: #6f6f6f;
}
.sec {
    font-family: "Inter", sans-serif;
    font-size: 11px;
    font-weight: 600;
    color: #7ea6ff;
    letter-spacing: 1.2px;
    padding-bottom: 2px;
}
.key {
    font-family: "JetBrains Mono", monospace;
    font-size: 11px;
    color: #b7ccff;
    background: rgba(126, 166, 255, 0.12);
    border-radius: 6px;
    padding: 3px 7px;
}
.desc {
    font-family: "Inter", sans-serif;
    font-size: 12px;
    color: #cdcdcd;
}
.hint {
    font-family: "Inter", sans-serif;
    font-size: 10px;
    color: #6f6f6f;
}
"""


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

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        root.set_margin_top(16)
        root.set_margin_bottom(12)
        root.set_margin_start(20)
        root.set_margin_end(20)
        self.add(root)

        title = Gtk.Label(label="Горячие клавиши")
        title.set_xalign(0.0)
        title.get_style_context().add_class("title")
        root.pack_start(title, False, False, 0)

        sub = Gtk.Label(label="Lunar Eclipse · Hyprland")
        sub.set_xalign(0.0)
        sub.get_style_context().add_class("subtitle")
        root.pack_start(sub, False, False, 0)

        grid = Gtk.Grid(column_spacing=36, row_spacing=14)
        grid.set_margin_top(14)
        root.pack_start(grid, False, False, 0)

        for i, (name, binds) in enumerate(SECTIONS):
            col = i % 2
            row = i // 2
            grid.attach(self._section(name, binds), col, row, 1, 1)

        hint = Gtk.Label(label="Esc — закрыть")
        hint.get_style_context().add_class("hint")
        hint.set_margin_top(14)
        root.pack_start(hint, False, False, 0)

        self.connect("key-press-event", self._on_key)
        self.connect("button-press-event", lambda *_: Gtk.main_quit())
        self.connect("focus-out-event", lambda *_: Gtk.main_quit())

    def _section(self, name: str, binds) -> Gtk.Box:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        head = Gtk.Label(label=name)
        head.set_xalign(0.0)
        head.get_style_context().add_class("sec")
        box.pack_start(head, False, False, 0)

        for keys, desc in binds:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            key = Gtk.Label(label=keys)
            key.set_xalign(0.0)
            key.get_style_context().add_class("key")
            key.set_size_request(160, -1)
            d = Gtk.Label(label=desc)
            d.set_xalign(0.0)
            d.get_style_context().add_class("desc")
            row.pack_start(key, False, False, 0)
            row.pack_start(d, False, False, 0)
            box.pack_start(row, False, False, 0)
        return box

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
