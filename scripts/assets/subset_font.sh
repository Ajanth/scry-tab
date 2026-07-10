#!/usr/bin/env bash

set -exu

# Source font: developer machine's locally-installed SF Pro Text Regular from Apple's
# SF Symbols.app (https://developer.apple.com/sf-symbols/). Avoids tracking a 2 MB
# binary in the repo, and picks up Apple's latest glyph refinements automatically
# whenever the developer updates SF Symbols.app.
SOURCE_FONT=/Library/Fonts/SF-Pro-Text-Regular.otf
if [ ! -f "$SOURCE_FONT" ]; then
  echo "Missing $SOURCE_FONT — install SF Symbols.app from https://developer.apple.com/sf-symbols/" >&2
  exit 1
fi

# Code points MUST stay in sync with the `Symbols` enum in
# src/switcher/main-window/TileFontIconView.swift plus the 20 space-number variants
# synthesized at runtime in StatusIconsView.symbolForSpace. SF Symbols live in
# Apple's private-use Unicode planes, so keep them as explicit code points here
# rather than raw glyphs that look like mojibake in diffs.
SYMBOL_UNICODES=(
  U+1020A1 U+100174 U+10004E U+10004C U+100567
  U+100038 U+10003A U+10003C U+10003E U+100040 U+100042 U+100044 U+100471 U+100046 U+100048 U+10004A U+100473 U+1004F5 U+1004F6 U+1004F7 U+1004F8 U+1004F9 U+1004FA U+1004FB U+1004FC U+1004FD U+1004FE U+1004FF U+100500 U+100501 U+100502 U+100503 U+100504 U+100505 U+100506 U+100507 U+100508 U+100509 U+10056C
  U+100039 U+10003B U+10003D U+10003F U+100041 U+100618 U+100043 U+100045 U+100472 U+100047 U+100049 U+10004B U+100474 U+100514 U+100515 U+100516 U+100517 U+100518 U+100519 U+10051A U+10051B U+10051C U+10051D U+10051E U+10051F U+100520 U+100521 U+100522 U+100523 U+100524 U+100525 U+100526 U+100527 U+100528 U+10056D
  U+100765 U+100194 U+1008CB U+10027B U+10057E U+1008B9 U+100BD4 U+1006ED U+10017C U+10017D U+25B4 U+25BE U+10004F U+1001F0 U+10029B U+1002AB U+10140E U+10140F U+101410 U+1001BF U+1001AD U+1001BA U+1007DB U+1002C3
)
UNICODES=$(IFS=,; echo "${SYMBOL_UNICODES[*]}")
SUBSETTER=()
if command -v pipenv >/dev/null 2>&1; then
  VENV=$(pipenv --venv)
  if [ -x "$VENV/bin/pyftsubset" ]; then
    SUBSETTER=("$VENV/bin/pyftsubset")
  fi
fi
if [ ${#SUBSETTER[@]} -eq 0 ] && command -v pyftsubset >/dev/null 2>&1; then
  SUBSETTER=("$(command -v pyftsubset)")
fi
if [ ${#SUBSETTER[@]} -eq 0 ] && python3 -c 'import fontTools.subset' >/dev/null 2>&1; then
  SUBSETTER=(python3 -m fontTools.subset)
fi
if [ ${#SUBSETTER[@]} -eq 0 ]; then
  echo "Missing FontTools — install pipenv or fonttools" >&2
  exit 1
fi
"${SUBSETTER[@]}" "$SOURCE_FONT" \
  --output-file=resources/SF-Pro-Text-Regular.otf \
  --unicodes="$UNICODES"
