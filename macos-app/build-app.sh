#!/bin/bash
# Build Loop Commander as a proper macOS .app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Swift binary..."
swift build -c debug 2>&1

# Find the built binary
BINARY=$(find .build -name "LoopCommander" -type f -not -path "*.dSYM*" | head -1)
if [ -z "$BINARY" ]; then
    echo "Error: Could not find built binary"
    exit 1
fi

APP_DIR="$SCRIPT_DIR/build/Loop Commander.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES"

# Copy binary
cp "$BINARY" "$MACOS_DIR/LoopCommander"
chmod +x "$MACOS_DIR/LoopCommander"

# Copy app icon if present
ICNS_SRC="$SCRIPT_DIR/Assets/AppIcon.icns"
if [ -f "$ICNS_SRC" ]; then
    cp "$ICNS_SRC" "$RESOURCES/AppIcon.icns"
    echo "Copied AppIcon.icns into bundle Resources."
else
    echo "Warning: $ICNS_SRC not found. Run scripts/generate-icon.py to create it."
fi

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>LoopCommander</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.loopcommander.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Loop Commander</string>
    <key>CFBundleDisplayName</key>
    <string>Loop Commander</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

echo "Built: $APP_DIR"
echo ""
echo "To run:  open \"$APP_DIR\""
