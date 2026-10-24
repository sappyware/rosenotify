#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-$HOME/.config/quickshell/rosenotify}"
DEST="${DEST/#\~/$HOME}"
TOML="$HOME/.config/rosenotify"
STAMP="$(date +%Y%m%d-%H%M%S)"

FILES=(shell.qml Card.qml Config.qml Notifs.qml Toml.js config.toml)

command -v qs >/dev/null || { echo "error: quickshell (qs) not found" >&2; exit 1; }

for f in "${FILES[@]}"; do
    [[ -f "$SRC/$f" ]] || { echo "error: missing $f" >&2; exit 1; }
done

mkdir -p "$DEST"

for f in "${FILES[@]}"; do
    dst="$DEST/$f"
    if [[ ! -f "$dst" ]]; then
        cp -p "$SRC/$f" "$dst"
        echo "installed $f"
    elif cmp -s "$SRC/$f" "$dst"; then
        echo "unchanged $f"
    else
        cp -p "$dst" "$dst.bak.$STAMP"
        cp -p "$SRC/$f" "$dst"
        echo "updated $f"
    fi
done

mkdir -p "$TOML"
[[ -f "$TOML/config.toml" ]] || cp -p "$SRC/config.toml" "$TOML/config.toml"

echo "done. restart quickshell: qs restart"