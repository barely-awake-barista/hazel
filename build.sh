#!/bin/bash
set -e

# Configuration
APP_NAME="hazel"
BUNDLE_ID="com.harryfrz.hazel"
BUNDLE_DIR="$PWD/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Building ${APP_NAME} for macOS 26..."

# Clean
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Compile Swift files
# We need to exclude the resources folder and find all .swift files
SWIFT_FILES=$(find "$PWD/hazel" -name "*.swift" -not -path "*/Resources/*")
echo "📦 Compiling Swift sources..."
swiftc -O -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -target arm64-apple-macos26 \
    -parse-as-library \
    -o "${MACOS_DIR}/${APP_NAME}" \
    ${SWIFT_FILES}

# Info.plist as per rule #3
echo "📝 Generating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>hazel</string>
    <key>CFBundleIconName</key>
    <string>hazel</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Assets Compilation per macOS 26 Icon Integration Guide
echo "🎨 Compiling Assets..."
xcrun actool "$PWD/hazel.icon" "$PWD/hazel/Assets.xcassets" \
    --compile "${RESOURCES_DIR}" \
    --minimum-deployment-target 26.0 \
    --platform macosx \
    --app-icon hazel \
    --output-partial-info-plist "${CONTENTS_DIR}/icon.plist"

# Resources (Fonts)
if [ -d "$PWD/hazel/Resources/Fonts" ]; then
    echo "🔤 Copying fonts..."
    cp -R "$PWD/hazel/Resources/Fonts/" "${RESOURCES_DIR}/"
fi

# Apply entitlements if needed
# For now, let's just use ad-hoc signing as per rule #3
echo "🔐 Sign & Quarantine..."
xattr -cr "${BUNDLE_DIR}"
codesign --force --deep -s - "${BUNDLE_DIR}"

echo "🚀 Built successfully at ${BUNDLE_DIR}"
