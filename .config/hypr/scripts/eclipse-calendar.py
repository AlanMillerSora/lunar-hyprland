#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════
#  eclipse-calendar.py — локальный календарь Lunar Eclipse.
#
#  Хранит события в ~/.local/share/lunar/calendar.json (права 0600):
#    {"events":[{id,date,time,title,remind,notified}...],
#     "settings":{"sound":bool,"remind":int}}
#
#  Команды (их зовёт сайдбар и Hub):
#    list                                   — весь календарь в JSON
#    add --date D [--time HH:MM] --title T [--remind N]
#    del --id ID
#    reminders                              — разослать напоминания (mako)
#    settings [--sound on|off] [--remind N] — настройки
#
#  Событие без времени считается «весь день»: напоминание в 09:00.
# ════════════════════════════════════════════════════════════════
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid

DEFAULT_REMIND = 10
ALLDAY_HOUR = 9          # во сколько «начинается» событие без времени
GRACE_MIN = 90           # сколько минут после начала ещё можно напомнить

BASE = os.environ.get("LUNAR_DATA") or os.path.join(
    os.path.expanduser("~"), ".local", "share", "lunar")
STORE = os.path.join(BASE, "calendar.json")


def load():
    try:
        with open(STORE, "r", encoding="utf-8") as f:
            d = json.load(f)
    except Exception:
        d = {}
    if not isinstance(d, dict):
        d = {}
    d.setdefault("events", [])
    st = d.setdefault("settings", {})
    st.setdefault("sound", False)
    st.setdefault("remind", DEFAULT_REMIND)
    return d


def save(d):
    os.makedirs(BASE, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=BASE, prefix=".cal-", suffix=".json")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
    os.chmod(tmp, 0o600)
    os.replace(tmp, STORE)


def event_start(ev):
    date = datetime.date.fromisoformat(ev["date"])
    t = ev.get("time") or ""
    if t:
        hh, mm = map(int, t.split(":"))
        return datetime.datetime.combine(date, datetime.time(hh, mm))
    return datetime.datetime.combine(date, datetime.time(ALLDAY_HOUR, 0))


def play_sound():
    for cmd in (["paplay", "/usr/share/sounds/freedesktop/stereo/complete.oga"],
                ["canberra-gtk-play", "-i", "complete"],
                ["pw-play", "/usr/share/sounds/freedesktop/stereo/complete.oga"]):
        if shutil.which(cmd[0]):
            subprocess.run(cmd, capture_output=True)
            return


def cmd_list(d, a):
    print(json.dumps(d, ensure_ascii=False))


def cmd_add(d, a):
    datetime.date.fromisoformat(a.date)          # проверка даты
    if a.time:
        datetime.datetime.strptime(a.time, "%H:%M")
    remind = a.remind if a.remind is not None else d["settings"].get("remind", DEFAULT_REMIND)
    ev = {"id": uuid.uuid4().hex[:12], "date": a.date, "time": a.time or "",
          "title": a.title.strip(), "remind": int(remind), "notified": False}
    d["events"].append(ev)
    save(d)
    print(json.dumps(ev, ensure_ascii=False))


def cmd_del(d, a):
    n = len(d["events"])
    d["events"] = [e for e in d["events"] if e.get("id") != a.id]
    save(d)
    print(json.dumps({"removed": n - len(d["events"])}, ensure_ascii=False))


def cmd_settings(d, a):
    if a.sound is not None:
        d["settings"]["sound"] = (a.sound == "on")
    if a.remind is not None:
        d["settings"]["remind"] = int(a.remind)
    save(d)
    print(json.dumps(d["settings"], ensure_ascii=False))


def cmd_reminders(d, a):
    now = datetime.datetime.now()
    sent = 0
    changed = False
    for ev in d["events"]:
        if ev.get("notified"):
            continue
        try:
            start = event_start(ev)
        except Exception:
            continue
        remind = int(ev.get("remind", d["settings"].get("remind", DEFAULT_REMIND)))
        when = start - datetime.timedelta(minutes=remind)
        if when <= now <= start + datetime.timedelta(minutes=GRACE_MIN):
            time_txt = start.strftime("%H:%M") if ev.get("time") else "весь день"
            body = f"{time_txt} · {ev.get('title', 'Событие')}"
            subprocess.run(["notify-send", "-a", "Календарь", "Напоминание", body],
                           capture_output=True)
            if d["settings"].get("sound"):
                play_sound()
            ev["notified"] = True
            sent += 1
            changed = True
        elif now > start + datetime.timedelta(minutes=GRACE_MIN):
            ev["notified"] = True      # просрочено — не спамим
            changed = True
    if changed:
        save(d)
    print(json.dumps({"sent": sent}, ensure_ascii=False))


def main():
    p = argparse.ArgumentParser(prog="eclipse-calendar.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    sub.add_parser("reminders")

    pa = sub.add_parser("add")
    pa.add_argument("--date", required=True)
    pa.add_argument("--time", default="")
    pa.add_argument("--title", required=True)
    pa.add_argument("--remind", type=int, default=None)

    pd = sub.add_parser("del")
    pd.add_argument("--id", required=True)

    ps = sub.add_parser("settings")
    ps.add_argument("--sound", choices=["on", "off"], default=None)
    ps.add_argument("--remind", type=int, default=None)

    a = p.parse_args()
    d = load()
    {"list": cmd_list, "add": cmd_add, "del": cmd_del,
     "settings": cmd_settings, "reminders": cmd_reminders}[a.cmd](d, a)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:                       # noqa: BLE001
        print(json.dumps({"error": str(e)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
