#!/usr/bin/env bash

set -exu

gh api repos/Ajanth/scry-tab-website/dispatches -f event_type=update-website
