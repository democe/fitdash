#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
PACKAGE_DIR="$PROJECT_DIR/package"
OUTPUT="$PROJECT_DIR/fitdash.plasmoid"
AUTH_SCRIPT_SRC="$SCRIPT_DIR/fitdash-auth.py"
STAGE_ROOT="$(mktemp -d)"
STAGE_PACKAGE_DIR="$STAGE_ROOT/package"

trap 'rm -rf "$STAGE_ROOT"' EXIT

if [[ ! -f "$AUTH_SCRIPT_SRC" ]]; then
    echo "Error: missing authorization script: $AUTH_SCRIPT_SRC" >&2
    exit 1
fi

# Read version from metadata.json
VERSION=$(python3 -c "import json; print(json.load(open('$PACKAGE_DIR/metadata.json'))['KPlugin']['Version'])")

rm -f "$OUTPUT"

# Stage package and include OAuth helper script in expected runtime path
cp -r "$PACKAGE_DIR" "$STAGE_PACKAGE_DIR"
mkdir -p "$STAGE_PACKAGE_DIR/contents/scripts"
cp "$AUTH_SCRIPT_SRC" "$STAGE_PACKAGE_DIR/contents/scripts/fitdash-auth.py"
chmod +x "$STAGE_PACKAGE_DIR/contents/scripts/fitdash-auth.py"

# A .plasmoid is a zip of the package/ directory contents
cd "$STAGE_PACKAGE_DIR"
python3 -c "
import zipfile, os
with zipfile.ZipFile('$OUTPUT', 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for f in files:
            if not f.startswith('.'):
                zf.write(os.path.join(root, f))
"

echo "Created $OUTPUT (v$VERSION)"
