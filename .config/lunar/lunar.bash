# ════════════════════════════════════════════════════════════
#  Lunar Eclipse — интерактивная оболочка.
#  Подключается из ~/.bashrc строкой:
#    [ -f ~/.config/lunar/lunar.bash ] && . ~/.config/lunar/lunar.bash
# ════════════════════════════════════════════════════════════

# Приветствие: fastfetch с логотипом-затмением (только в kitty, интерактивно)
if [ -n "${KITTY_WINDOW_ID:-}" ] && [ -t 1 ] && command -v fastfetch >/dev/null 2>&1; then
    # Картинка-затмение (chafa, kitty-графика) + шапка и инфо fastfetch справа.
    if command -v chafa >/dev/null 2>&1 && [ -f "$HOME/.config/fastfetch/eclipse-logo.png" ]; then
        chafa --size 20x16 "$HOME/.config/fastfetch/eclipse-logo.png"
        printf '\033[16A'
        { printf '  L U N A R   E C L I P S E\n\n'; fastfetch --logo none; } | sed 's/^/                       /'
    else
        fastfetch --logo none
    fi
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
