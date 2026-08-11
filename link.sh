#!/usr/bin/env sh

set -e

# "$@" goes before the package: stow's -S/-D/-R apply only to the packages
# listed after them, so trailing flags are silently ignored.
stow -t ~ "$@" . --dotfiles
