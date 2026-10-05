#!/usr/bin/env python3
"""Сверка токенов Theme.qml с документацией — ловлю дрейф доков.

Источник чисел — .config/quickshell/Theme.qml. Если код и доки
(AGENTS.md §5 и DESIGN.md §2.4) разошлись — это дрейф, exit 1.
Зову из ci/check.sh. Правлю числа — правлю и доки, и наоборот.
"""
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]


def flat(text: str) -> str:
    """Схлопываю переносы/отступы — доки свёрстаны по ширине."""
    return re.sub(r"\s+", " ", text)


def read(path: str) -> str:
    return flat((ROOT / path).read_text(encoding="utf-8"))


def nums(raw: str):
    return [int(x) for x in re.findall(r"\d+", raw)]


# ── Theme.qml: name -> (classic, arch | None) ───────────────────
def theme_tokens():
    src = (ROOT / ".config/quickshell/Theme.qml").read_text(encoding="utf-8")
    pat = re.compile(
        r"property\s+int\s+(\w+)\s*:\s*"
        r"(?:arch\s*\?\s*(\d+)\s*:\s*(\d+)|(\d+))"
    )
    out = {}
    for m in pat.finditer(src):
        name = m.group(1)
        if m.group(2) is not None:
            out[name] = (int(m.group(3)), int(m.group(2)))  # classic, arch
        else:
            out[name] = (int(m.group(4)), None)
    return out


def _seq(text, pattern, label):
    m = re.search(pattern, text)
    if not m:
        raise SystemExit(f"[токены] не нашёл в {label}: {pattern}")
    return nums(m.group(1))


def _int(text, pattern, label):
    m = re.search(pattern, text)
    if not m:
        raise SystemExit(f"[токены] не нашёл в {label}: {pattern}")
    return int(m.group(1))


# ── AGENTS.md §5 ────────────────────────────────────────────────
def agents_doc(t: str):
    d = {}
    for i, v in enumerate(_seq(t, r"`space1\.\.6`\s*([\d\s/]+?);", "AGENTS.md"), 1):
        d[f"space{i}"] = (v, None)
    for name, v in zip(
        ["rowHCompact", "rowH", "rowHComfy"],
        _seq(t, r"`rowHCompact/rowH/rowHComfy`\s*([\d\s/]+?),", "AGENTS.md"),
    ):
        d[name] = (v, None)
    d["headerH"] = (_int(t, r"`headerH`\s*(\d+)", "AGENTS.md"), None)

    radii = _seq(t, r"`radiusS/radius/radiusM/radiusL`\s*([\d\s/]+?)\s*\(arch", "AGENTS.md")
    radii_arch = _seq(t, r"`radiusS/radius/radiusM/radiusL`[^(]*\(arch\s*([\d\s/]+?)\)", "AGENTS.md")
    for name, v, a in zip(["radiusS", "radius", "radiusM", "radiusL"], radii, radii_arch):
        d[name] = (v, a)

    m = re.search(
        r"`barH/barMargin/barTop/barPad/barRadius`\s*classic\s*([\d\s/]+?)\s*\(arch\s*([\d\s/]+?)\)",
        t,
    )
    if not m:
        raise SystemExit("[токены] не нашёл в AGENTS.md строку панели")
    names = ["barH", "barMargin", "barTop", "barPad", "barRadius"]
    for name, v, a in zip(names, nums(m.group(1)), nums(m.group(2))):
        d[name] = (v, a)

    d["barCellH"] = (_int(t, r"`barCellH`\s*(\d+)", "AGENTS.md"), None)
    for name, v in zip(
        ["panelFieldH", "panelRowH", "sparkH"],
        _seq(t, r"`panelFieldH/panelRowH/sparkH`\s*([\d\s/]+?);", "AGENTS.md"),
    ):
        d[name] = (v, None)
    # `iconXL/cardPad` 30/16 — iconXL в Theme.qml через fontSize(), сверяю только cardPad
    d["cardPad"] = (_seq(t, r"`iconXL/cardPad`\s*([\d\s/]+?);", "AGENTS.md")[1], None)
    return d


# ── DESIGN.md §2.4 ──────────────────────────────────────────────
def design_doc(t: str):
    d = {}
    for i, v in enumerate(_seq(t, r"`space1\.\.6`\s*=\s*\*\*([\d\s/]+?)\*\*", "DESIGN.md"), 1):
        d[f"space{i}"] = (v, None)
    for name, v in zip(
        ["rowHCompact", "rowH", "rowHComfy"],
        _seq(t, r"`rowHCompact / rowH / rowHComfy`\s*=\s*\*\*([\d\s/]+?)\*\*", "DESIGN.md"),
    ):
        d[name] = (v, None)
    d["headerH"] = (_int(t, r"`headerH`\s*(\d+)", "DESIGN.md"), None)

    m = re.search(
        r"`radiusS / radius / radiusM / radiusL`\s*=\s*classic\s*\*\*([\d\s/]+?)\*\*"
        r"\s*→\s*arch\s*\*\*([\d\s/]+?)\*\*",
        t,
    )
    if not m:
        raise SystemExit("[токены] не нашёл в DESIGN.md строку радиусов")
    for name, v, a in zip(["radiusS", "radius", "radiusM", "radiusL"], nums(m.group(1)), nums(m.group(2))):
        d[name] = (v, a)

    def arrow(name, pattern):
        mm = re.search(pattern, t)
        if not mm:
            raise SystemExit(f"[токены] не нашёл в DESIGN.md: {name}")
        d[name] = (int(mm.group(1)), int(mm.group(2)))

    arrow("barH", r"`barH`\s*(\d+)\s*→\s*\*\*(\d+)\*\*")
    arrow("barMargin", r"`barMargin`\s*(\d+)\s*→\s*\*\*(\d+)\*\*")
    arrow("barTop", r"`barTop`\s*(\d+)\s*→\s*\*\*(\d+)\*\*")
    arrow("barRadius", r"`barRadius`\s*(\d+)\s*→\s*\*\*(\d+)\*\*")
    d["barPad"] = (_int(t, r"`barPad`\s*(\d+)", "DESIGN.md"), None)
    d["barCellH"] = (_int(t, r"`barCellH`\s*(\d+)", "DESIGN.md"), None)
    d["panelHeaderH"] = (_int(t, r"`panelHeaderH`\s*(\d+)", "DESIGN.md"), None)
    d["cardPad"] = (_int(t, r"`cardPad`\s*(\d+)", "DESIGN.md"), None)
    d["sparkH"] = (_int(t, r"`sparkH`\s*(\d+)", "DESIGN.md"), None)
    return d


def compare(label: str, doc: dict, theme: dict):
    bad = []
    for name, (dc, da) in doc.items():
        if name not in theme:
            bad.append(f"{name}: нет в Theme.qml, но документирован в {label}")
            continue
        tc, ta = theme[name]
        if tc != dc:
            bad.append(f"{name}: Theme classic={tc}, {label}={dc}")
        if da is not None:
            if ta is None:
                # токен без arch-ветки: док обязан совпасть с classic
                if da != tc:
                    bad.append(f"{name}: в Theme.qml нет arch-ветки (classic={tc}), {label} обещает arch={da}")
            elif ta != da:
                bad.append(f"{name}: Theme arch={ta}, {label}={da}")
    return bad


def main():
    theme = theme_tokens()
    problems = compare("AGENTS.md §5", agents_doc(read("AGENTS.md")), theme)
    problems += compare("DESIGN.md §2.4", design_doc(read("DESIGN.md")), theme)
    if problems:
        print("дрейф токенов Theme.qml ↔ доки:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"OK: {len(theme)} токенов Theme.qml, доки совпадают")
    return 0


if __name__ == "__main__":
    sys.exit(main())
