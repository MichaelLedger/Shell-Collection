#!/usr/bin/env bash
# Emit work/classes.csv: the canonical 447-class order (index, mid, name),
# derived from the MICA labels+calibration JSON.
source "$(dirname "$0")/../config.sh"
activate_venv

if [[ ! -f "$MICA_JSON" ]]; then
  echo "ERROR: MICA_JSON not found at: $MICA_JSON"
  echo "Set MICA_JSON=/path/to/mica_labels_calibration.json and retry."
  exit 1
fi

python "$ROUTEA_ROOT/src/prepare_labels.py" \
  --mica-json "$MICA_JSON" \
  --out "$CLASSES_CSV"
