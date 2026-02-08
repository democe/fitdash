#!/usr/bin/env bash
set -e

PLASMOID_ID="com.democe.fitdash"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA_HOME/plasma/plasmoids/$PLASMOID_ID"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

rm -rf "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/../package" "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/contents/scripts"
cp "$SCRIPT_DIR/fitdash-auth.py" "$INSTALL_DIR/contents/scripts/"
chmod +x "$INSTALL_DIR/contents/scripts/fitdash-auth.py"

# Install icon into user icon theme so Plasma can resolve it by name
ICON_DIR="$DATA_HOME/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DIR"
cp "$INSTALL_DIR/contents/icons/fitdash.svg" "$ICON_DIR/fitdash.svg"

echo "Installed to $INSTALL_DIR"
