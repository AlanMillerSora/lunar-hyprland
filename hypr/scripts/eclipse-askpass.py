#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════
#  eclipse-askpass.py — маленький GTK-диалог ввода пароля
#  в стиле райса (для Wi-Fi и т.п.). Печатает пароль в stdout.
#
#  Использование:  eclipse-askpass.py "Пароль для «Дом»"
# ════════════════════════════════════════════════════════════
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

GLib.set_prgname("eclipse-askpass")

CSS = b"""
window {
    background: rgba(10, 10, 10, 0.97);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 16px;
}
label.prompt {
    font-family: "Inter", sans-serif;
    font-size: 13px;
    color: #e6e6e6;
    padding: 16px 18px 4px 18px;
}
entry {
    font-family: "JetBrains Mono", monospace;
    font-size: 13px;
    color: #ffffff;
    background: rgba(255, 255, 255, 0.06);
    border: none;
    border-radius: 10px;
    padding: 9px 12px;
    margin: 6px 18px;
}
entry:focus { box-shadow: inset 0 0 0 1px rgba(126, 166, 255, 0.55); }
button {
    font-family: "Inter", sans-serif;
    font-size: 12px;
    color: #cdcdcd;
    background: rgba(255, 255, 255, 0.06);
    border: none;
    border-radius: 9px;
    padding: 7px 16px;
    margin: 8px 4px 14px 4px;
}
button:hover { background: rgba(255, 255, 255, 0.12); color: #ffffff; }
button.suggested { background: rgba(126, 166, 255, 0.20); color: #b7ccff; }
button.suggested:hover { background: rgba(126, 166, 255, 0.32); color: #ffffff; }
"""


class Askpass(Gtk.Window):
    def __init__(self, prompt: str) -> None:
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.answer: str | None = None

        self.set_decorated(False)
        self.set_resizable(False)
        self.set_skip_taskbar_hint(True)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_border_width(0)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(box)

        label = Gtk.Label(label=prompt)
        label.set_xalign(0.0)
        label.get_style_context().add_class("prompt")
        box.pack_start(label, False, False, 0)

        self.entry = Gtk.Entry()
        self.entry.set_visibility(False)
        self.entry.set_input_purpose(Gtk.InputPurpose.PASSWORD)
        box.pack_start(self.entry, False, False, 0)

        btns = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        btns.set_halign(Gtk.Align.END)
        cancel = Gtk.Button(label="Отмена")
        ok = Gtk.Button(label="ОК")
        ok.get_style_context().add_class("suggested")
        btns.pack_start(cancel, False, False, 0)
        btns.pack_start(ok, False, False, 0)
        box.pack_start(btns, False, False, 0)

        self.entry.connect("activate", self._ok)
        ok.connect("clicked", self._ok)
        cancel.connect("clicked", lambda *_: self._cancel())
        self.connect("key-press-event", self._on_key)
        self.connect("destroy", lambda *_: self._cancel())

    def _ok(self, *_args) -> None:
        self.answer = self.entry.get_text()
        Gtk.main_quit()

    def _cancel(self) -> None:
        self.answer = None
        Gtk.main_quit()

    def _on_key(self, _w, event) -> bool:
        if event.keyval == Gdk.KEY_Escape:
            self._cancel()
            return True
        return False


def main() -> int:
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Пароль:"
    win = Askpass(prompt)
    win.show_all()
    win.present()
    win.entry.grab_focus()
    Gtk.main()
    if win.answer is None:
        return 1
    sys.stdout.write(win.answer)
    return 0


if __name__ == "__main__":
    sys.exit(main())
