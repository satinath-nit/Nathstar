#!/bin/zsh
set -euo pipefail

source "${0:A:h}/toolchain.sh"

APP_NAME="Nathstar"
RELEASE_DIR="$NATHSTAR_PROJECT_DIR/release"
APP_DIR="$RELEASE_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
INFO_PLIST="$NATHSTAR_PROJECT_DIR/Resources/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
TARGET_ARCH="$(uname -m)"
BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"

cd "$NATHSTAR_PROJECT_DIR"
run_swift run NorthstarCoreChecks
run_swift build -c release --product Nathstar -debug-info-format none

BINARY_PATH="$NATHSTAR_SCRATCH_PATH/out/Products/Release/Nathstar"
if [[ ! -f "$BINARY_PATH" ]]; then
    BINARY_PATH="$NATHSTAR_SCRATCH_PATH/$TARGET_ARCH-apple-macosx/release/Nathstar"
fi
if [[ ! -f "$BINARY_PATH" ]]; then
    echo "Nathstar release binary was not found." >&2
    exit 1
fi

mkdir -p "$RELEASE_DIR"
if [[ -d "$APP_DIR" ]]; then
    mv "$APP_DIR" "$RELEASE_DIR/$APP_NAME.previous-$BACKUP_STAMP.app"
fi
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BINARY_PATH" "$CONTENTS_DIR/MacOS/Nathstar"
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"
cp "$NATHSTAR_PROJECT_DIR/Resources/NorthstarIcon-1024.png" "$CONTENTS_DIR/Resources/NorthstarIcon-1024.png"
cp "$NATHSTAR_PROJECT_DIR/Vendor/SwiftTerm/Sources/SwiftTerm/Apple/Metal/Shaders.metal" "$CONTENTS_DIR/Resources/Shaders.metal"
cp "$NATHSTAR_PROJECT_DIR/Vendor/SwiftTerm/LICENSE" "$CONTENTS_DIR/Resources/SwiftTerm-LICENSE.txt"

codesign --force --deep --sign - "$APP_DIR"

DMG_PATH="$RELEASE_DIR/Nathstar-$APP_VERSION-$TARGET_ARCH.dmg"
if [[ -f "$DMG_PATH" ]]; then
    mv "$DMG_PATH" "$DMG_PATH.previous-$BACKUP_STAMP"
fi
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH"

echo "Created: $APP_DIR"
echo "Created: $DMG_PATH"
