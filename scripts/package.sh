#!/bin/bash
#
# Package ClashX iOS app into an IPA for sideloading.
#
# This script is typically run as part of the GitHub Actions workflow.
# It can also be run locally on macOS with Xcode installed.
#
# Usage: ./scripts/package.sh [release|debug]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
CONFIGURATION="${1:-release}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Packaging ClashX for iOS ($CONFIGURATION) ===${NC}"

# Validate environment
if [ -z "${APPLE_TEAM_ID:-}" ]; then
    echo -e "${YELLOW}Warning: APPLE_TEAM_ID not set. Using development signing.${NC}"
fi

if [ -z "${BUNDLE_IDENTIFIER:-}" ]; then
    BUNDLE_IDENTIFIER="com.clashx.ios"
    echo -e "${YELLOW}Using default bundle identifier: $BUNDLE_IDENTIFIER${NC}"
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Clean previous builds
rm -rf "$BUILD_DIR/ClashX.xcarchive"
rm -rf "$BUILD_DIR/ipa"

echo -e "${YELLOW}Archiving ClashX...${NC}"

# Build and archive
xcodebuild archive \
    -project "$PROJECT_DIR/ClashX.xcodeproj" \
    -scheme ClashX \
    -configuration "$CONFIGURATION" \
    -archivePath "$BUILD_DIR/ClashX.xcarchive" \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
    | xcpretty || xcodebuild archive ... > /dev/null 2>&1

echo -e "${YELLOW}Exporting IPA...${NC}"

# Create export options plist
cat > "$BUILD_DIR/exportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadSymbols</key>
    <false/>
</dict>
</plist>
EOF

# Export IPA
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/ClashX.xcarchive" \
    -exportPath "$BUILD_DIR/ipa" \
    -exportOptionsPlist "$BUILD_DIR/exportOptions.plist" \
    -allowProvisioningUpdates \
    | xcpretty || true

# Verify IPA exists
IPA_PATH="$BUILD_DIR/ipa/ClashX.ipa"
if [ -f "$IPA_PATH" ]; then
    IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
    echo -e "${GREEN}✓ IPA generated successfully!${NC}"
    echo -e "${GREEN}  Path: $IPA_PATH${NC}"
    echo -e "${GREEN}  Size: $IPA_SIZE${NC}"

    # Generate SHA256 for verification
    SHA=$(shasum -a 256 "$IPA_PATH" | cut -d' ' -f1)
    echo -e "${GREEN}  SHA256: $SHA${NC}"
else
    echo -e "${RED}Error: IPA not found at $IPA_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}Done!${NC}"
echo ""
echo -e "${YELLOW}Installation instructions:${NC}"
echo "  1. Transfer ClashX.ipa to your iPhone (AirDrop, HTTP server, etc.)"
echo "  2. Open in AltStore or use SideStore to install"
echo "  3. Go to Settings > General > VPN & Device Management"
echo "  4. Trust the developer certificate"
echo "  5. Open ClashX and configure"
