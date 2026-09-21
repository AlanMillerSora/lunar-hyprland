# ════════════════════════════════════════════════════════════
#  Lunar Eclipse — zsh (монохром системы)
#  Устанавливается в ~/.zshrc
# ════════════════════════════════════════════════════════════

# ── Приветствие в kitty: картинка-затмение (chafa) + шапка и инфо ──
# Широкое окно — лого слева, инфо справа. Узкое — лого сверху, инфо снизу.
if [[ -n "$KITTY_WINDOW_ID" ]] && [[ -o interactive ]] && command -v fastfetch >/dev/null 2>&1; then
    _lunar_img="$HOME/.config/fastfetch/eclipse-logo.png"
    _lunar_cols=$(tput cols 2>/dev/null); [[ -z "$_lunar_cols" ]] && _lunar_cols=${COLUMNS:-80}
    if command -v chafa >/dev/null 2>&1 && [[ -f "$_lunar_img" ]] && (( _lunar_cols >= 72 )); then
        chafa --size 24x12 "$_lunar_img"
        printf '\033[12A'
        {
            printf '\e[38;5;15m  L U N A R   E C L I P S E\e[0m\n'
            printf '\e[38;5;240m  ─────────────────────────\e[0m\n\n'
            fastfetch --logo none
            printf '\e[38;5;240m  ─────────────────────────\e[0m\n'
        } | sed 's/^/                          /'
    elif command -v chafa >/dev/null 2>&1 && [[ -f "$_lunar_img" ]]; then
        chafa --size 18x9 "$_lunar_img"
        printf '\n\e[38;5;15m  L U N A R   E C L I P S E\e[0m\n'
        printf '\e[38;5;240m  ─────────────────────────\e[0m\n\n'
        fastfetch --logo none
    else
        fastfetch --logo none
    fi
    unset _lunar_img _lunar_cols
fi

# ── Промпт (starship) ──
eval "$(starship init zsh)"

# ── eza вместо ls (монохром) ──
export EZA_COLORS="uu=bright-black:gu=bright-black:da=bright-black:ur=white:uw=bright-black:ux=white:ue=bright-black:gr=bright-black:gw=bright-black:gx=white:tr=bright-black:fi=white:di=bright-white:ln=bright-black:pi=bright-black:so=bright-black:bd=bright-black:cd=bright-black:or=bright-black:mi=bright-black:ex=white"

alias ls='eza --icons'
alias ll='eza -lah --icons --git'
alias la='eza -a --icons'
alias lt='eza --tree --icons'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'

# ── Автодополнение ──
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors \
  '=(#b)*(=0)=38;5;250' \
  '=(#b)*(=1)=38;5;255' \
  '=(#b)*(=2)=38;5;245' \
  '=(#b)*(=3)=38;5;240'

# ── Autosuggestions (тёмно-серый) ──
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ── Syntax highlighting (монохром) ──
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_STYLES[command]='fg=white'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=white'
ZSH_HIGHLIGHT_STYLES[function]='fg=white'
ZSH_HIGHLIGHT_STYLES[alias]='fg=white'
ZSH_HIGHLIGHT_STYLES[path]='fg=245'
ZSH_HIGHLIGHT_STYLES[comment]='fg=240'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=245'
