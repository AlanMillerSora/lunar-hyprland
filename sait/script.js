// ═══════════════ Lunar Eclipse Hyperland Preview ═══════════════

const DESKTOP_NAMES = ['I','II','III','IV','V','VI','VII','VIII','IX'];
const ECLIPSE_COVERAGE = [0.02, 0.08, 0.40, 0.75, 1.00, 0.68, 0.35, 0.12, 0.02];

let currentDesktop = 5;
let openWindows = new Set();
let dragState = null;

// URL params: ?phase=1..8&clean=1 → выбрать стол / спрятать UI (для скриншотов)
const URL_PARAMS = new URLSearchParams(location.search);
const URL_PHASE = parseInt(URL_PARAMS.get('phase') || '');
if (URL_PHASE >= 1 && URL_PHASE <= 9) currentDesktop = URL_PHASE;
const CLEAN_CAPTURE = URL_PARAMS.get('clean') === '1';

// ═══════════════ BOOT SEQUENCE ═══════════════

function bootSequence() {
  if (CLEAN_CAPTURE) {
    document.getElementById('boot-screen').classList.add('hidden');
    document.getElementById('desktop').classList.remove('hidden');
    ['waybar', 'desktop-icons', 'wallpaper-text', 'notification-stack']
      .forEach(id => document.getElementById(id).classList.add('hidden'));
    initDesktop();
    return;
  }

  const lines = document.querySelectorAll('.boot-line');
  lines.forEach((line, i) => {
    const delay = parseInt(line.dataset.delay) || 0;
    setTimeout(() => line.classList.add('visible'), delay);
  });

  setTimeout(() => {
    document.getElementById('boot-screen').style.opacity = '0';
    document.getElementById('boot-screen').style.transition = 'opacity 0.6s ease';
    setTimeout(() => {
      document.getElementById('boot-screen').classList.add('hidden');
      document.getElementById('desktop').classList.remove('hidden');
      initDesktop();
    }, 600);
  }, 2000);
}

// ═══════════════ INITIALIZATION ═══════════════

function initDesktop() {
  createWorkspaces();
  createStars();
  createParticles();
  createMeteors();
  generateNightfall();
  setEclipsePhase(currentDesktop);
  startClock();
  initWaybarModules();
  initApps();
  initDrag();
  initCalculator();
  initAutoCycle();
  initMoonDrag();
  updateEclipseBar();
  showNotification('Добро пожаловать в Hyperland', 'Lunar Eclipse Edition — Arch Linux');
  setTimeout(triggerNightfall, 3400);
}

// ═══════════════ WORKSPACES ═══════════════

function createWorkspaces() {
  const container = document.getElementById('workspaces');
  for (let i = 0; i < 9; i++) {
    const btn = document.createElement('button');
    btn.className = 'ws-btn' + (i + 1 === currentDesktop ? ' active' : '');
    btn.title = `Desktop ${DESKTOP_NAMES[i]}`;
    btn.innerHTML = moonIconSVG(ECLIPSE_COVERAGE[i]);
    btn.addEventListener('click', () => switchDesktop(i + 1));
    container.appendChild(btn);
  }
}

function moonIconSVG(cover) {
  const c = 8, r = 6;
  const inner = leftDiscPath(c, r, cover);
  return `<svg class="ws-svg" width="18" height="18" viewBox="0 0 16 16" fill="none">
    <circle cx="${c}" cy="${c}" r="${r}" stroke="currentColor" stroke-width="1" opacity="0.9"/>
    ${inner}
  </svg>`;
}

// disc filled from left edge to the right (eclipse coverage 0..1 → left→right)
function leftDiscPath(cx, cy, r, cover) {
  if (cover <= 0.001) return '';
  if (cover >= 0.999) return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="currentColor"/>`;
  const p = cx - r + 2 * r * cover;
  const dx = Math.min(r - 0.01, Math.abs(p - cx)) * (p >= cx ? 1 : -1);
  const dy = Math.sqrt(r * r - dx * dx);
  const yt = cy - dy, yb = cy + dy;
  const large = p > cx ? 1 : 0;
  return `<path d="M ${p.toFixed(2)} ${yt.toFixed(2)} A ${r} ${r} 0 ${large} 0 ${p.toFixed(2)} ${yb.toFixed(2)} Z" fill="currentColor"/>`;
}

function switchDesktop(num) {
  if (num === currentDesktop) return;
  currentDesktop = num;
  setEclipsePhase(num);

  document.querySelectorAll('.ws-btn').forEach((btn, i) => {
    btn.classList.toggle('active', i + 1 === num);
  });

  applyWindowsForDesktop(num);

  updateEclipseBar();
  updateTrayActive();

  if (num === 4) {
    setTimeout(triggerNightfall, 150);
  }
}

function applyWindowsForDesktop(num) {
  document.querySelectorAll('.app-window').forEach(win => {
    const ws = parseInt(win.dataset.desktop || '0');
    const hide = ws !== num || win.dataset.minimized === '1';
    win.classList.toggle('hidden', hide);
    win.classList.toggle('ws-hidden', hide);
  });
}

function desktopWindows(num) {
  return Array.from(document.querySelectorAll('.app-window'))
    .filter(w => parseInt(w.dataset.desktop || '0') === num);
}

function setEclipsePhase(num) {
  const container = document.querySelector('.eclipse-container');
  container.style.transition = 'transform 0.8s cubic-bezier(0.4, 0, 0.2, 1)';
  container.className = 'eclipse-container';
  void container.offsetWidth;
  container.classList.add(`eclipse-phase-${num}`);

  // Фон, пыль, горизонт, звёзды живут вне .eclipse-container —
  // фазу вешаем ещё и на #desktop, чтобы селекторы вида .eclipse-phase-N .x работали
  const desktop = document.getElementById('desktop');
  desktop.classList.remove(
    'eclipse-phase-1', 'eclipse-phase-2', 'eclipse-phase-3', 'eclipse-phase-4',
    'eclipse-phase-5', 'eclipse-phase-6', 'eclipse-phase-7', 'eclipse-phase-8', 'eclipse-phase-9'
  );
  desktop.classList.add(`eclipse-phase-${num}`);
}

// ═══════════════ NIGHTFALL FLASH ═══════════════

function generateNightfall() {
  nightfallSVG();
}

function nightfallSVG() {
  const host = document.getElementById('nightfall');
  const cres = crescentPoints();
  const l = cres.left.map(p => p[0].toFixed(1) + ',' + p[1].toFixed(1)).join(' ');
  const r = cres.right.map(p => p[0].toFixed(1) + ',' + p[1].toFixed(1)).join(' ');
  host.innerHTML = `
    <svg class="nf-burst" viewBox="0 0 560 560" overflow="hidden">
      <defs>
        <linearGradient id="nfCresL" gradientUnits="userSpaceOnUse" x1="150" y1="0" x2="287" y2="0">
          <stop offset="0%" stop-color="#2e6bff"/>
          <stop offset="45%" stop-color="#a6c8ff"/>
          <stop offset="100%" stop-color="#ffffff"/>
        </linearGradient>
        <linearGradient id="nfCresR" gradientUnits="userSpaceOnUse" x1="273" y1="0" x2="410" y2="0">
          <stop offset="0%" stop-color="#ffffff"/>
          <stop offset="55%" stop-color="#a6c8ff"/>
          <stop offset="100%" stop-color="#2e6bff"/>
        </linearGradient>
      </defs>
      <polygon class="nf-crescent nf-left" points="${l}" fill="url(#nfCresL)"/>
      <polygon class="nf-crescent nf-right" points="${r}" fill="url(#nfCresR)"/>
    </svg>
  `;
}

// Classic side crescent (two overlapping circles of equal radius r):
// main circle centred (cx,cy), cut circle shifted by `off` towards the
// opposite side. Intersection of the circle edges gives the two horns
// (top and bottom). Thin crescent hugs the eclipse ring from the side.
function crescentPoints() {
  var cx = 280, cy = 280, r = 130, off = 14, n = 80;
  var cutCx = cx + off;                      // cut circle offset right → crescent bulges left
  var hornX = cx + off / 2;                  // horns sit on the perpendicular bisector
  var hornD = Math.sqrt(r * r - off * off / 4);
  var bot = [hornX, cy + hornD], top = [hornX, cy - hornD];

  var aTopMain = Math.atan2(top[1] - cy, top[0] - cx);       // angle of top horn on main
  if (aTopMain < 0) aTopMain += 2 * Math.PI;
  var aBotMain = Math.atan2(bot[1] - cy, bot[0] - cx);
  var aTopCut = Math.atan2(top[1] - cy, top[0] - cutCx);      // angle of top horn on cut
  if (aTopCut < 0) aTopCut += 2 * Math.PI;
  var aBotCut = Math.atan2(bot[1] - cy, bot[0] - cutCx);

  var pts = [];
  // outer arc: bottom horn → around back (left side) → top horn
  for (var i = 0; i <= n; i++) {
    var a = aBotMain + (aTopMain - aBotMain) * i / n;
    pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  // inner arc: top horn → around concave side → bottom horn
  for (var i = 0; i <= n; i++) {
    var a = aTopCut + (aBotCut - aTopCut) * i / n;
    pts.push([cutCx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }

  // mirror for the right-side crescent
  var mirror = pts.map(function(p) { return [2 * cx - p[0], p[1]]; });
  return { left: pts, right: mirror };
}

var nightfallSide = false;

function triggerNightfall() {
  nightfallSide = !nightfallSide;
  const nf = document.getElementById('nightfall');
  const l = nf.querySelector('.nf-left');
  const r = nf.querySelector('.nf-right');
  l.style.opacity = nightfallSide ? 1 : 0;
  r.style.opacity = nightfallSide ? 0 : 1;
  nf.classList.remove('show');
  void nf.offsetWidth;
  nf.classList.add('show');
}

// ═══════════════ STARS ═══════════════

function createStars() {
  const container = document.getElementById('stars');
  for (let i = 0; i < 150; i++) {
    const star = document.createElement('div');
    star.className = 'star';
    star.style.left = Math.random() * 100 + '%';
    star.style.top = Math.random() * 100 + '%';
    star.style.setProperty('--dur', (2 + Math.random() * 4) + 's');
    star.style.setProperty('--max-op', (0.3 + Math.random() * 0.7));
    star.style.animationDelay = Math.random() * 4 + 's';
    const size = Math.random() < 0.08 ? 2 : 1;
    star.style.width = size + 'px';
    star.style.height = size + 'px';
    container.appendChild(star);
  }
}

// ═══════════════ PARTICLES ═══════════════

function createParticles() {
  const desktop = document.getElementById('desktop');
  for (let i = 0; i < 15; i++) {
    const p = document.createElement('div');
    p.className = 'particle';
    p.style.left = Math.random() * 100 + '%';
    p.style.setProperty('--dur', (10 + Math.random() * 20) + 's');
    p.style.setProperty('--drift', (Math.random() * 100 - 50) + 'px');
    p.style.animationDelay = Math.random() * 15 + 's';
    p.style.width = p.style.height = (1 + Math.random() * 2) + 'px';
    desktop.appendChild(p);
  }
}

// ═══════════════ METEOR SHOWER ═══════════════

function createMeteors() {
  const host = document.getElementById('meteors');
  for (let i = 0; i < 7; i++) {
    const m = document.createElement('div');
    m.className = 'meteor';
    m.style.left = (45 + Math.random() * 55) + '%';
    m.style.top = (-2 + Math.random() * 25) + '%';
    m.style.animation = `meteorFall ${1.1 + Math.random() * 1.6}s linear ${3 + Math.random() * 9}s infinite`;
    host.appendChild(m);
  }
}

// ═══════════════ ECLIPSE PROGRESS BAR ═══════════════

function updateEclipseBar() {
  const pct = Math.round(ECLIPSE_COVERAGE[currentDesktop - 1] * 100);
  document.getElementById('ep-pct').textContent = pct + '%';
  const fill = document.getElementById('ep-fill');
  fill.style.width = pct + '%';
  fill.style.background = (currentDesktop === 4)
    ? 'linear-gradient(90deg, #c2344a, #f2657a)'
    : 'linear-gradient(90deg, #7ea6ff, #ffffff)';
}

// ═══════════════ AUTO-CYCLE DEMO MODE ═══════════════

let autoCycleTimer = null;

function initAutoCycle() {
  const btn = document.getElementById('auto-cycle');
  btn.addEventListener('click', () => {
    if (autoCycleTimer) {
      clearInterval(autoCycleTimer);
      autoCycleTimer = null;
      btn.classList.remove('on');
      showNotification('Автоцикл фаз', 'Демо-режим остановлен');
      return;
    }
    btn.classList.add('on');
    showNotification('Автоцикл фаз', 'Луна пойдёт по всем столам автоматически');
    autoCycleTimer = setInterval(() => {
      const next = currentDesktop >= 8 ? 1 : currentDesktop + 1;
      switchDesktop(next);
    }, 2200);
  });
}

// ═══════════════ MOON DRAG → PHASE SLIDER ═══════════════

// Позиции луны совпадают с таблицей фаз в style.css (столы 1..8):
// -339, -288, -230, -107, 0, +107, +230, +288 (индекс 0 не используется).
const MOON_OFFSETS = [0, -339, -288, -230, -107, 0, 107, 230, 288];

function moonDragDesktop(offset) {
  let best = 1, bestDist = Infinity;
  for (let d = 1; d <= 8; d++) {
    const dist = Math.abs(offset - MOON_OFFSETS[d]);
    if (dist < bestDist) { bestDist = dist; best = d; }
  }
  return best;
}

function initMoonDrag() {
  const container = document.querySelector('.eclipse-container');
  const moon = document.querySelector('.moon');
  let dragging = null;

  moon.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    dragging = { startX: e.clientX };
    moon.style.transition = 'none';
    container.style.transition = 'none';
    moon.classList.add('dragging');
    e.preventDefault();
  });

  document.addEventListener('mousemove', (e) => {
    if (!dragging) return;
    const dx = e.clientX - dragging.startX;
    const base = MOON_OFFSETS[currentDesktop];
    const target = base + dx;
    const clamped = Math.max(-260, Math.min(260, target));
    moon.style.transform = `translate(calc(-50% + ${clamped}px), -50%)`;
  });

  document.addEventListener('mouseup', (e) => {
    if (!dragging) return;
    const dx = e.clientX - dragging.startX;
    const target = MOON_OFFSETS[currentDesktop] + dx;
    const desk = moonDragDesktop(Math.max(-260, Math.min(260, target)));
    moon.style.transition = '';
    moon.style.transform = '';
    moon.classList.remove('dragging');
    container.style.transition = '';
    dragging = null;
    switchDesktop(desk);
  });
}

// ═══════════════ CLOCK ═══════════════

function startClock() {
  let cpuBase = 3, memBase = 4.2;
  function update() {
    const now = new Date();
    const h = String(now.getHours()).padStart(2, '0');
    const m = String(now.getMinutes()).padStart(2, '0');
    const s = String(now.getSeconds()).padStart(2, '0');
    document.getElementById('clock').textContent = `${h}:${m}:${s}`;

    const months = ['Янв','Фев','Мар','Апр','Май','Июн','Июл','Авг','Сен','Окт','Ноя','Дек'];
    const days = ['Вс','Пн','Вт','Ср','Чт','Пт','Сб'];
    document.getElementById('date-display').textContent =
      `${days[now.getDay()]} ${now.getDate()} ${months[now.getMonth()]}`;

    cpuBase += (Math.random() - 0.48) * 1.5;
    cpuBase = Math.max(1, Math.min(18, cpuBase));
    memBase += (Math.random() - 0.5) * 0.2;
    memBase = Math.max(3.2, Math.min(6.1, memBase));
    document.getElementById('cpu-val').textContent = Math.round(cpuBase) + '%';
    document.getElementById('memory-val').textContent = memBase.toFixed(1) + 'G';
  }
  update();
  setInterval(update, 1000);
}

// ═══════════════ WAYBAR MODULES ═══════════════

function initWaybarModules() {
  document.getElementById('battery').addEventListener('click', () => {
    showNotification('Батарея', 'Уровень заряда: 87% — ETA: 3ч 42м');
  });

  document.getElementById('volume').addEventListener('click', () => {
    showNotification('Громкость', 'Громкость: 72% — Аудио: Analog Output');
  });

  document.getElementById('network').addEventListener('click', () => {
    showNotification('Сеть', 'Wi-Fi: Connected — archlinux-5g');
  });
}

// ═══════════════ APP LAUNCHER ═══════════════

const APPS = [
  { name: 'Kitty', desc: 'Терминал', icon: '>', action: 'terminal' },
  { name: 'Thunar', desc: 'Файловый менеджер', icon: '▣', action: 'files' },
  { name: 'Firefox', desc: 'Браузер', icon: '◉', action: 'browser' },
  { name: 'VS Code', desc: 'Редактор кода', icon: '✎', action: 'vscode' },
  { name: 'Spotify', desc: 'Музыка', icon: '♪', action: 'spotify' },
  { name: 'Discord', desc: 'Чат', icon: '◎', action: 'discord' },
  { name: 'Obsidian', desc: 'Заметки', icon: '▤', action: 'obsidian' },
  { name: 'htop', desc: 'Мониторинг', icon: '▥', action: 'htop' },
  { name: 'neofetch', desc: 'Система', icon: '▧', action: 'neofetch' },
  { name: 'nmtui', desc: 'Настройка сети', icon: '≋', action: 'network' },
  { name: 'pavucontrol', desc: 'Звук', icon: '☊', action: 'volume' },
  { name: 'hyprshot', desc: 'Скриншот', icon: '◈', action: 'screenshot' },
];

function initApps() {
  // Desktop icons
  document.querySelectorAll('.desktop-icon').forEach(icon => {
    icon.addEventListener('click', () => openApp(icon.dataset.action));
  });

  // Wofi apps
  const container = document.getElementById('wofi-apps');
  APPS.forEach(app => {
    const div = document.createElement('div');
    div.className = 'wofi-app';
    div.innerHTML = `
      <div class="wofi-app-icon">${app.icon}</div>
      <div>
        <div class="wofi-app-name">${app.name}</div>
        <div class="wofi-app-desc">${app.desc}</div>
      </div>
    `;
    div.addEventListener('click', () => {
      closeWofi();
      openApp(app.action);
    });
    container.appendChild(div);
  });

  // Wofi input filter
  document.getElementById('wofi-input').addEventListener('input', (e) => {
    const q = e.target.value.toLowerCase();
    document.querySelectorAll('.wofi-app').forEach((div, i) => {
      const app = APPS[i];
      const match = app.name.toLowerCase().includes(q) || app.desc.toLowerCase().includes(q);
      div.style.display = match ? 'flex' : 'none';
    });
  });

  // Close wofi on overlay click
  document.getElementById('wofi-overlay').addEventListener('click', (e) => {
    if (e.target.id === 'wofi-overlay') closeWofi();
  });
}

function openApp(action) {
  const windowMap = {
    terminal: 'terminal-window',
    files: 'files-window',
    browser: 'browser-window'
  };

  const builtin = windowMap[action];
  if (builtin) {
    const win = document.getElementById(builtin);
    win.classList.remove('hidden');
    win.classList.remove('ws-hidden');
    win.dataset.minimized = '0';
    win.dataset.desktop = currentDesktop;
    openWindows.add(builtin);
    focusWindow(win);
    updateTray();
    if (action === 'terminal') {
      initTerminal();
      win.querySelector('.terminal-input').focus();
    }
    return;
  }

  const app = APPS.find(a => a.action === action);
  if (!app) return;
  const genId = 'gen-' + action;
  let win = document.getElementById(genId);
  if (!win) {
    win = buildGenericWindow(app, genId);
    document.getElementById('desktop').appendChild(win);
  }
  win.classList.remove('hidden');
  win.classList.remove('ws-hidden');
  win.dataset.minimized = '0';
  win.dataset.desktop = currentDesktop;
  openWindows.add(genId);
  focusWindow(win);
  updateTray();
}

function buildGenericWindow(app, genId) {
  const css = { vscode: '#007acc', spotify: '#1db954', discord: '#5865f2', obsidian: '#7c5cff', htop: '#62d76b', neofetch: '#b7b7ff', nmtui: '#9a8cff', pavucontrol: '#ff9a62', hyprshot: '#ffffff' };
  const win = document.createElement('div');
  win.className = 'app-window gen-window';
  win.id = genId;
  win.innerHTML = `
    <div class="window-bar">
      <div class="window-dots">
        <span class="dot red"></span>
        <span class="dot yellow"></span>
        <span class="dot green"></span>
      </div>
      <span class="window-title">${app.name} — ${app.desc}</span>
      <div class="window-controls">
        <button class="win-btn minimize" title="Свернуть">—</button>
        <button class="win-btn maximize" title="Развернуть">□</button>
        <button class="win-btn close" title="Закрыть">×</button>
      </div>
    </div>
    <div class="gen-body" style="--gen-accent: ${css[app.action] || '#ffffff'}">
      <div class="gen-header">
        <div class="gen-icon">${app.icon}</div>
        <div>
          <div class="gen-name">${app.name}</div>
          <div class="gen-desc">${app.desc}</div>
        </div>
      </div>
      <div class="gen-lines">
        ${genericLines(app)}
      </div>
    </div>
  `;
  return win;
}

function genericLines(app) {
  const action = app.action;
  const L = (text, cls) => `<div class="gen-line ${cls}">${text}</div>`;
  switch (action) {
    case 'htop': return [
        L('PID    USER     CPU%   MEM%   COMMAND', 'gen-hdr'),
        L('1240   lunar    2.3    1.4    hyprland', ''),
        L('2048   lunar    11.9   4.7    firefox', 'gen-active'),
        L('2183   lunar    0.8    0.9    kitty', ''),
        L('2196   lunar    34.1   6.2    vscode', 'gen-active'),
        L('2210   lunar    0.2    1.1    waybar', ''),
        L('2234   lunar    1.6    2.3    thunar', ''),
        L('2291   lunar    0.1    0.4    spotify', ''),
        L('2312   lunar    0.0    0.1    systemd --user', ''),
      ].join('');
    case 'neofetch': return [
        L('          .x+=:.', 'gen-acc'),
        L('         .:wMZ$Yz.', 'gen-acc'),
        L('        :ZZYW?  (M2', 'gen-acc'),
        L('       ,^#M7    ,$MY', 'gen-acc'),
        L('  .??MMMMM=??^^^7MmM#   lunar@arch', ''),
        L('  =7^...       ,7MmMM#  -----------------', ''),
        L('   ^??MMMMM=???7MmmMK   OS: Arch Linux x86_64', ''),
        L('        `#M7    ,$M', 'gen-acc'),
        L('         :ZZYX  (W', 'gen-acc'),
        L('          `:=^z-.', 'gen-acc'),
        L('                          De: Hyperland (Wayland)', ''),
        L('                          WM: Hyprland v0.44.1', ''),
        L('                          Theme: Lunar Eclipse', ''),
      ].join('');
    case 'vscode': return [
        L('EXPLORER', 'gen-hdr'),
        L('▸ HYPERLAND-PREVIEW', ''),
        L('  ▸ index.html', ''),
        L('  ▸ style.css', 'gen-active'),
        L('  ▸ script.js', ''),
        L('▸ OUTLINE', ''),
        L('  ▸ nightfallSVG()', ''),
        L('  ▸ crescentPoints()', ''),
      ].join('');
    case 'spotify': return [
        L('♫ › Сейчас играет', 'gen-hdr'),
        L('  Elira — Under the Black Sky', 'gen-active'),
        L('  ────────────────────●───────  3:12 / 4:47', ''),
        L('  ❮  ❯❯  ♡  ⌁', ''),
        L('  Плейлист: Lunar Eclipse Mix', ''),
      ].join('');
    case 'discord': return [
        L('◆ Каналы', 'gen-hdr'),
        L('  # общий — 128 сообщений', ''),
        L('  # hyprland — 58 сообщений', 'gen-active'),
        L('  # arch-packages — 14 новых', ''),
        L('  ● Голосовой канал: Eclipse Lounge', ''),
      ].join('');
    case 'obsidian': return [
        L('📝 Заметки', 'gen-hdr'),
        L('  ■ Лунное затмение — заметки', 'gen-active'),
        L('  ■ Настройка Hyprland', ''),
        L('  ■ Список пакетов AUR', ''),
        L('  ■ Идеи для обоев', ''),
      ].join('');
    case 'nmtui': return [
        L('СЕТЕВЫЕ ПОДКЛЮЧЕНИЯ', 'gen-hdr'),
        L('  ● Wi-Fi: archlinux-5g  [ Подключено ]', 'gen-active'),
        L('  ○ Ethernet: eth0', ''),
        L('  ○ VPN: lunar-vpn', ''),
      ].join('');
    case 'pavucontrol': return [
        L('ГРОМКОСТЬ', 'gen-hdr'),
        L('  ████████████░░░░░░  Аналоговый вывод', ''),
        L('  ████████░░░░░░░░░░  Spotify', 'gen-active'),
        L('  ██████████████░░░░  Браузер', ''),
      ].join('');
    default: return [
        L(`${app.name} запущен`, 'gen-active'),
        L('Полная версия доступна на вашем Arch Linux.', ''),
      ].join('');
  }
}

function closeApp(windowId) {
  document.getElementById(windowId).classList.add('hidden');
  openWindows.delete(windowId);
  updateTray();
}

// ═══════════════ TRAY ═══════════════

const TRAY_ICONS = { terminal: '>', files: '▣', browser: '◉', vscode: '✎', spotify: '♪', discord: '◎', obsidian: '▤', htop: '▥', neofetch: '▧', network: '≋', volume: '☊', hyprshot: '◈' };

function trayIconFor(id) {
  if (id === 'calculator-window') return '⃟';
  const action = id.replace('gen-', '');
  return TRAY_ICONS[action] || '◻';
}

function updateTray() {
  const host = document.getElementById('tray-icons');
  host.innerHTML = '';
  openWindows.forEach(id => {
    const el = document.createElement('div');
    el.className = 'tray-icon';
    el.textContent = trayIconFor(id);
    el.title = id;
    el.addEventListener('click', () => {
      const win = document.getElementById(id);
      if (!win) return;
      const desk = parseInt(win.dataset.desktop || '0');
      if (desk && desk !== currentDesktop) switchDesktop(desk);
      win.classList.remove('hidden');
      win.dataset.minimized = '0';
      focusWindow(win);
    });
    host.appendChild(el);
  });
}

function updateTrayActive() {
  document.querySelectorAll('.tray-icon').forEach(el => {
    const win = document.getElementById(el.title);
    if (win && win.classList.contains('hidden')) el.classList.remove('active');
    else el.classList.add('active');
  });
}

// ═══════════════ TERMINAL ═══════════════

const TERMINAL_COMMANDS = {
  help: () => [
    { text: 'Доступные команды:', class: 'info' },
    { text: '  help      — показать эту справку', class: 'muted' },
    { text: '  neofetch  — информация о системе', class: 'muted' },
    { text: '  ls        — список файлов', class: 'muted' },
    { text: '  pwd       — текущая директория', class: 'muted' },
    { text: '  whoami    — имя пользователя', class: 'muted' },
    { text: '  date      — текущая дата', class: 'muted' },
    { text: '  clear     — очистить терминал', class: 'muted' },
    { text: '  cat       — показать содержимое файла', class: 'muted' },
    { text: '  uname     — информация о ядре', class: 'muted' },
    { text: '  uptime    — время работы', class: 'muted' },
    { text: '  hyprctl   — управление Hyperland', class: 'muted' },
  ],
  neofetch: () => {
    return [
      { text: '                   .oOo.           lunar@arch', class: 'info' },
      { text: '                   .OOO.           ─────────────────', class: 'info' },
      { text: '                  .OOOOO.          OS: Arch Linux x86_64', class: '' },
      { text: '                 .OOOOOOO.         Host: Hyperland', class: '' },
      { text: '                .OOOOOOOOO.        Kernel: 6.11.2-arch1-1', class: '' },
      { text: '               .OOOOOOOOOOO.       Uptime: 3 hours, 42 mins', class: '' },
      { text: '              .OOOOOOOOOOOOO.      Shell: zsh 5.9', class: '' },
      { text: '             .OOOOOOOOOOOOOOO.     DE: Hyprland (Wayland)', class: '' },
      { text: '            .OOOOOOOOOOOOOOOOO.    WM: Hyprland v0.44.1', class: '' },
      { text: '           .OOOOOOOOOOOOOOOOOOO.   Bar: Waybar', class: '' },
      { text: '            `*OOOOOOOOOOOOO*\'      Terminal: kitty', class: '' },
      { text: '               `*OOOOOOO*\'         Theme: Lunar Eclipse', class: '' },
      { text: '                  `***\'            CPU: AMD Ryzen 9 5900X', class: '' },
      { text: '                                   GPU: NVIDIA RTX 4070', class: '' },
      { text: '                                   Memory: 4.2 GiB / 32 GiB', class: '' },
      { text: '', class: '' },
      { text: '   ████████████████████████████', class: 'info' },
    ];
  },
  ls: () => [
    { text: '.config  Documents  Downloads  Music  Pictures  Videos  .bashrc  .zshrc', class: '' },
  ],
  pwd: () => [{ text: '/home/lunar', class: '' }],
  whoami: () => [{ text: 'lunar', class: '' }],
  date: () => [{ text: new Date().toLocaleString('ru-RU'), class: '' }],
  uname: () => [{ text: 'Linux arch 6.11.2-arch1-1 #1 SMP PREEMPT_DYNAMIC x86_64 GNU/Linux', class: '' }],
  uptime: () => [{ text: ' 14:23:07 up  3:42,  1 user,  load average: 0.52, 0.61, 0.58', class: '' }],
  clear: () => 'CLEAR',
  hyprctl: () => [
    { text: 'HYPRLAND IPC REQUEST', class: 'info' },
    { text: '  keyword:general:col.active_border = rgba(ffffffff)', class: '' },
    { text: '  keyword:general:col.inactive_border = rgba(666666ff)', class: '' },
    { text: '  keyword:decoration:blur:size = 8', class: '' },
    { text: '  keyword:animations:enabled = true', class: '' },
    { text: '', class: '' },
    { text: '  ✦ Hyperland is working correctly', class: 'success' },
  ],
  cat: (args) => {
    if (!args) return [{ text: 'cat:_operand_missing', class: 'error' }];
    if (args === '.bashrc') return [
      { text: '# ~/.bashrc', class: 'muted' },
      { text: 'export PATH="$HOME/.local/bin:$PATH"', class: '' },
      { text: 'alias ll="ls -la"', class: '' },
      { text: 'alias gs="git status"', class: '' },
      { text: 'PS1="\\[\\e[38;5;111m\\]\\u@arch\\[\\e[0m\\]:\\[\\e[38;5;114m\\]\\w\\[\\e[0m\\]\\$ "', class: '' },
    ];
    if (args === '.zshrc') return [
      { text: '# ~/.zshrc', class: 'muted' },
      { text: 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)', class: '' },
      { text: 'source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh', class: '' },
    ];
    return [{ text: `cat: ${args}: No such file or directory`, class: 'error' }];
  },
};

let terminalInited = false;

function initTerminal() {
  if (terminalInited) return;
  terminalInited = true;

  const output = document.getElementById('terminal-output');
  const input = document.getElementById('terminal-input');

  addTerminalLines([
    { text: '  ╦  ╦┬┌─┐┬ ┬┌┬┐┌─┐', class: 'info' },
    { text: '  ╚╗╔╝│├─┤│ │ │ └─┐', class: 'info' },
    { text: '   ╚╝ ┴┴ ┴└─┘ ┴ └─┘', class: 'info' },
    { text: '', class: '' },
    { text: '  Lunar Eclipse Edition — Arch Linux', class: 'muted' },
    { text: '  Type "help" for available commands.', class: 'muted' },
    { text: '', class: '' },
  ]);

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      const cmd = input.value.trim();
      addTerminalLines([{ text: `lunar@arch:~$ ${cmd}`, class: '' }]);

      if (cmd) {
        const [command, ...args] = cmd.split(' ');
        const argStr = args.join(' ');

        if (command === 'clear') {
          output.innerHTML = '';
        } else if (TERMINAL_COMMANDS[command]) {
          addTerminalLines(TERMINAL_COMMANDS[command](argStr));
        } else {
          addTerminalLines([{ text: `zsh: command not found: ${command}`, class: 'error' }]);
        }
      }

      input.value = '';
      const body = document.getElementById('terminal-body');
      body.scrollTop = body.scrollHeight;
    }
  });
}

function addTerminalLines(lines) {
  const output = document.getElementById('terminal-output');
  lines.forEach(({ text, class: cls }) => {
    const div = document.createElement('div');
    div.className = 'line' + (cls ? ` ${cls}` : '');
    div.textContent = text;
    output.appendChild(div);
  });
}

// ═══════════════ WOFI ═══════════════

function openWofi() {
  const overlay = document.getElementById('wofi-overlay');
  overlay.classList.remove('hidden');
  const input = document.getElementById('wofi-input');
  input.value = '';
  input.focus();
  document.querySelectorAll('.wofi-app').forEach(d => d.style.display = 'flex');
}

function closeWofi() {
  document.getElementById('wofi-overlay').classList.add('hidden');
}

// ═══════════════ NOTIFICATION STACK ═══════════════

function showNotification(title, message, opts = {}) {
  const stack = document.getElementById('notification-stack');
  const notif = document.createElement('div');
  notif.className = 'notification';
  notif.innerHTML = `
    <div class="notif-icon">${opts.icon || '&#9790;'}</div>
    <div class="notif-text">
      <strong>${title}</strong>
      <span>${message}</span>
    </div>
    ${opts.progress !== undefined ? `<div class="notif-progress"></div>` : ''}
  `;
  stack.appendChild(notif);

  let dismissed = false;
  const dismiss = () => {
    if (dismissed) return;
    dismissed = true;
    clearTimeout(notif._timeout);
    notif.classList.add('leaving');
    setTimeout(() => notif.remove(), 350);
  };

  if (opts.progress !== undefined) {
    const fill = notif.querySelector('.notif-progress');
    fill.style.width = opts.progress + '%';
    notif._setProgress = (p) => { fill.style.width = Math.min(100, p) + '%'; };
  }

  notif.addEventListener('click', dismiss);
  if (opts.timeout !== 0) notif._timeout = setTimeout(dismiss, opts.timeout || 4000);
  else notif.classList.add('persistent');
  notif.style.cursor = 'grab';

  // Drag to dismiss (swipe right)
  (function attachDrag() {
    let startX = 0, startY = 0, dragging = false;
    notif.addEventListener('pointerdown', (e) => {
      startX = e.clientX; startY = e.clientY;
      dragging = true;
      notif.classList.add('dragging');
      notif.setPointerCapture(e.pointerId);
    });
    notif.addEventListener('pointermove', (e) => {
      if (!dragging) return;
      const dx = e.clientX - startX;
      if (dx > 0) notif.style.transform = `translateX(${dx}px)`;
      notif.style.opacity = Math.max(0.2, 1 - (dx / 120));
    });
    notif.addEventListener('pointerup', (e) => {
      if (!dragging) return;
      dragging = false;
      notif.classList.remove('dragging');
      const dx = e.clientX - startX;
      if (dx > 90) dismiss();
      else { notif.style.transform = ''; notif.style.opacity = ''; }
    });
  })();

  while (stack.children.length > 5) stack.firstElementChild.remove();
  return notif;
}

// ═══════════════ DOWNLOAD PROGRESS NOTIFICATION ═══════════════

let downloadTimers = new Set();

function simulateDownload(name = 'hyprland-settings.tar.gz') {
  const notif = showNotification('Загрузка', name, { icon: '⬇', progress: 0, timeout: 0 });
  let pct = 0;
  const timer = setInterval(() => {
    pct += Math.round(4 + Math.random() * 14);
    if (pct >= 100) {
      pct = 100;
      clearInterval(timer);
      downloadTimers.delete(timer);
      notif._setProgress(100);
      notif.querySelector('.notif-progress').fromUnused = 1;
      setTimeout(() => {
        if (notif.isConnected) {
          notif.querySelector('.notif-text strong').textContent = 'Загрузка завершена';
          notif.querySelector('span').textContent = name + ' — сохранён в ~/Загрузки';
          notif._setProgress(100);
          notif.querySelector('.notif-progress').style.background = '#62d76b';
          setTimeout(() => notif.click(), 1400);
        }
      }, 400);
      return;
    }
    if (notif.isConnected) notif._setProgress(pct);
  }, 260);
  downloadTimers.add(timer);
}

// ═══════════════ CALCULATOR ═══════════════

let calcAcc = null, calcOp = null, calcFresh = true;

function openCalculator() {
  const win = document.getElementById('calculator-window');
  win.classList.remove('hidden');
  win.dataset.calc = '1';
  win.dataset.desktop = currentDesktop;
  openWindows.add('calculator-window');
  focusWindow(win);
  updateTray();
}

function closeCalculator() {
  const win = document.getElementById('calculator-window');
  win.classList.add('hidden');
  openWindows.delete('calculator-window');
  updateTray();
  calcAcc = null; calcOp = null; calcFresh = true;
  setCalcDisplay('0');
}

function calcValue() {
  return parseFloat(document.getElementById('calc-display').textContent.replace(/,/g, '.'));
}

function setCalcDisplay(v) {
  const s = String(v);
  document.getElementById('calc-display').textContent = s.length > 14 ? v.toPrecision(10) : s;
}

function calcApplyOp() {
  const cur = calcValue();
  if (calcOp && calcAcc !== null) {
    if (calcOp === '+') calcAcc += cur;
    else if (calcOp === '-') calcAcc -= cur;
    else if (calcOp === '*') calcAcc *= cur;
    else if (calcOp === '/') calcAcc = cur === 0 ? 0 : calcAcc / cur;
    setCalcDisplay(calcAcc);
  } else {
    calcAcc = cur;
  }
}

function initCalculator() {
  document.querySelectorAll('#calculator-window .calc-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const key = btn.dataset.calc;
      const display = document.getElementById('calc-display');
      if (key === 'C') {
        calcAcc = null; calcOp = null; calcFresh = true;
        setCalcDisplay('0');
        return;
      }
      if (key === '±') {
        setCalcDisplay(-calcValue());
        return;
      }
      if (key === '%') {
        setCalcDisplay(calcValue() / 100);
        return;
      }
      if ('+-*/='.includes(key)) {
        if (key === '=') {
          calcApplyOp();
          calcAcc = null; calcOp = null;
        } else {
          calcApplyOp();
          calcOp = key;
          setCalcDisplay(calcAcc);
        }
        calcFresh = true;
        return;
      }
      // digits and dot
      let cur = display.textContent;
      if (calcFresh) { cur = '0'; calcFresh = false; }
      if (key === '.') {
        if (cur.includes('.')) return;
        setCalcDisplay(cur + '.');
      } else {
        setCalcDisplay(cur === '0' ? key : cur + key);
      }
    });
  });
}

// ═══════════════ WINDOW DRAG / FOCUS / TILING ═══════════════

let windowZ = 200;

function focusWindow(win) {
  windowZ += 1;
  win.style.zIndex = windowZ;
  document.querySelectorAll('.app-window').forEach(w => w.classList.remove('focused'));
  win.classList.add('focused');
  document.getElementById('waybar').classList.add('collapsed');
}

function expandWaybar() {
  document.getElementById('waybar').classList.remove('collapsed');
}

function initDrag() {
  // bring window to front on any interaction (delegated → covers dynamic windows)
  document.addEventListener('mousedown', (e) => {
    const win = e.target.closest('.app-window');
    if (win) {
      focusWindow(win);
    } else if (!e.target.closest('#waybar') && !e.target.closest('.context-menu') && !e.target.closest('#wofi-overlay')) {
      expandWaybar();
    }
  });

  document.addEventListener('dblclick', (e) => {
    const bar = e.target.closest('.window-bar');
    if (bar && !e.target.closest('.window-controls')) toggleMaximize(bar.closest('.app-window'));
  });

  document.addEventListener('mousedown', (e) => {
    const bar = e.target.closest('.window-bar');
    if (!bar || e.target.closest('.window-controls')) return;
    const win = bar.closest('.app-window');
    if (win.dataset.fwscreen === '1') return;
    const rect = win.getBoundingClientRect();
    dragState = {
      win,
      startX: e.clientX,
      startY: e.clientY,
      origX: rect.left,
      origY: rect.top,
    };
    win.classList.add('dragging');
    e.preventDefault();
  });

  document.addEventListener('mousemove', (e) => {
    if (!dragState) return;
    const dx = e.clientX - dragState.startX;
    const dy = e.clientY - dragState.startY;
    dragState.win.style.left = (dragState.origX + dx) + 'px';
    dragState.win.style.top = (dragState.origY + dy) + 'px';
  });

  document.addEventListener('mouseup', () => {
    if (dragState) {
      dragState.win.classList.remove('dragging');
      dragState = null;
    }
  });

  // Window controls — delegated, works for dynamically created windows
  document.addEventListener('click', (e) => {
    const close = e.target.closest('.win-btn.close');
    if (close) {
      const win = close.closest('.app-window');
      if (win.dataset.calc) { closeCalculator(); return; }
      win.style.animation = 'windowClose 0.2s ease forwards';
      setTimeout(() => {
        win.classList.add('hidden');
        win.style.animation = '';
        openWindows.delete(win.id);
        updateTray();
      }, 200);
      return;
    }
    const max = e.target.closest('.win-btn.maximize');
    if (max) { toggleMaximize(max.closest('.app-window')); return; }
    const min = e.target.closest('.win-btn.minimize');
    if (min) {
      const win = min.closest('.app-window');
      win.dataset.minimized = '1';
      win.classList.add('hidden', 'ws-hidden');
      updateTrayActive();
      if (win.dataset.calc) { closeCalculator(); return; }
      return;
    }
    const redDot = e.target.closest('.dot.red');
    if (redDot) {
      const win = redDot.closest('.app-window');
      if (win.dataset.calc) { closeCalculator(); return; }
      win.style.animation = 'windowClose 0.2s ease forwards';
      setTimeout(() => {
        win.classList.add('hidden');
        win.style.animation = '';
        openWindows.delete(win.id);
        updateTray();
      }, 200);
    }
  });
}

function toggleMaximize(win) {
  if (win.dataset.fwscreen === '1') {
    restoreWindow(win);
  } else {
    win.dataset.prevRect = JSON.stringify({
      left: win.style.left || getComputedStyle(win).left,
      top: win.style.top || getComputedStyle(win).top,
      width: getComputedStyle(win).width,
      height: getComputedStyle(win).height,
    });
    win.dataset.fwscreen = '1';
    win.style.cssText = 'left:0;top:36px;width:100vw;height:calc(100vh - 36px);z-index:' + (++windowZ);
    focusWindow(win);
  }
}

function restoreWindow(win) {
  delete win.dataset.fwscreen;
  const prev = JSON.parse(win.dataset.prevRect || '{}');
  win.style.left = prev.left || '100px';
  win.style.top = prev.top || '120px';
  win.style.width = prev.width || '700px';
  win.style.height = prev.height || '420px';
  focusWindow(win);
}

function tileWindow(win, dir) {
  if (!win) return;
  win.dataset.fwscreen = '1';
  const top = '36px', bottom = 'calc(100vh - 36px)';
  if (dir === 'left') {
    win.style.cssText = `left:0;top:${top};width:50vw;height:${bottom};z-index:${++windowZ}`;
  } else if (dir === 'right') {
    win.style.cssText = `left:50vw;top:${top};width:50vw;height:${bottom};z-index:${++windowZ}`;
  } else {
    toggleMaximize(win);
  }
  focusWindow(win);
}

function moveActiveWindowToDesktop(num) {
  const wins = desktopWindows(currentDesktop).filter(w => !w.classList.contains('hidden'));
  if (!wins.length) return;
  const active = document.querySelector('.app-window.focused');
  const target = (active && desktopWindows(currentDesktop).includes(active)) ? active : wins[wins.length - 1];
  target.dataset.desktop = num;
  applyWindowsForDesktop(currentDesktop);
  showNotification('Рабочий стол ' + DESKTOP_NAMES[num - 1],
    `Окно «${target.querySelector('.window-title').textContent}» перемещено`);
}

// window close animation
const style = document.createElement('style');
style.textContent = `
  @keyframes windowClose {
    to { opacity: 0; transform: scale(0.9); }
  }
`;
document.head.appendChild(style);

// ═══════════════ KEYBOARD SHORTCUTS ═══════════════

document.addEventListener('keydown', (e) => {
  // Super key simulation (Ctrl+something)
  if (e.ctrlKey && !e.shiftKey && e.key === 'd') {
    e.preventDefault();
    openWofi();
  }

  if (e.ctrlKey && e.key === 'c' && e.altKey) {
    e.preventDefault();
    openCalculator();
  }

  if (e.ctrlKey && !e.shiftKey && e.key >= '1' && e.key <= '8') {
    e.preventDefault();
    switchDesktop(parseInt(e.key));
  }

  // Move active window to desktop (Ctrl+Shift+num)
  if (e.ctrlKey && e.shiftKey && e.key >= '1' && e.key <= '8') {
    e.preventDefault();
    moveActiveWindowToDesktop(parseInt(e.key));
  }

  // Tiling: Ctrl+arrow
  if (e.ctrlKey && !e.shiftKey && e.key === 'ArrowLeft') {
    e.preventDefault();
    tileWindow(getActiveWindow(), 'left');
  }
  if (e.ctrlKey && !e.shiftKey && e.key === 'ArrowRight') {
    e.preventDefault();
    tileWindow(getActiveWindow(), 'right');
  }
  if (e.ctrlKey && !e.shiftKey && e.key === 'ArrowUp') {
    e.preventDefault();
    tileWindow(getActiveWindow(), 'max');
  }
  if (e.ctrlKey && !e.shiftKey && e.key === 'ArrowDown') {
    e.preventDefault();
    const win = getActiveWindow();
    if (win && win.dataset.fwscreen === '1') restoreWindow(win);
  }

  if (e.key === 'Escape') {
    closeWofi();
    if (document.querySelector('#calculator-window:not(.hidden)')) {
      closeCalculator();
    }
  }
});

function getActiveWindow() {
  const wins = desktopWindows(currentDesktop).filter(w => !w.classList.contains('hidden'));
  if (!wins.length) return null;
  const f = document.querySelector('.app-window.focused');
  return (f && wins.includes(f)) ? f : wins[wins.length - 1];
}

// ═══════════════ MOUSE WHEEL DESKTOP ═══════════════

document.addEventListener('wheel', (e) => {
  // Only if no app windows are focused
  if (e.target.closest('.app-window')) return;
  if (e.target.closest('#wofi-overlay')) return;
  if (e.target.closest('#waybar')) return;

  if (e.deltaY > 0) {
    switchDesktop(Math.min(8, currentDesktop + 1));
  } else {
    switchDesktop(Math.max(1, currentDesktop - 1));
  }
}, { passive: true });

// ═══════════════ EXPORT ECLIPSE WALLPAPERS (Hyprland + swww) ═══════════════

const EX_W = 1920, EX_H = 1080;
const EX_CX = 960, EX_CY = 475;
const EX_SUN_R = 160, EX_MOON_R = 157;
const EX_OFF = [0, -339, -319, -207, -107, 0, 107, 207, 274, 320];

const EX_PHASES = {
  1: { bg: [[0, '#10151c'], [60, '#05070c']],                       sun: 1,    halo: 0.85, glow: 0.2,  pen: 0.5,  bead: 0,    dust: 0,    horizon: 0 },
  2: { bg: [[0, '#0d1218'], [65, '#04060a']],                       sun: 0.95, halo: 0.85, glow: 0.35, pen: 0.9,  bead: 0.25, dust: 0,    horizon: 0 },
  3: { bg: [[0, '#0e1018'], [60, '#06070d']],                       sun: 0.88, halo: 0.65, glow: 0.6,  pen: 1,    bead: 0.7,  dust: 0.35, horizon: 0.35 },
  4: { bg: [[0, '#14110f'], [22, '#1a0c0e'], [62, '#050307']],      sun: 0.95, halo: 0.5,  glow: 0.85, pen: 0.25, bead: 0.95, dust: 0.9,  horizon: 'blood', blood: 1 },
  5: { bg: [[0, '#0b1019'], [62, '#050812']],                       sun: 0.95, halo: 0.5,  glow: 0.6,  pen: 1,    bead: 0.7,  dust: 0.35, horizon: 0.35 },
  6: { bg: [[0, '#0e1018'], [60, '#06070d']],                       sun: 0.88, halo: 0.65, glow: 0.35, pen: 0.9,  bead: 0.25, dust: 0,    horizon: 0 },
  7: { bg: [[0, '#0d1218'], [65, '#04060a']],                       sun: 0.95, halo: 0.85, glow: 0.2,  pen: 0.5,  bead: 0,    dust: 0,    horizon: 0 },
  8: { bg: [[0, '#10151c'], [60, '#05070c']],                       sun: 1,    halo: 0.85, glow: 0.2,  pen: 0,    bead: 0,    dust: 0,    horizon: 0 },
};

function makeStarRng(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

// Deterministic star field — idem on every phase, smooth swww crossfades
const EXPORT_STARS = (() => {
  const rnd = makeStarRng(42);
  let out = '';
  for (let i = 0; i < 170; i++) {
    const x = rnd() * EX_W, y = rnd() * EX_H;
    const r = rnd() < 0.06 ? 1.9 : (rnd() < 0.5 ? 1.1 : 0.7);
    const o = 0.3 + rnd() * 0.7;
    out += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r}" fill="#ffffff" opacity="${o.toFixed(2)}"/>`;
  }
  return out;
})();

function exportPhaseSVG(n) {
  const P = EX_PHASES[n];
  const mx = EX_CX + EX_OFF[n];
  const ring = (n === 4 ? 0.5 : (n === 3 || n === 5 ? 0.2 : 0));
  const bgStops = P.bg.map(([o, c]) => `<stop offset="${o}%" stop-color="${c}"/>`).join('');
  const dustEl = P.dust ? [
    [320, 260, 460], [1480, 220, 380], [1240, 780, 520], [420, 760, 420], [960, 520, 400],
  ].map(([dx, dy, dr]) =>
    `<ellipse cx="${dx}" cy="${dy}" rx="${dr}" ry="${dr * 0.62}" fill="#dfe9ff" opacity="0.05" filter="url(#blurDust)"/>`
  ).join('') : '';
  const horizonEl = P.horizon === 'blood'
    ? `<ellipse cx="${EX_CX}" cy="1210" rx="1180" ry="290" fill="#8f1e2c" opacity="0.34" filter="url(#blurHorizon)"/>` +
      `<ellipse cx="${EX_CX}" cy="1160" rx="980" ry="170" fill="#c8324a" opacity="0.22" filter="url(#blurHorizon)"/>` +
      `<ellipse cx="${EX_CX}" cy="1092" rx="900" ry="7" fill="#ff6a78" opacity="0.28" filter="url(#blurHorizon)"/>`
    : P.horizon
      ? `<ellipse cx="${EX_CX}" cy="1150" rx="1500" ry="360" fill="#dfe9ff" opacity="${(P.horizon * 0.35).toFixed(2)}" filter="url(#blurHorizon)"/>`
      : '';
  const redGlow = P.blood
    ? `<circle cx="${mx}" cy="${EX_CY}" r="215" fill="url(#redGlow)" opacity="0.34"/>`
    : '';
  const moonFill = P.blood ? 'url(#blood)' : '#000000';

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${EX_W}" height="${EX_H}" viewBox="0 0 ${EX_W} ${EX_H}">
<defs>
  <radialGradient id="bg" cx="50%" cy="46%" r="78%">${bgStops}</radialGradient>
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
    <stop offset="0%" stop-color="#ffffff" stop-opacity="0"/><stop offset="45%" stop-color="#ffffff" stop-opacity="${n === 4 ? 0.14 : 0.05}"/>
    <stop offset="72%" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="redGlow" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#a01c2e" stop-opacity="0"/><stop offset="55%" stop-color="#a01c2e" stop-opacity="0.26"/>
    <stop offset="100%" stop-color="#a01c2e" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="blood" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#3b1018"/><stop offset="55%" stop-color="#20060f"/>
    <stop offset="85%" stop-color="#0c0108"/><stop offset="100%" stop-color="#000000"/>
  </radialGradient>
  <radialGradient id="vig" cx="50%" cy="50%" r="72%">
    <stop offset="55%" stop-color="#000000" stop-opacity="0"/><stop offset="100%" stop-color="#000000" stop-opacity="0.42"/>
  </radialGradient>
  <filter id="blurDust" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="70"/></filter>
  <filter id="blurHorizon" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="46"/></filter>
  <filter id="beadGlow"><feGaussianBlur stdDeviation="1.6"/></filter>
</defs>
  <rect width="${EX_W}" height="${EX_H}" fill="url(#bg)"/>
  ${EXPORT_STARS}
  <g opacity="${P.dust}">${dustEl}</g>
  ${horizonEl}
  <circle cx="${EX_CX}" cy="${EX_CY}" r="205" fill="url(#halo)" opacity="${P.halo}"/>
  <circle cx="${EX_CX}" cy="${EX_CY}" r="${EX_SUN_R}" fill="url(#sun)" opacity="${P.sun}"/>
  <circle cx="${mx}" cy="${EX_CY}" r="228" fill="url(#moonGlow)" opacity="${P.glow}"/>
  <circle cx="${mx}" cy="${EX_CY}" r="192" fill="url(#pen)" opacity="${P.pen}"/>
  ${redGlow}
  <circle cx="${mx}" cy="${EX_CY}" r="${EX_MOON_R}" fill="${moonFill}"/>
  <circle cx="${mx}" cy="${EX_CY}" r="228" fill="url(#coronaBig)"/>
  <circle cx="${mx}" cy="${EX_CY}" r="161" fill="url(#ring)" opacity="${ring}"/>
  <circle cx="${mx}" cy="${EX_CY}" r="158.5" fill="none" stroke="#ffffff" stroke-width="2.6"
          stroke-dasharray="2.2 8.5" opacity="${P.bead}" filter="url(#beadGlow)"/>
  <rect width="${EX_W}" height="${EX_H}" fill="url(#vig)"/>
</svg>`;
}

function downloadBlob(name, blob) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 8000);
}

function downloadHyprlandScript() {
  const script = `#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  Hyperland "Lunar Eclipse" — обои по фазам на каждом столе
#  Нужно: swww, socat
#
#  Установка:
#    1. Кидай 8 картинок в  ~/Pictures/EclipseWalls/  (eclipse_01..08.jpg)
#    2. mkdir -p ~/.local/bin
#    3. Сохрани этот файл как ~/.local/bin/eclipse-walls.sh && chmod +x
#    4. В hyprland.conf добавь:
#         exec-once = swww-daemon
#         exec-once = ~/.local/bin/eclipse-walls.sh
# ════════════════════════════════════════════════════════════

WALLDIR="\${1:-$HOME/Pictures/EclipseWalls}"
SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Поднимаем демон, если ещё не запущен
pgrep -x swww-daemon >/dev/null || { swww-daemon; sleep 1; }

set_wallpaper() {
  local ws="$1"
  local file="$WALLDIR/eclipse_\$(printf '%02d' "\$ws").jpg"
  [[ -f "\$file" ]] && swww img "\$file" \\
    --transition-type=wipe \\
    --transition-duration=0.7 \\
    --transition-bezier=0.4,0,0.2,1 \\
    --transition-fps=60
}

# Сразу ставим обои активного стола
cur="\$(hyprctl activeworkspace -j | sed -n 's/.*"id":\\(-\\?[0-9][0-9]*\\).*/\\1/p' | head -n1)"
[[ -n "\$cur" ]] && set_wallpaper "\$cur"

# ...и меняем при каждом переключении стола
while IFS= read -r line; do
  [[ "\$line" == workspace\\>\\>* ]] || continue
  ws="\${line#workspace\\>\\>}"
  set_wallpaper "\$ws"
done < <(socat -U - UNIX-CONNECT:"$SOCK")
`;
  downloadBlob('wallpaper-switch.sh', new Blob([script], { type: 'text/plain' }));
  showNotification('Hyprland', 'wallpaper-switch.sh — перемести в ~/.local/bin/ и readme в начале файла', { icon: '▾' });
}

function exportEclipsePhases() {
  showNotification('Экспорт обоев', 'Качаются 8 фаз eclipse_01..08.jpg — разреши множественные загрузки браузером', { icon: '⬇' });
  let i = 1;
  (function next() {
    if (i > 8) {
      showNotification('Экспорт готов', 'Фазы сохранены. Кидай их в ~/Pictures/EclipseWalls/');
      return;
    }
    const n = i++;
    const img = new Image();
    img.onload = () => {
      const c = document.createElement('canvas');
      c.width = EX_W; c.height = EX_H;
      c.getContext('2d').drawImage(img, 0, 0);
      c.toBlob((b) => {
        if (b) downloadBlob(`eclipse_${String(n).padStart(2, '0')}.jpg`, b);
        setTimeout(next, 250);
      }, 'image/jpeg', 0.96);
    };
    img.onerror = next;
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(exportPhaseSVG(n));
  })();
}

// ═══════════════ CONTEXT MENU ═══════════════

document.addEventListener('contextmenu', (e) => {
  e.preventDefault();
  if (e.target.closest('.app-window')) return;

  // Remove existing menu
  document.querySelectorAll('.context-menu').forEach(m => m.remove());

  const menu = document.createElement('div');
  menu.className = 'context-menu';
  menu.style.cssText = `
    position: fixed; left: ${e.clientX}px; top: ${e.clientY}px;
    background: rgba(10, 10, 10, 0.95); backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 10px;
    padding: 6px; z-index: 1000; min-width: 180px;
    box-shadow: 0 10px 40px rgba(0,0,0,0.5);
    animation: wofiOpen 0.15s ease;
  `;

  const items = [
    { label: '▸ Открыть терминал', action: () => openApp('terminal') },
    { label: '▸ Файлы', action: () => openApp('files') },
    { label: '▸ Браузер', action: () => openApp('browser') },
    { label: null },
    { label: '▸ Поиск (Wofi)', action: () => openWofi() },
    { label: null },
    { label: '▸ Сменить обои', action: () => showNotification('Обои', 'Здесь можно сменить обои рабочего стола') },
    { label: null },
    { label: '▾ Экспорт обоев (8 фаз)', action: exportEclipsePhases },
    { label: '▾ Скачать wallpaper-switch.sh', action: downloadHyprlandScript },
    { label: '▸ Настройки', action: () => showNotification('Настройки', 'Hyprland конфигурация: ~/.config/hypr/hyprland.conf') },
    { label: null },
    { label: '⬇ Тестовая загрузка', action: simulateDownload },
  ];

  items.forEach(item => {
    if (item.label === null) {
      const sep = document.createElement('div');
      sep.style.cssText = 'height:1px;background:rgba(255,255,255,0.1);margin:4px 8px;';
      menu.appendChild(sep);
      return;
    }
    const el = document.createElement('div');
    el.style.cssText = `
      padding: 8px 14px; border-radius: 6px; cursor: pointer;
      font-size: 13px; color: #e6e6e6; transition: background 0.15s;
    `;
    el.textContent = item.label;
    el.addEventListener('mouseenter', () => el.style.background = 'rgba(255,255,255,0.08)');
    el.addEventListener('mouseleave', () => el.style.background = 'transparent');
    el.addEventListener('click', () => { menu.remove(); item.action(); });
    menu.appendChild(el);
  });

  document.body.appendChild(menu);

  const closeMenu = (ev) => {
    if (!menu.contains(ev.target)) {
      menu.remove();
      document.removeEventListener('click', closeMenu);
    }
  };
  setTimeout(() => document.addEventListener('click', closeMenu), 10);
});

// ═══════════════ START ═══════════════

bootSequence();
