#!/bin/bash
set -euo pipefail

# ============================================
# ClaudeBridgeApp Release Build Script
# ============================================
#
# 使用方法:
#   ./scripts/release.sh 1.1.0
#
# 首次使用前的一次性设置:
#   1. 在 Xcode 中构建一次项目（为了下载 Sparkle 工具）
#   2. 生成签名密钥:
#      $(find ~/Library/Developer/Xcode/DerivedData -name generate_keys -type f | head -1)
#      会输出公钥，把它填入 ClaudeBridgeApp/Info.plist 的 SUPublicEDKey
#      私钥自动存入 macOS 钥匙串，不需要手动管理
#
# 不需要 Apple 开发者账号！
# ============================================

VERSION="${1:?用法: ./scripts/release.sh <版本号>  例如: ./scripts/release.sh 1.1.0}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="ClaudeBridgeApp"
ZIP_NAME="ClaudeBridge"
ZIP_PATH="${BUILD_DIR}/${ZIP_NAME}.zip"

echo ""
echo "🔨 Building ${APP_NAME} v${VERSION}..."
echo ""

# 清理
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 直接构建 Release（不需要 archive/export，避免签名问题）
xcodebuild build \
  -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "${BUILD_DIR}/DerivedData" \
  MARKETING_VERSION="${VERSION}" \
  CURRENT_PROJECT_VERSION="${VERSION}" \
  CODE_SIGN_IDENTITY="-" \
  2>&1 | tail -5

# 找到构建出的 .app
APP_PATH=$(find "${BUILD_DIR}/DerivedData" -name "${APP_NAME}.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
  echo "❌ Build failed - ${APP_NAME}.app not found"
  exit 1
fi

echo "✅ Build succeeded: ${APP_PATH}"

# 压缩
echo "🗜  Creating zip..."
cd "$(dirname "$APP_PATH")"
zip -r -y "${ZIP_PATH}" "${APP_NAME}.app"
cd "${PROJECT_DIR}"

FILE_LENGTH=$(wc -c < "${ZIP_PATH}" | tr -d ' ')
echo "📦 Zip: ${ZIP_PATH} (${FILE_LENGTH} bytes)"

# 用 Sparkle EdDSA 签名
echo ""
echo "🔑 Signing with Sparkle EdDSA..."
SIGN_TOOL=$(find ~/Library/Developer/Xcode/DerivedData -name sign_update -type f 2>/dev/null | head -1)

if [ -z "$SIGN_TOOL" ]; then
  echo ""
  echo "⚠️  sign_update 工具未找到！"
  echo "   请先在 Xcode 中 Build 一次项目，Sparkle 工具会自动下载。"
  echo "   然后重新运行此脚本。"
  echo ""
  echo "   如果已经 Build 过，试试:"
  echo "   find ~/Library/Developer/Xcode/DerivedData -name sign_update -type f"
  exit 1
fi

SIGN_OUTPUT=$("${SIGN_TOOL}" "${ZIP_PATH}" 2>&1)
echo "${SIGN_OUTPUT}"

# 解析签名
ED_SIGNATURE=$(echo "${SIGN_OUTPUT}" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Release v${VERSION} 构建完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 接下来的步骤:"
echo ""
echo "  Step 1: 把下面这段 XML 粘贴到 appcast.xml 的 <channel> 里:"
echo ""
echo "    <item>"
echo "      <title>Version ${VERSION}</title>"
echo "      <sparkle:version>${VERSION}</sparkle:version>"
echo "      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>"
echo "      <pubDate>$(date -R)</pubDate>"
echo "      <enclosure"
echo "        url=\"https://github.com/xuhaoyuan/${APP_NAME}/releases/download/v${VERSION}/${ZIP_NAME}.zip\""
echo "        sparkle:edSignature=\"${ED_SIGNATURE}\""
echo "        length=\"${FILE_LENGTH}\""
echo "        type=\"application/octet-stream\""
echo "      />"
echo "    </item>"
echo ""
echo "  Step 2: 提交并推送 appcast.xml"
echo "    git add appcast.xml && git commit -m 'Update appcast for v${VERSION}' && git push"
echo ""
echo "  Step 3: 在 GitHub 创建 Release"
echo "    打开: https://github.com/xuhaoyuan/${APP_NAME}/releases/new"
echo "    Tag: v${VERSION}"
echo "    上传: ${ZIP_PATH}"
echo ""
