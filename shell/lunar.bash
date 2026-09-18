# ════════════════════════════════════════════════════════════
#  Lunar Eclipse — интерактивная оболочка.
#  Подключается из ~/.bashrc строкой:
#    [ -f ~/.config/lunar/lunar.bash ] && . ~/.config/lunar/lunar.bash
# ════════════════════════════════════════════════════════════

# Приветствие: fastfetch с логотипом-затмением (только в kitty, интерактивно)
if [ -n "${KITTY_WINDOW_ID:-}" ] && [ -t 1 ] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi

# Мелкие удобства
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'

# PS1 в палитре райса
if [ -t 1 ]; then
    PS1='\[\e[38;5;111m\]\u\[\e[38;5;240m\]@\[\e[38;5;111m\]\h \[\e[38;5;250m\]\w \[\e[38;5;111m\]󰖔\[\e[0m\] '
fi
