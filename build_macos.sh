#!/bin/bash
set -euo pipefail

#=============================================================================
# Lona macOS Build & DMG Packaging Script
# 
# Usage:
#   ./build_macos.sh                    # Build + create DMG (no signing)
#   ./build_macos.sh --sign             # Build + sign + create signed DMG
#   ./build_macos.sh --sign --notarize  # Build + sign + notarize + staple
#
# Prerequisites:
#   - Flutter SDK installed and in PATH
#   - Xcode and command line tools installed
#   - For signing: Developer ID Application certificate in keychain
#   - For notarization: Apple ID app-specific password stored in keychain
#=============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Lona"
BUNDLE_ID="com.focuskpi.linkedup"
TEAM_ID="3GQ93ABMNG"

# Read version from pubspec.yaml
VERSION=$(grep '^version:' "$SCRIPT_DIR/pubspec.yaml" | sed 's/version: //' | cut -d'+' -f1)
BUILD_NUMBER=$(grep '^version:' "$SCRIPT_DIR/pubspec.yaml" | sed 's/version: //' | cut -d'+' -f2)

# Signing configuration
SIGN_IDENTITY="Developer ID Application"  # Will be auto-detected
SIGN_IDENTITY_FULL=""  # Set during signing step
DMG_FILENAME="${APP_NAME}_${VERSION}_universal.dmg"
BUILD_DIR="$SCRIPT_DIR/build/macos/Build/Products/Release"
OUTPUT_DIR="$SCRIPT_DIR/build/dmg"

# Parse arguments
DO_SIGN=false
DO_NOTARIZE=false
APPLE_ID=""
APP_PASSWORD_KEYCHAIN_ITEM="AC_PASSWORD"

while [[ $# -gt 0 ]]; do
  case $1 in
    --sign)
      DO_SIGN=true
      shift
      ;;
    --notarize)
      DO_NOTARIZE=true
      DO_SIGN=true  # Notarization requires signing
      shift
      ;;
    --apple-id)
      APPLE_ID="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --sign              Sign the app and DMG with Developer ID"
      echo "  --notarize          Submit for Apple notarization (implies --sign)"
      echo "  --apple-id EMAIL    Apple ID for notarization"
      echo "  --help              Show this help message"
      echo ""
      echo "Environment Variables:"
      echo "  AC_PASSWORD         App-specific password for notarization"
      echo "                      (or store in keychain as 'AC_PASSWORD')"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

#=============================================================================
# Helper Functions
#=============================================================================

print_step() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
  echo -e "${GREEN}  ✓ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}  ⚠ $1${NC}"
}

print_error() {
  echo -e "${RED}  ✗ $1${NC}"
}

#=============================================================================
# Step 1: Pre-flight checks
#=============================================================================
print_step "Pre-flight Checks"

# Check Flutter
if ! command -v flutter &> /dev/null; then
  print_error "Flutter not found in PATH"
  exit 1
fi
print_success "Flutter found: $(flutter --version | head -1)"

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
  print_error "Xcode command line tools not found"
  exit 1
fi
print_success "Xcode found: $(xcodebuild -version | head -1)"

# Check signing certificate if signing
if [ "$DO_SIGN" = true ]; then
  SIGN_IDENTITY_FULL=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
  if [ -z "$SIGN_IDENTITY_FULL" ]; then
    print_error "Developer ID Application certificate not found in keychain"
    echo ""
    echo -e "${YELLOW}  To create a Developer ID certificate:${NC}"
    echo "  1. Open https://developer.apple.com/account/resources/certificates/list"
    echo "  2. Click '+' to create a new certificate"
    echo "  3. Select 'Developer ID Application'"
    echo "  4. Follow the steps to create a CSR from Keychain Access"
    echo "  5. Download and install the certificate"
    echo ""
    echo -e "${YELLOW}  Or run without --sign to create an unsigned DMG:${NC}"
    echo "  ./build_macos.sh"
    exit 1
  fi
  print_success "Signing identity: $SIGN_IDENTITY_FULL"
fi

echo ""
echo -e "  App:     ${APP_NAME}"
echo -e "  Version: ${VERSION} (build ${BUILD_NUMBER})"
echo -e "  Bundle:  ${BUNDLE_ID}"
echo -e "  Sign:    $([ "$DO_SIGN" = true ] && echo "Yes" || echo "No")"
echo -e "  Notarize: $([ "$DO_NOTARIZE" = true ] && echo "Yes" || echo "No")"

#=============================================================================
# Step 2: Clean and build Flutter macOS app
#=============================================================================
print_step "Building Flutter macOS Release"

cd "$SCRIPT_DIR"

# Run fix_build.sh if it exists (Xcode 15 compatibility)
if [ -f "fix_build.sh" ]; then
  print_warning "Running fix_build.sh for Xcode compatibility..."
  bash fix_build.sh 2>/dev/null || true
fi

# Clean previous build
flutter clean
print_success "Cleaned previous build"

# Get dependencies
flutter pub get
print_success "Dependencies resolved"

# Build macOS release
flutter build macos --release
print_success "Flutter macOS build complete"

# Verify app exists
APP_PATH="$BUILD_DIR/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
  print_error "Build output not found at: $APP_PATH"
  exit 1
fi
print_success "App bundle: $APP_PATH"

#=============================================================================
# Step 3: Code signing (if --sign)
#=============================================================================
if [ "$DO_SIGN" = true ]; then
  print_step "Code Signing with Developer ID"
  
  # Embed provisioning profile
  PROFILE="$SCRIPT_DIR/macos/Runner/embedded.provisionprofile"
  if [ -f "$PROFILE" ]; then
    cp "$PROFILE" "$APP_PATH/Contents/embedded.provisionprofile"
    print_success "Provisioning profile embedded"
  else
    print_warning "No provisioning profile found at $PROFILE"
    print_warning "Some features (keychain, push) may not work"
  fi

  # Sign all embedded frameworks and dylibs first
  find "$APP_PATH" -name "*.framework" -o -name "*.dylib" | while read -r lib; do
    codesign --deep --force --options runtime \
      --sign "$SIGN_IDENTITY_FULL" \
      --timestamp \
      "$lib" 2>/dev/null || true
  done
  print_success "Signed embedded frameworks"

  # Sign the main app bundle
  codesign --deep --force --options runtime \
    --sign "$SIGN_IDENTITY_FULL" \
    --timestamp \
    --entitlements "$SCRIPT_DIR/macos/Runner/Release-DirectDistribution.entitlements" \
    "$APP_PATH"
  print_success "Signed app bundle"

  # Verify signature
  codesign --verify --deep --strict "$APP_PATH"
  print_success "Signature verified"
fi

#=============================================================================
# Step 4: Create DMG
#=============================================================================
print_step "Creating DMG Installer"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Remove old DMG if exists
rm -f "$OUTPUT_DIR/$DMG_FILENAME"

# Create a temporary directory for DMG contents
DMG_TEMP="$OUTPUT_DIR/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app to temp directory
cp -R "$APP_PATH" "$DMG_TEMP/"

# Create a symlink to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_TEMP" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$OUTPUT_DIR/$DMG_FILENAME"

# Clean up temp
rm -rf "$DMG_TEMP"

print_success "DMG created: $OUTPUT_DIR/$DMG_FILENAME"

# Show file size
DMG_SIZE=$(du -h "$OUTPUT_DIR/$DMG_FILENAME" | cut -f1)
print_success "DMG size: $DMG_SIZE"

#=============================================================================
# Step 5: Sign DMG (if --sign)
#=============================================================================
if [ "$DO_SIGN" = true ]; then
  print_step "Signing DMG"
  
  codesign --sign "$SIGN_IDENTITY_FULL" \
    --timestamp \
    "$OUTPUT_DIR/$DMG_FILENAME"
  
  print_success "DMG signed"
fi

#=============================================================================
# Step 6: Notarize (if --notarize)
#=============================================================================
if [ "$DO_NOTARIZE" = true ]; then
  print_step "Submitting for Apple Notarization"
  
  if [ -z "$APPLE_ID" ]; then
    print_error "Apple ID required for notarization. Use --apple-id EMAIL"
    exit 1
  fi

  # Check for app-specific password
  if [ -z "${AC_PASSWORD:-}" ]; then
    print_warning "AC_PASSWORD not set. Trying keychain item '$APP_PASSWORD_KEYCHAIN_ITEM'..."
    NOTARIZE_PASSWORD="@keychain:$APP_PASSWORD_KEYCHAIN_ITEM"
  else
    NOTARIZE_PASSWORD="$AC_PASSWORD"
  fi

  # Submit for notarization
  echo "  Submitting... (this may take several minutes)"
  xcrun notarytool submit "$OUTPUT_DIR/$DMG_FILENAME" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$NOTARIZE_PASSWORD" \
    --wait

  print_success "Notarization complete"

  # Staple the ticket
  print_step "Stapling Notarization Ticket"
  xcrun stapler staple "$OUTPUT_DIR/$DMG_FILENAME"
  print_success "Ticket stapled to DMG"
fi

#=============================================================================
# Step 7: Copy to project root for easy access
#=============================================================================
print_step "Finalizing"

cp "$OUTPUT_DIR/$DMG_FILENAME" "$SCRIPT_DIR/$DMG_FILENAME"
print_success "DMG copied to: $SCRIPT_DIR/$DMG_FILENAME"

#=============================================================================
# Summary
#=============================================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Build Complete! 🎉${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  DMG:     ${SCRIPT_DIR}/${DMG_FILENAME}"
echo -e "  Size:    ${DMG_SIZE}"
echo -e "  Version: ${VERSION} (build ${BUILD_NUMBER})"
echo -e "  Signed:  $([ "$DO_SIGN" = true ] && echo "Yes ✓" || echo "No (unsigned)")"
echo -e "  Notarized: $([ "$DO_NOTARIZE" = true ] && echo "Yes ✓" || echo "No")"
echo ""

if [ "$DO_SIGN" = false ]; then
  echo -e "${YELLOW}  ⚠ Note: This DMG is unsigned. Users may see Gatekeeper warnings.${NC}"
  echo -e "${YELLOW}    To sign and notarize, run:${NC}"
  echo -e "${YELLOW}    ./build_macos.sh --sign --notarize --apple-id YOUR_EMAIL${NC}"
  echo ""
fi

echo -e "  Next steps:"
echo -e "  1. Upload DMG to GitHub Releases:"
echo -e "     gh release create v${VERSION} ${DMG_FILENAME} --repo FocusKPI-DS/LinkedUp-Club-MacOS"
echo -e "  2. Or copy the download URL and update the website"
echo ""
