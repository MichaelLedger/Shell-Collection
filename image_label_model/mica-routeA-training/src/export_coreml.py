#!/usr/bin/env python3
"""Convert the trained SavedModel to MobileICA.mlpackage and emit the drop-in
labels JSON, both matching the MICAImageLabeler contract exactly:

  * input feature ``image_nhwc``, shape [1, 224, 224, 3], float32, raw 0..255
    (MobileNetV3's include_preprocessing scaling is baked into the graph);
  * single output feature = 447 per-class sigmoid probabilities;
  * labels JSON keyed by output index 0..446 with calib=null, so the Swift
    ``calibratedScore`` falls back to the raw probability.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

import coremltools as ct


def load_classes(classes_csv: Path) -> list[tuple[int, str, str]]:
    rows: list[tuple[int, str, str]] = []
    with classes_csv.open() as fh:
        for row in csv.DictReader(fh):
            rows.append((int(row["index"]), row["mid"], row["name"]))
    rows.sort(key=lambda r: r[0])
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--saved-model", required=True, type=Path)
    ap.add_argument("--classes-csv", required=True, type=Path)
    ap.add_argument("--out-mlpackage", required=True, type=Path)
    ap.add_argument("--out-labels-json", required=True, type=Path)
    ap.add_argument("--img-size", type=int, default=224)
    ap.add_argument("--precision", default="float16", choices=["float16", "float32"])
    ap.add_argument("--input-name", default="image_nhwc")
    args = ap.parse_args()

    classes = load_classes(args.classes_csv)
    num_classes = len(classes)

    precision = (ct.precision.FLOAT16 if args.precision == "float16"
                 else ct.precision.FLOAT32)
    mlmodel = ct.convert(
        str(args.saved_model),
        source="tensorflow",
        inputs=[ct.TensorType(name=args.input_name,
                              shape=(1, args.img_size, args.img_size, 3))],
        compute_precision=precision,
        minimum_deployment_target=ct.target.iOS16,
    )
    mlmodel.short_description = (
        "MobileICA — MobileNetV3 multi-label tagger trained on Open Images "
        "(447 MICA classes). Input image_nhwc raw 0..255; outputs per-class "
        "sigmoid probabilities."
    )
    args.out_mlpackage.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(args.out_mlpackage))
    print(f"Saved Core ML model -> {args.out_mlpackage}")

    labels_doc = {
        "numOutputs": num_classes,
        "input": {
            "name": args.input_name,
            "shape": [1, args.img_size, args.img_size, 3],
            "note": "raw RGB 0..255, NHWC; normalization baked into the model",
        },
        # calib is null for every class: the model already outputs calibrated
        # sigmoid probabilities, so MICAImageLabeler uses the raw score.
        "labels": [
            {"index": idx, "mid": mid, "name": name, "calib": None}
            for idx, mid, name in classes
        ],
    }
    args.out_labels_json.parent.mkdir(parents=True, exist_ok=True)
    with args.out_labels_json.open("w") as fh:
        json.dump(labels_doc, fh, ensure_ascii=False, indent=2)
    print(f"Wrote labels JSON ({num_classes} classes) -> {args.out_labels_json}")
    print("\nDrop-in steps:")
    print(f"  1. Ship {args.out_mlpackage.name} via ODR (replaces the .tflite payload).")
    print(f"  2. Copy {args.out_labels_json.name} over the SDK's "
          "Resource/BestPhoto/mica_labels_calibration.json.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
