# ════════════════════════════════════════════════════════════
#  Lunar Eclipse — интерактивная оболочка.
#  Подключается из ~/.bashrc строкой:
#    [ -f ~/.config/lunar/lunar.bash ] && . ~/.config/lunar/lunar.bash
# ════════════════════════════════════════════════════════════

# Приветствие: fastfetch с логотипом-затмением (только в kitty, интерактивно)
if [ -n "${KITTY_WINDOW_ID:-}" ] && [ -t 1 ] && command -v fastfetch >/dev/null 2>&1; then
    # Широкое окно — лого слева, инфо справа. Узкое — лого сверху, инфо снизу.
    _lunar_img="$HOME/.config/fastfetch/eclipse-logo.png"
    _lunar_cols=$(tput cols 2>/dev/null); [ -z "$_lunar_cols" ] && _lunar_cols=${COLUMNS:-80}
    if command -v chafa >/dev/null 2>&1 && [ -f "$_lunar_img" ] && [ "$_lunar_cols" -ge 72 ]; then
        chafa --size 24x12 "$_lunar_img"
        printf '\033[12A'
        {
            printf '\e[38;5;15m  L U N A R   E C L I P S E\e[0m\n'
            printf '\e[38;5;240m  ─────────────────────────\e[0m\n\n'
            fastfetch --logo none
            printf '\e[38;5;240m  ─────────────────────────\e[0m\n'
        } | sed 's/^/                          /'
    elif command -v chafa >/dev/null 2>&1 && [ -f "$_lunar_img" ]; then
        chafa --size 18x9 "$_lunar_img"
        printf '\n\e[38;5;15m  L U N A R   E C L I P S E\e[0m\n'
        printf '\e[38;5;240m  ─────────────────────────\e[0m\n\n'
        fastfetch --logo none
    else
        fastfetch --logo none
    fi
    unset _lunar_img _lunar_cols
fi

# Мелкие удобства
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'

# PS1 — двухстрочный, в монохромной палитре системы (белый/серый)
if [ -t 1 ]; then
    PS1='\[\e[38;5;245m\]\u\[\e[38;5;240m\]@\[\e[38;5;245m\]\h  \[\e[38;5;240m\]\w\[\e[0m\]\n\[\e[38;5;15m\]󰖔 ❯\[\e[0m\] '
fi
