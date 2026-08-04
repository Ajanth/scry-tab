#!/usr/bin/env bash

# Publishes the freshly-signed Sparkle feed to the website repo, which Cloudflare Pages serves
# at https://scrytab.pages.dev/appcast.xml. Every installed copy polls that URL, so a stale or
# unreachable feed means nobody receives updates.
#
# This runs last in the pipeline on purpose: the appcast's enclosure points at the GitHub
# release assets, so publishing the feed before the release exists would advertise a 404.
#
# $GH_TOKEN needs `contents: write` on the website repo.

set -exu

repo="Ajanth/scrytab-cms"
path="public/appcast.xml"
version="$(cat "$VERSION_FILE")"

# the contents API needs the blob SHA to replace an existing file; absent on first publish
sha="$(gh api "repos/$repo/contents/$path" --jq '.sha' 2>/dev/null || true)"

args=(
  -X PUT
  -f "message=chore(appcast): publish ScryTab $version"
  -f "content=$(base64 -i appcast.xml | tr -d '\n')"
)
if [[ -n "$sha" ]]; then
  args+=(-f "sha=$sha")
fi

gh api "repos/$repo/contents/$path" "${args[@]}"
