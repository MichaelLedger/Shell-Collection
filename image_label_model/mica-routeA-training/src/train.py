#!/usr/bin/env python3
"""Fine-tune MobileNetV3 as a multi-label image tagger over the 447 MICA classes.

Key design choices that keep the exported model a drop-in for MICAImageLabeler:
  * Input is raw RGB 0..255, shape [1, H, W, 3] (NHWC). We use
    ``include_preprocessing=True`` so MobileNetV3's own (x -> [-1,1]) scaling is
    baked into the graph — the Swift side feeds raw pixels, exactly like ML Kit.
  * Output is a single dense layer of 447 sigmoids (independent per-class
    probabilities), so downstream code can treat each output as a confidence.
    The exported labels JSON therefore uses calib=null (raw score is the score).

Open Images labels are partial, so we train with a *masked* binary cross-entropy:
loss is averaged only over classes that are known-present or known-absent for
each image; unknown classes contribute nothing.
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

import tensorflow as tf


def load_class_index(classes_csv: Path) -> dict[str, int]:
    mid_to_index: dict[str, int] = {}
    with classes_csv.open() as fh:
        for row in csv.DictReader(fh):
            mid_to_index[row["mid"]] = int(row["index"])
    return mid_to_index


def make_dataset(
    manifest: Path,
    mid_to_index: dict[str, int],
    num_classes: int,
    img_size: int,
    batch_size: int,
    training: bool,
) -> tf.data.Dataset:
    filepaths: list[str] = []
    y_rows: list[list[float]] = []
    mask_rows: list[list[float]] = []

    with manifest.open() as fh:
        for row in csv.DictReader(fh):
            y = [0.0] * num_classes
            mask = [0.0] * num_classes
            for mid in filter(None, row["pos"].split("|")):
                idx = mid_to_index.get(mid)
                if idx is not None:
                    y[idx] = 1.0
                    mask[idx] = 1.0
            for mid in filter(None, row["neg"].split("|")):
                idx = mid_to_index.get(mid)
                if idx is not None:
                    mask[idx] = 1.0
            filepaths.append(row["filepath"])
            y_rows.append(y)
            mask_rows.append(mask)

    print(f"{manifest.name}: {len(filepaths)} samples")

    y_tensor = tf.constant(y_rows, dtype=tf.float32)
    mask_tensor = tf.constant(mask_rows, dtype=tf.float32)
    ds = tf.data.Dataset.from_tensor_slices((filepaths, y_tensor, mask_tensor))

    def _load(path, y, mask):
        raw = tf.io.read_file(path)
        img = tf.io.decode_image(raw, channels=3, expand_animations=False)
        # Stretch to the fixed model input, matching MICAImageLabeler's resize.
        img = tf.image.resize(img, [img_size, img_size], method="bilinear")
        img = tf.cast(img, tf.float32)  # raw 0..255; model normalizes internally
        return img, tf.concat([y, mask], axis=0)

    if training:
        ds = ds.shuffle(4096, reshuffle_each_iteration=True)
    ds = ds.map(_load, num_parallel_calls=tf.data.AUTOTUNE)
    if training:
        ds = ds.map(lambda x, t: (tf.image.random_flip_left_right(x), t),
                    num_parallel_calls=tf.data.AUTOTUNE)
    return ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)


def masked_bce(num_classes: int):
    """BCE averaged only over known (present/absent) labels per image."""
    bce = tf.keras.losses.BinaryCrossentropy(reduction="none")

    def loss_fn(y_packed, y_pred):
        y_true = y_packed[:, :num_classes]
        mask = y_packed[:, num_classes:]
        per_class = bce(tf.expand_dims(y_true, -1), tf.expand_dims(y_pred, -1))
        per_class = per_class * mask
        denom = tf.reduce_sum(mask) + 1e-8
        return tf.reduce_sum(per_class) / denom

    return loss_fn


def build_model(backbone: str, img_size: int, num_classes: int) -> tf.keras.Model:
    factory = getattr(tf.keras.applications, backbone)
    base = factory(
        input_shape=(img_size, img_size, 3),
        include_top=False,
        weights="imagenet",
        include_preprocessing=True,  # accepts raw 0..255
        pooling="avg",
    )
    inputs = base.input
    x = tf.keras.layers.Dropout(0.2)(base.output)
    outputs = tf.keras.layers.Dense(num_classes, activation="sigmoid",
                                    name="probabilities")(x)
    return tf.keras.Model(inputs, outputs, name="MobileICA"), base


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--classes-csv", required=True, type=Path)
    ap.add_argument("--manifest-dir", required=True, type=Path)
    ap.add_argument("--ckpt-dir", required=True, type=Path)
    ap.add_argument("--backbone", default="MobileNetV3Small")
    ap.add_argument("--img-size", type=int, default=224)
    ap.add_argument("--batch-size", type=int, default=64)
    ap.add_argument("--head-epochs", type=int, default=5)
    ap.add_argument("--finetune-epochs", type=int, default=15)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--finetune-lr", type=float, default=1e-4)
    args = ap.parse_args()

    mid_to_index = load_class_index(args.classes_csv)
    num_classes = len(mid_to_index)
    print(f"Training {num_classes}-class multi-label {args.backbone}")

    train_ds = make_dataset(args.manifest_dir / "train.csv", mid_to_index,
                            num_classes, args.img_size, args.batch_size, training=True)
    val_ds = make_dataset(args.manifest_dir / "val.csv", mid_to_index,
                          num_classes, args.img_size, args.batch_size, training=False)

    model, base = build_model(args.backbone, args.img_size, num_classes)
    loss_fn = masked_bce(num_classes)

    # Phase 1: train the head only.
    base.trainable = False
    model.compile(optimizer=tf.keras.optimizers.Adam(args.lr), loss=loss_fn)
    model.fit(train_ds, validation_data=val_ds, epochs=args.head_epochs)

    # Phase 2: fine-tune the whole backbone at a lower LR.
    base.trainable = True
    model.compile(optimizer=tf.keras.optimizers.Adam(args.finetune_lr), loss=loss_fn)
    args.ckpt_dir.mkdir(parents=True, exist_ok=True)
    ckpt = tf.keras.callbacks.ModelCheckpoint(
        filepath=str(args.ckpt_dir / "best.keras"),
        monitor="val_loss", save_best_only=True, verbose=1,
    )
    model.fit(train_ds, validation_data=val_ds,
              epochs=args.head_epochs + args.finetune_epochs,
              initial_epoch=args.head_epochs, callbacks=[ckpt])

    saved_model_dir = args.ckpt_dir / "saved_model"
    model.export(str(saved_model_dir))
    print(f"Exported SavedModel -> {saved_model_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
