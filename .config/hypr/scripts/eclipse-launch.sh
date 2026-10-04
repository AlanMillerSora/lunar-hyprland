#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  eclipse-launch.sh <app> — запуск приложения из белого списка.
#
#  Нужен агенту: он предлагает `eclipse-launch.sh firefox`, а не
#  произвольный exec. Так «запуск приложений» остаётся безопасным
#  (никакой произвольной команды), а процесс отвязывается от шелла.
# ════════════════════════════════════════════════════════════════
set -u

app="${1:-}"
case "$app" in
  firefox)  cmd="firefox" ;;
  kitty)    cmd="kitty" ;;
  thunar)   cmd="thunar" ;;
  telegram) cmd="telegram-desktop" ;;
  discord)  cmd="discord" ;;
  vesktop)  cmd="vesktop" ;;
  steam)    cmd="steam" ;;
  lutris)   cmd="lutris" ;;
  code)     cmd="code" ;;
  btop)     cmd="kitty -e btop" ;;
  hub)      exec setsid qs ipc call hub toggle ;;
  *) echo "не разрешено: ${app}" >&2; exit 1 ;;
esac

# shellcheck disable=SC2086
exec setsid $cmd >/dev/null 2>&1
