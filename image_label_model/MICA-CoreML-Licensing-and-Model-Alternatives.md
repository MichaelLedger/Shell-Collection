# MICA Core ML — Licensing Analysis & License-Clean Model Alternatives

Research notes (2026-07-16) covering: (1) whether converting ML Kit's base image-labeling
model to Core ML is permitted under Apache 2.0, and (2) license-clean model options that keep
the ~44 MB `MLKitVisionKit` size win.

> Not legal advice. The ToS/IP conclusions below should be confirmed by legal before shipping.

---

## 1. Does the Core ML conversion "obey Apache 2.0"?

**Short answer: the *tools* comply with Apache 2.0, but Apache 2.0 does NOT govern the model —
so it grants no right to extract/convert/ship ML Kit's base model.**

### What Apache 2.0 actually covers here
The ML Kit docs footer states: *"content of this page is licensed under CC‑BY‑4.0, and **code
samples** are licensed under the Apache 2.0 License."* So Apache 2.0 covers only:
- Google's **sample code** snippets, and
- the **open-source conversion tools** we ran.

Conversion tool licenses (all permissive, compliance = retain notices; none copyleft):

| Tool | License |
|---|---|
| coremltools | BSD‑3‑Clause |
| tf2onnx, onnx, onnx2torch, TensorFlow / ai-edge-litert | Apache‑2.0 |
| onnxruntime | MIT |
| PyTorch, NumPy | BSD |

### What Apache 2.0 does NOT cover — the model
The base model (`mobile_ica_8bit_with_metadata.tflite`, its 447-label map, and the score
calibration) is **proprietary Google IP** governed by the **ML Kit Terms of Service** (which
incorporate the Google APIs ToS) — NOT Apache 2.0. Verbatim from the ML Kit ToS
(https://developers.google.com/ml-kit/terms, last modified 2025‑05‑14):

- *"For purposes of these terms, machine learning models will be considered related software."*
- *"you may not reverse engineer or **attempt to extract** the source code or **any related
  software** …"*

Our Option D pipeline extracts that `.tflite` from the SDK binary → converts → redistributes the
weights. That is extracting Google's proprietary model, which the ToS prohibits. Apache 2.0
provides no cover because the model was never offered under it (Google's docs confirm the base
model is proprietary and not available as a standalone download).

**Conclusion:** conversion is technically sound and the tooling is license-clean, but
**redistributing the converted ML Kit base model is very likely an ML Kit ToS violation.**
This is the long-standing "Licensing call" risk — an owner/legal decision.

---

## 2. The label space is Open Images (permissively licensed)

All 447 labels are Google **Knowledge Graph MIDs** (`/m/…`) — the same label space as
**Open Images**. Google also publishes the exact 447-label map at
https://developers.google.com/ml-kit/vision/image-labeling/label-map (index 0 = Team,
1 = Bonfire, 2 = Comics, … — matches our extracted `mica_labels_calibration.json`).

Overlap of our 447 labels vs Open Images V3 (`class-descriptions.csv` = 19,995 classes;
`classes-trainable.txt` = 5,000):

| Metric | Count | % |
|---|---|---|
| Present in Open Images V3 (19,995 classes) | 446 / 447 | **99.8%** |
| Present in Open Images V3 **trainable** (5,000) | 410 / 447 | **91.7%** |
| Not in Open Images V3 at all | 1 (`Steaming` `/m/0dxpb`) | 0.2% |
| Name mismatches among matched | 2 (trivial synonyms: Bicycle/Bike, Cutlery/Silverware — same MID) | — |

Open Images licensing: annotations **CC‑BY‑4.0**, repo code/models **Apache‑2.0**, images
**CC‑BY‑2.0** (verify per-image; standard Open Images caveat). Because everything is keyed by
MID, swapping in an Open-Images-space model needs **near-zero remapping** — the
PhotoEventEngine keeps matching by name/MID.

---

## 3. Model options (keep the 44 MB win, license-clean)

There is **no ready-made mobile-sized Apache‑2.0 classifier in the Open Images label space**.
The only official Open Images image-level classifier is the large `oidv2-resnet_v1_101`
(~170 MB). All ready-made *mobile* MobileNet classifiers (TF Hub / Kaggle / KerasHub) are
**ImageNet‑1k** — the wrong label space.

| Option | License | Mobile size | Label match | Effort | Verdict |
|---|---|---|---|---|---|
| **A. Train MobileNet on Open Images** (447 classes) | CC‑BY‑4.0 data / output yours | ~3–6 MB | Exact MIDs, ~zero remap | ML training + data | **Recommended** |
| **B. Distill Open Images ResNet‑101 → MobileNet student** | Apache‑2.0 teacher / output yours | ~3–6 MB | Exact MIDs | Distillation pipeline | Good if you have unlabeled images |
| C. Convert Apache Open Images ResNet‑101 as-is | Apache‑2.0 | ~85 MB fp16 | Exact MIDs, drop-in | Low | ❌ bigger than the 44 MB removed |
| D. ImageNet MobileNet (drop-in) | Apache‑2.0 | ~3–6 MB | Poor concept overlap | Low | ❌ PhotoEventEngine rules break |

### Recommended: Route A
Fine-tune a MobileNetV3 on Open Images image-level labels restricted to the 447 MIDs.
- Mobile-sized, fully-owned, license-clean, exact MID space → `MICAImageLabeler` +
  PhotoEventEngine unchanged (drop-in `.mlpackage` + labels JSON swap; re-run the same 224×224
  path; calibration optional/re-fit).
- 410/447 are "trainable" (≥30 verified samples); the other 37 + the 1 absent `Steaming` are
  data-sparse → expect weaker accuracy on those, or drop them.
- Obligations are permissive and satisfiable: **CC‑BY‑4.0 attribution** for annotations +
  per-image license verification — fundamentally different from the ML Kit ToS, which flatly
  prohibits extraction.

### Reference URLs
- ML Kit ToS: https://developers.google.com/ml-kit/terms
- ML Kit base label map (447): https://developers.google.com/ml-kit/vision/image-labeling/label-map
- Open Images class descriptions: https://storage.googleapis.com/openimages/2017_11/class-descriptions.csv
- Open Images trainable classes: https://storage.googleapis.com/openimages/2017_11/classes-trainable.txt
- Open Images ResNet‑101 (oidv2) checkpoint: https://storage.googleapis.com/openimages/2017_07/oidv2-resnet_v1_101.ckpt.tar.gz

---

## 4. Bottom line

- The Core ML **code + tooling** we shipped is license-clean and model-agnostic.
- Shipping the **extracted ML Kit base model** (current `MobileICA.mlpackage`) is the licensing
  risk — likely an ML Kit ToS violation; get legal sign-off or replace the model.
- The label-space problem is **solved** (Open Images, permissive, 99.8% MID overlap). The only
  remaining work to be fully clean is producing a mobile model in that space via **Route A
  (train)** or **Route B (distill)** — then drop it into the existing `MICAImageLabeler` path.
