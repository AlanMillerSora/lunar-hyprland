#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════
#  eclipse-palette.py — раскладка единой палитры Lunar Eclipse.
#
#  Источник цветов: ~/.config/lunar/palette.toml (пресеты + active).
#  Шаблоны:         ~/.config/lunar/templates/*.in
#
#  Что делает:
#    · пишет ~/.cache/lunar/palette.json (его читает Theme.qml);
#    · раскладывает цвета по приложениям — kitty, GTK3/4, qt6ct,
#      mako, btop, yazi и fastfetch.
#  Основные конфиги НЕ перезаписываю: генерирую отдельные файлы,
#  которые подключаются через include/@import.
#
#  Запуск:
#    eclipse-palette.py                      # dry-run: показать план
#    eclipse-palette.py --preset steel       # dry-run другого пресета
#    eclipse-palette.py --out /tmp/test      # записать всё в каталог (тест)
#    eclipse-palette.py --apply              # записать в реальные места
#
#  Только stdlib (python3.11+: tomllib). Живые конфиги не трогаю, пока
#  явно не передан --apply.
# ════════════════════════════════════════════════════════════════
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    print("нужен python3.11+ (модуль tomllib)", file=sys.stderr)
    raise SystemExit(1)

HOME = Path.home()

# Скрипт лежит в <root>/.config/hypr/scripts/, поэтому <root>/.config —
# это parents[2]. Так путь одинаков и в репозитории, и в ~/.config.
CONFIG_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PALETTE = CONFIG_ROOT / "lunar" / "palette.toml"
DEFAULT_TEMPLATES = CONFIG_ROOT / "lunar" / "templates"

# Куда пишем при --apply.
APPLY_CONFIG_ROOT = HOME / ".config"
# KDE-схема живёт не в ~/.config, а в ~/.local/share/color-schemes
APPLY_SHARE_ROOT = HOME / ".local" / "share"
APPLY_CACHE_JSON = HOME / ".cache" / "lunar" / "palette.json"
APPLY_STATE_PRESET = HOME / ".cache" / "lunar" / "preset"
# путь картинки, из которой построена «фотопалитра» (--from-image)
APPLY_PHOTO_PATH = HOME / ".cache" / "lunar" / "photo"
# пресет, который стоял ДО фотопалитры: возвращаю его на «сцену»
APPLY_PREV_PRESET = HOME / ".cache" / "lunar" / "preset-prev"


# ── цвета ───────────────────────────────────────────────────────
def parse_hex(value: str):
    """'#rrggbb' | '#rrggbbaa' -> (r, g, b, a) с a в 0..1."""
    s = value.strip().lstrip("#")
    if len(s) == 6:
        s += "ff"
    if len(s) != 8:
        raise ValueError(f"не понимаю цвет: {value!r}")
    r, g, b, a = (int(s[i:i + 2], 16) for i in (0, 2, 4, 6))
    return r, g, b, a / 255.0


def rgb6(value: str) -> str:
    """'#rrggbb' или '#rrggbbaa' -> '#rrggbb' (без альфы)."""
    r, g, b, _ = parse_hex(value)
    return f"#{r:02x}{g:02x}{b:02x}"


def solid(value: str, over: str) -> str:
    """Сплющить цвет с альфой поверх фона (нужно там, где альфа не держится:
    btop, yazi, qt6ct, GTK borders). 6-значный отдаём как есть."""
    s = value.strip().lstrip("#")
    if len(s) == 6:
        return f"#{s.lower()}"
    r, g, b, a = parse_hex(value)
    br, bg_, bb, _ = parse_hex(over)
    mix = lambda c, d: round(c * a + d * (1 - a))
    return f"#{mix(r, br):02x}{mix(g, bg_):02x}{mix(b, bb):02x}"


def argb(value: str, alpha: str = "ff") -> str:
    """qt6ct ждёт #aarrggbb."""
    return "#" + alpha + rgb6(value).lstrip("#")


def hex8(value: str, alpha: str = "ff") -> str:
    """mako ждёт #rrggbbaa."""
    return rgb6(value) + alpha


def rgb_triple(value: str) -> str:
    """KDE-схема ждёт 'r,g,b'."""
    r, g, b, _ = parse_hex(value)
    return f"{r},{g},{b}"


# ── рендер шаблонов ─────────────────────────────────────────────
def render(text: str, ctx: dict) -> str:
    out = text
    for key, val in ctx.items():
        out = out.replace("{{" + key + "}}", str(val))
    return out


def dominant_color(path: Path):
    """Доминирующий цвет картинки. Считаю гистограмму ImageMagick и беру
    самый частый СРЕДИ насыщенных: почти чёрное и почти белое отбрасываю —
    иначе любой фон сведётся к серому."""
    try:
        out = subprocess.run(
            ["magick", str(path), "-resize", "160x160", "-colors", "6",
             "-depth", "8", "-format", "%c", "histogram:info:"],
            capture_output=True, text=True, timeout=25).stdout
    except Exception:
        return (8, 9, 13)
    best, best_score = None, -1.0
    for line in out.splitlines():
        m = re.match(r"\s*(\d+):\s*\((\d+),(\d+),(\d+)", line)
        if not m:
            continue
        cnt = int(m.group(1))
        r, g, b = int(m.group(2)), int(m.group(3)), int(m.group(4))
        mx, mn = max(r, g, b), min(r, g, b)
        if mx < 14 or mn > 242:
            continue
        sat = (mx - mn) / max(1, mx)
        score = cnt * (0.35 + sat)
        if score > best_score:
            best_score, best = score, (r, g, b)
    return best or (8, 9, 13)


def rgb_to_hsl(r, g, b):
    r, g, b = r / 255, g / 255, b / 255
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2
    if mx == mn:
        return 0.0, 0.0, l
    d = mx - mn
    s = d / (2 - mx - mn) if l > 0.5 else d / (mx + mn)
    if mx == r:
        h = ((g - b) / d + (6 if g < b else 0)) / 6
    elif mx == g:
        h = ((b - r) / d + 2) / 6
    else:
        h = ((r - g) / d + 4) / 6
    return h, s, l


def hsl_to_hex(h, s, l):
    def f(n):
        k = (n + h * 12) % 12
        a = s * min(l, 1 - l)
        return l - a * max(-1, min(k - 3, 9 - k, 1))
    return "#%02x%02x%02x" % (round(255 * f(0)), round(255 * f(8)), round(255 * f(4)))


def palette_from_image(path: Path) -> dict:
    """Пресет из картинки: тон обоев, но по нейтральной серой лестнице.

    Светлота идёт ровными ступенями как у lunar, а насыщенность зажата
    (по сути микс с серым) — иначе фотопалитра уходила в «чёрный квадрат»:
    фон ≈ #000, текст ≈ #fff, почти без средних серых. Вторичный тон
    (textDim/textMuted) держу сине-серым, как fg_muted у 43PR, — он и даёт
    мягкость; акцент тоже не чистый белый."""
    r, g, b = dominant_color(path)
    h, s, _ = rgb_to_hsl(r, g, b)

    # поверхность: тон обоев на низкой насыщенности — то же, что подмешать
    # цвет к нейтральной ступени. Ступени совпадают с lunar.
    def surf(light, sat_mul):
        return hsl_to_hex(h, min(0.22, s * sat_mul), light)

    # текст: почти нейтральный, только лёгкий оттенок обоев
    def fg(light, sat=0.05):
        return hsl_to_hex(h, min(0.14, sat), light)

    # вторичный/приглушённый: тон обоев с зажатой насыщенностью — «сине-серый»
    def muted(light, sat_mul=0.85):
        return hsl_to_hex(h, min(0.24, max(0.10, s * sat_mul)), light)

    return {
        "bg":           surf(0.050, 0.55),
        "bgPanel":      surf(0.075, 0.55),
        "bgCard":       surf(0.110, 0.50),
        "bgTrack":      surf(0.150, 0.45),
        "bgHover":      surf(0.200, 0.45),
        "text":         fg(0.905),
        "textSoft":     fg(0.760),
        "textDim":      muted(0.600, 0.95),
        "textMuted":    muted(0.470, 0.85),
        "textFaint":    muted(0.360, 0.75),
        "accent":       hsl_to_hex(h, max(0.30, min(0.48, s * 1.05)), 0.700),
        "accent2":      hsl_to_hex(h, max(0.22, min(0.42, s * 0.85)), 0.820),
        "danger":       "#ff003c",
        "ok":           fg(0.800),
        "border":       "#ffffff12",
        "borderAccent": hsl_to_hex(h, 0.40, 0.58) + "33",
        "barText":      fg(0.860),
        "barDim":       muted(0.620, 0.95),
        "barFaint":     muted(0.460, 0.80),
        "barPill":      surf(0.090, 0.55),
        "cursor":       fg(0.905),
    }


def load_template(templates_dir: Path, name: str) -> str:
    path = templates_dir / name
    if not path.is_file():
        raise FileNotFoundError(f"нет шаблона {path}")
    return path.read_text(encoding="utf-8")


# ── сборка содержимого ──────────────────────────────────────────
def build_context(preset: dict, name: str) -> dict:
    ctx = {k: v for k, v in preset.items() if isinstance(v, str)}
    ctx["preset"] = name
    # «плотные» версии полупрозрачных рамок — для приложений без альфы
    ctx["borderSolid"] = solid(preset["border"], preset["bgCard"])
    ctx["borderAccentSolid"] = solid(preset["borderAccent"], preset["bgCard"])
    # наведение в GTK — акцент на малой альфе (gtk.css ссылается на lunar_hover)
    ar, ag, ab, _ = parse_hex(preset["accent"])
    ctx["accentHoverRgba"] = f"rgba({ar}, {ag}, {ab}, 0.06)"
    # тень libadwaita — фон на альфе 0.4
    br, bg_, bb, _ = parse_hex(preset["bg"])
    ctx["shadeRgba"] = f"rgba({br}, {bg_}, {bb}, 0.4)"

    # kitty: 16 цветов — градации от фона к тексту, danger/ok отдельно
    kitty_colors = [
        preset["bg"], preset["textDim"], preset["barText"], preset["accent"],
        preset["barText"], preset["textDim"], preset["barText"], preset["text"],
        preset["textFaint"], preset["danger"], preset["ok"], preset["accent"],
        preset["barText"], preset["textDim"], preset["accent"], preset["text"],
    ]
    for i, c in enumerate(kitty_colors):
        ctx[f"color{i}"] = c
    ctx["selectionBg"] = preset["bgTrack"]

    # mako: #rrggbbaa
    ctx["makoBg"] = hex8(preset["bgPanel"], "e6")
    ctx["makoText"] = hex8(preset["text"], "ff")
    ctx["makoBorder"] = hex8(ctx["borderSolid"], "ff")
    ctx["makoProgress"] = hex8(preset["accent"], "ff")
    ctx["makoLowBg"] = hex8(preset["bgPanel"], "99")
    ctx["makoLowBorder"] = hex8(preset["textDim"], "ff")
    ctx["makoCritBg"] = hex8(preset["bgPanel"], "f2")
    ctx["makoCritBorder"] = hex8(preset["danger"], "ff")

    # qt6ct: три строки ARGB по 22 значения (порядок как в исходном lunar.conf)
    p = preset
    active = [
        p["text"], p["bgCard"], ctx["borderAccentSolid"], ctx["borderSolid"],
        p["bgPanel"], p["bgTrack"], p["text"], p["danger"], p["text"],
        p["bgCard"], p["bgPanel"], p["bg"], p["bgTrack"], p["text"],
        p["accent"], p["textDim"], p["bgTrack"], p["bg"], p["text"],
        p["text"], p["textDim"], p["accent"],
    ]
    disabled = [
        p["textFaint"], p["bgCard"], ctx["borderAccentSolid"], ctx["borderSolid"],
        p["bgPanel"], p["bgTrack"], p["textFaint"], p["danger"], p["textFaint"],
        p["bgCard"], p["bgPanel"], p["bg"], p["bgTrack"], p["textFaint"],
        p["accent"], p["textFaint"], p["bgTrack"], p["bg"], p["textFaint"],
        p["text"], p["textDim"], p["accent"],
    ]
    # позиции 8, 13, 15 у disabled полупрозрачные (80), остальное — ff
    dim = {7, 12, 14}
    ctx["active_colors"] = ", ".join(argb(c) for c in active)
    ctx["disabled_colors"] = ", ".join(
        argb(c, "80" if i in dim else "ff") for i, c in enumerate(disabled)
    )
    ctx["inactive_colors"] = ctx["active_colors"]

    # KDE-схема: секции отличаются только поверхностями, текст/акцент общие.
    # ForegroundPositive — это `ok` (светлый), зелёного в рисе нет.
    def kde_section(title: str, bg: str, alt: str) -> str:
        return "\n".join([
            f"[Colors:{title}]",
            f"BackgroundNormal={rgb_triple(bg)}",
            f"BackgroundAlternate={rgb_triple(alt)}",
            f"ForegroundNormal={rgb_triple(p['text'])}",
            f"ForegroundInactive={rgb_triple(p['textDim'])}",
            f"ForegroundActive={rgb_triple(p['accent'])}",
            f"ForegroundLink={rgb_triple(p['accent'])}",
            f"ForegroundVisited={rgb_triple(p['textDim'])}",
            f"ForegroundNegative={rgb_triple(p['danger'])}",
            f"ForegroundNeutral={rgb_triple(p['textDim'])}",
            f"ForegroundPositive={rgb_triple(p['ok'])}",
            f"DecorationFocus={rgb_triple(p['accent'])}",
            f"DecorationHover={rgb_triple(p['accent'])}",
        ])

    ctx["kdeSections"] = "\n\n".join([
        kde_section("Window", p["bg"], p["bgPanel"]),
        kde_section("View", p["bg"], p["bgPanel"]),
        kde_section("Button", p["bgCard"], p["bgTrack"]),
        kde_section("Selection", p["bgTrack"], p["bgTrack"]),
        kde_section("Tooltip", p["bgPanel"], p["bgTrack"]),
        kde_section("Complementary", p["bg"], p["bgPanel"]),
        kde_section("Header", p["bg"], p["bgPanel"]),
    ])
    return ctx


def build_artifacts(preset: dict, name: str, templates_dir: Path):
    ctx = build_context(preset, name)
    gtk = render(load_template(templates_dir, "gtk-colors.css.in"), ctx)
    artifacts = [
        ("kitty/lunar-theme.conf",
         render(load_template(templates_dir, "kitty-theme.conf.in"), ctx)),
        ("gtk-3.0/lunar-colors.css", gtk),
        ("gtk-4.0/lunar-colors.css", gtk),
        ("qt6ct/colors/lunar.conf",
         render(load_template(templates_dir, "qt6ct.conf.in"), ctx)),
        ("mako/colors.conf",
         render(load_template(templates_dir, "mako-colors.conf.in"), ctx)),
        ("btop/themes/lunar.theme",
         render(load_template(templates_dir, "btop-theme.in"), ctx)),
        ("yazi/theme.toml",
         render(load_template(templates_dir, "yazi-theme.toml.in"), ctx)),
        ("fastfetch/config.jsonc",
         render(load_template(templates_dir, "fastfetch-config.jsonc.in"), ctx)),
    ]
    # KDE-схема — не в ~/.config, а в ~/.local/share/color-schemes
    # (её читают KDE/Qt-приложения по имени из kdeglobals).
    share_artifacts = [
        ("color-schemes/LunarEclipse.colors",
         render(load_template(templates_dir, "kde-colorscheme.in"), ctx)),
    ]
    # Выходы палитры — только файлы приложений. Каталог шаблонов
    # (lunar/templates/) генератор лишь читает; писать туда не должен,
    # иначе источник и результат снова смешаются. Стерегу это здесь.
    for rel, _ in artifacts + share_artifacts:
        if rel.startswith("lunar/") or "templates/" in rel:
            raise ValueError(f"выход палитры уехал в шаблоны: {rel}")
    return artifacts, share_artifacts, render(
        load_template(templates_dir, "palette.json.in"), ctx)


# ── CLI ─────────────────────────────────────────────────────────
def main() -> int:
    ap = argparse.ArgumentParser(
        description="Раскладка единой палитры Lunar Eclipse по приложениям.")
    ap.add_argument("--preset", help="имя пресета из palette.toml (по умолчанию active)")
    ap.add_argument("--from-image", metavar="ФАЙЛ",
                    help="построить палитру из картинки (обои) и применить")
    ap.add_argument("--restore-preset", action="store_true",
                    help="вернуть пресет, который стоял до фотопалитры (--from-image)")
    ap.add_argument("--out", metavar="DIR",
                    help="записать всё в DIR (тест), не трогая живые конфиги")
    ap.add_argument("--apply", action="store_true",
                    help="записать в реальные места (~/.config и ~/.cache/lunar)")
    ap.add_argument("--palette", default=str(DEFAULT_PALETTE),
                    help=f"путь к palette.toml (по умолчанию {DEFAULT_PALETTE})")
    ap.add_argument("--templates", default=str(DEFAULT_TEMPLATES),
                    help=f"каталог шаблонов (по умолчанию {DEFAULT_TEMPLATES})")
    args = ap.parse_args()

    palette_path = Path(args.palette)
    templates_dir = Path(args.templates)

    if not palette_path.is_file():
        print(f"нет файла палитры {palette_path}", file=sys.stderr)
        print("он лежит в репозитории — скопируй конфиги (install.sh) или укажи --palette",
              file=sys.stderr)
        return 1
    with palette_path.open("rb") as fh:
        data = tomllib.load(fh)
    presets = data.get("presets", {})
    # выбранный в Hub пресет помню в ~/.cache/lunar/preset: palette.toml
    # остаётся «заводским» (репо == живое), а выбор переживает install.sh
    saved = APPLY_STATE_PRESET.read_text(encoding="utf-8").strip() if APPLY_STATE_PRESET.exists() else ""

    # --restore-preset: возвращаю пресет, который стоял до фотопалитры
    # (фото запоминаю в APPLY_PREV_PRESET, когда применяю палитру из картинки).
    # Трогаю только если сейчас реально стоит фотопалитра — иначе не сбиваю
    # ручной пресет (lunar/steel/photo), выбранный в Hub.
    if args.restore_preset:
        if saved != "photo":
            print("[пресет] сейчас не фотопалитра — возврат не нужен")
            return 0
        prev = APPLY_PREV_PRESET.read_text(encoding="utf-8").strip() \
            if APPLY_PREV_PRESET.exists() else ""
        active = data.get("active")
        if prev in presets:
            args.preset = prev
        elif active in presets:
            args.preset = active
        else:
            args.preset = next(iter(presets), None)

    photo = Path(args.from_image) if args.from_image else None
    # сохранённую фотопалитру беру только если пресет не задан явно
    if photo is None and args.preset is None and saved == "photo":
        if APPLY_PHOTO_PATH.exists():
            cand = Path(APPLY_PHOTO_PATH.read_text(encoding="utf-8").strip())
            if cand.is_file():
                photo = cand
            else:
                print(f"картинка фотопалитры пропала ({cand}) — беру пресет из palette.toml",
                      file=sys.stderr)
        else:
            print("нет записи о картинке фотопалитры — беру пресет из palette.toml",
                  file=sys.stderr)

    if photo is not None:
        if not photo.is_file():
            print(f"нет картинки {photo}", file=sys.stderr)
            return 1
        preset = palette_from_image(photo)
        name = "photo"
    else:
        name = args.preset or (saved if saved in presets else data.get("active"))
        if name not in presets:
            print(f"нет пресета {name!r} в {palette_path}", file=sys.stderr)
            print("доступно: " + ", ".join(presets), file=sys.stderr)
            return 2
        preset = presets[name]

    artifacts, share_artifacts, palette_json = build_artifacts(
        preset, name, templates_dir)

    if args.apply and args.out:
        print("--apply и --out взаимоисключающие", file=sys.stderr)
        return 2

    if not args.apply and not args.out:
        # dry-run: показываю план и ничего не пишу
        print(f"[палитра] {palette_path}")
        print(f"[пресет]  {name}  (active={data.get('active')})")
        print(f"[режим]   dry-run — ничего не записано\n")
        print(f"  ~/.cache/lunar/palette.json  ← JSON для Theme.qml")
        for rel, _ in artifacts:
            print(f"  ~/.config/{rel}")
        for rel, _ in share_artifacts:
            print(f"  ~/.local/share/{rel}")
        print("\nчтобы записать в тест:  --out DIR")
        print("чтобы записать в живые: --apply")
        return 0

    if args.out:
        base = Path(args.out)
        for rel, content in artifacts:
            dst = base / "config" / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text(content, encoding="utf-8")
        for rel, content in share_artifacts:
            dst = base / "share" / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text(content, encoding="utf-8")
        cache = base / "cache" / "lunar" / "palette.json"
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(palette_json, encoding="utf-8")
        print(f"[пресет] {name}")
        print(f"[режим]  запись в {base} (живые конфиги не тронуты)")
        for rel, _ in artifacts:
            print(f"  + {base / 'config' / rel}")
        for rel, _ in share_artifacts:
            print(f"  + {base / 'share' / rel}")
        print(f"  + {cache}")
        return 0

    # --apply
    for rel, content in artifacts:
        dst = APPLY_CONFIG_ROOT / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(content, encoding="utf-8")
    for rel, content in share_artifacts:
        dst = APPLY_SHARE_ROOT / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(content, encoding="utf-8")
    APPLY_CACHE_JSON.parent.mkdir(parents=True, exist_ok=True)
    APPLY_CACHE_JSON.write_text(palette_json, encoding="utf-8")
    # перед уходом в фотопалитру помню прежний пресет — чтобы «сцена» вернула его
    if name == "photo":
        if saved and saved != "photo" and saved in presets:
            APPLY_PREV_PRESET.write_text(saved + "\n", encoding="utf-8")
    APPLY_STATE_PRESET.write_text(name + "\n", encoding="utf-8")
    if name == "photo" and photo is not None:
        APPLY_PHOTO_PATH.write_text(str(photo) + "\n", encoding="utf-8")
    print(f"[пресет] {name}")
    print(f"[режим]  apply — записано в ~/.config и {APPLY_CACHE_JSON}")
    for rel, _ in artifacts:
        print(f"  + ~/.config/{rel}")
    for rel, _ in share_artifacts:
        print(f"  + ~/.local/share/{rel}")
    print(f"  + {APPLY_CACHE_JSON}")
    print("\nподключи сгенерированные файлы (include/@import/flavor) — см. отчёт.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
