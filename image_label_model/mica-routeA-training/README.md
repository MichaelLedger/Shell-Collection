# Route A — Train a license-clean MobileICA replacement on Open Images

This pipeline fine-tunes a **MobileNetV3** multi-label image tagger on the
**Open Images V7** image-level labels, restricted to the **447 MICA classes**
we currently use. The result is a drop-in `MobileICA.mlpackage` + labels JSON
for `MICAImageLabeler`, trained on permissively-licensed data instead of the
extracted ML Kit base model — see `MICA-CoreML-Licensing-and-Model-Alternatives.md`.

## Why this is drop-in

The exported artifacts match the `MICAImageLabeler` contract with **zero Swift
changes**:

| Contract | This pipeline |
|---|---|
| Input `image_nhwc`, `[1,224,224,3]` float, raw `0..255` | MobileNetV3 with `include_preprocessing=True` bakes normalization into the graph |
| Single output feature (per-class scores) | Dense(447, sigmoid) → per-class probabilities |
| Per-class `calib` applied on top | Model already outputs calibrated probabilities → labels JSON uses `calib: null` (raw score used) |
| Labels ordered by output index, keyed by MID | `classes.csv` fixes order to the MICA index; JSON carries `index`/`mid`/`name` |

## Pipeline

Run in order (each script sources `config.sh` and validates its inputs):

```bash
cd ~/Desktop/mica-routeA-training
./scripts/00_setup.sh          # venv + deps (needs Python 3.11)
./scripts/01_prepare_labels.sh # work/classes.csv (447 rows: index,mid,name)
./scripts/02_download_data.sh  # Open Images subset -> work/manifests/{train,val}.csv
./scripts/03_train.sh          # MobileNetV3 multi-label -> work/checkpoints/saved_model
./scripts/04_export_coreml.sh  # -> work/export/MobileICA.mlpackage + mica_labels_calibration.json
```

## Configuration

All knobs live in `config.sh` and can be overridden inline, e.g.:

```bash
MAX_SAMPLES_PER_CLASS=3000 BACKBONE=MobileNetV3Large ./scripts/02_download_data.sh
```

Key knobs: `MICA_JSON` (source label space), `MAX_SAMPLES_PER_CLASS`
(download/quality trade-off), `BACKBONE`, `BATCH_SIZE`, `HEAD_EPOCHS`,
`FINETUNE_EPOCHS`, `COREML_PRECISION` (`float16` ≈ 5–6 MB).

## Files

- `config.sh` — shared paths + hyperparameters.
- `src/prepare_labels.py` — MICA JSON → `classes.csv` (canonical 447-class order).
- `src/download_data.py` — FiftyOne Open Images V7 subset → label manifests
  (records positives **and** negatives so training can mask unknown labels).
- `src/train.py` — MobileNetV3, masked BCE multi-label training, two-phase
  (head → full fine-tune), raw-`0..255` input.
- `src/export_coreml.py` — SavedModel → `MobileICA.mlpackage` + drop-in JSON.

## After export

1. Ship `work/export/MobileICA.mlpackage` via the existing ODR provider (it
   replaces the old `.tflite` payload); point
   `MDBestPhotoManager.imageLabelingModelPathProvider` at the materialized path.
2. Copy `work/export/mica_labels_calibration.json` over the SDK's
   `Sources/PRTSelectPhoto/Resource/BestPhoto/mica_labels_calibration.json`.
3. Run the end-to-end parity check against the ML Kit baseline on a fixed image
   set (see the size-reduction plan).

## Notes / caveats

- **Label parity is approximate.** Open Images image-level labels cover most of
  the 447 MICA MIDs, but coverage/quality per class varies. `download_data.py`
  prints any MICA MIDs missing from the Open Images class descriptions.
- **Not every MICA class will be well-represented.** Consider raising
  `MAX_SAMPLES_PER_CLASS`, adding data augmentation, or supplementing rare
  classes. Validate top-N behavior against the ML Kit baseline before shipping.
- **Scores are model probabilities**, not ML Kit's calibrated confidences.
  Downstream thresholds in `PhotoEventEngine` may need re-tuning; keep `calib`
  null unless you fit a new calibration against a labeled validation set.
- Open Images annotations are CC BY 4.0; the images are individually licensed
  (mostly CC BY 2.0). Retain attribution as your legal team requires.
