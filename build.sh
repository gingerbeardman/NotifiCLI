#!/bin/bash
set -e

BUILD_DIR="build"
ICONS_DIR="icons"
BACKUP_DIR=".build_backup"

# Backup existing binaries if main.swift doesn't exist
if [ ! -f "main.swift" ]; then
    echo "⚠️  main.swift not found, preserving existing binaries..."
    if [ -f "$BUILD_DIR/NotifiCLI.app/Contents/MacOS/NotifiCLI" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$BUILD_DIR/NotifiCLI.app/Contents/MacOS/NotifiCLI" "$BACKUP_DIR/NotifiCLI"
        cp "$BUILD_DIR/NotifiPersistent.app/Contents/MacOS/NotifiPersistent" "$BACKUP_DIR/NotifiPersistent" 2>/dev/null || true
    fi
fi

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Base apps: NotifiCLI and NotifiPersistent (use default AppIcon.icns)
BASE_APPS=("NotifiCLI" "NotifiPersistent")

for APP_NAME in "${BASE_APPS[@]}"; do
    echo "🔨 Building $APP_NAME..."
    APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
    CONTENTS_DIR="${APP_BUNDLE}/Contents"
    MACOS_DIR="${CONTENTS_DIR}/MacOS"
    RESOURCES_DIR="${CONTENTS_DIR}/Resources"
    
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

    # Copy appropriate Info.plist
    if [ "$APP_NAME" == "NotifiPersistent" ]; then
        cp Info_Persistent.plist "${CONTENTS_DIR}/Info.plist"
    else
        cp Info.plist "${CONTENTS_DIR}/Info.plist"
    fi

    # Copy default app icon
    if [ -f "AppIcon.icns" ]; then
        cp AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
    fi

    # Compile Swift or use backup binary
    if [ -f "main.swift" ]; then
        swiftc main.swift -o "${MACOS_DIR}/${APP_NAME}" -target arm64-apple-macosx11.0
    elif [ -f "$BACKUP_DIR/NotifiCLI" ]; then
        echo "   Using preserved binary..."
        cp "$BACKUP_DIR/NotifiCLI" "${MACOS_DIR}/${APP_NAME}"
    else
        echo "❌ Error: No main.swift and no existing binary to copy!"
        exit 1
    fi

    # Ad-hoc sign
    codesign --force --deep -s - "$APP_BUNDLE"
    echo "✅ Built ${APP_BUNDLE}"
done

# Embed NotifiPersistent inside NotifiCLI.app/Contents/Apps/
echo "📦 Embedding NotifiPersistent inside NotifiCLI..."
APPS_DIR="${BUILD_DIR}/NotifiCLI.app/Contents/Apps"
mkdir -p "$APPS_DIR"
mv "${BUILD_DIR}/NotifiPersistent.app" "$APPS_DIR/"
codesign --force --deep -s - "${BUILD_DIR}/NotifiCLI.app"
echo "✅ NotifiPersistent embedded in NotifiCLI.app/Contents/Apps/"

# Cleanup backup
rm -rf "$BACKUP_DIR"

# Icon Variants: Build a separate app for each .icns or .png in the icons/ folder
# These use NotifiCLI as the base, just with different icons
if [ -d "$ICONS_DIR" ]; then
    # Process both .icns and .png files
    for ICON_FILE in "$ICONS_DIR"/*.icns "$ICONS_DIR"/*.png; do
        [ -e "$ICON_FILE" ] || continue  # Skip if file doesn't exist
        
        # Get variant name and extension
        FILENAME=$(basename "$ICON_FILE")
        EXTENSION="${FILENAME##*.}"
        VARIANT_NAME="${FILENAME%.*}"
        # Process both variants: Standard and Persistent
        VARIANTS=("NotifiCLI" "NotifiPersistent")
        
        for BASE_TYPE in "${VARIANTS[@]}"; do
            APP_NAME="${BASE_TYPE}-${VARIANT_NAME}"
            echo "🎨 Building icon variant: $APP_NAME..."
            
            APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
            CONTENTS_DIR="${APP_BUNDLE}/Contents"
            MACOS_DIR="${CONTENTS_DIR}/MacOS"
            RESOURCES_DIR="${CONTENTS_DIR}/Resources"
            
            mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

            # Use appropriate Info.plist as base and modify bundle ID
            if [ "$BASE_TYPE" == "NotifiPersistent" ]; then
                BASE_PLIST="Info_Persistent.plist"
                # Use a different bundle ID suffix for persistent variants
                sed "s/com.saihgupr.NotifiPersistent/com.saihgupr.NotifiPersistent.${VARIANT_NAME}/" "$BASE_PLIST" > "${CONTENTS_DIR}/Info.plist"
            else
                BASE_PLIST="Info.plist"
                sed "s/com.saihgupr.NotifiCLI.v2/com.saihgupr.NotifiCLI.${VARIANT_NAME}/" "$BASE_PLIST" > "${CONTENTS_DIR}/Info.plist"
            fi

            # Handle icon conversion if PNG
            if [ "$EXTENSION" == "png" ]; then
                echo "   Converting PNG to iconset..."
                ICONSET_DIR="${BUILD_DIR}/${VARIANT_NAME}.iconset"
                mkdir -p "$ICONSET_DIR"
                
                # Generate all required sizes using sips
                sips -z 16 16     "$ICON_FILE" --out "${ICONSET_DIR}/icon_16x16.png" 2>/dev/null
                sips -z 32 32     "$ICON_FILE" --out "${ICONSET_DIR}/icon_16x16@2x.png" 2>/dev/null
                sips -z 32 32     "$ICON_FILE" --out "${ICONSET_DIR}/icon_32x32.png" 2>/dev/null
                sips -z 64 64     "$ICON_FILE" --out "${ICONSET_DIR}/icon_32x32@2x.png" 2>/dev/null
                sips -z 128 128   "$ICON_FILE" --out "${ICONSET_DIR}/icon_128x128.png" 2>/dev/null
                sips -z 256 256   "$ICON_FILE" --out "${ICONSET_DIR}/icon_128x128@2x.png" 2>/dev/null
                sips -z 256 256   "$ICON_FILE" --out "${ICONSET_DIR}/icon_256x256.png" 2>/dev/null
                sips -z 512 512   "$ICON_FILE" --out "${ICONSET_DIR}/icon_256x256@2x.png" 2>/dev/null
                sips -z 512 512   "$ICON_FILE" --out "${ICONSET_DIR}/icon_512x512.png" 2>/dev/null
                sips -z 1024 1024 "$ICON_FILE" --out "${ICONSET_DIR}/icon_512x512@2x.png" 2>/dev/null
                
                # Convert iconset to icns
                iconutil -c icns "$ICONSET_DIR" -o "${RESOURCES_DIR}/AppIcon.icns"
                rm -rf "$ICONSET_DIR"
            else
                # Copy the icns directly
                cp "$ICON_FILE" "${RESOURCES_DIR}/AppIcon.icns"
            fi

            # Copy the compiled binary (match the base type)
            if [ "$BASE_TYPE" == "NotifiPersistent" ]; then
                # Need to use the embedded persistent binary
                cp "${APPS_DIR}/NotifiPersistent.app/Contents/MacOS/NotifiPersistent" "${MACOS_DIR}/${APP_NAME}"
            else
                cp "${BUILD_DIR}/NotifiCLI.app/Contents/MacOS/NotifiCLI" "${MACOS_DIR}/${APP_NAME}"
            fi

            # Ad-hoc sign
            codesign --force --deep -s - "$APP_BUNDLE"
            
            # Move into NotifiCLI.app/Contents/Apps/
            mv "$APP_BUNDLE" "${BUILD_DIR}/NotifiCLI.app/Contents/Apps/"
            # echo "✅ Built and embedded ${APP_NAME} into NotifiCLI"
        done
        echo "✅ Built standard and persistent variants for '${VARIANT_NAME}'"
    done
fi

echo ""
echo "🎉 All builds complete."
echo ""
echo "Usage:"
echo "  notificli [args]                    # Default icon"
echo "  notificli -persistent [args]        # Persistent notification"
echo "  notificli -app VariantName [args]   # Custom icon variant"
