#!/bin/bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
appPath="$repoRoot/DerivedData/Build/Products/Debug/ScryTab.app"

killExistingScryTabProcesses() {
    if ! pgrep -x ScryTab >/dev/null 2>&1; then
        return
    fi
    pkill -TERM -x ScryTab || true
    for _ in {1..50}; do
        if ! pgrep -x ScryTab >/dev/null 2>&1; then
            return
        fi
        sleep 0.1
    done
    pkill -KILL -x ScryTab || true
    for _ in {1..50}; do
        if ! pgrep -x ScryTab >/dev/null 2>&1; then
            return
        fi
        sleep 0.1
    done
    echo "Failed to terminate existing ScryTab processes" >&2
    exit 1
}

killExistingScryTabProcesses
open -n "$appPath" --args --logs=debug
