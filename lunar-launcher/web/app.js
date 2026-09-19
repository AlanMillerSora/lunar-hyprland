/* ═══ Lunar Launcher — логика ═══ */
"use strict";

const API = "/api/state";
const ACT = "/api/action";

const APPS = [
  { id: "terminal",  icon: "\uF489", label: "Терминал" },
  { id: "files",     icon: "\uF07C", label: "Dolphin" },
  { id: "browser",   icon: "\uF269", label: "Firefox" },
  { id: "chromium",  icon: "\uF113", label: "Chromium" },
  { id: "btop",      icon: "\uF4BC", label: "btop" },
  { id: "mpv",       icon: "\uF001", label: "mpv" },
  { id: "audio",     icon: "\uF028", label: "Звук" },
  { id: "bluetooth", icon: "\uF293", label: "Bluetooth" },
  { id: "network",   icon: "\uF1EB", label: "Сети" },
  { id: "thunar",    icon: "\uF07B", label: "Thunar" },
  { id: "vim",       icon: "\uF120", label: "Vim" },
];

const $ = (id) => document.getElementById(id);

function setFill(slider) {
  const pct = ((slider.value - slider.min) / (slider.max - slider.min)) * 100;
  slider.style.setProperty("--fill", pct + "%");
}

/* ── API ─────────────────────────────────────────────── */
async function post(payload) {
  try {
    const r = await fetch(ACT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    return await r.json();
  } catch (e) {
    return { ok: false };
  }
}

async function loadState() {
  try {
    const r = await fetch(API, { cache: "no-store" });
    const s = await r.json();

    const vol = $("vol"), brt = $("brt"), opc = $("opc");
    vol.value = s.volume; setFill(vol);
    $("vol-val").textContent = (s.muted ? "🔇 " : "") + s.volume + "%";

    if (s.ok) { brt.disabled = false; brt.value = s.brightness; setFill(brt); }
    else { brt.disabled = true; brt.value = 0; $("brt-val").textContent = "—"; }
    $("brt-val").textContent = s.ok ? s.brightness + "%" : "нет доступа";

    opc.value = s.opacity; setFill(opc);
    $("opc-val").textContent = s.opacity + "%";

    const w = $("wifi");
    w.classList.toggle("active", s.wifi);
    $("wifi-lbl").textContent = s.wifi ? (s.ssid || "Wi-Fi") : "off";
  } catch (e) { /* сервер ещё встаёт — повторим */ }
}

/* ── Сетка приложений ────────────────────────────────── */
const appsEl = $("apps");
APPS.forEach((a) => {
  const b = document.createElement("button");
  b.className = "app";
  b.innerHTML = `<span class="icon">${a.icon}</span><span class="label">${a.label}</span>`;
  b.onclick = () => post({ cmd: "app", id: a.id });
  appsEl.appendChild(b);
});

/* ── События ─────────────────────────────────────────── */
let volTimer, brtTimer, opcTimer;

$("vol").addEventListener("input", (e) => {
  setFill(e.target);
  $("vol-val").textContent = e.target.value + "%";
  clearTimeout(volTimer);
  volTimer = setTimeout(() => post({ cmd: "volume", value: +e.target.value }), 120);
});

$("brt").addEventListener("input", (e) => {
  setFill(e.target);
  $("brt-val").textContent = e.target.value + "%";
  clearTimeout(brtTimer);
  brtTimer = setTimeout(async () => {
    const r = await post({ cmd: "brightness", value: +e.target.value });
    if (!r.ok) { e.target.disabled = true; $("brt-val").textContent = "нет доступа"; }
  }, 150);
});

$("opc").addEventListener("input", (e) => {
  setFill(e.target);
  $("opc-val").textContent = e.target.value + "%";
  clearTimeout(opcTimer);
  opcTimer = setTimeout(() => post({ cmd: "opacity", value: +e.target.value }), 150);
});

$("close").onclick = () => post({ cmd: "close" });

$("wifi").onclick = async (e) => {
  const wasOn = e.target.classList.contains("active");
  await post({ cmd: "wifi", on: !wasOn });
  loadState();
};
$("net").onclick = () => post({ cmd: "netmenu" });
$("prev").onclick = () => post({ cmd: "media", action: "previous" });
$("play").onclick = () => post({ cmd: "media", action: "play-pause" });
$("next").onclick = () => post({ cmd: "media", action: "next" });

document.querySelectorAll("[data-power]").forEach((b) => {
  b.onclick = () => post({ cmd: "power", action: b.dataset.power });
});

/* ── Часы ────────────────────────────────────────────── */
function tick() {
  const now = new Date();
  $("time").textContent = now.toTimeString().slice(0, 5);
}
setInterval(tick, 2000);
tick();

loadState();
setInterval(loadState, 5000);