#!/usr/bin/env bash
# Shared configuration for the Route A training pipeline.
# Every script sources this file. Override any value by exporting it before running,
# e.g. `MAX_SAMPLES_PER_CLASS=2000 ./scripts/02_download_data.sh`.

set -euo pipefail

# --- Paths -------------------------------------------------------------------
# Root of this pipeline (the directory containing this file).
ROUTEA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROUTEA_ROOT

# Python virtual environment location.
export VENV_DIR="${VENV_DIR:-$ROUTEA_ROOT/.venv}"

# Where downloaded data, manifests, checkpoints and exports are written.
export WORK_DIR="${WORK_DIR:-$ROUTEA_ROOT/work}"
export DATA_DIR="${DATA_DIR:-$WORK_DIR/data}"           # FiftyOne / Open Images images
export MANIFEST_DIR="${MANIFEST_DIR:-$WORK_DIR/manifests}"
export CKPT_DIR="${CKPT_DIR:-$WORK_DIR/checkpoints}"
export EXPORT_DIR="${EXPORT_DIR:-$WORK_DIR/export}"

# Canonical 447-class definition (produced by 01_prepare_labels.sh).
export CLASSES_CSV="${CLASSES_CSV:-$WORK_DIR/classes.csv}"

# --- Inputs ------------------------------------------------------------------
# The MICA labels+calibration JSON extracted from ML Kit. Defaults to the copy
# bundled in the SDK; falls back to the Desktop copy.
DEFAULT_MICA_JSON="/Users/gavinxiang/Downloads/PRTBusinessUnit/Sources/PRTSelectPhoto/Resource/BestPhoto/mica_labels_calibration.json"
if [[ ! -f "$DEFAULT_MICA_JSON" ]]; then
  DEFAULT_MICA_JSON="$HOME/Desktop/mica_labels_calibration.json"
fi
export MICA_JSON="${MICA_JSON:-$DEFAULT_MICA_JSON}"

# --- Model / training hyperparameters ---------------------------------------
export IMG_SIZE="${IMG_SIZE:-224}"                       # model input side (matches MICAImageLabeler)
export BACKBONE="${BACKBONE:-MobileNetV3Small}"          # MobileNetV3Small | MobileNetV3Large
export BATCH_SIZE="${BATCH_SIZE:-64}"
export HEAD_EPOCHS="${HEAD_EPOCHS:-5}"                   # epochs training only the new head
export FINETUNE_EPOCHS="${FINETUNE_EPOCHS:-15}"          # epochs fine-tuning the whole backbone
export LEARNING_RATE="${LEARNING_RATE:-1e-3}"
export FINETUNE_LR="${FINETUNE_LR:-1e-4}"

# --- Dataset controls --------------------------------------------------------
# Cap images per class to keep the download/training tractable. Raise for quality.
export MAX_SAMPLES_PER_CLASS="${MAX_SAMPLES_PER_CLASS:-1500}"
export VAL_MAX_SAMPLES_PER_CLASS="${VAL_MAX_SAMPLES_PER_CLASS:-200}"
# Open Images split names in FiftyOne: train | validation | test
export OI_VERSION="${OI_VERSION:-open-images-v7}"

# --- Export ------------------------------------------------------------------
export OUT_MLPACKAGE="${OUT_MLPACKAGE:-$EXPORT_DIR/MobileICA.mlpackage}"
export OUT_LABELS_JSON="${OUT_LABELS_JSON:-$EXPORT_DIR/mica_labels_calibration.json}"
export COREML_PRECISION="${COREML_PRECISION:-float16}"   # float16 (~5.7MB) | float32

mkdir -p "$WORK_DIR" "$DATA_DIR" "$MANIFEST_DIR" "$CKPT_DIR" "$EXPORT_DIR"

activate_venv() {
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
}
