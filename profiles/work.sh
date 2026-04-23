#!/usr/bin/env bash
# Work profile — loaded when DOTFILES_PROFILE=work
# Git identity for this profile is controlled via git/.gitconfig-work
# (loaded automatically via includeIf for ~/work/ and ~/Projects/intechideas/)

PROFILE_NAME="work"
PROFILE_GIT_EMAIL="carlos.chong@intechideas.com"

# Work-specific tools to highlight during setup (already in Brewfile, annotated [work])
PROFILE_NOTES=(
  "kubernetes-cli and k9s for cluster management"
  "linear for project management"
  "docker-desktop for containerization"
  "mole for SSH tunneling"
)
