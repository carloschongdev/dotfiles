[ -f ~/.aliases ] && source ~/.aliases
[ -f ~/.exports ] && source ~/.exports
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"

eval "$(starship init zsh)"
fastfetch

# -----------------------------------------------
# gh auto-switch por carpeta
# -----------------------------------------------

function chpwd() {
  case "$PWD" in
    $HOME/Projects/Intechideas-International | $HOME/Projects/Intechideas-International/*)
      gh auth switch --user CarlosChong28 2>/dev/null
      echo "→ gh: intech (CarlosChong28)"
      ;;
    *)
      gh auth switch --user carloschongdev 2>/dev/null
      echo "→ gh: personal (carloschongdev)"
      ;;
  esac
}

# Ejecutar al abrir terminal para detectar carpeta actual
chpwd
