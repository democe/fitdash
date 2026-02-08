#!/usr/bin/env bash

PLASMOID_ID="com.democe.fitdash"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA_HOME/plasma/plasmoids/$PLASMOID_ID"

if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed $INSTALL_DIR"
else
    echo "Not installed"
fi

# Remove icon from user icon theme
ICON_FILE="$DATA_HOME/icons/hicolor/scalable/apps/fitdash.svg"
if [ -f "$ICON_FILE" ]; then
    rm "$ICON_FILE"
    echo "Removed $ICON_FILE"
fi
