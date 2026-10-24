#!/bin/zsh
set -euo pipefail

source "${0:A:h}/toolchain.sh"
cd "$NATHSTAR_PROJECT_DIR"

run_swift run NorthstarCoreChecks
run_swift build --product Nathstar
