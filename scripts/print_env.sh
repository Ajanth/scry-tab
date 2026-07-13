#!/usr/bin/env bash

set -ex

pwd
env | awk -F= '/^(GITHUB_TOKEN|SENTRY_AUTH_TOKEN|APPLE_PASSWORD|APPLE_P12_CERTIFICATE|SPARKLE_ED_PRIVATE_KEY|WEBSITE_DISPATCH_TOKEN)=/ { next } { print }' | sort
jq --version
