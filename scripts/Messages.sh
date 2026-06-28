#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
XGETTEXT_BIN="${XGETTEXT:-xgettext}"
PODIR="${podir:-$PROJECT_DIR/po}"

mkdir -p "$PODIR"

cd "$PROJECT_DIR"

"$XGETTEXT_BIN" \
    --from-code=UTF-8 \
    --language=JavaScript \
    --keyword=i18n \
    --keyword=i18nc:1c,2 \
    --add-comments=TRANSLATORS \
    --package-name=FitDash \
    --package-version=1.0.5 \
    --msgid-bugs-address=democe@outlook.com \
    -o "$PODIR/plasma_applet_com.democe.fitdash.pot" \
    package/contents/ui/*.qml \
    package/contents/config/*.qml
