#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
PACKAGE_DIR="$PROJECT_DIR/package"
OUTPUT="$PROJECT_DIR/fitdash.plasmoid"

# Read version from metadata.json
VERSION=$(python3 -c "import json; print(json.load(open('$PACKAGE_DIR/metadata.json'))['KPlugin']['Version'])")

rm -f "$OUTPUT"

# A .plasmoid is a zip of the package/ directory contents
cd "$PACKAGE_DIR"
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
