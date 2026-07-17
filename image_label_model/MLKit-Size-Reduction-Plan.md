# MLKit App Size Reduction Plan

**Goal:** Shrink the app package (currently >200 MB) by removing the ~44 MB `MLKitVisionKit`
binary that the **base** image-labeling model drags in, while keeping the PhotoEventEngine's
label matching behavior identical.

**Context:** `Sources/PRTSelectPhoto` links `MLKitObjectDetection` + `MLKitImageLabeling`
(`google-mlkit-swiftpm` 9.0.2). Only `MLKitImageLabeling` / `MLKitVision` are actually imported.

---

## ⛔️ BLOCKER (2026-07-16): core premise is FALSE — Custom also needs VisionKit

Proven at the binary level (`nm`) against the resolved 9.0.2 artifacts:

- `MLKitImageLabelingCustom.xcframework` has **undefined** references to
  `_OBJC_CLASS_$_MLKVisionKitImageLabeler`, `_OBJC_CLASS_$_MLKVisionKitErrorExtractor`,
  `_OBJC_CLASS_$_VNKMLKitImageLabelingOptions` (plus `createVisionKitImageLabeler`,
  `visionKitOptionsFromMLKitOptions:`, …).
- Those classes are **defined only in `MLKitVisionKit.framework` (44 MB)**.
- Google's official podspec agrees: `MLKitImageLabelingCustom (1.2.0)` → depends on
  `MLKitVisionKit (~> 2.1)`. The `Planetart`/`d-date` SwiftPM **product**
  `MLKitImageLabelingCustom` omits the `MLKitVisionKit` target, which is exactly why the
  device link now fails with `Undefined symbol: _OBJC_CLASS_$_MLKVisionKitImageLabeler` etc.

**Consequence:** switching base → custom does **not** remove `MLKitVisionKit`. Any use of the
ML Kit image labeler (base *or* custom) requires the 44 MB `MLKitVisionKit`. The only way to
actually drop it is to stop using ML Kit for labeling and run the `.tflite` via **TensorFlowLite**
(already linked through `MirrorSDK` / PhotoEventEngine). See "Revised options" below.

## Key findings (verified against resolved artifacts)

| Item | Fact |
|---|---|
| Biggest cost | `MLKitVisionKit` ≈ **44 MB** (arm64 thinned) |
| ~~`MLKitImageLabelingCustom` avoids VisionKit~~ | ❌ **WRONG** — Custom links `MLKitVisionKit` too (see BLOCKER above) |
| `MLKitObjectDetection` | Declared in `Package.swift` but **never imported** → free to delete |
| Base model file | `mobile_ica_8bit_with_metadata.tflite` (2.9 MB), lives inside `MLKitImageLabeling.xcframework` |
| Model labels | Embedded metadata: `0-labels-en.txt`, `0-labels.txt`, `0-score-calibration.txt` (the exact 400-entity vocabulary) |
| Model sha256 | `4afa3970d3efd6726d147d505e28c7ff1e4fe1c24be7bcda6b5429eb099777a5` |
| Official download? | **No.** Google docs: base model is proprietary / SDK-bundled. Custom path points to TF Hub / AutoML (different labels). |
| ODR | Frameworks CANNOT go in ODR. A standalone `.tflite` data file CAN. |

---

## Risks / open decisions (resolve BEFORE shipping)

- [ ] **Licensing call (owner: team):** Re-bundling Google's extracted `.tflite` is a gray area,
      not officially sanctioned. Decide: extract-and-reuse vs. train/host an equivalent model.
- [ ] **SDK upgrade brittleness:** Every `google-mlkit-swiftpm` bump requires re-extracting the
      model + re-checking the sha256. Add a guard/checksum test.
- [ ] **Behavioral parity:** Base labeler may preprocess differently than the custom path.
      Must validate identical top-N labels/confidences before merge (not assume).

---

## Task breakdown

### Phase 0 — Free win (zero risk)  ✅ DONE
- [x] Remove `.product(name: "MLKitObjectDetection", …)` from `Package.swift` — was unused.

### Phase 1 — Switch to custom framework  ✅ DONE
- [x] Change `MLKitImageLabeling` → `MLKitImageLabelingCustom` in `Package.swift`.
- [x] Manifest validated (`swift package dump-package` OK).
- [ ] Confirm `MLKitVisionKit` gone from resolved graph after a device build (pending build).

### Phase 2 — Model delivery  (owner: you, main project)  ✅ DONE
- [x] Extracted `mobile_ica_8bit_with_metadata.tflite` → `~/Desktop` (2.9 MB, sha256 `4afa3970…777a5`).
- [x] Add the `.tflite` to the main project's ODR xcassets tag
      (`bestphoto.xcassets/mobile_ica_8bit_with_metadata.dataset`, tag `bestphoto_mlkit_label`).
      Verified on-disk sha256 == `4afa3970…777a5`.
- [x] Store expected sha256 for a checksum guard
      (`WBKBestPhotoImageLabelingModelProvider.expectedSHA256`; enforced on materialize + cache read).

### Phase 3 — Code changes (`MDBestPhotoManager+ImageLabeling.swift`)  ✅ DONE
- [x] Replaced `ImageLabelerOptions()` (base) with `CustomImageLabelerOptions(localModel:)`.
- [x] Added `public static var imageLabelingModelPathProvider: (() -> String?)?` injection point
      + `Bundle.main` fallback (`mobile_ica_8bit_with_metadata.tflite`).
- [x] Preserved `imageAlignedWithPhotobooksMLKitInput` normalization + threshold 0 + top-40 sort.
- [x] Set `maxResultCount = 1000` (custom API defaults to 10 — would truncate labels).
- [x] Used `NSNumber(value:)` for `confidenceThreshold` (custom API type is `NSNumber?`, not `Float`).
- [x] Kept `#if !targetEnvironment(simulator)` guards; returns `[]` when model unavailable.

#### Main-project integration contract (what the host app must do)  ✅ DONE
- Implemented in `WBKBestPhotoImageLabelingModelProvider` (in `WBKBestPhotoBookManager.swift`,
  PBSubmodule). Chose option (a): download tag → verify SHA-256 → write `NSDataAsset` bytes to
  `Application Support/.odr/bestphoto_mlkit_odr/mobile_ica_8bit_with_metadata.tflite` → hand that
  path to `MDBestPhotoManager.imageLabelingModelPathProvider`. Mirrors the existing
  `MDBestPhotoNsfwODRProvider` pattern in the SDK.
- Provider install is automatic on `WBKBestPhotoBookManager` init; download is pre-warmed from the
  best-photo entry points (`-generateBestPhotoBook` and the album-picker confirm) via
  `-prewarmImageLabelingModel`, so the ~2.9 MB model lands on disk before generation reads it.
- The provider assignment is guarded by `#if !targetEnvironment(simulator)` and
  `if #available(iOS 16.0, *)` to match the SDK API's own gating.
- Original notes (why a file path is needed): asset-catalog **Data Sets** expose `NSDataAsset`
  (in-memory `Data`), NOT a file path, while `LocalModel` needs a **file path**.

### Phase 4 — Validation
- [ ] Extend `MDBestPhotoEventTaggingSampleCapDeviceTests` (or new test): run a fixed image set
      through base vs. custom-with-extracted-model, assert identical top-N labels + confidences
      (within tolerance).
- [ ] Confirm PhotoEventEngine event tagging output is unchanged on the sample set.
- [ ] Measure final `.ipa` / app thinning size delta (expect ~44 MB drop from always-installed).

---

## Revised options (after the BLOCKER)

- **A. Unblock now, keep ML Kit (abandons the size win).** Add the `MLKitVisionKit` target back
  to the link — simplest via re-adding `.product(name: "MLKitImageLabeling", …)` in the SDK
  `Package.swift` (base pulls VisionKit), or patch the `Planetart/google-mlkit-swiftpm` fork so the
  `MLKitImageLabelingCustom` product includes the `MLKitVisionKit` target. Build links again, but
  the 44 MB stays. ODR model delivery (already wired) becomes moot for size, though harmless.
- **B. Achieve the size win: drop ML Kit labeling, run `mobile_ica…tflite` on TensorFlowLite**
  (already linked). Removes `MLKitVisionKit` + `MLKitImageLabeling(Custom/Common)`. Requires
  re-implementing: input preprocessing to match ML Kit, parsing the embedded label maps +
  score-calibration, and top-N output parity. The ODR `.tflite` delivery already built is reused
  (TFLite `Interpreter(modelPath:)` consumes the same materialized file path).
- **C. VisionKit-free custom labeler** — not available (Google's podspec makes Custom depend on
  VisionKit). Not viable.
- **D. ✅ CHOSEN & PROVEN: convert the `.tflite` to a native Core ML `.mlpackage`.** Drops ALL of
  ML Kit (44 MB VisionKit + ImageLabeling*) *and* avoids TFLite; runs on the ANE via Vision/CoreML,
  reusing the app's existing Core ML infra (`MDBestPhotoCoreMLLoader`, `UIQACoreMLPredictor`).

### Option D — conversion status (2026-07-16)  ✅ FEASIBILITY PROVEN
- Model = int8 MobileNet. Input `conv_net_input` `[1,224,224,3]` uint8, normalize `(x-128)/128`
  (i.e. `[-1,1]`). Output `[1,1,1,447]` — **447 classes, 1:1 with the 447 labels (no background)**.
- Metadata (labels + score-calibration) is a ZIP appended to the `.tflite`; extracted to JSON.
  Calibration is a per-class sigmoid: `c = scale/(1+exp(-(slope*raw+offset)))` (17 classes have
  no calibration → use raw). 400→ actually **447** entries.
- Conversion pipeline (no direct converter exists):
  `tflite → (tf2onnx --dequantize) → float ONNX → (strip QDQ) → (onnx2torch) → torch → (coremltools) → .mlpackage`.
- Parity: Core ML(float) == ONNX(float) == PyTorch(float) **exactly**; differs from int8 TFLite only
  by quantization (≈0.15/step), top-N identical on real content. Validate on a fixed image set before merge.
- Artifacts (on `~/Desktop`): `MobileICA.mlpackage` (**5.7 MB fp16**), `mica_labels_calibration.json`
  (447 labels + calibration), `convert_mica_to_coreml.py` (reproducible — re-run on any SDK bump).

### Option D — integration work  ✅ DONE (SDK side, 2026-07-16)
- [x] Swift labeler `MICAImageLabeler` (`Sources/PRTSelectPhoto/Source/BestPhoto/MICAImageLabeler.swift`):
      raw Core ML (`model.prediction(from:)`, input is a **MLMultiArray** `image_nhwc [1,224,224,3]`,
      not an ImageType → no `VNCoreMLRequest`) → 447 logits → per-class sigmoid calibration from the
      bundled JSON (null → raw) → sort desc, tie-break by class index → top-40. Model loaded from a
      path (compiles `.mlpackage` if not `.mlmodelc`), cached; returns `[]` if unavailable.
- [x] `MDBestPhotoManager+ImageLabeling.swift` rewired to `MICAImageLabeler`; all ML Kit imports/APIs
      removed; simulator guard dropped (Core ML runs on simulator). Preprocessing preserved:
      `imageAlignedWithPhotobooksMLKitInput` (≤480 aspect-fit, scale=1, `.up`) then the labeler
      stretches to the model's fixed 224×224.
- [x] `imageLabelingModelPathProvider` repurposed to return the **Core ML** model path (`.mlmodelc`/
      `.mlpackage`); `Bundle.main` fallback name `MobileICA`. (Main-project ODR provider must now
      deliver `MobileICA.mlpackage` instead of the `.tflite`.)
- [x] Labels+calibration bundled in the SDK: `Resource/BestPhoto/mica_labels_calibration.json`
      (447 entries, 17 null). Loaded via `Bundle.module`.
- [x] Removed `MLKitImageLabelingCustom` **and** the `google-mlkit-swiftpm` package dependency from
      `Package.swift`. Confirmed `google-mlkit-swiftpm` is **gone from the resolved package graph** →
      `MLKitVisionKit` (44 MB) no longer linked.
- [x] `xcodebuild` on iOS Simulator: **BUILD SUCCEEDED** for `PRTSelectPhoto`.
- [x] Regression tests (`MICAImageLabelerTests`, 6/6 passing, no model needed): labels JSON load,
      calibration math, top-N ordering + tie-break, maxResults, NHWC channel layout.

### Option D — main-project delivery  ✅ DONE (2026-07-16)
- [x] Zipped `MobileICA.mlpackage` (plain zip, no password) → **2.4 MB** and shipped it as an
      ODR-tagged Data Set `bestphoto.xcassets/MobileICA.dataset` (tag `bestphoto_mlkit_label`,
      `NSDataAsset` name `MobileICA`).
- [x] Removed the now-unused `mobile_ica_8bit_with_metadata.dataset` (the old `.tflite` payload).
- [x] Rewrote `WBKBestPhotoImageLabelingModelProvider` (`WBKBestPhotoBookManager.swift`, PBSubmodule):
      download tag → write zip to `Application Support/.odr/bestphoto_mica_odr/` → unzip via
      `SSZipArchive` (`import ZipArchive`) → validate `MobileICA.mlpackage/Manifest.json` → hand that
      path to `MDBestPhotoManager.imageLabelingModelPathProvider`. Dropped the SHA-256 guard (zip is
      re-compressible; validity is now “unzipped `.mlpackage` with a `Manifest.json`”). Simulator guard
      removed (Core ML runs on simulator); still `if #available(iOS 16.0, *)`.
- [x] Prewarm wiring unchanged: `-prewarmImageLabelingModel` still fires from `-generateBestPhotoBook`
      and the album-picker confirm, so the ~2.4 MB model downloads before generation reads it.
- [x] **Wait for ODR before labeling** (no more silent skip on first run): SDK gained an async
      `MDBestPhotoManager.imageLabelingModelPreparer` hook, awaited once in `detectImageLabels(with:)`
      via `ensureImageLabelingModelReady(timeout: 60)` (fast-paths out once the model is on disk;
      60 s bound so an offline user degrades to no-labeling instead of hanging). The host sets the
      preparer in `installModelPathProvider()` to run `prepareModel()` (download → unzip → validate).
      Verified: `xcodebuild` iOS Simulator **BUILD SUCCEEDED** for `PRTSelectPhoto`.

### Option D — remaining (owner: you / main project)
- [ ] End-to-end parity on a fixed real-image set: compare current base ML Kit output (from a build
      before this change) vs Core ML top-N labels + calibrated scores; confirms the 224×224 resize
      choice matches. (Model-numeric parity already proven offline during conversion.)
- [ ] Device build + measure `.ipa` / app-thinning size delta (expect ~44 MB drop, +5.7 MB model via ODR).

## Expected outcome

- Always-installed binary: **~44 MB smaller** (VisionKit removed).
- Model (`MobileICA.mlpackage`, 5.9 MB on disk / **2.4 MB zipped**): deferred to on-demand download
  instead of statically linked.
- PhotoEventEngine: behavior unchanged (same model, same labels, same calibration).
