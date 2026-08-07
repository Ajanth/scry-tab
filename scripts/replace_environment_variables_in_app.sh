#!/usr/bin/env bash

set -euo pipefail

# Inject CI values via the same xcconfig override mechanism used locally.
# Xcode substitutes $(VAR) refs into Info.plist at build time.
# xcconfig treats // as a comment, so break DSN URLs with /$()/.
SENTRY_DSN_XCCONFIG=$(printf '%s' "$SENTRY_DSN" | sed 's#://#:/\$()/#')
cat > config/local.xcconfig <<EOF
CURRENT_PROJECT_VERSION = $(cat "$VERSION_FILE")
SENTRY_DSN = $SENTRY_DSN_XCCONFIG
EOF
