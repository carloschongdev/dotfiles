#!/bin/zsh

git_email() {
  local email=$(git config user.email 2>/dev/null)

  if [ -z "$email" ]; then
    email=$(git config --global user.email 2>/dev/null)
  fi

  if [[ "$email" == *"intechideas"* ]]; then
    echo "WORK"
  elif [ -n "$email" ]; then
    echo "PERSONAL"
  else
    echo "-"
  fi
}