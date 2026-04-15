#!/bin/bash
set -euo pipefail

# ============================================
# ClaudeBridgeApp Release Build Script
# ============================================
# Usage:
#   ./scripts/release.sh 1.1.0
#
# Prerequisites:
#   1. Generate EdDSA key: $(find ~/Library/Developer/Xcode/DerivedData -name generate_keys -type f | head -1)
#   2. Replace SUPublicEDKey in Info.plist with the generated public key
# ============================================

VERSION="${1:?Usage: ./scripts/release.sh <version>}"
BUILD_NUMBER="${2:-$(date +%s)}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/ClaudeBridgeApp.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
ZIP_PATH="${BUILD_DIR}/ClaudeBridgeApp.zip"

echo "🔨 Building ClaudeBridgeApp v${VERSION} (build ${BUILD_NUMBER})..."

# Clean
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Archive
xcodebuild archive \
  -project "${PROJECT_DIR}/ClaudeBridgeApp.xcodeproj" \
  -scheme ClaudeBridgeApp \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  MARKETING_VERSION="${VERSION}" \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
  | tail -5

echo "📦 Exporting app..."

# Create export options plist
cat > "${BUILD_DIR}/ExportOptions.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
</dict>
</plist>
PLIST

# Export .app from archive
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
  -exportPath "${EXPORT_PATH}" \
  | tail -3

# Zip the .app
echo "🗜 Creating zip..."
cd "${EXPORT_PATH}"
zip -r -y "${ZIP_PATH}" ClaudeBridgeApp.app
cd "${PROJECT_DIR}"

# Sign with Sparkle EdDSA
echo "🔑 Signing with EdDSA..."
SIGN_TOOL=$(find ~/Library/Developer/Xcode/DerivedData -name sign_update -type f 2>/dev/null | head -1)
if [ -z "$SIGN_TOOL" ]; then
  echo "⚠ sign_update not found. Build the project in Xcode first to get Sparkle tools."
  echo "  Then run: ${SIGN_TOOL:-sign_update} ${ZIP_PATH}"
  echo ""
  echo "📄 Zip file ready at: ${ZIP_PATH}"
  echo "📏 File size: $(wc -c < "${ZIP_PATH}" | tr -d ' ') bytes"
  exit 0
fi

SIGN_OUTPUT=$("${SIGN_TOOL}" "${ZIP_PATH}")
echo "${SIGN_OUTPUT}"

# Parse signature and length from output
ED_SIGNATURE=$(echo "${SIGN_OUTPUT}" | grep 'sparkle:edSignature=' | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
FILE_LENGTH=$(wc -c < "${ZIP_PATH}" | tr -d ' ')

echo ""
echo "✅ Release build complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📄 Zip:       ${ZIP_PATH}"
echo "📏 Size:      ${FILE_LENGTH} bytes"
echo "🔑 Signature: ${ED_SIGNATURE}"
echo ""
echo "📝 Next steps:"
echo "  1. Update appcast.xml with this item:"
echo ""
cat << APPCAST
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <pubDate>$(date -R)</pubDate>
      <enclosure
        url="https://github.com/xuhaoyuan/ClaudeBridgeApp/releases/download/v${VERSION}/ClaudeBridgeApp.zip"
        sparkle:edSignature="${ED_SIGNATURE}"
        length="${FILE_LENGTH}"
        type="application/octet-stream"
      />
    </item>
APPCAST
echo ""
echo "  2. Commit appcast.xml and push to main"
echo "  3. Create GitHub Release v${VERSION} and upload ${ZIP_PATH}"

