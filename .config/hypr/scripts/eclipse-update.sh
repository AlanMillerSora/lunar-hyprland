#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-update.sh — обновление системы с буфером и бэкапом.
#
#  Идея: Arch — rolling, свежее обновление иногда ломает. Скрипт:
#    1) ждёт 1–2 дня после выхода свежих новостей Arch (буфер);
#    2) проверяет новости через informant (блокирует, пока не прочитаны);
#    3) переводит свежие новости на русский (translate-shell / Google);
#    4) делает бэкап конфигов (eclipse-backup.sh);
#    5) обновляет систему (pacman -Syu + AUR через paru/yay).
#
#  Запуск:  eclipse-update.sh [--now] [--check] [--news] [--no-backup]
#    без флага      — с буфером (ждём, если новости свежие)
#    --now          — обновить сразу, игнорируя буфер
#    --check        — только показать, что ждёт обновления (не обновлять)
#    --news         — показать свежие новости (переведённые) и выйти
#    --no-backup    — без бэкапа конфигов
# ════════════════════════════════════════════════════════════════
set -uo pipefail

BUFFER_DAYS=2
RSS_URL="https://archlinux.org/feeds/news/"
CACHE="$HOME/.cache/lunar-news"
mkdir -p "$CACHE"

MODE="update"      # update | check | news
NOW=0
DO_BACKUP=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --now) NOW=1; shift ;;
    --check) MODE="check"; shift ;;
    --news) MODE="news"; shift ;;
    --no-backup) DO_BACKUP=0; shift ;;
    *) echo "usage: $0 [--now|--check|--news] [--no-backup]" >&2; exit 1 ;;
  esac
done

say() { printf '\033[38;5;15m==>\033[0m %s\n' "$*"; }

# ── перевод через translate-shell (Google), с кэшем ─────────────
translate() {
  local text="$1"
  local key; key="$(printf '%s' "$text" | md5sum | cut -d' ' -f1)"
  local cache="$CACHE/$key.ru"
  if [[ -f "$cache" ]]; then cat "$cache"; return; fi
  if command -v trans >/dev/null 2>&1; then
    local out
    out="$(printf '%s' "$text" | trans -b -no-ansi :ru 2>/dev/null)"
    [[ -n "$out" ]] && { printf '%s' "$out" > "$cache"; echo "$out"; return; }
  fi
  echo "$text"   # перевод недоступен — отдаём оригинал
}

# ── свежие новости из RSS (заголовок + дата) ────────────────────
news_items() {
  curl -s --max-time 20 "$RSS_URL" 2>/dev/null | python3 -c '
import sys, re, html
from email.utils import parsedate_to_datetime
data = sys.stdin.read()
items = re.findall(r"<item>(.*?)</item>", data, re.S)
for it in items:
    t = re.search(r"<title>(.*?)</title>", it, re.S)
    d = re.search(r"<pubDate>(.*?)</pubDate>", it, re.S)
    if not t: continue
    title = html.unescape(re.sub(r"<.*?>", "", t.group(1))).strip()
    date = ""
    if d:
        try:
            dt = parsedate_to_datetime(d.group(1).strip())
            date = dt.strftime("%Y-%m-%d")
        except Exception:
            date = d.group(1).strip()
    print(f"{date}\t{title}")
' 2>/dev/null
}

# ── самая свежая новость и её возраст в днях ────────────────────
newest_age_days() {
  news_items | head -1 | cut -f1 | python3 -c '
import sys, datetime
s = sys.stdin.read().strip()
if not s:
    print(999); sys.exit()
try:
    d = datetime.date.fromisoformat(s)
    print((datetime.date.today() - d).days)
except Exception:
    print(999)
'
}

# ── показать новости (переведённые) ────────────────────────────
show_news() {
  local limit="${1:-5}"
  say "Свежие новости Arch (перевод → оригинал):"
  local i=0
  while IFS=$'\t' read -r date title; do
    [[ -n "$title" ]] || continue
    i=$((i+1)); [[ $i -gt $limit ]] && break
    echo
    echo "── $date ──"
    echo "RU: $(translate "$title")"
    echo "EN: $title"
  done < <(news_items)
  echo
}

# ── проверка непрочитанных новостей через informant ─────────────
informant_pending() {
  command -v informant >/dev/null 2>&1 || { echo 0; return; }
  informant check >/dev/null 2>&1
  echo $?   # >0 — есть непрочитанные
}

# ── основной поток ──────────────────────────────────────────────
syu_available() {
  if command -v checkupdates >/dev/null 2>&1; then
    checkupdates 2>/dev/null | wc -l
  else
    pacman -Qu 2>/dev/null | wc -l
  fi
}

if [[ "$MODE" == "news" ]]; then
  show_news 5
  exit 0
fi

AGE="$(newest_age_days)"

if [[ "$MODE" == "check" ]]; then
  say "самая свежая новость Arch: ${AGE} дн. назад (буфер: ${BUFFER_DAYS} дн.)"
  [[ "$AGE" -lt "$BUFFER_DAYS" ]] && echo "→ рано обновляться (буфер)"
  N="$(syu_available)"; echo "→ пакетов к обновлению: ${N:-?}"
  echo "→ непрочитанных новостей: $(informant_pending)"
  exit 0
fi

# буфер
if [[ "$NOW" != 1 && "$AGE" -lt "$BUFFER_DAYS" ]]; then
  say "Свежая новость вышла ${AGE} дн. назад — ждём буфер ${BUFFER_DAYS} дн."
  say "Обновить сейчас принудительно: eclipse-update.sh --now"
  show_news 3
  exit 2
fi

# новости: если informant есть — показываем и отмечаем прочитанными
if [[ "$(informant_pending)" -gt 0 ]]; then
  say "Есть непрочитанные новости Arch — читаем (с переводом):"
  informant list --unread 2>/dev/null | head -10
  echo
  show_news 3
  if command -v informant >/dev/null 2>&1; then
    informant read --all >/dev/null 2>&1 || true
    say "новости отмечены прочитанными"
  fi
fi

# бэкап
if [[ "$DO_BACKUP" == 1 && -x "$HOME/.config/hypr/scripts/eclipse-backup.sh" ]]; then
  say "бэкап конфигов перед обновлением"
  "$HOME/.config/hypr/scripts/eclipse-backup.sh" --quiet || say "бэкап не удался (продолжаю)"
fi

# снимок timeshift (если установлен) — системный откат
if command -v timeshift >/dev/null 2>&1; then
  say "снимок timeshift перед обновлением"
  sudo timeshift --create --comments "lunar before update $(date +%F\ %T)" --scripted \
    || say "timeshift-снимок не создался (продолжаю)"
else
  say "timeshift не установлен — системный снимок пропущен"
fi

# обновление
say "обновляю систему (pacman -Syu)"
sudo pacman -Syu --noconfirm || { say "pacman завершился с ошибкой"; exit 1; }

# AUR
if command -v paru >/dev/null 2>&1; then
  say "обновляю AUR (paru)"
  paru -Sua --noconfirm || say "AUR: есть проблемы"
elif command -v yay >/dev/null 2>&1; then
  say "обновляю AUR (yay)"
  yay -Sua --noconfirm || say "AUR: есть проблемы"
fi

say "обновление завершено"
notify-send -a "Lunar" "Обновление системы" "Готово" 2>/dev/null || true
