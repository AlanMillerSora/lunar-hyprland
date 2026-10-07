#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════════════
#  Lunar TUI — приложение. Окно-хост на GTK3 + VTE: запускает наш
#  lunar_tui.py как родной терминал внутри ЧИСТОГО окна (без шапки,
#  скроллбара и рамок kitty). Внешне — ровно тот же TUI.
#
#  Класс окна — `lunar-tui`: по нему Hyprland делает окно плавающим
#  (window_rule в hyprland.lua) и по нему же лаунчер находит окно.
#
#  Запуск: ~/.config/hypr/scripts/lunar-tui (хоткей SUPER+M)
# ════════════════════════════════════════════════════════════════════════
import os
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("Pango", "1.0")
gi.require_version("Vte", "2.91")

from gi.repository import Gdk, GLib, Gtk, Pango, Vte  # noqa: E402

APP_ID = "lunar-tui"
TITLE = "Lunar TUI"
PLAYER = os.path.expanduser("~/.config/lunar/tui/lunar_tui.py")
FONT = os.environ.get("LUNAR_TUI_FONT", "Roboto Mono 12")
WIN_W = int(os.environ.get("LUNAR_TUI_W", "1600"))
WIN_H = int(os.environ.get("LUNAR_TUI_H", "900"))

# цвета из lunar-палитры (kitty lunar-theme): фон/текст + 16 базовых
BG = "#0a0b0f"
FG = "#e6e7e8"
PALETTE = [
    "#0b0d0f", "#819ab1", "#dadbdd", "#9bb4ca",
    "#dadbdd", "#819ab1", "#dadbdd", "#e6e7e8",
    "#475d70", "#ff003c", "#c9cccf", "#9bb4ca",
    "#dadbdd", "#819ab1", "#9bb4ca", "#e6e7e8",
]

CSS = """
window, window.background, vte-terminal {
    background-color: %s;
    padding: 0;
    margin: 0;
    border: 0;
}
""" % BG


def rgba(hexstr):
    c = Gdk.RGBA()
    c.parse(hexstr)
    return c


class LunarApp(Gtk.Window):
    def __init__(self):
        super().__init__(title=TITLE)
        self.set_wmclass(APP_ID, APP_ID)
        self.set_role(APP_ID)
        self.set_decorated(False)          # рамку/скругление рисует Hyprland
        self.set_resizable(True)
        self.set_default_size(WIN_W, WIN_H)

        # фон окна — как у плеера (без белой вспышки при старте)
        prov = Gtk.CssProvider()
        prov.load_from_data(CSS.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), prov,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.term = Vte.Terminal()
        self.term.set_font(Pango.FontDescription(FONT))
        self.term.set_scrollback_lines(0)          # без истории и скроллбара
        self.term.set_cursor_blink_mode(Vte.CursorBlinkMode.OFF)
        self.term.set_cursor_shape(Vte.CursorShape.BLOCK)
        self.term.set_allow_bold(True)
        for opt, val in (("set_mouse_autohide", True),
                         ("set_rewrap_on_resize", True)):
            fn = getattr(self.term, opt, None)
            if fn:
                fn(val)
        self.term.set_colors(rgba(FG), rgba(BG), [rgba(c) for c in PALETTE])

        self.add(self.term)
        self.connect("destroy", Gtk.main_quit)
        self.term.connect("child-exited", lambda *_: Gtk.main_quit())

        ok, pid = self.term.spawn_sync(
            Vte.PtyFlags.DEFAULT, None,
            ["python3", PLAYER], None,
            GLib.SpawnFlags.DEFAULT, None, None, None)
        if not ok:
            # mpv/TUI не поднялись — покажем окно всё равно, но скажем
            sys.stderr.write("lunar-tui: не удалось запустить плеер\n")


def main():
    # имя процесса → app_id окна на Wayland; нужно для window_rule
    GLib.set_prgname(APP_ID)
    Gtk.init(None)
    app = LunarApp()
    app.show_all()
    app.present()
    Gtk.main()


if __name__ == "__main__":
    main()
