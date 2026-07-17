#!/usr/bin/env bash
# Download an Open Images V7 subset (images + classification labels) for the 447
# classes and write train/val manifests. This can be large & slow the first time;
# tune MAX_SAMPLES_PER_CLASS to trade quality for download size.
source "$(dirname "$0")/../config.sh"
activate_venv

if [[ ! -f "$CLASSES_CSV" ]]; then
  echo "ERROR: $CLASSES_CSV missing. Run scripts/01_prepare_labels.sh first."
  exit 1
fi

python "$ROUTEA_ROOT/src/download_data.py" \
  --classes-csv "$CLASSES_CSV" \
  --dataset-dir "$DATA_DIR" \
  --manifest-dir "$MANIFEST_DIR" \
  --oi-version "$OI_VERSION" \
  --max-per-class "$MAX_SAMPLES_PER_CLASS" \
  --val-max-per-class "$VAL_MAX_SAMPLES_PER_CLASS"
