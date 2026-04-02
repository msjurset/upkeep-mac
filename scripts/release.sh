#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: release.sh <version> (e.g. 1.1.0)}"
APP_NAME="Upkeep"
BUNDLE="${APP_NAME}.app"
DMG="${APP_NAME}-${VERSION}.dmg"
SIGN_TOOL=".build/artifacts/sparkle/Sparkle/bin/sign_update"
BUILD_NUM=$(git rev-list --count HEAD 2>/dev/null || echo "1")

echo "==> Building Upkeep v${VERSION} (build ${BUILD_NUM})..."

# Update version in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUM}" Info.plist

# Build release
swift build -c release

# Bundle .app
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources" "${BUNDLE}/Contents/Frameworks"
cp .build/release/Upkeep "${BUNDLE}/Contents/MacOS/${APP_NAME}"
install_name_tool -add_rpath @loader_path/../Frameworks "${BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
cp Info.plist "${BUNDLE}/Contents/Info.plist"
cp -R .build/arm64-apple-macosx/release/Sparkle.framework "${BUNDLE}/Contents/Frameworks/"

# Generate icon if needed
test -f AppIcon.icns || swift scripts/generate-icon.swift
cp AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"

echo "==> Creating DMG..."

# Create DMG
rm -f "${DMG}"
mkdir -p dmg_staging
cp -R "${BUNDLE}" dmg_staging/
ln -sf /Applications dmg_staging/Applications

hdiutil create -volname "${APP_NAME}" \
    -srcfolder dmg_staging \
    -ov -format UDZO \
    "${DMG}"

rm -rf dmg_staging

# Sign DMG with Sparkle EdDSA
echo "==> Signing DMG..."
if [ ! -f "${SIGN_TOOL}" ]; then
    echo "Sparkle sign_update tool not found. Run 'swift package resolve' first."
    exit 1
fi

SIGNATURE=$("${SIGN_TOOL}" "${DMG}" 2>&1 | grep 'sparkle:edSignature=' | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
LENGTH=$(stat -f%z "${DMG}")

if [ -z "${SIGNATURE}" ]; then
    echo "Warning: Could not extract signature. Trying alternate format..."
    SIGN_OUTPUT=$("${SIGN_TOOL}" "${DMG}" 2>&1)
    echo "sign_update output: ${SIGN_OUTPUT}"
    SIGNATURE=$(echo "${SIGN_OUTPUT}" | grep -oE '[A-Za-z0-9+/=]{40,}' | head -1)
fi

echo "  Signature: ${SIGNATURE}"
echo "  Length: ${LENGTH}"

# Generate appcast.xml
echo "==> Generating appcast.xml..."
PUBDATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
DOWNLOAD_URL="https://github.com/msjurset/upkeep-mac/releases/download/v${VERSION}/${DMG}"

cat > appcast.xml <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Upkeep</title>
    <link>https://github.com/msjurset/upkeep-mac</link>
    <description>Upkeep app updates</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${BUILD_NUM}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <pubDate>${PUBDATE}</pubDate>
      <enclosure
        url="${DOWNLOAD_URL}"
        length="${LENGTH}"
        type="application/octet-stream"
        sparkle:edSignature="${SIGNATURE}" />
    </item>
  </channel>
</rss>
APPCAST

echo "==> Committing version bump and appcast..."
git add Info.plist appcast.xml
git commit -m "Release v${VERSION}"
git tag "v${VERSION}"
git push origin main --tags

echo "==> Creating GitHub release..."
gh release create "v${VERSION}" "${DMG}" \
    --title "Upkeep v${VERSION}" \
    --notes "Upkeep v${VERSION}

Download the DMG, open it, and drag Upkeep to Applications.
Existing installations will be notified of this update automatically."

echo ""
echo "==> Release v${VERSION} complete!"
echo "    DMG: ${DMG}"
echo "    GitHub: https://github.com/msjurset/upkeep-mac/releases/tag/v${VERSION}"
echo "    Appcast: https://raw.githubusercontent.com/msjurset/upkeep-mac/main/appcast.xml"
