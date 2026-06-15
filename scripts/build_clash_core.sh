#!/bin/bash
#
# Build Clash Go core for iOS using gomobile.
# This script compiles the ClashCore bridge package into an .xcframework
# that can be embedded in the Xcode project.
#
# Prerequisites:
#   - macOS with Xcode 15+
#   - Go 1.21+
#   - gomobile (go install golang.org/x/mobile/cmd/gomobile@latest)
#   - gomobile init (run once after installing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BRIDGE_DIR="$PROJECT_DIR/ClashCoreBridge"
OUTPUT_DIR="$PROJECT_DIR/ClashCore"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Building Clash Core for iOS ===${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v go &> /dev/null; then
    echo -e "${RED}Error: Go is not installed. Please install Go 1.21+.${NC}"
    exit 1
fi

GO_VERSION=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+')
echo "Go version: $GO_VERSION"

if ! command -v gomobile &> /dev/null; then
    echo -e "${YELLOW}gomobile not found. Installing...${NC}"
    go install golang.org/x/mobile/cmd/gomobile@latest
fi

if ! gomobile version &> /dev/null; then
    echo -e "${YELLOW}Initializing gomobile...${NC}"
    gomobile init
fi

echo -e "${YELLOW}gomobile is ready${NC}"

# Clean output
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Download dependencies
echo -e "${YELLOW}Downloading Go dependencies...${NC}"
cd "$BRIDGE_DIR"
go mod tidy

# Build for iOS
echo -e "${YELLOW}Building ClashCore.xcframework for iOS...${NC}"
gomobile bind \
    -target ios \
    -iosversion 15.0 \
    -o "$OUTPUT_DIR/ClashCore.xcframework" \
    -ldflags "-s -w" \
    ./

echo -e "${GREEN}✓ ClashCore.xcframework built successfully!${NC}"
echo -e "${GREEN}  Output: $OUTPUT_DIR/ClashCore.xcframework${NC}"

# Show framework info
echo -e "${YELLOW}Framework structure:${NC}"
find "$OUTPUT_DIR/ClashCore.xcframework" -maxdepth 3 -type d | head -10

echo ""
echo -e "${GREEN}Done! The framework is ready to be added to Xcode.${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Open ClashX.xcodeproj in Xcode"
echo "  2. Add ClashCore.xcframework to the project"
echo "  3. Ensure it's embedded in both the main app and tunnel targets"
echo "  4. Build and run"
