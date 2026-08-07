#!/usr/bin/env bash

set -euo pipefail

github_api_request() {
  local url="$1"
  local repo="${2:-Ajanth/scry-tab}"
  curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$repo$url"
}

# Releases live in the public repo, so download counts must be read from there; this repo is
# private and has no release assets to count.
public_repo_api_request() {
  github_api_request "$1" "Ajanth/scrytab-public"
}

unicode_sort() {
  python3 -c 'import sys, unicodedata; print("".join(sorted((line for line in sys.stdin if line.strip()), key=lambda s: unicodedata.normalize("NFKD", s.casefold()))), end="")'
}

github_contributors() {
  github_api_request "/contributors" |
    jq -r '.[]|("[" + .login + "](" + .html_url + ")")' |
    sed -e '/semantic-release-bot/d' |
    unicode_sort |
    awk '{printf "%s%s", sep, $0; sep=", "} END{print ""}'
}

# Rewrite only the "Developed ScryTab" section of docs/contributors.md. Everything from
# "## Built AltTab" down is frozen: it carries the GPL-3.0 attribution for the upstream
# AltTab authors and translators, which CI must never overwrite.
update_developer_contributors() {
  local file="docs/contributors.md"
  {
    echo "## Developed ScryTab"
    echo
    github_contributors
    echo
    sed -n '/## Built AltTab/,$p' "$file"
  } > "$file.tmp" && mv "$file.tmp" "$file"
}

get_total_downloads() {
  local downloads=0
  local page=1
  while true; do
    local response
    response=$(public_repo_api_request "/releases?per_page=100&page=$page")
    # Safely sum all download counts, even if assets are empty
    local count
    count=$(echo "$response" | jq '[.[]?.assets[]?.download_count // 0] | add // 0')
    downloads=$((downloads + count))
    # Stop if no more releases
    if [[ $(echo "$response" | jq 'length') -lt 1 ]]; then
      break
    fi
    page=$((page + 1))
  done
  echo "$downloads"
}

get_stars() {
  public_repo_api_request "" | jq '.stargazers_count'
}

format_number() {
  local NUM=$1
  if (( NUM >= 1000000 )); then
    printf "%.1fM" "$(echo "$NUM/1000000" | bc -l)"
  elif (( NUM >= 1000 )); then
    printf "%.0fK" "$(echo "$NUM/1000" | bc -l)"
  else
    printf "%d" "$NUM"
  fi
}

downloads=$(format_number "$(get_total_downloads)")
stars=$(format_number "$(get_stars)")

# Stats are baked into docs/readme/main.svg (one consolidated SVG that holds
# the hero, stats, CTAs, and screenshot). Each stat text element is preceded by
# an XML comment marker — anchor sed on the marker and replace whatever value
# follows up to the next `<` (i.e. the closing `</text>`).
sed -i "" -E "s|(<!--downloads-->)[^<]*|\1${downloads}|" "docs/readme/main.svg"
sed -i "" -E "s|(<!--stars-->)[^<]*|\1${stars}|" "docs/readme/main.svg"

update_developer_contributors
