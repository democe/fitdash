#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="com.democe.fitdash"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA_HOME/plasma/plasmoids/$PLASMOID_ID"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUTH_SCRIPT_SRC="$SCRIPT_DIR/fitdash-auth.py"
AUTH_SCRIPT_DST="$INSTALL_DIR/contents/scripts/fitdash-auth.py"

rm -rf "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/../package" "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/contents/scripts"

if [[ ! -f "$AUTH_SCRIPT_SRC" ]]; then
    echo "Error: missing authorization script: $AUTH_SCRIPT_SRC" >&2
    exit 1
fi

cp "$AUTH_SCRIPT_SRC" "$AUTH_SCRIPT_DST"
chmod +x "$AUTH_SCRIPT_DST"

# Install icon into user icon theme so Plasma can resolve it by name
ICON_DIR="$DATA_HOME/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DIR"
cp "$INSTALL_DIR/contents/icons/fitdash.svg" "$ICON_DIR/fitdash.svg"

echo "Installed to $INSTALL_DIR"
