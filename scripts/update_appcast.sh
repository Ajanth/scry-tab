#!/usr/bin/env bash

set -euo pipefail

version="$(cat "$VERSION_FILE")"
date="$(date +'%a, %d %b %Y %H:%M:%S %z')"
minimumSystemVersion="$(awk -F ' = ' '/MACOSX_DEPLOYMENT_TARGET/ { print $2; }' < config/base.xcconfig)"
zipName="$APP_NAME-$version.zip"
# Sparkle 2.9 removed `-s <key>`: "Specifying private key as an argument is no longer supported."
# The key is piped to --ed-key-file - so it never appears in the process list or CI logs.
edSignatureAndLength=$(printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | vendor/Sparkle/bin/sign_update --ed-key-file - "$XCODE_BUILD_PATH/$zipName")

echo "
    <item>
      <title>Version $version</title>
      <pubDate>$date</pubDate>
      <sparkle:minimumSystemVersion>$minimumSystemVersion</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/Ajanth/scrytab-public/releases/tag/v$version</sparkle:releaseNotesLink>
      <enclosure
        url=\"https://github.com/Ajanth/scrytab-public/releases/download/v$version/$zipName\"
        sparkle:version=\"$version\"
        sparkle:shortVersionString=\"$version\"
        $edSignatureAndLength
        type=\"application/octet-stream\"/>
    </item>
" > ITEM.txt

sed -i '' -e "/<\/language>/r ITEM.txt" appcast.xml
