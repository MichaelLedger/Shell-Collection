#!/usr/bin/env bash
# Convert the trained SavedModel to MobileICA.mlpackage + drop-in labels JSON.
source "$(dirname "$0")/../config.sh"
activate_venv

SAVED_MODEL="$CKPT_DIR/saved_model"
if [[ ! -d "$SAVED_MODEL" ]]; then
  echo "ERROR: $SAVED_MODEL missing. Run scripts/03_train.sh first."
  exit 1
fi

python "$ROUTEA_ROOT/src/export_coreml.py" \
  --saved-model "$SAVED_MODEL" \
  --classes-csv "$CLASSES_CSV" \
  --out-mlpackage "$OUT_MLPACKAGE" \
  --out-labels-json "$OUT_LABELS_JSON" \
  --img-size "$IMG_SIZE" \
  --precision "$COREML_PRECISION"
