#!/bin/bash
# Usage:
# Go to the folder that you want to develop in
# >pyact 3.12
# This switches the version and activates the venv in the directory
# ./venv-python3.12
# Afterwards pip can be used to install packages
# to deactivate:
# > pydeact
#
# Copy to your .bashrc or .bash_functions and install pyenv.
# This is a poor man's conda, but so much less annoying.
# Hope its useful.

function pyact() {
  eval "$(pyenv init -)"
  pyenv shell "$1"
  if [ "$(pyenv shell)" != "$1" ]; then
    echo Install "$1"!
    echo pyenv install "$1"
  fi
  if [ -d "venv-python$1" ]; then
    # shellcheck disable=SC1090
    . "./venv-python$1/bin/activate"
  else
    version=$(cut -d "." -f -2 <<< "$1")
    "python$version" -m venv "venv-python$1"
    # shellcheck disable=SC1090
    . "./venv-python$1/bin/activate"
  fi
}

function pydeact() {
  deactivate
  pyenv shell system
}
