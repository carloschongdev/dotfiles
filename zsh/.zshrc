[ -f ~/.aliases ] && source ~/.aliases
[ -f ~/.exports ] && source ~/.exports
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"

eval "$(starship init zsh)"
fastfetch
