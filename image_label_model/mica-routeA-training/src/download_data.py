#!/usr/bin/env python3
"""Download an Open Images V7 subset (images + image-level labels) restricted to
our 447 MICA classes, and emit a training manifest.

Uses FiftyOne, which handles image download + classification annotations. We key
everything on Knowledge Graph MIDs (stable across releases) and translate to the
display names FiftyOne expects via the official Open Images class-descriptions
CSV.

Open Images image-level labels are *partial*: for a given image only some classes
are human-verified present (confidence 1.0) or absent (confidence 0.0); the rest
are unknown. We record both positives and negatives so training can mask the
unknowns (see train.py). This matches the recommended Open Images training recipe
and avoids penalising the model for classes that were simply never annotated.

Manifest columns (per split): filepath, pos, neg
    pos / neg are '|'-joined MIDs drawn from our 447-class set.
"""
from __future__ import annotations

import argparse
import csv
import sys
import urllib.request
from pathlib import Path

OI_CLASS_DESCRIPTIONS_URL = (
    "https://storage.googleapis.com/openimages/v7/oidv7-class-descriptions.csv"
)


def load_classes(classes_csv: Path) -> list[tuple[int, str, str]]:
    rows: list[tuple[int, str, str]] = []
    with classes_csv.open() as fh:
        for row in csv.DictReader(fh):
            rows.append((int(row["index"]), row["mid"], row["name"]))
    rows.sort(key=lambda r: r[0])
    return rows


def load_mid_name_maps(cache_dir: Path) -> tuple[dict[str, str], dict[str, str]]:
    """Return (mid->name, name->mid) from the official Open Images descriptions."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    csv_path = cache_dir / "oidv7-class-descriptions.csv"
    if not csv_path.exists():
        print(f"Downloading Open Images class descriptions -> {csv_path}")
        urllib.request.urlretrieve(OI_CLASS_DESCRIPTIONS_URL, csv_path)
    mid_to_name: dict[str, str] = {}
    name_to_mid: dict[str, str] = {}
    with csv_path.open() as fh:
        reader = csv.reader(fh)
        header = next(reader, None)
        # File has header ("LabelName,DisplayName") in v7; guard either way.
        if header and header[0].startswith("/m/"):
            mid, name = header[0], header[1]
            mid_to_name[mid] = name
            name_to_mid[name] = mid
        for mid, name in reader:
            mid_to_name[mid] = name
            name_to_mid[name] = mid
    return mid_to_name, name_to_mid


def build_split(
    split: str,
    fo_classes: list[str],
    name_to_mid: dict[str, str],
    our_mids: set[str],
    max_per_class: int,
    dataset_dir: Path,
    oi_version: str,
    manifest_path: Path,
) -> None:
    import fiftyone as fo
    import fiftyone.zoo as foz

    print(f"[{split}] loading {oi_version} (classifications, "
          f"max {max_per_class}/class, {len(fo_classes)} classes)...")
    dataset = foz.load_zoo_dataset(
        oi_version,
        split=split,
        label_types=["classifications"],
        classes=fo_classes,
        max_samples=max_per_class * len(fo_classes) if max_per_class else None,
        seed=42,
        shuffle=True,
        dataset_dir=str(dataset_dir),
    )

    written = 0
    with manifest_path.open("w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(["filepath", "pos", "neg"])
        for sample in dataset.iter_samples(progress=True):
            classifications = sample.get_field("positive_labels") or sample.get_field("ground_truth")
            # FiftyOne stores OI image labels under "positive_labels"/"negative_labels"
            # (v6+) or a single "ground_truth" Classifications with confidences.
            pos, neg = set(), set()
            for field_name, bucket in (("positive_labels", pos), ("negative_labels", neg)):
                field = sample.get_field(field_name)
                if field is None:
                    continue
                for cls in field.classifications:
                    mid = name_to_mid.get(cls.label)
                    if mid in our_mids:
                        bucket.add(mid)
            # Fallback: single classifications field carrying confidences.
            if not pos and not neg:
                field = sample.get_field("ground_truth") or sample.get_field("classifications")
                if field is not None:
                    for cls in field.classifications:
                        mid = name_to_mid.get(cls.label)
                        if mid not in our_mids:
                            continue
                        (pos if (cls.confidence or 0) >= 0.5 else neg).add(mid)
            if not pos and not neg:
                continue
            writer.writerow([sample.filepath, "|".join(sorted(pos)), "|".join(sorted(neg))])
            written += 1

    print(f"[{split}] wrote {written} rows -> {manifest_path}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--classes-csv", required=True, type=Path)
    ap.add_argument("--dataset-dir", required=True, type=Path)
    ap.add_argument("--manifest-dir", required=True, type=Path)
    ap.add_argument("--oi-version", default="open-images-v7")
    ap.add_argument("--max-per-class", type=int, default=1500)
    ap.add_argument("--val-max-per-class", type=int, default=200)
    args = ap.parse_args()

    classes = load_classes(args.classes_csv)
    our_mids = {mid for _, mid, _ in classes}
    mid_to_name, name_to_mid = load_mid_name_maps(args.dataset_dir)

    # Resolve the display names FiftyOne expects, preferring the official OI name
    # and falling back to the MICA name when a MID is missing from the CSV.
    fo_classes: list[str] = []
    missing: list[str] = []
    for _, mid, mica_name in classes:
        name = mid_to_name.get(mid, mica_name)
        fo_classes.append(name)
        if mid not in mid_to_name:
            missing.append(f"{mid} ({mica_name})")
    if missing:
        print(f"WARNING: {len(missing)} MIDs not in OI descriptions, using MICA name:")
        for m in missing:
            print(f"  - {m}")

    args.manifest_dir.mkdir(parents=True, exist_ok=True)
    build_split("train", fo_classes, name_to_mid, our_mids, args.max_per_class,
                args.dataset_dir, args.oi_version, args.manifest_dir / "train.csv")
    build_split("validation", fo_classes, name_to_mid, our_mids, args.val_max_per_class,
                args.dataset_dir, args.oi_version, args.manifest_dir / "val.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
