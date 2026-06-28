#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <package-dir>" >&2
    exit 2
fi

if ! command -v msgfmt >/dev/null 2>&1; then
    echo "Warning: msgfmt not found; skipping translations" >&2
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
PACKAGE_DIR="$1"
DOMAIN="plasma_applet_com.democe.fitdash"

shopt -s nullglob
for po_file in "$PROJECT_DIR"/po/*.po; do
    lang="$(basename "$po_file" .po)"
    locale_dir="$PACKAGE_DIR/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$locale_dir"
    msgfmt --check --output-file="$locale_dir/$DOMAIN.mo" "$po_file"
done
