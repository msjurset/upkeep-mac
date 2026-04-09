#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: release.sh <version> (e.g. 1.1.0)}"
APP_NAME="Upkeep"
BUNDLE="${APP_NAME}.app"
DMG="${APP_NAME}-${VERSION}.dmg"
SIGN_TOOL=".build/artifacts/sparkle/Sparkle/bin/sign_update"
SIGN_IDENTITY="Developer ID Application: Mark Sjurseth (RR3C36U9G4)"
NOTARY_PROFILE="notarytool-profile"
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

# Codesign
echo "==> Codesigning..."
codesign --deep --force --options runtime \
    --sign "${SIGN_IDENTITY}" \
    "${BUNDLE}/Contents/Frameworks/Sparkle.framework"
codesign --force --options runtime \
    --sign "${SIGN_IDENTITY}" \
    --entitlements /dev/stdin <<ENTITLEMENTS "${BUNDLE}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

echo "  Verifying signature..."
codesign --verify --deep --strict "${BUNDLE}"
echo "  Signature OK"

echo "==> Creating DMG..."

# Generate background if missing
test -f dmg-background.png || swift scripts/generate-dmg-bg.swift

rm -f "${DMG}"
create-dmg \
    --volname "${APP_NAME}" \
    --background "dmg-background.png" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 80 \
    --icon "${BUNDLE}" 170 170 \
    --app-drop-link 490 170 \
    --hide-extension "${BUNDLE}" \
    --no-internet-enable \
    "${DMG}" \
    "${BUNDLE}"

# Codesign the DMG
codesign --force --sign "${SIGN_IDENTITY}" "${DMG}"

# Notarize
echo "==> Notarizing DMG (this may take a few minutes)..."
xcrun notarytool submit "${DMG}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "${DMG}"

# Sign DMG with Sparkle EdDSA
echo "==> Signing DMG with Sparkle EdDSA..."
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

echo "  Sparkle signature: ${SIGNATURE}"
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
