#!/bin/bash
# package.sh - Build and package NotifiCLI for release
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${DIR}/build"
RELEASE_ZIP="${DIR}/NotifiCLI.app.zip"

echo "🔨 Starting clean build..."
./build.sh

echo "🔍 Verifying build contents..."
APPS_COUNT=$(ls -1 "${BUILD_DIR}/NotifiCLI.app/Contents/Apps" 2>/dev/null | wc -l)

if [ "$APPS_COUNT" -eq 0 ]; then
    echo "❌ Error: NotifiCLI.app/Contents/Apps/ is empty!"
    echo "   The build failed to embed variant apps. Aborting packaging."
    exit 1
fi

echo "✅ Verified: $APPS_COUNT items found in Contents/Apps/"

echo "📦 Creating release ZIP..."
# Remove old zip if exists
[ -f "$RELEASE_ZIP" ] && rm "$RELEASE_ZIP"

# Use cd to avoid including the 'build/' path prefix in the zip
cd "$BUILD_DIR"
zip -r -q "$RELEASE_ZIP" "NotifiCLI.app"
cd "$DIR"

echo "✨ Package created: $RELEASE_ZIP"
echo "📊 Size: $(du -sh "$RELEASE_ZIP" | cut -f1)"
echo "🔐 SHA256: $(shasum -a 256 "$RELEASE_ZIP" | cut -d' ' -f1)"
echo ""
echo "🚀 Ready for release!"
