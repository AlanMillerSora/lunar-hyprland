#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════════════
#  Lunar Eclipse — генератор ЖИВЫХ обоев (animated GIF) для awww
#
#  Рисует ту же сцену, что и сайт-превью (sait/script.js, exportPhaseSVG),
#  и добавляет её анимации:
#    • мерцание звёзд            (twinkle)
#    • дыхание гало Солнца       (sunBreath)
#    • дрейф космической пыли    (dustDrift)
#    • пульс короны              (coronaPulse, фаза 4)
#    • метеорный поток           (meteorFall, только фаза 4)
#
#  Зависимости: python3, rsvg-convert (librsvg), ffmpeg (с gif + palettegen)
#
#  Пример:
#     ./eclipse-anim-gen.py                       # все 8 фаз → ~/Pictures/EclipseWalls
#     ./eclipse-anim-gen.py --phases 4 --frames-keep
#     ./eclipse-anim-gen.py --duration 8 --fps 25 --out /tmp/walls
#     ./eclipse-anim-gen.py --video               # ещё и eclipse_NN.webm (для mpvpaper)
#
#  Результат: eclipse_01.gif … eclipse_08.gif
#  eclipse-walls.sh сам предпочитает .gif, если он есть (иначе .png).
# ════════════════════════════════════════════════════════════════════════

import argparse
import math
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

W, H = 1920, 1080
CX, CY = 960, 475
SUN_R, MOON_R = 160, 157
# Точные значения из sait/script.js: EX_OFF = [0,-319,-207,-107,0,107,207,274,320]
# EX_OFF[n] для фазы n (фаза 4 — полное затмение, смещение 0)
OFF = {1: -319, 2: -207, 3: -107, 4: 0, 5: 107, 6: 207, 7: 274, 8: 320}

# ── Палитра/параметры фаз (1:1 из sait/script.js → EX_PHASES) ────────────
PHASES = {
    1: dict(bg=[[0, '#10151c'], [60, '#05070c']], sun=1.00, halo=0.85, glow=0.20, pen=0.50, bead=0.00, dust=0.00, horizon=0),
    2: dict(bg=[[0, '#0d1218'], [65, '#04060a']], sun=0.95, halo=0.85, glow=0.35, pen=0.90, bead=0.25, dust=0.00, horizon=0),
    3: dict(bg=[[0, '#0e1018'], [60, '#06070d']], sun=0.88, halo=0.65, glow=0.60, pen=1.00, bead=0.70, dust=0.35, horizon=0.35),
    4: dict(bg=[[0, '#14110f'], [22, '#1a0c0e'], [62, '#050307']], sun=0.95, halo=0.50, glow=0.85, pen=0.25, bead=0.95, dust=0.90, horizon='blood', blood=1),
    5: dict(bg=[[0, '#0b1019'], [62, '#050812']], sun=0.95, halo=0.50, glow=0.60, pen=1.00, bead=0.70, dust=0.35, horizon=0.35),
    6: dict(bg=[[0, '#0e1018'], [60, '#06070d']], sun=0.88, halo=0.65, glow=0.35, pen=0.90, bead=0.25, dust=0.00, horizon=0),
    7: dict(bg=[[0, '#0d1218'], [65, '#04060a']], sun=0.95, halo=0.85, glow=0.20, pen=0.50, bead=0.00, dust=0.00, horizon=0),
    8: dict(bg=[[0, '#10151c'], [60, '#05070c']], sun=1.00, halo=0.85, glow=0.20, pen=0.00, bead=0.00, dust=0.00, horizon=0),
}


# ── Детерминированный ГПСЧ (эмуляция JS makeStarRng) ─────────────────────
class StarRng:
    def __init__(self, seed):
        self.s = seed & 0xFFFFFFFF

    def next(self):
        self.s = (self.s * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.s / 4294967296.0


def build_stars():
    """Точная копия EXPORT_STARS: 170 звёзд, тот же порядок вызовов rnd()."""
    rnd = StarRng(42).next
    stars = []
    for _ in range(170):
        x = rnd() * W
        y = rnd() * H
        if rnd() < 0.06:
            r = 1.9
        elif rnd() < 0.5:
            r = 1.1
        else:
            r = 0.7
        o = 0.3 + rnd() * 0.7
        stars.append([x, y, r, o])
    # мерцание берём из отдельного ГПСЧ, чтобы не сдвигать звёздное поле сайта
    rnd2 = StarRng(9001).next
    for s in stars:
        k = rnd2()
        s.append(1 if k < 0.45 else (2 if rnd2() < 0.6 else 3))   # циклов за петлю
        s.append(rnd2())                                          # фаза
    return [tuple(s) for s in stars]


STARS = build_stars()

# пылинки (аналог .particle — атмосферные мошки)
def build_motes():
    rnd = StarRng(1337).next
    motes = []
    for _ in range(26):
        x = rnd() * W
        y = rnd() * H
        s = 1.0 + rnd() * 2.2
        phase = rnd()
        drift = (rnd() * 2 - 1) * 110
        speed = 1 if rnd() < 0.6 else 2
        motes.append((x, y, s, phase, drift, speed))
    return motes


MOTES = build_motes()

# метеоры (фаза 4): доля пути за цикл, старт, период (целое число циклов за петлю)
def build_meteors():
    rnd = StarRng(2718).next
    meteors = []
    for _ in range(7):
        left = 0.45 + rnd() * 0.55
        top = -0.02 + rnd() * 0.27
        cycles = 3 + int(rnd() * 3)          # 3..5 циклов за петлю → 1.0..1.7s
        phase = rnd()
        meteors.append((left, top, cycles, phase))
    return meteors


METEORS = build_meteors()


def phase_svg(n, t):
    """SVG одного кадра. t ∈ [0,1) — фаза петли."""
    P = PHASES[n]
    mx = CX + OFF[n]
    ring = 0.5 if n == 4 else (0.2 if n in (3, 5) else 0)

    bg_stops = ''.join(f'<stop offset="{o}%" stop-color="{c}"/>' for o, c in P['bg'])

    # ── звёзды с мерцанием (twinkle: 0.1 → max-op → 0.1) ────────────────
    boost = 1.35 if n == 4 else 1.0
    star_els = []
    for (x, y, r, o, speed, ph) in STARS:
        k = 0.5 - 0.5 * math.cos(2 * math.pi * (t * speed + ph))
        op = min(1.0, (0.10 + (o - 0.10) * k) * boost)
        star_els.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="#ffffff" opacity="{op:.2f}"/>')

    # ── пылинки ─────────────────────────────────────────────────────────
    mote_els = []
    for (x, y, s, ph, drift, speed) in MOTES:
        a = 2 * math.pi * (t * speed + ph)
        yy = y - math.sin(a) * 34
        xx = x + math.sin(a) * (drift * 0.3)
        op = 0.06 + 0.16 * (0.5 - 0.5 * math.cos(a))
        mote_els.append(f'<circle cx="{xx:.1f}" cy="{yy:.1f}" r="{s:.2f}" fill="#ffffff" opacity="{op:.2f}"/>')

    # ── дыхание гало Солнца (sunBreath: масштаб 1 → 1.06) ──────────────
    breath = math.sin(2 * math.pi * t)
    halo_r = 205 * (1 + 0.060 * breath)
    halo_op = P['halo'] * (0.92 + 0.08 * breath)

    # ── пыль (dustDrift: translate(-28px, 10px) scale(1.06)) ────────────
    dx = -28 * breath
    dy = 10 * breath
    ds = 1 + 0.035 * breath
    dust_el = ''
    if P['dust']:
        ell = ''.join(
            f'<ellipse cx="{ex}" cy="{ey}" rx="{er}" ry="{er * 0.62:.0f}" fill="#dfe9ff" opacity="0.05" filter="url(#blurDust)"/>'
            for ex, ey, er in [(320, 260, 460), (1480, 220, 380), (1240, 780, 520), (420, 760, 420), (960, 520, 400)]
        )
        dust_el = (f'<g opacity="{P["dust"]:.2f}">'
                   f'<g transform="translate({CX} {CY}) scale({ds:.4f}) translate({-CX} {-CY}) translate({dx:.1f} {dy:.1f})">'
                   f'{ell}</g></g>')

    # ── горизонт ────────────────────────────────────────────────────────
    if P.get('horizon') == 'blood':
        horizon_el = (f'<ellipse cx="{CX}" cy="1150" rx="1500" ry="360" fill="#d22837" opacity="0.5" filter="url(#blurHorizon)"/>'
                      f'<ellipse cx="{CX}" cy="1092" rx="1400" ry="10" fill="#ffffff" opacity="0.4" filter="url(#blurHorizon)"/>')
    elif P['horizon']:
        horizon_el = (f'<ellipse cx="{CX}" cy="1150" rx="1500" ry="360" fill="#dfe9ff" '
                      f'opacity="{P["horizon"] * 0.35:.2f}" filter="url(#blurHorizon)"/>')
    else:
        horizon_el = ''

    red_glow = ''
    if P.get('blood'):
        red_glow = f'<circle cx="{mx}" cy="{CY}" r="215" fill="url(#redGlow)" opacity="0.55"/>'
    moon_fill = 'url(#blood)' if P.get('blood') else '#000000'

    # ── пульс короны (фаза 4) ───────────────────────────────────────────
    corona_op = (0.8 + 0.2 * (0.5 - 0.5 * math.cos(2 * math.pi * t))) if n == 4 else 1.0
    corona_stop = 0.14 if n == 4 else 0.05

    # ── метеоры (только фаза 4) ─────────────────────────────────────────
    meteor_el = ''
    if n == 4:
        parts = []
        for (left, top, cycles, ph) in METEORS:
            p = (t * cycles + ph) % 1.0
            x = left * W - p * (0.45 * W)
            y = top * H + p * (0.34 * H)
            if 0.0 <= p < 0.03:
                op = 0.35 * (p / 0.03)
            elif p < 0.07:
                op = 0.35 + 0.65 * ((p - 0.03) / 0.04)
            elif p < 0.40:
                op = 1.0
            elif p < 0.62:
                op = 1.0 - (p - 0.40) / 0.22
            else:
                op = 0.0
            if op <= 0.01:
                continue
            parts.append(
                f'<g transform="translate({x:.1f} {y:.1f}) rotate(-24)" opacity="{op:.2f}">'
                f'<line x1="-118" y1="0" x2="0" y2="0" stroke="url(#meteorTail)" stroke-width="2" stroke-linecap="round"/>'
                f'<circle cx="0" cy="0" r="1.4" fill="#ffffff"/>'
                f'<circle cx="0" cy="0" r="4" fill="#ffffff" opacity="0.25" filter="url(#beadGlow)"/>'
                f'</g>')
        meteor_el = ''.join(parts)

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <radialGradient id="bg" cx="50%" cy="46%" r="78%">{bg_stops}</radialGradient>
  <radialGradient id="sun" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#ffffff"/><stop offset="40%" stop-color="#ffffff"/>
    <stop offset="55%" stop-color="#f7f7f7"/><stop offset="72%" stop-color="#ffffff" stop-opacity="0.6"/>
    <stop offset="84%" stop-color="#ffffff" stop-opacity="0.14"/><stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="halo" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#ffffff" stop-opacity="0.16"/><stop offset="46%" stop-color="#ffffff" stop-opacity="0.07"/>
    <stop offset="70%" stop-color="#ffffff" stop-opacity="0.02"/><stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="pen" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#000000" stop-opacity="0.85"/><stop offset="46%" stop-color="#000000" stop-opacity="0.55"/>
    <stop offset="62%" stop-color="#000000" stop-opacity="0.28"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="moonGlow" cx="50%" cy="50%" r="50%">
    <stop offset="63%" stop-color="#ffffff" stop-opacity="0"/><stop offset="68%" stop-color="#b4c8ff" stop-opacity="0.10"/>
    <stop offset="73%" stop-color="#96b4ff" stop-opacity="0.24"/><stop offset="80%" stop-color="#aac8ff" stop-opacity="0.12"/>
    <stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="ring" cx="50%" cy="50%" r="50%">
    <stop offset="96%" stop-color="#ffffff" stop-opacity="0"/><stop offset="98.2%" stop-color="#ffffff" stop-opacity="0.70"/>
    <stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="coronaBig" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#ffffff" stop-opacity="0"/><stop offset="45%" stop-color="#ffffff" stop-opacity="{corona_stop}"/>
    <stop offset="72%" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="redGlow" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#b22234" stop-opacity="0"/><stop offset="52%" stop-color="#b22234" stop-opacity="0.30"/>
    <stop offset="100%" stop-color="#b22234" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="blood" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#3b1018"/><stop offset="55%" stop-color="#20060f"/>
    <stop offset="85%" stop-color="#0c0108"/><stop offset="100%" stop-color="#000000"/>
  </radialGradient>
  <radialGradient id="vig" cx="50%" cy="50%" r="72%">
    <stop offset="55%" stop-color="#000000" stop-opacity="0"/><stop offset="100%" stop-color="#000000" stop-opacity="0.42"/>
  </radialGradient>
  <linearGradient id="meteorTail" x1="0%" y1="0%" x2="100%" y2="0%">
    <stop offset="0%" stop-color="#ffffff" stop-opacity="0"/>
    <stop offset="70%" stop-color="#dceaff" stop-opacity="0.55"/>
    <stop offset="100%" stop-color="#ffffff" stop-opacity="0.95"/>
  </linearGradient>
  <filter id="blurDust" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="70"/></filter>
  <filter id="blurHorizon" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="46"/></filter>
  <filter id="beadGlow"><feGaussianBlur stdDeviation="1.6"/></filter>
</defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  {''.join(star_els)}
  {''.join(mote_els)}
  {dust_el}
  {horizon_el}
  <circle cx="{CX}" cy="{CY}" r="{halo_r:.1f}" fill="url(#halo)" opacity="{halo_op:.2f}"/>
  <circle cx="{CX}" cy="{CY}" r="{SUN_R}" fill="url(#sun)" opacity="{P['sun']:.2f}"/>
  <circle cx="{mx}" cy="{CY}" r="228" fill="url(#moonGlow)" opacity="{P['glow']:.2f}"/>
  <circle cx="{mx}" cy="{CY}" r="192" fill="url(#pen)" opacity="{P['pen']:.2f}"/>
  {red_glow}
  <circle cx="{mx}" cy="{CY}" r="{MOON_R}" fill="{moon_fill}"/>
  <circle cx="{mx}" cy="{CY}" r="228" fill="url(#coronaBig)" opacity="{corona_op:.2f}"/>
  <circle cx="{mx}" cy="{CY}" r="161" fill="url(#ring)" opacity="{ring}"/>
  <circle cx="{mx}" cy="{CY}" r="158.5" fill="none" stroke="#ffffff" stroke-width="2.6"
          stroke-dasharray="2.2 8.5" opacity="{P['bead']:.2f}" filter="url(#beadGlow)"/>
  {meteor_el}
  <rect width="{W}" height="{H}" fill="url(#vig)"/>
</svg>'''


def which(*names):
    for n in names:
        if shutil.which(n):
            return shutil.which(n)
    return None


def render_phase(n, args, rsvg, ffmpeg):
    frames = args.fps * args.duration
    pdir = os.path.join(args.workdir, f'p{n:02d}')
    os.makedirs(pdir, exist_ok=True)

    svg_paths = []
    for i in range(frames):
        t = i / frames
        p = os.path.join(pdir, f'f_{i:04d}.svg')
        with open(p, 'w') as fh:
            fh.write(phase_svg(n, t))
        svg_paths.append(p)

    def to_png(svg):
        png = svg[:-4] + '.png'
        subprocess.run([rsvg, '-w', str(W), '-h', str(H), '-o', png, svg],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return png

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        list(pool.map(to_png, svg_paths))

    seq = os.path.join(pdir, 'f_%04d.png')
    created = []

    if not args.no_gif:
        out = os.path.join(args.out, f'eclipse_{n:02d}.gif')
        palette = os.path.join(pdir, 'palette.png')
        # 1-й проход: единая палитра по всем кадрам
        #   stats_mode=full — фон статичный и большой, поэтому учитываем ВСЕ пиксели:
        #   иначе палитра «экономится» на движении и на градиентах вылезают полосы.
        subprocess.run([ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                        '-framerate', str(args.fps), '-i', seq,
                        '-vf', f'palettegen=stats_mode={args.palette_stat}:max_colors=256',
                        palette], check=True)
        # 2-й проход: сборка GIF
        subprocess.run([ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                        '-framerate', str(args.fps), '-i', seq, '-i', palette,
                        '-lavfi', f'paletteuse=dither={args.dither}:diff_mode=rectangle',
                        '-loop', '0', out], check=True)
        created.append(out)

    # Видео — для mpvpaper: полный цвет, без 256-цветного зерна/полос.
    if args.video:
        if args.video_codec == 'vp9':
            vfile = os.path.join(args.out, f'eclipse_{n:02d}.webm')
            vcmd = [ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                    '-framerate', str(args.fps), '-i', seq,
                    '-c:v', 'libvpx-vp9', '-pix_fmt', 'yuv420p10le',
                    '-crf', str(args.video_crf), '-b:v', '0',
                    '-row-mt', '1', '-cpu-used', '4', '-deadline', 'good',
                    '-an', vfile]
        else:
            vfile = os.path.join(args.out, f'eclipse_{n:02d}.mp4')
            vcmd = [ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                    '-framerate', str(args.fps), '-i', seq,
                    '-c:v', 'libx264', '-preset', 'medium', '-crf', str(args.video_crf),
                    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', vfile]
        subprocess.run(vcmd, check=True)
        created.append(vfile)

    if not args.frames_keep:
        shutil.rmtree(pdir, ignore_errors=True)
    return created


def main():
    ap = argparse.ArgumentParser(description='Живые обои Lunar Eclipse → animated GIF для awww')
    ap.add_argument('--phases', default='1,2,3,4,5,6,7,8', help='какие фазы (по умолчанию все)')
    ap.add_argument('--out', default=os.path.expanduser('~/Pictures/EclipseWalls'), help='куда класть GIF')
    ap.add_argument('--duration', type=int, default=6, help='длина петли, сек (по умолчанию 6)')
    ap.add_argument('--fps', type=int, default=25,
                    help='кадров в секунду (по умолчанию 25; GIF хранит задержку в сотых, '
                         'поэтому ровные fps: 20, 25, 50 — иначе лёгкий рывок)')
    ap.add_argument('--dither', default='sierra2_4a',
                    help='дизер: sierra2_4a | bayer:bayer_scale=3 | none (по умолчанию sierra2_4a)')
    ap.add_argument('--palette-stat', default='full', choices=['full', 'diff', 'single'],
                    help='учёт пикселей для палитры: full — плавные градиенты (по умолчанию)')
    ap.add_argument('--jobs', type=int, default=min(8, os.cpu_count() or 4), help='параллельных рендеров')
    ap.add_argument('--frames-keep', action='store_true', help='не удалять промежуточные кадры')
    ap.add_argument('--no-gif', action='store_true',
                    help='не собирать GIF (нужен вместе с --video)')
    ap.add_argument('--video', action='store_true',
                    help='собрать видео для mpvpaper: eclipse_NN.webm/mp4 (полный цвет)')
    ap.add_argument('--video-codec', default='vp9', choices=['vp9', 'h264'],
                    help='кодек видео: vp9 (10-бит градиенты) или h264 (mp4, лёгкое декодирование)')
    ap.add_argument('--video-crf', type=int, default=18,
                    help='CRF видео (меньше = качественнее, по умолчанию 18)')
    ap.add_argument('--workdir', default=None, help='каталог для кадров (по умолчанию tmp)')
    ap.add_argument('--prune-png', action='store_true', help='удалить старые .png той же фазы')
    args = ap.parse_args()

    rsvg = which('rsvg-convert')
    ffmpeg = which('ffmpeg')
    if not rsvg:
        sys.exit('Ошибка: не найден rsvg-convert (пакет librsvg).')
    if not ffmpeg:
        sys.exit('Ошибка: не найден ffmpeg.')
    if args.no_gif and not args.video:
        sys.exit('Ошибка: --no-gif без --video делать нечего.')
    if not shutil.which('awww') and not args.no_gif:
        print('Предупреждение: awww не найден — GIF будут созданы, но не применены.', file=sys.stderr)
    if args.video and not shutil.which('mpvpaper'):
        print('Предупреждение: mpvpaper не найден — видео будет собрано, но не применено '
              '(поставить: yay -S mpvpaper).', file=sys.stderr)

    phases = [int(x) for x in args.phases.split(',') if x.strip()]
    for n in phases:
        if n not in PHASES:
            sys.exit(f'Ошибка: неизвестная фаза {n}')

    os.makedirs(args.out, exist_ok=True)
    auto_tmp = args.workdir is None
    tmp = args.workdir or tempfile.mkdtemp(prefix='eclipse-frames-')
    os.makedirs(tmp, exist_ok=True)
    args.workdir = tmp

    print(f'▶ Живые обои: {len(phases)} фаз, {args.duration}s × {args.fps}fps = {args.duration * args.fps} кадров')
    print(f'  рендер: {rsvg}  →  {ffmpeg}  →  {args.out}')
    for n in phases:
        created = render_phase(n, args, rsvg, ffmpeg)
        for p in created:
            print(f'  ✔ фаза {n}: {os.path.basename(p)}  ({os.path.getsize(p) / 1e6:.1f} MB)')
        if args.prune_png:
            for ext in ('png', 'jpg'):
                p = os.path.join(args.out, f'eclipse_{n:02d}.{ext}')
                if os.path.exists(p):
                    os.remove(p)
                    print(f'      удалён старый {os.path.basename(p)}')

    if auto_tmp and not args.frames_keep:
        shutil.rmtree(tmp, ignore_errors=True)
    else:
        print(f'  промежуточные кадры: {tmp}')
    print('Готово. Перезапусти eclipse-walls.sh или примени вручную:')
    if not args.no_gif:
        print(f'  awww img {args.out}/eclipse_04.gif')
    if args.video:
        ext = 'webm' if args.video_codec == 'vp9' else 'mp4'
        print(f'  mpvpaper -o "no-audio loop" \'*\' {args.out}/eclipse_04.{ext}   # нужен пакет mpvpaper')


if __name__ == '__main__':
    main()
