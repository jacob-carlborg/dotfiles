#!/bin/bash

set -e

source "$HOME/.rvm/scripts/rvm"

if [ -f .ruby-gemset ]; then
  rvm use "$(cat .ruby-version)"@"$(cat .ruby-gemset)" > /dev/null
else
  rvm use "$(cat .ruby-version)" > /dev/null
fi

exec "$@"
