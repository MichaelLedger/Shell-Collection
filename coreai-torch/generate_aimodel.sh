#!/bin/sh
# Created by Gavin Xiang on 10/16/26.
# Copyright © 2026 PlanetArt. All rights reserved.

# Convert a UIQA checkpoint to UIQAModel.aimodel, then compile one .aimodelc per iOS chip.
# Usage:
#   ./generate_aimodel.sh [checkpoint.pth] [UIQAModel.aimodel] [UIQAModel.mlpackage]

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
checkpoint=${1:-"$root/v4-2026-05-25/UIQA_UHD_IQA_V4__NR_epoch_3_SRCC_0.736391.pth"}
aimodel=${2:-"$root/v4-2026-05-25/UIQAModel.aimodel"}
mlpackage=${3:-}

if [ -x "$root/.venv/bin/python" ]; then
    python="$root/.venv/bin/python"
else
    python=python3
fi

set -- --checkpoint "$checkpoint" --aimodel "$aimodel"
if [ -n "$mlpackage" ]; then
    set -- "$@" --mlpackage "$mlpackage"
fi

"$python" -u "$root/convert_to_aimodel.py" "$@"
"$root/compile_aimodel.sh" "$aimodel"
