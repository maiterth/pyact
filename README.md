# pyact

Python venv version manager using pyenv or uv.
Lightweight Python environment activation without exposing pyenv/uv commands in day-to-day usage.
Kind of like conda, but a creates a 'venv-python<version>-<os>-<arch>' easily removable via 'rm'
and activatable via 'pyact <version>', from the director (or subdirectory) it was created from.
Ease of use, while not having to remember or deal with each tools' peculiarities directly.

## Features

- Prefers `pyenv`; falls back to `uv` automatically.
- Keeps venvs host-specific for shared filesystems:
  - `venv-python<version>-<os>-<arch>`
  - example: `venv-python3.12.2-darwin-arm64`
- Supports partial version requests:
  - `3.12` resolves to highest available `3.12.x`
- In uv fallback mode, uses `uv venv --seed` and `UV_NO_PYTHON_DOWNLOADS=1`.
- If uv cannot find a requested Python, `pyact` prints: `uv python install <version>`.

## Usage

Create a venv:

```bash
pyact -c 3.12
```

Create a venv from a custom Python executable (version is derived automatically):

```bash
pyact -c --python /path/to/python
```

This creates the same host-aware folder naming and verifies `pip` is available in the new venv.

Activate a specific version:

```bash
pyact 3.12
```

Activate the highest available version for this host:

```bash
pyact
```

Deactivate:

```bash
pydeact
```

Inspect cache usage (size and file count):

```bash
pyact cache
```

Clean caches safely (keeps installed Python versions and venvs):

```bash
pyact cache purge
```

## Setup

Install into a prefix you control. Typical choices are:

- `$HOME/.local/pyact`
- `$LOCAL/pyact`
- `/usr/local/pyact` (system-wide)

For your dotfiles setup, use `$LOCAL/pyact`:

```bash
./install.sh --prefix "$LOCAL/pyact"
```

After install, choose one runtime mode:

- Command mode (no sourcing): ensure `<prefix>/bin` is on `PATH`, then use `pyact`.
- Function mode (same-shell activation): source `pyact.sh` in your shell startup.

Example for function mode:

```bash
source "$LOCAL/pyact/pyact.sh"
```

This gives same-shell activation behavior.

If you prefer standalone commands, add `<prefix>/bin` to `PATH`.

## Standalone command mode

`bin/pyact` can be called directly. For activation commands, it opens a subshell with the venv active. Exit that shell to return.

```bash
/path/to/pyact/bin/pyact 3.12
```

Use `pyact.sh` for backwards-compatible sourcing:

```bash
source /path/to/pyact/pyact.sh
```
