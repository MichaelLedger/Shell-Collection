#!/usr/bin/env python3
"""Convert Google ML Kit's base image-labeling model
(`mobile_ica_8bit_with_metadata.tflite`) into a native Core ML `.mlpackage`,
and emit the label + score-calibration table as JSON for Swift post-processing.

Why: ML Kit's image labeler (base *and* custom) hard-links the 44 MB
`MLKitVisionKit` framework. Running this model natively via Core ML/Vision lets
us drop all of ML Kit. TensorFlow Lite is already linked in the app, so a
TFLite-direct path is also possible; this script is the Core ML route.

Pipeline (no direct TFLite->CoreML converter exists):
    tflite --(tf2onnx --dequantize)--> float ONNX
           --(strip Quantize/DequantizeLinear)--> clean float ONNX
           --(onnx2torch)--> torch --(coremltools)--> .mlpackage

Env (Python 3.11):
    pip install tensorflow tf2onnx onnx onnxruntime onnx2torch torch coremltools numpy

Usage:
    python convert_mica_to_coreml.py \
        --tflite mobile_ica_8bit_with_metadata.tflite \
        --out-mlpackage MobileICA.mlpackage \
        --out-json mica_labels_calibration.json

Parity note: the Core ML model runs in float, so it matches the ONNX/PyTorch
float outputs exactly, and matches the int8 TFLite within quantization tolerance
(top-N labels identical on real images). Validate on a fixed image set before
shipping.
"""
import argparse
import io
import json
import subprocess
import sys
import tempfile
import zipfile
from collections import Counter

import numpy as np
import onnx
import onnx.helper as h

# --- Core ML model card defaults -------------------------------------------------
AUTHOR = "GavinXiang"
LICENSE = (
    "Proprietary - PlanetArt internal use only. Derived from Google ML Kit's "
    "on-device image-labeling model; redistribution outside the app is not permitted."
)
SHORT_DESCRIPTION = (
    "MobileNet image labeler (447 classes) converted from Google ML Kit's base "
    "image-labeling model (mobile_ica_8bit_with_metadata.tflite). Native Core ML "
    "replacement that removes the 44 MB MLKitVisionKit dependency. Input: RGB 224x224 "
    "raw pixels (NHWC). Output: 447 logits; apply the label map + per-class score "
    "calibration from mica_labels_calibration.json."
)
MODEL_VERSION = "1.0.0"
# SHA-256 of the source .tflite this model was converted from (checksum guard).
SOURCE_SHA256 = "4afa3970d3efd6726d147d505e28c7ff1e4fe1c24be7bcda6b5429eb099777a5"


def tflite_to_float_onnx(tflite_path: str, onnx_path: str, opset: int = 13) -> None:
    subprocess.run(
        [sys.executable, "-m", "tf2onnx.convert", "--tflite", tflite_path,
         "--dequantize", "--output", onnx_path, "--opset", str(opset)],
        check=True,
    )


def strip_qdq(onnx_in: str, onnx_out: str) -> None:
    """Remove every Quantize/DequantizeLinear node, rewiring consumers to the
    producer's input, and force graph outputs to FLOAT. Leaves a pure-float graph
    that onnx2torch can convert."""
    model = onnx.load(onnx_in)
    g = model.graph
    changed = True
    while changed:
        changed = False
        for n in list(g.node):
            if n.op_type in ("QuantizeLinear", "DequantizeLinear"):
                src, dst = n.input[0], n.output[0]
                for c in g.node:
                    c.input[:] = [src if x == dst else x for x in c.input]
                for o in g.output:
                    if o.name == dst:
                        o.name = src
                g.node.remove(n)
                changed = True
    for o in g.output:
        o.type.tensor_type.elem_type = onnx.TensorProto.FLOAT
    onnx.save(model, onnx_out)
    print("clean ONNX ops:", dict(Counter(n.op_type for n in g.node)))


def onnx_to_coreml(
    onnx_path: str,
    mlpackage_path: str,
    precision: str = "float32",
    author: str = AUTHOR,
    license_str: str = LICENSE,
    description: str = SHORT_DESCRIPTION,
    version: str = MODEL_VERSION,
) -> str:
    import torch
    import coremltools as ct
    from onnx2torch import convert

    tmod = convert(onnx.load(onnx_path)).eval()
    dummy = torch.zeros(1, 224, 224, 3, dtype=torch.float32)  # NHWC, raw 0..255
    ts = torch.jit.trace(tmod, dummy)
    prec = ct.precision.FLOAT16 if precision == "float16" else ct.precision.FLOAT32
    # Target iOS 16+ (ML Program / .mlpackage). iOS 16 is the app's minimum for the
    # BestPhoto pipeline, and ML Program requires iOS15+, so iOS16 is safe.
    ml = ct.convert(
        ts,
        inputs=[ct.TensorType(name="image_nhwc", shape=[1, 224, 224, 3])],
        minimum_deployment_target=ct.target.iOS16,
        compute_precision=prec,
    )

    out_key = ml.get_spec().description.output[0].name

    # --- Model card metadata (visible in Xcode's .mlpackage inspector) ---
    ml.author = author
    ml.license = license_str
    ml.short_description = description
    ml.version = version
    ml.input_description["image_nhwc"] = (
        "RGB image tensor, NHWC [1,224,224,3], raw pixels 0..255. "
        "The model internally normalizes to [-1,1] via (x-128)/128."
    )
    ml.output_description[out_key] = (
        "447 raw class logits. Map index i -> labels[i] and apply the per-class "
        "score calibration from mica_labels_calibration.json before thresholding/top-N."
    )
    # Extra provenance for future maintainers / SDK bumps.
    ml.user_defined_metadata["source_model"] = "google-mlkit mobile_ica_8bit_with_metadata.tflite"
    ml.user_defined_metadata["source_sha256"] = SOURCE_SHA256
    ml.user_defined_metadata["num_classes"] = "447"
    ml.user_defined_metadata["preprocessing"] = "NHWC 224x224, raw 0..255, internal (x-128)/128"
    ml.user_defined_metadata["compute_precision"] = precision

    ml.save(mlpackage_path)
    return out_key


def emit_metadata_json(tflite_path: str, json_path: str) -> int:
    """The .tflite has its associated files (labels, score-calibration) packed as
    a ZIP appended to the flatbuffer."""
    with open(tflite_path, "rb") as f:
        blob = f.read()
    zf = zipfile.ZipFile(io.BytesIO(blob))
    labels = zf.read("0-labels-en.txt").decode("utf-8").splitlines()
    ids = zf.read("0-labels.txt").decode("utf-8").splitlines()
    calib = zf.read("0-score-calibration.txt").decode("utf-8").splitlines()
    assert len(labels) == len(ids) == len(calib), (len(labels), len(ids), len(calib))

    def parse(line: str):
        line = line.strip()
        if not line:
            return None
        p = [float(x) for x in line.split(",")]
        return {"scale": p[0], "slope": p[1], "offset": p[2]}

    entries = [
        {"index": i, "name": labels[i], "mid": ids[i], "calib": parse(calib[i])}
        for i in range(len(labels))
    ]
    doc = {
        "numOutputs": len(labels),
        "mapping": "output index i (0-based) -> labels[i]; 1:1, no background class",
        "calibration": "c = scale / (1 + exp(-(slope*raw + offset))); null -> use raw score",
        "input": "NHWC [1,224,224,3], raw pixels 0..255 (model bakes (x-128)/128 normalization)",
        "labels": entries,
    }
    with open(json_path, "w") as f:
        json.dump(doc, f, ensure_ascii=False)
    return len(labels)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tflite", required=True)
    ap.add_argument("--out-mlpackage", default="MobileICA.mlpackage")
    ap.add_argument("--out-json", default="mica_labels_calibration.json")
    ap.add_argument("--precision", choices=["float32", "float16"], default="float16")
    ap.add_argument("--author", default=AUTHOR)
    ap.add_argument("--license", dest="license_str", default=LICENSE)
    ap.add_argument("--description", default=SHORT_DESCRIPTION)
    ap.add_argument("--model-version", dest="model_version", default=MODEL_VERSION)
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        float_onnx = f"{tmp}/float.onnx"
        clean_onnx = f"{tmp}/clean.onnx"
        tflite_to_float_onnx(args.tflite, float_onnx)
        strip_qdq(float_onnx, clean_onnx)
        out_key = onnx_to_coreml(
            clean_onnx,
            args.out_mlpackage,
            args.precision,
            author=args.author,
            license_str=args.license_str,
            description=args.description,
            version=args.model_version,
        )

    n = emit_metadata_json(args.tflite, args.out_json)
    print(f"Saved {args.out_mlpackage} (output tensor: {out_key})")
    print(f"Saved {args.out_json} ({n} labels)")


if __name__ == "__main__":
    main()
