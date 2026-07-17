# Converting ML Kit's Base Image-Labeling Model (`mobile_ica_8bit_with_metadata.tflite`) to Core ML

A step-by-step tutorial for turning Google ML Kit's base image-labeling model into a
native **Core ML `.mlpackage`**, so iOS can run it via Vision/Core ML (on the ANE) and
the app can drop **all** of ML Kit.

---

## Why do this?

ML Kit's image labeler — **both** the base `MLKitImageLabeling` and the "custom"
`MLKitImageLabelingCustom` — hard-links the **44 MB `MLKitVisionKit`** framework.

Proof (device link fails once VisionKit is dropped):

```
Undefined symbol: _OBJC_CLASS_$_MLKVisionKitImageLabeler
Undefined symbol: _OBJC_CLASS_$_MLKVisionKitErrorExtractor
Undefined symbol: _OBJC_CLASS_$_VNKMLKitImageLabelingOptions
```

Those classes are defined **only** in `MLKitVisionKit.framework`, and
`MLKitImageLabelingCustom.xcframework` references them (`nm -u` on the binary shows the
undefined symbols; Google's own podspec lists `MLKitImageLabelingCustom → MLKitVisionKit (~> 2.1)`).

**Conclusion:** you cannot keep ML Kit's labeler and remove the 44 MB. Running the model
natively in Core ML removes the entire ML Kit dependency chain.

> Note: TensorFlow Lite is already linked in the app (via `MirrorSDK` / PhotoEventEngine),
> so a "run the same `.tflite` through TFLite" path is also possible with exact parity.
> This tutorial covers the **Core ML** route (native, ANE-accelerated, no TFLite dependency).

---

## What you get

| Artifact | Description |
|---|---|
| `MobileICA.mlpackage` | The Core ML model (~5.7 MB fp16 / ~11 MB fp32). Input `[1,224,224,3]`, output 447 logits. |
| `mica_labels_calibration.json` | 447 labels + per-class score-calibration, extracted from the model's metadata. |
| `convert_mica_to_coreml.py` | Reproducible conversion script — re-run on any ML Kit SDK bump. |

---

## The model at a glance

Inspected with the LiteRT interpreter:

- **Input** — `conv_net_input`, shape `[1, 224, 224, 3]`, `uint8`, quant `scale=0.0078125, zero_point=128`.
  → dequantized pixel = `(x - 128) / 128`, i.e. normalize to `[-1, 1]`. (Standard MobileNet.)
- **Output** — shape `[1, 1, 1, 447]`, `uint8`, quant `scale=0.15287849, zero_point=215`.
  → **447 classes, mapped 1:1 to the 447 labels (no background class).**
- Architecture: int8-quantized **MobileNet** (30 Conv, relu6/Clip, one AveragePool). 92 tensors.

### Embedded metadata

TFLite Metadata packs the associated files as a **ZIP appended to the `.tflite`**, so you can
read them directly:

```bash
unzip -l mobile_ica_8bit_with_metadata.tflite
#   0-labels-en.txt         (447 English label names)
#   0-labels.txt            (447 Knowledge-Graph MIDs, e.g. /m/011l78)
#   0-score-calibration.txt  (447 rows: "scale,slope,offset"; 17 rows blank = no calibration)
```

**Score calibration** (ML Kit applies this to each raw score):

```
calibrated = scale / (1 + exp(-(slope * raw + offset)))      # blank row → use raw score
```

---

## Prerequisites

- macOS with **Python 3.11** (TensorFlow / coremltools do not yet ship wheels for 3.13).
- The model file `mobile_ica_8bit_with_metadata.tflite`.

```bash
python3.11 -m venv micaenv
source micaenv/bin/activate
pip install --upgrade pip
pip install tensorflow tf2onnx onnx onnxruntime onnx2torch torch coremltools numpy ai-edge-litert
```

> There is **no direct TFLite → Core ML converter**. The pipeline hops through ONNX and PyTorch:
> `tflite → (tf2onnx) → ONNX → (onnx2torch) → torch → (coremltools) → .mlpackage`.

---

## Step 1 — Inspect the model (optional but recommended)

```python
from ai_edge_litert.interpreter import Interpreter
it = Interpreter(model_path="mobile_ica_8bit_with_metadata.tflite"); it.allocate_tensors()
print(it.get_input_details()[0])   # shape/dtype/quant
print(it.get_output_details()[0])
```

Capture a ground-truth output to validate against later:

```python
import numpy as np
inp, out = it.get_input_details()[0], it.get_output_details()[0]
img = np.random.default_rng(42).integers(0, 256, (1,224,224,3), np.uint8)
it.set_tensor(inp['index'], img); it.invoke()
raw = it.get_tensor(out['index']).astype(np.float32).reshape(-1)
s, z = out['quantization']; deq = (raw - z) * s      # dequantized logits
np.save("ref_img.npy", img); np.save("ref_tflite_deq.npy", deq)
```

## Step 2 — TFLite → float ONNX

`tf2onnx` reads `.tflite` directly; `--dequantize` folds the int8 quantization into a float graph.

```bash
python -m tf2onnx.convert --tflite mobile_ica_8bit_with_metadata.tflite \
    --dequantize --output float.onnx --opset 13
```

## Step 3 — Strip Quantize/DequantizeLinear nodes

`onnx2torch` can't convert `QuantizeLinear`. Remove every `Quantize/DequantizeLinear`,
rewire consumers to the producer's input, and force the graph output to `FLOAT`:

```python
import onnx
from collections import Counter
m = onnx.load("float.onnx"); g = m.graph
changed = True
while changed:
    changed = False
    for n in list(g.node):
        if n.op_type in ("QuantizeLinear", "DequantizeLinear"):
            src, dst = n.input[0], n.output[0]
            for c in g.node:
                c.input[:] = [src if x == dst else x for x in c.input]
            for o in g.output:
                if o.name == dst: o.name = src
            g.node.remove(n); changed = True
for o in g.output:
    o.type.tensor_type.elem_type = onnx.TensorProto.FLOAT
onnx.save(m, "clean.onnx")
print(dict(Counter(n.op_type for n in g.node)))   # -> only Conv/Clip/Relu/AveragePool/Reshape/Transpose/Cast/Sub/Mul
```

(Optional) sanity-check the float graph vs the TFLite ground truth with `onnxruntime`:

```python
import onnxruntime as ort, numpy as np
img, ref = np.load("ref_img.npy"), np.load("ref_tflite_deq.npy")
sess = ort.InferenceSession("clean.onnx", providers=["CPUExecutionProvider"])
name = sess.get_inputs()[0].name
o = sess.run(None, {name: img.astype(np.uint8)})[0].reshape(-1)
print("onnx top5:", o.argsort()[::-1][:5], "tflite top5:", ref.argsort()[::-1][:5])
```

## Step 4 — ONNX → PyTorch → Core ML

```python
import onnx, torch, coremltools as ct
from onnx2torch import convert

tmod = convert(onnx.load("clean.onnx")).eval()
dummy = torch.zeros(1, 224, 224, 3, dtype=torch.float32)   # NHWC, raw pixels 0..255
ts = torch.jit.trace(tmod, dummy)

ml = ct.convert(
    ts,
    inputs=[ct.TensorType(name="image_nhwc", shape=[1, 224, 224, 3])],
    minimum_deployment_target=ct.target.iOS16,
    compute_precision=ct.precision.FLOAT16,   # ~5.7 MB; use FLOAT32 for ~11 MB
)
ml.save("MobileICA.mlpackage")
```

> **Tip (image input):** the model bakes `(x-128)/128` internally, so it takes **raw** pixels
> `0..255` in NHWC. If you prefer a Core ML `ImageType` input (feed a `CVPixelBuffer`/`UIImage`
> directly), strip the leading `Cast/Sub/Mul` from `clean.onnx` and set the image preprocessing
> in `coremltools` instead: `scale = 1/128`, `bias = [-1, -1, -1]`.

## Step 5 — Emit labels + calibration JSON

```python
import io, json, zipfile
blob = open("mobile_ica_8bit_with_metadata.tflite", "rb").read()
zf = zipfile.ZipFile(io.BytesIO(blob))
labels = zf.read("0-labels-en.txt").decode().splitlines()
ids    = zf.read("0-labels.txt").decode().splitlines()
calib  = zf.read("0-score-calibration.txt").decode().splitlines()

def parse(l):
    l = l.strip()
    return None if not l else dict(zip(("scale","slope","offset"), map(float, l.split(","))))

doc = {"numOutputs": len(labels),
       "mapping": "output index i (0-based) -> labels[i]; 1:1, no background",
       "calibration": "c = scale/(1+exp(-(slope*raw+offset))); null -> raw",
       "labels": [{"index": i, "name": labels[i], "mid": ids[i], "calib": parse(calib[i])}
                  for i in range(len(labels))]}
json.dump(doc, open("mica_labels_calibration.json", "w"), ensure_ascii=False)
```

## Step 6 — Validate parity

```python
import numpy as np, coremltools as ct
img, ref = np.load("ref_img.npy").astype(np.float32), np.load("ref_tflite_deq.npy")
ml = ct.models.MLModel("MobileICA.mlpackage")
out = ml.predict({"image_nhwc": img}); co = np.array(list(out.values())[0]).reshape(-1)
print("coreml top5:", co.argsort()[::-1][:5], "tflite top5:", ref.argsort()[::-1][:5])
```

**Expected:** Core ML (float) == ONNX == PyTorch **exactly**. It differs from the int8 TFLite
only by quantization (output step ≈ 0.15). On real images with clear content the top-N labels
match; on pure noise the lowest-ranked ties can differ (meaningless). Always validate on a
**fixed real-image set** before shipping.

---

## One-shot script

Everything above is bundled in `convert_mica_to_coreml.py`:

```bash
python convert_mica_to_coreml.py \
    --tflite mobile_ica_8bit_with_metadata.tflite \
    --out-mlpackage MobileICA.mlpackage \
    --out-json mica_labels_calibration.json \
    --precision float16
```

Re-run it whenever the ML Kit SDK bumps and the extracted model changes (also re-verify the
model's SHA-256 checksum guard).

---

## Using it in the app (integration outline)

1. **Ship the model** — add `MobileICA.mlpackage` to the app target (compile in at 5.7 MB, or
   ODR-tag it like the other BestPhoto models).
2. **Preprocess** — resize to 224×224 aspect-fit, raw RGB `0..255`, NHWC. Must match the existing
   `imageAlignedWithPhotobooksMLKitInput` (scale=1, `.up` orientation) so pixels are identical.
3. **Infer** — run via Core ML / `VNCoreMLRequest` → 447 raw logits.
4. **Post-process** — apply per-class calibration from `mica_labels_calibration.json`
   (`scale/(1+exp(-(slope*raw+offset)))`, or raw when `calib == null`), threshold, sort, take top-N.
   Map output index `i` → `labels[i]`.
5. **Replace ML Kit** — swap the ML Kit calls in `MDBestPhotoManager+ImageLabeling.swift` for the
   Core ML labeler, then remove `MLKitImageLabelingCustom` from the SDK `Package.swift`.
   `MLKitVisionKit` (44 MB) drops out of the link.
6. **Regression-test** — base ML Kit vs Core ML top-N labels + calibrated scores on a fixed set.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Converter is not implemented (... QuantizeLinear)` in onnx2torch | You didn't strip QDQ (Step 3), or a `QuantizeLinear` feeds a trailing `Reshape` — strip **all** Q/DQ nodes and rewire. |
| `pip install tensorflow` fails | You're on Python 3.13. Use **3.11**. |
| Core ML top-5 differs from TFLite on noise | Expected — int8 vs float on meaningless scores. Validate on real images. |
| Wrong labels / off-by-one | Mapping is **1:1, 0-based** (447 outputs ↔ 447 labels). There is **no** background class. |
| `coremltools` warns about untested TF/Torch versions | Harmless; conversion still succeeds. |
```
