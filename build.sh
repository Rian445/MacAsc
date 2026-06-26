#!/bin/bash

# Exit on any error
set -e

echo "=== Building Mac ASC.app ==="

# Define directories
APP_DIR="Mac ASC.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Create standard macOS App Bundle structure
echo "Creating app directory structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Compile custom application icon if app_icon.png exists
if [ -f "app_icon.png" ]; then
    echo "Converting app_icon.png into native macOS AppIcon.icns..."
    ICON_SET_DIR="AppIcon.iconset"
    mkdir -p "$ICON_SET_DIR"
    
    # Generate standard macOS icon set sizes using sips
    sips -s format png -z 16 16     app_icon.png --out "${ICON_SET_DIR}/icon_16x16.png" > /dev/null 2>&1
    sips -s format png -z 32 32     app_icon.png --out "${ICON_SET_DIR}/icon_16x16@2x.png" > /dev/null 2>&1
    sips -s format png -z 32 32     app_icon.png --out "${ICON_SET_DIR}/icon_32x32.png" > /dev/null 2>&1
    sips -s format png -z 64 64     app_icon.png --out "${ICON_SET_DIR}/icon_32x32@2x.png" > /dev/null 2>&1
    sips -s format png -z 128 128   app_icon.png --out "${ICON_SET_DIR}/icon_128x128.png" > /dev/null 2>&1
    sips -s format png -z 256 256   app_icon.png --out "${ICON_SET_DIR}/icon_128x128@2x.png" > /dev/null 2>&1
    sips -s format png -z 256 256   app_icon.png --out "${ICON_SET_DIR}/icon_256x256.png" > /dev/null 2>&1
    sips -s format png -z 512 512   app_icon.png --out "${ICON_SET_DIR}/icon_256x256@2x.png" > /dev/null 2>&1
    sips -s format png -z 512 512   app_icon.png --out "${ICON_SET_DIR}/icon_512x512.png" > /dev/null 2>&1
    sips -s format png -z 1024 1024 app_icon.png --out "${ICON_SET_DIR}/icon_512x512@2x.png" > /dev/null 2>&1
    
    # Compile iconset folder to single .icns file
    iconutil -c icns "$ICON_SET_DIR" -o "${RESOURCES_DIR}/AppIcon.icns"
    
    # Clean up temporary icon folder
    rm -rf "$ICON_SET_DIR"
    echo "AppIcon.icns compiled successfully."
else
    echo "Warning: app_icon.png not found. Building without custom icon."
fi

# Find Swift compiler and SDK path
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
echo "Using macOS SDK at: ${SDK_PATH}"

# Compile all Swift files together from the Sources directory
echo "Compiling Swift files..."
swiftc -O \
  -sdk "${SDK_PATH}" \
  -target arm64-apple-macosx13.0 \
  Sources/*.swift \
  -o "${MACOS_DIR}/Mac ASC"

# Create Info.plist file to hide Dock icon, set app properties, and lock network access
echo "Creating Info.plist..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Mac ASC</string>
    <key>CFBundleIdentifier</key>
    <string>com.rian445.MacASC</string>
    <key>CFBundleName</key>
    <string>Mac ASC</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
</dict>
</plist>
EOF

# Make sure binary is executable
chmod +x "${MACOS_DIR}/Mac ASC"

echo "=== Build Completed Successfully! ==="

# Build Installer DMG
echo "=== Packaging Installer DMG ==="
DMG_TEMP_DIR="dmg_temp"
mkdir -p "$DMG_TEMP_DIR"

# Copy the app bundle
cp -R "Mac ASC.app" "$DMG_TEMP_DIR/"

# Create symlink to /Applications
ln -sf /Applications "$DMG_TEMP_DIR/Applications"

# Build DMG using hdiutil
DMG_NAME="Mac_ASC.dmg"
rm -f "$DMG_NAME"
hdiutil create -volname "Mac ASC" -srcfolder "$DMG_TEMP_DIR" -ov -format UDZO "$DMG_NAME"

# Clean up temp dir
rm -rf "$DMG_TEMP_DIR"

echo "=== DMG Created Successfully: ${DMG_NAME} ==="
