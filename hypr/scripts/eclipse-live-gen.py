#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════
#  Живые обои Lunar Eclipse — ВИД 1-В-1 с сайтом (sait/)
#
#  Кадры снимаются прямо с ЖИВОЙ CSS-сцены сайта через headless Chromium,
#  затем кодируются в VP9 10-бит для mpvpaper. В отличие от
#  eclipse-anim-gen.py (порт exportPhaseSVG в SVG) здесь получается тот же
#  вид, что в браузере: радиус солнца 125, на фазе 4 — чёрная луна с тонким
#  кольцом и «blood»-свечением, как в style.css.
#
#  Как это работает:
#    • capture.html собирается из sait/index.html (сам сайт не трогаем):
#      base href, отключение transition, seeded Math.random, гашение таймеров;
#    • каждый кадр замораживается на времени t через document.getAnimations();
#    • длительности анимаций квантуются на делители длины петли L — иначе шов
#      петли «прыгает» (звёзды/пылинки/метеоры/дыхание солнца);
#    • съёмка идёт по CDP (--remote-debugging-pipe), один браузер на фазу,
#      фазы параллельно. Это в ~10 раз быстрее запуска chromium на каждый кадр.
#
#  Запуск:
#    eclipse-live-gen.py                      # все 8 фаз, 12с × 60fps
#    eclipse-live-gen.py --phases 4 --duration 2 --fps 10   # быстрый тест
#    eclipse-live-gen.py --capture proc       # медленный fallback (процесс/кадр)
# ════════════════════════════════════════════════════════════

import argparse
import base64
import json
import os
import pathlib
import shutil
import signal
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

HERE = pathlib.Path(__file__).resolve()
REPO = HERE.parents[2]  # .../rice

CHROMIUM_CANDIDATES = [
    'chromium', 'chromium-browser', 'google-chrome-stable',
    'google-chrome', 'brave', 'brave-browser',
]

_LAUNCH_LOCK = threading.Lock()

PRE_JS = (
    '<script>(function(){var Q=new URLSearchParams(location.search);'
    'var s=(parseInt(Q.get("seed")||"1337",10)>>>0)||1337;'
    'Math.random=function(){s=(Math.imul(s,1664525)+1013904223)>>>0;'
    'return s/4294967296;};'
    # Гасим таймеры: сцена статична, а one-shot nightfallBurst
    # (setTimeout 3400ms) не должен срабатывать во время съёмки.
    'window.setTimeout=function(){return 0;};'
    'window.setInterval=function(){return 0;};'
    'window.clearTimeout=function(){};window.clearInterval=function(){};'
    '})();</script>'
)

# Квантуем длительности на делители L (иначе шов петли «прыгает») и
# замораживаем все анимации на времени t. __freeze(t) зовётся на каждый кадр,
# квантование выполняется один раз.
POST_JS = '''<script>(function(){
var L=__LOOP_MS__;
function cands(lo,hi){var a=[];for(var d=1000;d<=30000;d+=100){if(L%d===0&&d>=lo&&d<=hi)a.push(d);}return a;}
function near(ms,a){var b=a[0],bd=1e9;for(var i=0;i<a.length;i++){var d=Math.abs(ms-a[i]);if(d<bd||(d===bd&&a[i]>b)){bd=d;b=a[i];}}return b;}
window.__quant=false;
window.__freeze=function(t){
  if(!window.__quant){
    window.__quant=true;
    var cs=cands(2000,6000), cp=cands(6000,30000), cm=cands(1000,3000);
    document.querySelectorAll(".star").forEach(function(el){
      var c=parseFloat(getComputedStyle(el).animationDuration)*1000;
      if(cs.length) el.style.animationDuration=near(c,cs)+"ms";});
    document.querySelectorAll(".particle").forEach(function(el){
      var c=parseFloat(getComputedStyle(el).animationDuration)*1000;
      if(cp.length) el.style.animationDuration=near(c,cp)+"ms";});
    document.querySelectorAll(".meteor").forEach(function(el){
      var c=parseFloat(getComputedStyle(el).animationDuration)*1000;
      if(cm.length) el.style.animationDuration=near(c,cm)+"ms";});
  }
  document.getAnimations().forEach(function(a){try{a.pause();a.currentTime=t;}catch(e){}});
};
var Q=new URLSearchParams(location.search);
if(Q.get("ms")!==null) window.__freeze(parseFloat(Q.get("ms")));
})();</script>'''


def which_chromium():
    for name in CHROMIUM_CANDIDATES:
        p = shutil.which(name)
        if p:
            return p
    return None


def find_sait(explicit):
    if explicit:
        p = pathlib.Path(explicit).expanduser()
        return p if (p / 'index.html').is_file() else None
    for cand in (REPO / 'sait', pathlib.Path.home() / 'rice' / 'sait'):
        if (cand / 'index.html').is_file():
            return cand
    return None


def build_capture_page(sait: pathlib.Path, workdir: pathlib.Path, loop_ms: int) -> pathlib.Path:
    """Собираем capture.html из index.html: base href, отключение transition,
    квантование CSS-длительностей, seeded RNG и заморозка анимаций."""
    html = (sait / 'index.html').read_text(encoding='utf-8')

    head_inject = (
        f'<base href="file://{sait}/">\n'
        '<style>\n'
        '  *{transition:none!important}\n'
        '  .sun-glow-outer{animation-duration:6s!important}\n'
        '  .space-dust{animation-duration:12s!important}\n'
        '</style>\n'
    )
    html = html.replace('<head>', '<head>\n' + head_inject, 1)

    post = POST_JS.replace('__LOOP_MS__', str(loop_ms))
    html = html.replace(
        '<script src="script.js"></script>',
        PRE_JS + '\n<script src="script.js"></script>\n' + post,
        1,
    )
    out = workdir / 'capture.html'
    out.write_text(html, encoding='utf-8')
    return out


def encode(ffmpeg, seq, fps, out, codec, crf):
    if codec == 'vp9':
        vcmd = [ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                '-framerate', str(fps), '-i', seq,
                '-c:v', 'libvpx-vp9', '-pix_fmt', 'yuv420p10le',
                '-crf', str(crf), '-b:v', '0',
                '-row-mt', '1', '-cpu-used', '4', '-deadline', 'good',
                '-an', out]
    else:
        vcmd = [ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                '-framerate', str(fps), '-i', seq,
                '-c:v', 'libx264', '-preset', 'medium', '-crf', str(crf),
                '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', out]
    subprocess.run(vcmd, check=True)


# ───────────────────────── CDP (remote-debugging-pipe) ─────────────────────────

class Browser:
    """Минимальный CDP-клиент поверх --remote-debugging-pipe (fd 3/4,
    сообщения JSON, разделённые NUL). Без websocket и сторонних библиотек."""

    def __init__(self, chromium, url, width, height):
        cmd_r, cmd_w = os.pipe()
        evt_r, evt_w = os.pipe()

        def preexec():
            os.setsid()  # своя группа процессов → killpg убьёт и детей Chromium
            os.dup2(cmd_r, 3)
            os.dup2(evt_w, 4)
            os.set_inheritable(3, True)
            os.set_inheritable(4, True)

        with _LAUNCH_LOCK:
            self.p = subprocess.Popen(
                [chromium, '--headless=new', '--remote-debugging-pipe', '--no-sandbox',
                 '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                 f'--window-size={width},{height}', url],
                preexec_fn=preexec, close_fds=False,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        os.close(cmd_r)
        os.close(evt_w)
        self.w = cmd_w
        self.r = evt_r
        self.buf = b''
        self.n = 0
        self.sid = None

    def _recv(self):
        while b'\0' not in self.buf:
            chunk = os.read(self.r, 1 << 20)
            if not chunk:
                raise EOFError('CDP-канал закрыт')
            self.buf += chunk
        raw, _, self.buf = self.buf.partition(b'\0')
        return json.loads(raw)

    def call(self, method, params=None, session=None, timeout=60):
        self.n += 1
        msg = {'id': self.n, 'method': method}
        if params is not None:
            msg['params'] = params
        if session:
            msg['sessionId'] = session
        os.write(self.w, json.dumps(msg).encode() + b'\0')
        t0 = time.time()
        while True:
            if time.time() - t0 > timeout:
                raise TimeoutError(method)
            m = self._recv()
            if m.get('id') == self.n:
                if 'error' in m:
                    raise RuntimeError(f'{method}: {m["error"]}')
                return m.get('result', {})

    def close(self):
        for fd in (self.w, self.r):
            try:
                os.close(fd)
            except OSError:
                pass
        try:
            os.killpg(os.getpgid(self.p.pid), signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            self.p.terminate()
        try:
            self.p.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(os.getpgid(self.p.pid), signal.SIGKILL)
            except OSError:
                self.p.kill()

    def screenshot(self, out_path, ms):
        self.call('Runtime.evaluate', {'expression': f'window.__freeze({ms})'}, session=self.sid)
        res = self.call('Page.captureScreenshot', {'format': 'png'}, session=self.sid)
        out_path.write_bytes(base64.b64decode(res['data']))


def open_browser(chromium, url, width, height):
    b = Browser(chromium, url, width, height)
    targets = b.call('Target.getTargets')['targetInfos']
    pages = [t for t in targets if t['type'] == 'page']
    if not pages:
        b.close()
        raise RuntimeError('CDP: не найдена страница')
    b.sid = b.call('Target.attachToTarget',
                   {'targetId': pages[0]['targetId'], 'flatten': True})['sessionId']
    b.call('Page.enable', session=b.sid)
    b.call('Runtime.enable', session=b.sid)
    b.call('Emulation.setDeviceMetricsOverride',
           {'width': width, 'height': height, 'deviceScaleFactor': 1, 'mobile': False},
           session=b.sid)
    for _ in range(300):
        r = b.call('Runtime.evaluate', {'expression': '!!window.__freeze'}, session=b.sid)
        if r.get('result', {}).get('value'):
            return b
        time.sleep(0.02)
    b.close()
    raise RuntimeError('CDP: сцена не инициализировалась')


def capture_chunk_cdp(chromium, page, phase, indices, loop_ms, nframes, pdir, width, height):
    b = open_browser(chromium, f'file://{page}?phase={phase}&clean=1', width, height)
    try:
        for i in indices:
            b.screenshot(pdir / f'f_{i:04d}.png', i * loop_ms / nframes)
    finally:
        b.close()


def capture_chunk_proc(chromium, page, phase, indices, loop_ms, nframes, pdir, width, height, budget):
    url = f'file://{page}?phase={phase}&clean=1'
    for i in indices:
        subprocess.run([
            chromium, '--headless=new', '--no-sandbox', '--disable-gpu', '--hide-scrollbars',
            '--force-device-scale-factor=1', f'--window-size={width},{height}',
            f'--virtual-time-budget={budget}', f'--screenshot={pdir / f"f_{i:04d}.png"}',
            f'{url}&ms={i * loop_ms / nframes}',
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    ap = argparse.ArgumentParser(
        description='Живые обои 1-в-1 с сайтом: съёмка живой CSS-сцены → VP9 (mpvpaper)')
    ap.add_argument('--phases', default='1,2,3,4,5,6,7,8', help='какие фазы')
    ap.add_argument('--out', default=os.path.expanduser('~/Pictures/EclipseWalls'),
                    help='куда класть .webm/.mp4')
    ap.add_argument('--sait', default=None, help='каталог sait/ (index.html, style.css, script.js)')
    ap.add_argument('--chromium', default=None, help='путь к chromium')
    ap.add_argument('--capture', default='cdp', choices=['cdp', 'proc'],
                    help='cdp — быстро (по умолчанию), proc — процесс на кадр')
    ap.add_argument('--duration', type=int, default=12, help='длина петли, сек (по умолчанию 12)')
    ap.add_argument('--fps', type=int, default=60, help='кадров в секунду (по умолчанию 60)')
    ap.add_argument('--video-codec', default='vp9', choices=['vp9', 'h264'])
    ap.add_argument('--video-crf', type=int, default=18, help='CRF видео (по умолчанию 18)')
    ap.add_argument('--jobs', type=int, default=min(8, os.cpu_count() or 4),
                    help='сколько браузеров/процессов параллельно')
    ap.add_argument('--workdir', default=None, help='каталог для кадров (по умолчанию кэш на диске)')
    ap.add_argument('--frames-keep', action='store_true', help='не удалять кадры фазы')
    ap.add_argument('--seed', type=int, default=1337, help='seed генератора сцены')
    args = ap.parse_args()

    chromium = args.chromium or which_chromium()
    if not chromium:
        sys.exit('Ошибка: не найден chromium/google-chrome.')
    sait = find_sait(args.sait)
    if not sait:
        sys.exit('Ошибка: не найден sait/index.html (укажи --sait /путь/к/sait).')
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        sys.exit('Ошибка: не найден ffmpeg (для кодирования видео).')

    phases = [int(x) for x in args.phases.split(',') if x.strip()]
    for n in phases:
        if n not in range(1, 9):
            sys.exit(f'Ошибка: неизвестная фаза {n}')

    loop_ms = args.duration * 1000
    nframes = args.duration * args.fps
    width, height = 1920, 1080

    os.makedirs(args.out, exist_ok=True)
    workdir = pathlib.Path(args.workdir) if args.workdir else (
        pathlib.Path.home() / '.cache' / 'eclipse-live')
    workdir.mkdir(parents=True, exist_ok=True)
    page = build_capture_page(sait, workdir, loop_ms)

    print(f'▶ Живые обои: {len(phases)} фаз, {args.duration}s × {args.fps}fps = {nframes} кадров/фаза')
    print(f'  sait: {sait}')
    print(f'  chromium: {chromium}   режим: {args.capture}   jobs: {args.jobs}   петля: {loop_ms} ms')

    ext = 'webm' if args.video_codec == 'vp9' else 'mp4'
    t_all = time.time()

    # Фазы идут ПАРАЛЛЕЛЬНО; если фаз меньше, чем воркеров, кадры фазы
    # дополнительно дробятся на шарды (один браузер на шард).
    shards = max(1, args.jobs // len(phases))
    phase_chunks = {
        n: [c for c in (list(range(nframes))[s::shards] for s in range(shards)) if c]
        for n in phases
    }

    def run_phase(n):
        pdir = workdir / f'p{n:02d}'
        shutil.rmtree(pdir, ignore_errors=True)
        pdir.mkdir(parents=True, exist_ok=True)
        chunks = phase_chunks[n]

        t0 = time.time()
        with ThreadPoolExecutor(max_workers=len(chunks)) as pool:
            futs = []
            for c in chunks:
                if args.capture == 'cdp':
                    futs.append(pool.submit(capture_chunk_cdp, chromium, page, n, c,
                                            loop_ms, nframes, pdir, width, height))
                else:
                    futs.append(pool.submit(capture_chunk_proc, chromium, page, n, c,
                                            loop_ms, nframes, pdir, width, height, 1200))
            for f in futs:
                f.result()
        dt = time.time() - t0

        seq = str(pdir / 'f_%04d.png')
        out = os.path.join(args.out, f'eclipse_{n:02d}.{ext}')
        encode(ffmpeg, seq, args.fps, out, args.video_codec, args.video_crf)
        if not args.frames_keep:
            shutil.rmtree(pdir, ignore_errors=True)
        return n, out, dt

    with ThreadPoolExecutor(max_workers=min(args.jobs, len(phases))) as pool:
        futs = [pool.submit(run_phase, n) for n in phases]
        for f in futs:
            n, out, dt = f.result()
            print(f'  ✔ фаза {n}: {os.path.basename(out)}  ({os.path.getsize(out) / 1e6:.1f} MB)'
                  f'  [{dt:.0f}s съёмка, {dt / nframes * 1000:.0f} ms/кадр]')

    print(f'Готово за {time.time() - t_all:.0f}s. Перезапусти eclipse-walls.sh '
          f'(mpvpaper подхватит видео).')
    print(f'  mpvpaper -o "no-audio loop" \'*\' {args.out}/eclipse_04.{ext}')


if __name__ == '__main__':
    main()
