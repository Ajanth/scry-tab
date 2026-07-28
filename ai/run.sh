#!/bin/bash

set -euo pipefail

repoRoot="$(cd "$(dirname "$0")/.." && pwd)"
appPath="$repoRoot/DerivedData/Build/Products/Debug/ScryTab.app"
shouldBuild=0

usage() {
    echo "Usage: $(basename "$0") [-b]" >&2
    echo "  -b  Build before running" >&2
    exit 1
}

while getopts ":b" opt; do
    case "$opt" in
        b) shouldBuild=1 ;;
        *) usage ;;
    esac
done

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

if [[ "$shouldBuild" -eq 1 ]]; then
    "$repoRoot/ai/build.sh"
fi

killExistingScryTabProcesses
open -n "$appPath" --args --logs=debug
