#!/bin/sh
# Created by Gavin Xiang on 10/16/26.
# Copyright © 2026 PlanetArt. All rights reserved.

# Ahead-of-time Core AI compile for every iPhone and iPad architecture.
# Omitting --architecture compiles the whole iOS set. GPU is required:
# this float32 graph is rejected by the Neural Engine.

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
input=${1:-"$root/v4-2026-05-25/UIQAModel.aimodel"}
output=${2:-"$root/v4-2026-05-25/compiled"}

mkdir -p "$output"
xcrun --sdk iphoneos coreai-build compile "$input" \
    --platform iOS \
    --preferred-compute gpu \
    --output "$output"
