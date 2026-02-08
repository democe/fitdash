#!/usr/bin/env bash

PLASMOID_ID="com.democe.fitdash"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA_HOME/plasma/plasmoids/$PLASMOID_ID"

if [ ! -d "$INSTALL_DIR" ]; then
    echo "Error: Widget not installed. Run install.sh first." >&2
    exit 1
fi

if ! command -v plasmawindowed &>/dev/null; then
    echo "Error: plasmawindowed not found. Install plasma-sdk." >&2
    exit 1
fi

plasmawindowed "$PLASMOID_ID"
