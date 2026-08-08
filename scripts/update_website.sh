#!/usr/bin/env bash

# Publishes the freshly-signed Sparkle feed and website release manifest to the website repo.
# Cloudflare Pages serves them at https://scrytab.pages.dev. Installed copies poll the appcast,
# while the landing and source pages read the manifest instead of hardcoding a release version.
#
# This runs last in the pipeline on purpose: the appcast's enclosure points at the GitHub
# release assets, so publishing the feed before the release exists would advertise a 404.
#
# $GH_TOKEN needs `contents: write` on the website repo.

set -euo pipefail

repo="Ajanth/scrytab-cms"
version="$(cat "$VERSION_FILE")"
releaseRoot="https://github.com/Ajanth/scrytab-public/releases/download/v$version"
manifest="$(printf '{\n  \"version\": \"%s\",\n  \"downloadUrl\": \"%s/ScryTab-%s.dmg\",\n  \"sourceUrl\": \"%s/ScryTab-%s-source.tar.gz\"\n}' "$version" "$releaseRoot" "$version" "$releaseRoot" "$version")"

publish() {
  local path="$1"
  local message="$2"
  local content="$3"
  local sha
  local -a args

  # The contents API needs the blob SHA to replace an existing file; absent on first publish.
  sha="$(gh api "repos/$repo/contents/$path" --jq '.sha' 2>/dev/null || true)"
  args=(
    -X PUT
    -f "message=$message"
    -f "content=$(printf '%s' "$content" | base64 | tr -d '\n')"
  )
  if [[ -n "$sha" ]]; then
    args+=(-f "sha=$sha")
  fi

  gh api "repos/$repo/contents/$path" "${args[@]}"
}

publish "public/appcast.xml" "chore(appcast): publish ScryTab $version" "$(<appcast.xml)"
publish "public/release.json" "chore(release): publish ScryTab $version" "$manifest"
