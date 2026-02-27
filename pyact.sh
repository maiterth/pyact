#!/usr/bin/env bash

if [ -n "${_PYACT_LIB_LOADED:-}" ]; then
  return 0
fi
_PYACT_LIB_LOADED=1

function _pyact_version_gt() {
  local version_a="$1"
  local version_b="$2"
  local IFS=.
  local -a parts_a parts_b
  local i max part_a part_b

  read -r -a parts_a <<<"$version_a"
  read -r -a parts_b <<<"$version_b"

  if [ "${#parts_a[@]}" -gt "${#parts_b[@]}" ]; then
    max=${#parts_a[@]}
  else
    max=${#parts_b[@]}
  fi

  for ((i = 0; i < max; i++)); do
    part_a=${parts_a[i]:-0}
    part_b=${parts_b[i]:-0}
    part_a=${part_a%%[^0-9]*}
    part_b=${part_b%%[^0-9]*}
    if [ "$part_a" == "" ]; then part_a=0; fi
    if [ "$part_b" == "" ]; then part_b=0; fi
    if ((10#$part_a > 10#$part_b)); then
      return 0
    fi
    if ((10#$part_a < 10#$part_b)); then
      return 1
    fi
  done

  return 1
}

function _pyact_backend() {
  if command -v pyenv >/dev/null 2>&1; then
    echo "pyenv"
    return 0
  fi

  if command -v uv >/dev/null 2>&1; then
    echo "uv"
    return 0
  fi

  return 0
}

function _pyact_host_tag() {
  local host_os host_arch

  host_os=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
  host_arch=$(uname -m 2>/dev/null | tr '[:upper:]' '[:lower:]')

  case "$host_os" in
  darwin) host_os="darwin" ;;
  linux) host_os="linux" ;;
  *) ;;
  esac

  case "$host_arch" in
  x86_64 | amd64) host_arch="amd64" ;;
  aarch64 | arm64) host_arch="arm64" ;;
  *) ;;
  esac

  echo "${host_os}-${host_arch}"
}

function _pyact_venv_name() {
  local version="$1"
  local hosttag="$2"

  echo "venv-python${version}-${hosttag}"
}

function _pyact_matches_version_request() {
  local candidate="$1"
  local request="$2"

  if [ "$request" == "" ] || [ "$candidate" == "$request" ] || [[ "$candidate" == "$request".* ]]; then
    return 0
  fi

  return 1
}

function _pyact_find_best_venv() {
  local request="$1"
  local hosttag="$2"
  local bestdir=""
  local bestversion=""
  local foundvenv candidateversion suffix

  suffix="-$hosttag"
  while IFS= read -r foundvenv; do
    candidateversion=${foundvenv#./venv-python}
    if [[ "$candidateversion" != *"$suffix" ]]; then
      continue
    fi
    candidateversion=${candidateversion%"$suffix"}

    if [ "$candidateversion" == "" ]; then
      continue
    fi

    if ! _pyact_matches_version_request "$candidateversion" "$request"; then
      continue
    fi

    if [ "$bestversion" == "" ] || _pyact_version_gt "$candidateversion" "$bestversion"; then
      bestdir="$foundvenv"
      bestversion="$candidateversion"
    fi
  done < <(find . -maxdepth 1 -type d -name "venv-python*-$hosttag")

  if [ "$bestdir" != "" ]; then
    printf '%s\t%s\n' "$bestdir" "$bestversion"
  fi
}

function _pyact_resolve_pyenv_version() {
  local request="$1"
  local resolved

  resolved=$(PYENV_VERSION="$request" pyenv version-name 2>/dev/null) || return 1
  if [ "$resolved" == "" ]; then
    return 1
  fi

  echo "$resolved"
}

function _pyact_resolve_python_bin() {
  local requested="$1"
  local resolved

  if [ "$requested" == "" ]; then
    return 1
  fi

  if [[ "$requested" == */* ]]; then
    if [ -x "$requested" ]; then
      echo "$requested"
      return 0
    fi
    return 1
  fi

  resolved=$(type -P "$requested" 2>/dev/null) || return 1
  if [ "$resolved" == "" ] || [ ! -x "$resolved" ]; then
    return 1
  fi

  echo "$resolved"
}

function _pyact_python_version() {
  local python_bin="$1"

  "$python_bin" -c 'import sys; print("{}.{}.{}".format(*sys.version_info[:3]))' 2>/dev/null
}

function _pyact_venv_has_pip() {
  local venvname="$1"
  local venv_python

  venv_python="./$venvname/bin/python"
  if [ ! -x "$venv_python" ]; then
    return 1
  fi

  "$venv_python" -m pip --version >/dev/null 2>&1
}

function _pyact_create_with_python() {
  local python_request="$1"
  local hosttag="$2"
  local python_bin
  local resolvedversion
  local venvname
  local ensurepip_available
  local venv_python

  python_bin=$(_pyact_resolve_python_bin "$python_request")
  if [ "$python_bin" == "" ]; then
    echo "Python executable not found: $python_request"
    return 1
  fi

  resolvedversion=$(_pyact_python_version "$python_bin")
  if [ "$resolvedversion" == "" ]; then
    echo "Failed to determine Python version from: $python_bin"
    return 1
  fi

  if ! "$python_bin" -c 'import venv' >/dev/null 2>&1; then
    echo "Python at $python_bin does not support venv."
    return 1
  fi

  ensurepip_available=1
  if ! "$python_bin" -c 'import ensurepip' >/dev/null 2>&1; then
    ensurepip_available=0
  fi

  venvname=$(_pyact_venv_name "$resolvedversion" "$hosttag")
  if [ -d "$venvname" ]; then
    echo "$venvname already exists"
    return 0
  fi

  "$python_bin" -m venv "$venvname" || return 1

  if ! _pyact_venv_has_pip "$venvname"; then
    if [ "$ensurepip_available" == "1" ]; then
      venv_python="./$venvname/bin/python"
      "$venv_python" -m ensurepip --upgrade >/dev/null 2>&1 || true
    fi

    if ! _pyact_venv_has_pip "$venvname"; then
      if [[ "$venvname" == venv-python* ]] && [ -d "$venvname" ]; then
        rm -rf "./${venvname:?}"
      fi
      if [ "$ensurepip_available" == "1" ]; then
        echo "Created $venvname but pip could not be initialized."
      else
        echo "Created $venvname but pip is unavailable and ensurepip is missing in $python_bin."
      fi
      return 1
    fi
  fi

  echo "Created $venvname"
}

function _pyact_pip_cache_dir() {
  local myos

  if [ -n "${PIP_CACHE_DIR:-}" ]; then
    echo "$PIP_CACHE_DIR"
    return 0
  fi

  myos=$(uname -s 2>/dev/null)
  if [ "$myos" == "Darwin" ]; then
    echo "$HOME/Library/Caches/pip"
    return 0
  fi

  echo "${XDG_CACHE_HOME:-$HOME/.cache}/pip"
}

function _pyact_cache_paths() {
  local xdg_cache_home pyenv_root pip_cache_dir

  xdg_cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  pyenv_root="${PYENV_ROOT:-$HOME/.pyenv}"
  pip_cache_dir=$(_pyact_pip_cache_dir)

  printf 'pyenv\t%s\n' "$pyenv_root/cache"
  printf 'pip\t%s\n' "$pip_cache_dir"
  printf 'uv\t%s\n' "$xdg_cache_home/uv"
}

function _pyact_cache_show() {
  local name path size files

  echo "pyact cache"
  printf '%-8s %-8s %-8s %s\n' "name" "size" "files" "path"
  while IFS=$'\t' read -r name path; do
    if [ -d "$path" ]; then
      size=$(du -sh "$path" 2>/dev/null | cut -f1)
      files=$(find "$path" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
      if [ "$size" == "" ]; then
        size="?"
      fi
      if [ "$files" == "" ]; then
        files="0"
      fi
      printf '%-8s %-8s %-8s %s\n' "$name" "$size" "$files" "$path"
    else
      printf '%-8s %-8s %-8s %s\n' "$name" "-" "0" "$path"
    fi
  done < <(_pyact_cache_paths)
}

function _pyact_cache_purge() {
  local name path

  while IFS=$'\t' read -r name path; do
    if [ -d "$path" ]; then
      if [ "$path" == "" ] || [ "$path" == "/" ]; then
        echo "Refusing to remove unsafe cache path for $name: $path" >&2
        return 1
      fi
      rm -rf "${path:?}"
      echo "Removed $name cache: $path"
    else
      echo "No $name cache at: $path"
    fi
  done < <(_pyact_cache_paths)
}

function _pyact_cache_command() {
  case "${1:-}" in
  "" | show)
    _pyact_cache_show
    ;;
  clean | purge)
    _pyact_cache_purge
    ;;
  -h | --help | help)
    echo "Usage: pyact cache [show|clean|purge]"
    ;;
  *)
    echo "Usage: pyact cache [show|clean|purge]"
    return 1
    ;;
  esac
}

function _pyact_usage() {
  echo "Usage:"
  echo "  pyact -c <python-version>"
  echo "  pyact -c --python <python-bin>"
  echo "  pyact [python-version]"
  echo "  pyact cache [show|clean|purge]"
  echo ""
  echo "Notes:"
  echo "  - Prefers pyenv; falls back to uv."
  echo "  - uv fallback uses UV_NO_PYTHON_DOWNLOADS=1."
  echo "  - Install missing uv Python with: uv python install <version>."
  echo "  - Custom python create ensures pip in the created venv."
}

function pyact() {
  local backend
  local hosttag
  local request
  local resolvedversion
  local venvname
  local venvpath
  local actualversion
  local targetvenv
  local match
  local venvdir

  _PYACT_ACTIVATED=0

  if [ "${1:-}" == "-h" ] || [ "${1:-}" == "--help" ] || [ "${1:-}" == "help" ]; then
    _pyact_usage
    return 0
  fi

  if [ "$1" == "cache" ]; then
    _pyact_cache_command "$2"
    return $?
  fi

  if [ "$(pwd)" == "$(dirname "$HOME")" ] || [ "$(pwd)" == "/" ]; then
    echo "no venv-python$1 from here to HOME(exclusive)."
    return 1
  fi

  hosttag=$(_pyact_host_tag)

  if [ "$1" == "-c" ]; then
    if [ "${2:-}" == "--python" ] || [[ "${2:-}" == --python=* ]]; then
      if [ "${2:-}" == "--python" ]; then
        request="$3"
        if [ "$request" == "" ] || [ "${4:-}" != "" ]; then
          echo "Usage: pyact -c --python <python-bin>"
          return 1
        fi
      else
        request="${2#--python=}"
        if [ "$request" == "" ] || [ "${3:-}" != "" ]; then
          echo "Usage: pyact -c --python <python-bin>"
          return 1
        fi
      fi

      _pyact_create_with_python "$request" "$hosttag"
      return $?
    fi

    request="$2"
    if [ "$request" == "" ] || [ "${3:-}" != "" ]; then
      echo "Usage: pyact -c <python-version>"
      return 1
    fi

    backend=$(_pyact_backend)
    if [ "$backend" == "" ]; then
      echo "Neither pyenv nor uv is available."
      return 1
    fi

    if [ "$backend" == "pyenv" ]; then
      resolvedversion=$(_pyact_resolve_pyenv_version "$request")
      if [ "$resolvedversion" == "" ]; then
        echo "Python $request is not installed in pyenv for $hosttag."
        echo "Install it first, e.g.: pyenv install $request"
        return 1
      fi

      venvname=$(_pyact_venv_name "$resolvedversion" "$hosttag")
      if [ -d "$venvname" ]; then
        echo "$venvname already exists"
        return 0
      fi

      PYENV_VERSION="$request" pyenv exec python -m venv "$venvname" || return 1
      echo "Created $venvname"
      return 0
    fi

    venvname=$(_pyact_venv_name "$request" "$hosttag")
    if [ -d "$venvname" ]; then
      echo "$venvname already exists"
      return 0
    fi

    if ! uv python find --no-python-downloads "$request" >/dev/null 2>&1; then
      echo "Python $request is not available for uv on $hosttag (UV_NO_PYTHON_DOWNLOADS=1)."
      echo "Install it first, e.g.: uv python install $request"
      return 1
    fi

    UV_NO_PYTHON_DOWNLOADS=1 uv venv --seed --python "$request" "$venvname" || return 1

    venvpath="./$venvname/bin/python"
    if [ -x "$venvpath" ]; then
      actualversion=$("$venvpath" -c 'import sys; print("{}.{}.{}".format(*sys.version_info[:3]))' 2>/dev/null)
      if [ "$actualversion" != "" ] && [ "$actualversion" != "$request" ]; then
        targetvenv=$(_pyact_venv_name "$actualversion" "$hosttag")
        if [ ! -d "$targetvenv" ]; then
          mv "$venvname" "$targetvenv"
          venvname="$targetvenv"
        fi
      fi
    fi

    echo "Created $venvname"
    return 0
  fi

  if [ "$1" != "" ]; then
    echo "Trying venv-python$1-$hosttag in $(pwd):"
  else
    echo "Searching any venv-python in $(pwd) for $hosttag"
  fi

  match=$(_pyact_find_best_venv "$1" "$hosttag")
  if [ "$match" != "" ]; then
    venvdir=${match%%$'\t'*}
    # shellcheck disable=SC1090,SC1091
    . "$venvdir/bin/activate"
    _PYACT_ACTIVATED=1
    return 0
  fi

  pushd .. >/dev/null || return 1
  pyact "$@"
  local ret=$?
  popd >/dev/null || return 1
  return $ret
}

function pydeact() {
  if type deactivate >/dev/null 2>&1; then
    deactivate
  fi

  if [ "$(type -t pyenv)" == "function" ]; then
    pyenv shell system
  else
    unset PYENV_VERSION
  fi
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  _pyact_root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  exec "$_pyact_root_dir/bin/pyact" "$@"
fi
