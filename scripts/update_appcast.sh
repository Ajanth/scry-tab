#!/usr/bin/env bash

set -euo pipefail

release_notes_html() {
  local previousTag conventional breaking subject note found
  previousTag="$(git describe --tags --abbrev=0 HEAD)"
  conventional='^(feat|fix|perf|revert)(\([^)]*\))?!?:[[:space:]]*(.+)$'
  breaking='^[[:alpha:]]+(\([^)]*\))?!:[[:space:]]*(.+)$'
  found=false
  while IFS= read -r subject; do
    if [[ "$subject" =~ $conventional ]]; then
      note="${BASH_REMATCH[3]}"
    elif [[ "$subject" =~ $breaking ]]; then
      note="${BASH_REMATCH[2]}"
    else
      continue
    fi
    note="$(printf '%s\n' "$note" | awk '{ text = toupper(substr($0, 1, 1)) substr($0, 2); if (text !~ /[.!?]$/) text = text "."; print text }' | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
    printf '          <li>%s</li>\n' "$note"
    found=true
  done < <(git log --no-merges --reverse --format=%s "$previousTag..HEAD")
  if [[ "$found" == false ]]; then
    printf '          <li>Maintenance and reliability improvements.</li>\n'
  fi
}

version="$(cat "$VERSION_FILE")"
date="$(date +'%a, %d %b %Y %H:%M:%S %z')"
minimumSystemVersion="$(awk -F ' = ' '/MACOSX_DEPLOYMENT_TARGET/ { print $2; }' < config/base.xcconfig)"
zipName="$APP_NAME-$version.zip"
# Sparkle 2.9 removed `-s <key>`: "Specifying private key as an argument is no longer supported."
# The key is piped to --ed-key-file - so it never appears in the process list or CI logs.
edSignatureAndLength=$(printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | vendor/Sparkle/bin/sign_update --ed-key-file - "$XCODE_BUILD_PATH/$zipName")
releaseNotes="$(release_notes_html)"

# Advertise only the latest release. Drop stale feed items before inserting the newly
# signed enclosure so Sparkle and the website never advertise withdrawn downloads.
sed -i '' -e '/<item>/,/<\/item>/d' appcast.xml

echo "
    <item>
      <title>Version $version</title>
      <pubDate>$date</pubDate>
      <sparkle:minimumSystemVersion>$minimumSystemVersion</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <ul>
$releaseNotes
        </ul>
        <p><a href=\"https://github.com/Ajanth/scry-tab/releases/tag/v$version\">Full release notes</a></p>
      ]]></description>
      <enclosure
        url=\"https://github.com/Ajanth/scry-tab/releases/download/v$version/$zipName\"
        sparkle:version=\"$version\"
        sparkle:shortVersionString=\"$version\"
        $edSignatureAndLength
        type=\"application/octet-stream\"/>
    </item>
" > ITEM.txt

sed -i '' -e "/<\/language>/r ITEM.txt" appcast.xml
xmllint --noout appcast.xml
[[ $(xmllint --xpath 'count(//*[local-name()="item"])' appcast.xml) == "1" ]]
