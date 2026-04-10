[ -f ~/.aliases ] && source ~/.aliases
[ -f ~/.exports ] && source ~/.exports
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"


PROMPT='%~ $ '
eval "$(starship init zsh)"
fastfetch

