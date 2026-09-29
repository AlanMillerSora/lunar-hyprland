#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-api-limit.sh — расход лимитов OpenCode Go для панели api-limit.
#    Читает локальную БД OpenCode (readonly), считает доллары за
#    5 часов / неделю / 30 дней по провайдеру opencode-go и отдаёт
#    строки key=value + по строке на модель.
#    Лимиты — долларовые, на модель (источник: opencode.ai/docs/go):
#      5ч = 20% месячного, неделя = 50%, месяц = 100%.
#    Секретов не содержит: только локальная БД и публичная таблица лимитов.
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

read -r h5 wk mo <<EOF
$(sql "SELECT
  round(coalesce(sum(CASE WHEN time_updated >= $h5_from THEN cost END),0),4) || ' ' ||
  round(coalesce(sum(CASE WHEN time_updated >= $wk_from THEN cost END),0),4) || ' ' ||
  round(coalesce(sum(CASE WHEN time_updated >= $mo_from THEN cost END),0),4)
FROM session_v2
WHERE cost > 0 AND json_extract(model,'\$.providerID') = 'opencode-go';")
EOF

# ведущая модель месяца — по ней считаем лимиты (5ч/неделя/месяц)
lead=$(sql "SELECT json_extract(model,'\$.id')
FROM session_v2
WHERE cost > 0 AND json_extract(model,'\$.providerID') = 'opencode-go'
  AND time_updated >= $mo_from
GROUP BY json_extract(model,'\$.id')
ORDER BY sum(cost) DESC LIMIT 1;")

molim=$(model_limit "${lead:-}")

printf 'ok=1\n'
printf 'lead=%s\n' "${lead:-}"
printf 'h5=%s\n' "${h5:-0}"
printf 'wk=%s\n' "${wk:-0}"
printf 'mo=%s\n' "${mo:-0}"
printf 'molim=%s\n' "$molim"

# разбивка по моделям за месяц: M id usd lim tin tout cache
sql "SELECT json_extract(model,'\$.id') || '|' ||
       round(sum(cost),4) || '|' ||
       coalesce(sum(tokens_input),0) || '|' ||
       coalesce(sum(tokens_output),0) || '|' ||
       coalesce(sum(tokens_cache_read),0)
FROM session_v2
WHERE cost > 0 AND json_extract(model,'\$.providerID') = 'opencode-go'
  AND time_updated >= $mo_from
GROUP BY json_extract(model,'\$.id')
ORDER BY sum(cost) DESC
LIMIT 6;" | while IFS='|' read -r id usd tin tout cache; do
    [ -n "$id" ] || continue
    printf 'M %s %s %s %s %s %s\n' "$id" "$usd" "$(model_limit "$id")" "$tin" "$tout" "$cache"
done
