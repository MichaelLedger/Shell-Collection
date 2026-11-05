# UIQA Core AI model

Photo Score, for this test, includes only the iPhone 16 chip. That is `h17p` (A18 and A18 Pro), delivered as one On-Demand Resource.

## Generate

From `coreai-torch`, with the project virtualenv:

```sh
./generate_aimodel.sh
```

That reads `v4-2026-05-25/UIQA_UHD_IQA_V4__NR_epoch_3_SRCC_0.736391.pth` and writes:

- `v4-2026-05-25/UIQAModel.aimodel` — source model, about 87 MB, INT8 weights
- `v4-2026-05-25/compiled/UIQAModel.<architecture>.aimodelc` — one GPU executable per iOS chip, about 356 MB each

Pass your own paths when the checkpoint is not the V4 file:

```sh
./generate_aimodel.sh /path/to/model.pth /path/to/UIQAModel.aimodel
```

Add a Core ML package as the third argument when you also want `UIQAModel.mlpackage`:

```sh
./generate_aimodel.sh \
  v4-2026-05-25/UIQA_UHD_IQA_V4__NR_epoch_3_SRCC_0.736391.pth \
  v4-2026-05-25/UIQAModel.aimodel \
  v4-2026-05-25/UIQAModel.mlpackage
```

Compile again without converting when the `.aimodel` is already current:

```sh
./compile_aimodel.sh v4-2026-05-25/UIQAModel.aimodel v4-2026-05-25/compiled
```

`compile_aimodel.sh` runs:

```sh
xcrun --sdk iphoneos coreai-build compile UIQAModel.aimodel \
  --platform iOS \
  --preferred-compute gpu \
  --output v4-2026-05-25/compiled
```

GPU is required. This graph's float32 activations are rejected by the Neural Engine, so a default compile does not produce a usable iPhone executable.

Check which chip a compiled file targets:

```sh
xcrun --sdk iphoneos coreai-build inspect \
  v4-2026-05-25/compiled/UIQAModel.h17p.aimodelc --no-io
```

## Chips

`coreai-build` names each file `UIQAModel.<architecture>.aimodelc`. iPhone and iPad chips that share an architecture share one file.

| File | Chips |
|---|---|
| `UIQAModel.h13g.aimodelc` | M1 |
| `UIQAModel.h14g.aimodelc` | M2 |
| `UIQAModel.h15g.aimodelc` | M3 |
| `UIQAModel.h16g.aimodelc` | M4 |
| `UIQAModel.h16p.aimodelc` | A17 Pro |
| `UIQAModel.h17g.aimodelc` | M5 |
| `UIQAModel.h17p.aimodelc` | A18, A18 Pro |
| `UIQAModel.h18p.aimodelc` | A19, A19 Pro |
| `UIQAModel.h19p.aimodelc` | iOS 27 chip, name not reported by the compiler |

The `.aimodelc` is larger than the `.aimodel` because the GPU executable stores the INT8 weights as float32. There is no compile flag that packs them back down.

## On-Demand Resources

`UIQAScoreDemo` currently tags only `UIQAModel.h17p.aimodelc` as an On-Demand Resource, with tag `h17p`. It is not part of the initial install. The other compiled files can stay on disk; they are not in this demo.

On launch the app does this:

1. Read `AIModel.deviceArchitectureName`.
2. `NSBundleResourceRequest(tags: [architecture])` and `beginAccessingResources()`.
3. Open `UIQAModel.<architecture>.aimodelc` from the app bundle.
4. `AIModel.specialize`, then `AIModel(contentsOf:options:)` with `SpecializationOptions(preferredComputeUnitKind: .gpu)`.
5. Run one warmup inference so the first photo is not paying for GPU pipeline setup.

The resource request is kept for the life of the process so the system does not purge the downloaded file. If that tag is missing, the app loads the bundled source `UIQAModel.aimodel` and specializes it on the device. That path is the slow one.

A debug install hosts the `h17p` pack on the Mac, under `OnDemandResources` next to the app. The installed app stays about 88 MB. The Xcode console logs `odr download`, then the load phases, then each `score` phase. The on-screen load time starts after the download returns, so `odr download` is not inside `load total`.

## iPhone 16 debug timing

Measured on an iPhone 16 debug install, first launch, tag `h17p`. The pack was hosted by Xcode on the Mac.

| Phase | Seconds |
|---|---|
| odr download | 12.336 |
| load cache lookup | 0.007 |
| load specialize | 0.681 |
| load AIModel | 0.001 |
| load function | 0.578 |
| load warmup | 5.525 |
| load total | 6.792 |
| score pixels | 0.040 |
| score input | 0.020 |
| score run | 0.269 |
| score read | 0.000 |
| score total | 0.330 |

`load total` is the sum of the five load rows above it. Wall time until the first photo can be scored is the download plus that total, 19.128 seconds. Warmup is most of the load. After it, scoring one photo is 0.330 seconds, and 0.269 seconds of that is `function.run`.

iOS 27 marks `NSBundleResourceRequest` deprecated and points at Background Assets. Photo Score still uses the On-Demand Resource request, which is what produces these asset packs.

## Model contract

The Core AI model takes one input, `image`: float32 NCHW `[1, 3, 360, 360]`, RGB pixels 0...255. It returns `quality_score`. ImageNet normalization and the distortion fragments are inside the model.

The Core ML package, when you generate one, takes three 360×360 RGB images: `input_aesthetics`, `input_distortion`, and `input_saliency`. It returns `quality_score`. `UIQACoreMLDemo` loads that package.
