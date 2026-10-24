#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_PATH="$PROJECT_DIR/release/Nathstar.app"

if [[ ! -x "$APP_PATH/Contents/MacOS/Nathstar" ]]; then
    "$PROJECT_DIR/scripts/package-macos.sh"
fi

NATHSTAR_SMOKE_TEST=1 "$APP_PATH/Contents/MacOS/Nathstar"
