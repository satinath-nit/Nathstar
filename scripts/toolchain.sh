#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
DEFAULT_CLT_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"

if [[ -n "${NATHSTAR_SDK_PATH:-}" ]]; then
    SDK_PATH="$NATHSTAR_SDK_PATH"
elif [[ -d "$DEFAULT_CLT_SDK" ]]; then
    SDK_PATH="$DEFAULT_CLT_SDK"
else
    SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
fi

INTERFACE_FILE="$SDK_PATH/usr/lib/swift/Swift.swiftmodule/arm64e-apple-macos.swiftinterface"
SWIFT_FLAGS=()
if [[ -f "$INTERFACE_FILE" ]]; then
    INTERFACE_VERSION="$(sed -nE '2s/.*swiftlang-([0-9.]+).*/\1/p' "$INTERFACE_FILE")"
    if [[ -n "$INTERFACE_VERSION" ]]; then
        SWIFT_FLAGS=(
            -Xswiftc -Xfrontend
            -Xswiftc -interface-compiler-version
            -Xswiftc -Xfrontend
            -Xswiftc "$INTERFACE_VERSION"
        )
    fi
fi

export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/swift-cache"
export SDKROOT="$SDK_PATH"
export NATHSTAR_PROJECT_DIR="$PROJECT_DIR"
export NATHSTAR_SCRATCH_PATH="$PROJECT_DIR/.build/sdk"
export NATHSTAR_SWIFT_FLAGS="${(j: :)SWIFT_FLAGS}"

run_swift() {
    local subcommand="$1"
    shift
    swift "$subcommand" --disable-sandbox --scratch-path "$NATHSTAR_SCRATCH_PATH" "${SWIFT_FLAGS[@]}" "$@"
}
