#!/usr/bin/env bash
# Fine-tune MobileNetV3 (multi-label, masked BCE) and export a SavedModel.
source "$(dirname "$0")/../config.sh"
activate_venv

for f in train.csv val.csv; do
  if [[ ! -f "$MANIFEST_DIR/$f" ]]; then
    echo "ERROR: $MANIFEST_DIR/$f missing. Run scripts/02_download_data.sh first."
    exit 1
  fi
done

python "$ROUTEA_ROOT/src/train.py" \
  --classes-csv "$CLASSES_CSV" \
  --manifest-dir "$MANIFEST_DIR" \
  --ckpt-dir "$CKPT_DIR" \
  --backbone "$BACKBONE" \
  --img-size "$IMG_SIZE" \
  --batch-size "$BATCH_SIZE" \
  --head-epochs "$HEAD_EPOCHS" \
  --finetune-epochs "$FINETUNE_EPOCHS" \
  --lr "$LEARNING_RATE" \
  --finetune-lr "$FINETUNE_LR"
