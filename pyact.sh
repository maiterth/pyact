#!/bin/bash
# Usage:
# Go to the folder that you want to develop in
# >pyact -c 3.12
# This creates (-c) the venv with the respective python version using pyenv 
# ( and makes sure that the pyvenv is installed).
#
# >pyact 3.12
# switches the python version and activates the venv in the directory (previously installed with -c)
# Alternatively: without version this searches the highest version and activates that + the python version.
# >pyact 
# ./venv-python3.12
# Afterwards pip can be used to install packages
# to deactivate:
# > pydeact
#
# To clean up after yourself simply rm the venv-python3.X
#
# Copy to your .bashrc or .bash_functions and install pyenv.
# This is a poor man's conda, but so much less annoying.
# Hope its useful.

function pyact() {
	if [ "$(pwd)" == "$(dirname $(echo $HOME))" ] || [ "$(pwd)" == "/" ]; then
		echo "no venv-python$1 from here to HOME(exclusive)."
	else
		eval "$(pyenv init -)"
		if [ "$1" == "-c" ]; then
			pyenv shell "$2"
			version=$(cut -d "." -f -2 <<< "$2")
			"python$version" -m venv "venv-python$2"
		elif [ "$1" != "" ]; then
			echo "Trying venv-python$1 in $(pwd):"
			pyenv shell "$1"
			if [ "$(pyenv shell)" != "$1" ]; then
				echo Install "$1"!
				echo pyenv install "$1"
			fi
			if [ -d "venv-python$1" ]; then
				# shellcheck disable=SC1090
				. "./venv-python$1/bin/activate"
			else
				pushd .. > /dev/null
				pyact $@
				popd > /dev/null
				#version=$(cut -d "." -f -2 <<< "$1")
				#"python$version" -m venv "venv-python$1"
				# shellcheck disable=SC1090
				#. "./venv-python$1/bin/activate"
			fi
		else
			echo "Searching any venv-python in $(pwd)"
			venvdir=$(find . -maxdepth 1 -type d -name "venv-python*" | sort -d | head -n 1)
			if [ "$venvdir" != "" ]; then
				fullversion=$(echo ${venvdir:13})
				pyact $fullversion
			else
				pushd .. > /dev/null
				pyact
				popd > /dev/null
			fi
		fi

	fi
}

function pydeact() {
  deactivate
  pyenv shell system
}
