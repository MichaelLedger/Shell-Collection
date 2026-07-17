#!/usr/bin/env python3
"""Emit the canonical 447-class definition for Route A training.

The output ``classes.csv`` fixes the model's output order to exactly match the
MICA label space (index 0..446), so the exported model + labels JSON are a
drop-in replacement for ML Kit's base image labeler on the Swift side.

Columns:
    index   0-based output index (identical to the MICA index)
    mid     Knowledge Graph MID, e.g. /m/011l78 (Open Images label id)
    name    Human-readable class name (e.g. "Team")

MIDs are the stable join key against Open Images image-level labels, so we key
the whole pipeline on MIDs rather than display names (which drift between
Open Images releases).
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path


def load_mica_labels(mica_json: Path) -> list[dict]:
    with mica_json.open() as fh:
        doc = json.load(fh)
    labels = doc["labels"] if isinstance(doc, dict) else doc
    # Order strictly by output index so index i -> row i.
    labels = sorted(labels, key=lambda e: e["index"])
    if labels[0]["index"] != 0 or labels[-1]["index"] != len(labels) - 1:
        raise SystemExit(
            f"Unexpected index range: {labels[0]['index']}..{labels[-1]['index']} "
            f"for {len(labels)} labels (expected contiguous 0..N-1)."
        )
    return labels


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--mica-json", required=True, type=Path,
                    help="Path to mica_labels_calibration.json.")
    ap.add_argument("--out", required=True, type=Path,
                    help="Path to write classes.csv.")
    args = ap.parse_args()

    labels = load_mica_labels(args.mica_json)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(["index", "mid", "name"])
        for entry in labels:
            writer.writerow([entry["index"], entry["mid"], entry["name"]])

    print(f"Wrote {len(labels)} classes -> {args.out}")
    print(f"  first: {labels[0]['index']},{labels[0]['mid']},{labels[0]['name']}")
    print(f"  last : {labels[-1]['index']},{labels[-1]['mid']},{labels[-1]['name']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
