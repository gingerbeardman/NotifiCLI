#!/bin/bash
# Extract app icon and create a NotifiCLI variant
# Usage: ./add-icon.sh "/Applications/Keyboard Maestro.app" KeyboardMaestro

set -e

# Resolve script directory to allow running from anywhere
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

APP_PATH="$1"
VARIANT_NAME="$2"
ICONS_DIR="icons"

if [ -z "$APP_PATH" ] || [ -z "$VARIANT_NAME" ]; then
    echo "Usage: ./add-icon.sh \"/path/to/App.app\" VariantName"
    echo ""
    echo "Example:"
    echo "  ./add-icon.sh \"/Applications/Keyboard Maestro.app\" KeyboardMaestro"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found: $APP_PATH"
    exit 1
fi

# Find the app icon from Info.plist
PLIST="$APP_PATH/Contents/Info.plist"
if [ ! -f "$PLIST" ]; then
    echo "❌ Error: No Info.plist found in app"
    exit 1
fi

# Get icon filename from plist (CFBundleIconFile)
ICON_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$PLIST" 2>/dev/null || echo "")

# Add .icns if not present
if [ -n "$ICON_NAME" ] && [[ "$ICON_NAME" != *.icns ]]; then
    ICON_NAME="${ICON_NAME}.icns"
fi

# Fallback to AppIcon.icns if not found
if [ -z "$ICON_NAME" ]; then
    ICON_NAME="AppIcon.icns"
fi

ICON_PATH="$APP_PATH/Contents/Resources/$ICON_NAME"

if [ ! -f "$ICON_PATH" ]; then
    echo "❌ Error: Icon not found: $ICON_PATH"
    echo "Available icons:"
    ls "$APP_PATH/Contents/Resources/"*.icns 2>/dev/null || echo "  (none)"
    exit 1
fi

# Copy the icon
mkdir -p "$ICONS_DIR"
cp "$ICON_PATH" "$ICONS_DIR/${VARIANT_NAME}.icns"
echo "✅ Copied icon to $ICONS_DIR/${VARIANT_NAME}.icns"

# Rebuild
echo ""
echo "🔨 Rebuilding..."
./build.sh

echo ""
echo "🎉 Done! Use with:"
echo "   notificli -app $VARIANT_NAME -title \"Title\" -message \"Message\""
