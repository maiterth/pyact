#!/usr/bin/env bash
set -euo pipefail

prefix=""

while [ "$#" -gt 0 ]; do
  case "$1" in
  --prefix)
    if [ "$#" -lt 2 ]; then
      echo "Missing value for --prefix" >&2
      exit 1
    fi
    prefix="$2"
    shift 2
    ;;
  -h | --help)
    echo "Install pyact into a prefix"
    echo ""
    echo "Usage:"
    echo "  ./install.sh --prefix <path>"
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [ "$prefix" == "" ]; then
  echo "Usage: ./install.sh --prefix <path>" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

mkdir -p "$prefix/bin"

if [ -d "$prefix/lib" ]; then
  rm -rf "${prefix:?}/lib"
fi

install -m 755 "$script_dir/bin/pyact" "$prefix/bin/pyact"
install -m 755 "$script_dir/bin/pydeact" "$prefix/bin/pydeact"
install -m 644 "$script_dir/pyact.sh" "$prefix/pyact.sh"
install -m 644 "$script_dir/README.md" "$prefix/README.md"
install -m 644 "$script_dir/LICENSE" "$prefix/LICENSE"

echo "Installed pyact into $prefix"
