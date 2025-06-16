#!/usr/bin/env sh

set -e

stow -t ~ . --dotfiles "$@"
