#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-api-limit.sh — расход лимитов OpenCode Go для панели api-limit.
#    Источник истины — официальный эндпоинт OpenCode Go:
#       GET https://opencode.ai/zen/go/v1/usage   (Authorization: Bearer)
#    Он отдаёт проценты по окнам rolling(5ч)/weekly/monthly и время сброса.
#    Ключ беру из локальной БД OpenCode (credential, integration_id
#    opencode-go) — в репозиторий и логи он не попадает.
#    Доллары оцениваю как percent/100 × лимит окна (месяц = лимит ведущей
#    модели; 5ч = 20%, неделя = 50%). Если API недоступен — считаю сам
#    по session_message (per-message cost + время).
#    Разбивку по моделям беру из session_message (API её не отдаёт).
#    Секретов в файле нет: только локальная БД и публичный эндпоинт.
# ════════════════════════════════════════════════════════════════
set -u

DB="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db"
if [ ! -r "$DB" ]; then
    echo "err=nodb"
    exit 0
fi

sql() { sqlite3 -readonly -cmd ".timeout 1500" "$DB" "$1" 2>/dev/null; }

now_ms=$(( $(date +%s) * 1000 ))
h5_from=$(( now_ms - 5 * 3600 * 1000 ))
wk_from=$(( now_ms - 7 * 86400 * 1000 ))
mo_from=$(( now_ms - 30 * 86400 * 1000 ))

# Месячный лимит модели в долларах (0 = без лимита, «unlimited»).
# Таблица Go с https://opencode.ai/docs/go; не покрытые id → $60.
model_limit() {
    case "$1" in
        deepseek-v4-flash|qwen3.8-flash|hy4-preview)
            echo 30 ;;
        glm-5.3|kimi-k3|mimo-v2.6-pro|mimo-v2.5-pro|qwen3.8-max|deepseek-v4-pro|deepseek-v4-flash-vision-exp|grok-4.7|grok-4.6|gpt-6-luna|gpt-5.6-luna)
            echo 15 ;;
        longcat-2.5-preview-free|space-bunny-free)
            echo 0 ;;
        *)
            echo 60 ;;
    esac
}

# ведущая модель (по сумме cost) — по ней беру месячный лимит
lead=$(sql "SELECT json_extract(data,'\$.model.id')
FROM session_message
WHERE json_extract(data,'\$.cost') > 0
  AND json_extract(data,'\$.model.providerID') = 'opencode-go'
GROUP BY json_extract(data,'\$.model.id')
ORDER BY sum(json_extract(data,'\$.cost')) DESC LIMIT 1;")
molim=$(model_limit "${lead:-}")

# ── официальный источник: проценты окон ──
source="local"
h5pct="" ; wkpct="" ; mopct=""
key=$(sql "SELECT json_extract(value,'\$.key') FROM credential
           WHERE integration_id='opencode-go' LIMIT 1;")
if [ -n "${key:-}" ]; then
    usage=$(curl -s --max-time 8 -H "Authorization: Bearer $key" \
        https://opencode.ai/zen/go/v1/usage 2>/dev/null)
    hp=$(printf '%s' "$usage" | jq -r '.usage.rolling.percent // empty' 2>/dev/null)
    wp=$(printf '%s' "$usage" | jq -r '.usage.weekly.percent // empty' 2>/dev/null)
    mp=$(printf '%s' "$usage" | jq -r '.usage.monthly.percent // empty' 2>/dev/null)
    if [ -n "$hp" ] && [ -n "$wp" ] && [ -n "$mp" ]; then
        source="api" ; h5pct=$hp ; wkpct=$wp ; mopct=$mp
    fi
fi

if [ "$source" = "api" ]; then
    # проценты официальные; доллары — оценка от лимита окна
    h5=$(awk -v p="$h5pct" -v l="$molim" 'BEGIN{printf "%.4f", p/100*l*0.2}')
    wk=$(awk -v p="$wkpct" -v l="$molim" 'BEGIN{printf "%.4f", p/100*l*0.5}')
    mo=$(awk -v p="$mopct" -v l="$molim" 'BEGIN{printf "%.4f", p/100*l}')
else
    # фолбэк: считаю по session_message (точное время каждого ответа)
    read -r h5 wk mo <<EOF
$(sql "SELECT
  round(coalesce(sum(CASE WHEN time_created >= $h5_from THEN json_extract(data,'\$.cost') END),0),4) || ' ' ||
  round(coalesce(sum(CASE WHEN time_created >= $wk_from THEN json_extract(data,'\$.cost') END),0),4) || ' ' ||
  round(coalesce(sum(CASE WHEN time_created >= $mo_from THEN json_extract(data,'\$.cost') END),0),4)
FROM session_message
WHERE json_extract(data,'\$.cost') > 0
  AND json_extract(data,'\$.model.providerID') = 'opencode-go';")
EOF
fi

printf 'ok=1\n'
printf 'source=%s\n' "$source"
printf 'lead=%s\n' "${lead:-}"
printf 'h5=%s\n' "${h5:-0}"
printf 'wk=%s\n' "${wk:-0}"
printf 'mo=%s\n' "${mo:-0}"
printf 'molim=%s\n' "$molim"

# разбивка по моделям за месяц: M id usd lim tin tout cache
sql "SELECT json_extract(data,'\$.model.id') || '|' ||
       round(sum(json_extract(data,'\$.cost')),4) || '|' ||
       coalesce(sum(json_extract(data,'\$.tokens.input')),0) || '|' ||
       coalesce(sum(json_extract(data,'\$.tokens.output')),0) || '|' ||
       coalesce(sum(json_extract(data,'\$.tokens.cache.read')),0)
FROM session_message
WHERE json_extract(data,'\$.cost') > 0
  AND json_extract(data,'\$.model.providerID') = 'opencode-go'
  AND time_created >= $mo_from
GROUP BY json_extract(data,'\$.model.id')
ORDER BY sum(json_extract(data,'\$.cost')) DESC
LIMIT 6;" | while IFS='|' read -r id usd tin tout cache; do
    [ -n "$id" ] || continue
    printf 'M %s %s %s %s %s %s\n' "$id" "$usd" "$(model_limit "$id")" "$tin" "$tout" "$cache"
done
