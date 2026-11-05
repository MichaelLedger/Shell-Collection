# Created by Gavin Xiang on 10/16/26.
# Copyright © 2026 PlanetArt. All rights reserved.

"""Convert a UIQA checkpoint into a Core AI .aimodel and, optionally, a Core ML package.

The exported function takes one RGB image and returns a quality score.
Input ``image`` is float32 NCHW ``[1, 3, 360, 360]`` with pixel values in
``0...255``. Normalization and the distortion-branch spatial fragments run
inside the model. Weights are stored as INT8 per channel.
"""

import argparse
import math
import shutil
import sys
from pathlib import Path

import coremltools as ct
import coremltools.optimize as cto
import torch
import torch.nn as nn
from coreai.runtime import AIModelAssetMetadata
from coreai_opt.coreai_utils import DType, quantize_weights
from coreai_torch import TorchConverter, get_decomp_table
from coreai_torch._utils import get_operand
from torchvision.models import swin_t

INPUT_SIZE = 360
FRAGMENT_COUNT = 15
FRAGMENT_SIZE = 32
CHECKPOINT = Path(
    "v2-2025-10-18/UIQA_UHD_IQA_V2__NR_epoch_42_SRCC_0.726446.pth"
)
OUTPUT = Path("v2-2025-10-18/UIQAModel.aimodel")


def spatial_fragments(image: torch.Tensor) -> torch.Tensor:
    """Tile a fixed grid of crops into one distortion-branch tensor."""
    rows = []
    height_step = INPUT_SIZE // FRAGMENT_COUNT
    width_step = INPUT_SIZE // FRAGMENT_COUNT
    max_start = INPUT_SIZE - FRAGMENT_SIZE
    for row in range(FRAGMENT_COUNT):
        top = min(row * height_step, max_start)
        tiles = []
        for column in range(FRAGMENT_COUNT):
            left = min(column * width_step, max_start)
            tiles.append(
                image[
                    :,
                    :,
                    top : top + FRAGMENT_SIZE,
                    left : left + FRAGMENT_SIZE,
                ]
            )
        rows.append(torch.cat(tiles, dim=3))
    return torch.cat(rows, dim=2)


class SwinBackbone(nn.Module):
    def __init__(self):
        super().__init__()
        network = swin_t(weights=None)
        network.head = nn.Identity()
        self.network = network

    def forward(self, image: torch.Tensor) -> torch.Tensor:
        return self.network(image)


class UIQAModel(nn.Module):
    """Aesthetics, distortion, and saliency branches fused into one score."""

    def __init__(self):
        super().__init__()
        self.aesthetics_feature_extraction = SwinBackbone()
        self.distortion_feature_extraction = SwinBackbone()
        self.saliency_feature_extraction = SwinBackbone()
        self.quality = nn.Sequential(
            nn.Linear(768 * 3, 128),
            nn.Linear(128, 1),
        )

    def forward(self, aesthetics, distortion, saliency):
        features = torch.cat(
            (
                self.aesthetics_feature_extraction(aesthetics),
                self.distortion_feature_extraction(distortion),
                self.saliency_feature_extraction(saliency),
            ),
            dim=1,
        )
        return self.quality(features)


class PhotoScoreModel(nn.Module):
    """One photo in, one score out. Pixels are 0...255 RGB."""

    def __init__(self, model: UIQAModel):
        super().__init__()
        self.model = model
        self.register_buffer(
            "mean", torch.tensor([0.485, 0.456, 0.406]).view(1, 3, 1, 1)
        )
        self.register_buffer(
            "std", torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1)
        )

    def normalize(self, image: torch.Tensor) -> torch.Tensor:
        return (image.float() / 255.0 - self.mean) / self.std

    def forward(self, image: torch.Tensor) -> torch.Tensor:
        normalized = self.normalize(image)
        return self.model(
            normalized, spatial_fragments(normalized), normalized
        )


class BranchScoreModel(nn.Module):
    """Three RGB images in, one score out. Pixels are 0...255.

    Distortion is the only branch that is split into spatial fragments.
    The Core ML package keeps these as separate image inputs.
    """

    def __init__(self, scorer: PhotoScoreModel):
        super().__init__()
        self.scorer = scorer

    def forward(self, aesthetics, distortion, saliency):
        normalize = self.scorer.normalize
        return self.scorer.model(
            normalize(aesthetics),
            spatial_fragments(normalize(distortion)),
            normalize(saliency),
        )


def load_checkpoint(model: UIQAModel, path: Path) -> None:
    checkpoint = torch.load(path, map_location="cpu", weights_only=False)
    state = checkpoint["model_state_dict"] if "model_state_dict" in checkpoint else checkpoint
    remapped = {}
    for key, value in state.items():
        remapped[key.replace("_feature_extraction.", "_feature_extraction.network.")] = value
    missing, unexpected = model.load_state_dict(remapped, strict=True)
    if missing or unexpected:
        raise RuntimeError(f"checkpoint mismatch missing={missing} unexpected={unexpected}")


def _is_contiguous_reshape(size, stride, offset, numel) -> bool:
    """True when as_strided only reinterprets a dense buffer as ``size``."""
    if offset not in (0, None):
        return False
    if math.prod(size) != numel:
        return False
    running = 1
    contiguous = [0] * len(size)
    for index in range(len(size) - 1, -1, -1):
        contiguous[index] = running
        running *= size[index]
    for length, actual, expected in zip(size, stride, contiguous):
        if length != 1 and actual != expected:
            return False
    return True


def lower_as_strided(values_map, node, loc):
    """Lower the Swin reshape that Core AI does not map itself.

    The V2 graph contains three ``aten.as_strided`` nodes that view a
    768-vector as ``[1, 768, 1, 1]``. Size-1 dimensions carry dummy strides,
    and the remaining layout is contiguous, so this is a reshape.
    """
    del loc
    from coreai._compiler.dialects import coreai

    size = [int(item) for item in node.args[1]]
    stride = [int(item) for item in node.args[2]]
    offset = int(node.args[3]) if len(node.args) > 3 else 0
    source_value = node.args[0].meta["val"]
    numel = math.prod(int(dim) for dim in source_value.shape)
    if not _is_contiguous_reshape(size, stride, offset, numel):
        raise ValueError(
            "as_strided is not a dense reshape: "
            f"size={size} stride={stride} offset={offset} numel={numel}"
        )
    return coreai.reshape(get_operand(values_map, node, 0), size)


def save_aimodel(scorer: PhotoScoreModel, checkpoint_path: Path, output_path: Path) -> None:
    example = torch.rand(1, 3, INPUT_SIZE, INPUT_SIZE) * 255
    print("Exporting Core AI program...")
    exported = torch.export.export(scorer, (example,))
    exported = exported.run_decompositions(get_decomp_table())
    converter = TorchConverter()
    converter.register_torch_lowering("aten::as_strided.default")(lower_as_strided)
    program = converter.add_exported_program(
        exported,
        input_names=["image"],
        output_names=["quality_score"],
    ).to_coreai()
    print("Quantizing Core AI weights to INT8 per channel...")
    program = quantize_weights(coreai_program=program, dtype=DType.INT8, in_place=False)
    metadata = AIModelAssetMetadata()
    metadata.author = "PlanetArt"
    metadata.license = "Proprietary"
    metadata.model_description = (
        "UIQA no-reference photo quality score. "
        "Weights are INT8 per channel. "
        "Input image is float32 NCHW [1, 3, 360, 360], RGB pixels 0...255. "
        "Output quality_score is the fused regression value."
    )
    metadata.set_custom("checkpoint", checkpoint_path.name)
    metadata.set_custom("input_size", str(INPUT_SIZE))
    metadata.set_custom("weight_precision", "int8_per_channel")
    asset = program.save_asset(output_path, metadata=metadata)
    print(f"Saved {asset.path}")


def save_mlpackage(scorer: PhotoScoreModel, checkpoint_path: Path, output_path: Path) -> None:
    branch_model = BranchScoreModel(scorer).eval()
    example = torch.rand(1, 3, INPUT_SIZE, INPUT_SIZE) * 255
    print("Exporting Core ML program...")
    exported = torch.export.export(branch_model, (example, example, example))
    exported = exported.run_decompositions({})
    image = dict(shape=example.shape, color_layout=ct.colorlayout.RGB, scale=1.0, bias=[0, 0, 0])
    mlmodel = ct.convert(
        exported,
        inputs=[
            ct.ImageType(name="input_aesthetics", **image),
            ct.ImageType(name="input_distortion", **image),
            ct.ImageType(name="input_saliency", **image),
        ],
        outputs=[ct.TensorType(name="quality_score")],
        minimum_deployment_target=ct.target.iOS16,
        convert_to="mlprogram",
        compute_units=ct.ComputeUnit.ALL,
    )
    mlmodel.author = "PlanetArt"
    mlmodel.license = "Proprietary"
    mlmodel.short_description = (
        "UIQA no-reference photo quality score. "
        f"Converted from {checkpoint_path.name}. "
        "Three 360x360 RGB images; weights are INT8 per channel."
    )
    mlmodel.version = "1.0.0"
    print("Quantizing Core ML weights to INT8...")
    op_config = cto.coreml.OpLinearQuantizerConfig(
        mode="linear_symmetric",
        weight_threshold=512,
    )
    mlmodel = cto.coreml.linear_quantize_weights(
        mlmodel,
        config=cto.coreml.OptimizationConfig(global_config=op_config),
    )
    staging = output_path.with_name(output_path.stem + ".next.mlpackage")
    if staging.exists():
        shutil.rmtree(staging)
    mlmodel.save(str(staging))
    if output_path.exists():
        shutil.rmtree(output_path)
    staging.rename(output_path)
    print(f"Saved {output_path}")


def main() -> None:
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Convert a UIQA checkpoint to Core AI and Core ML.")
    parser.add_argument("--checkpoint", type=Path, default=root / CHECKPOINT)
    parser.add_argument("--aimodel", type=Path, default=root / OUTPUT)
    parser.add_argument("--mlpackage", type=Path, default=None)
    parser.add_argument("--skip-aimodel", action="store_true")
    args = parser.parse_args()
    checkpoint_path = args.checkpoint if args.checkpoint.is_absolute() else root / args.checkpoint
    aimodel_path = args.aimodel if args.aimodel.is_absolute() else root / args.aimodel

    print(f"Loading {checkpoint_path}")
    model = UIQAModel()
    load_checkpoint(model, checkpoint_path)
    model.eval()
    scorer = PhotoScoreModel(model).eval()
    example = torch.rand(1, 3, INPUT_SIZE, INPUT_SIZE) * 255
    with torch.no_grad():
        reference = scorer(example)
    print(f"PyTorch score {reference.detach().flatten()[0].item():.6f}")

    save_aimodel(scorer, checkpoint_path, aimodel_path) if not args.skip_aimodel else None
    if args.mlpackage is not None:
        mlpackage_path = args.mlpackage if args.mlpackage.is_absolute() else root / args.mlpackage
        save_mlpackage(scorer, checkpoint_path, mlpackage_path)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Conversion failed: {error}", file=sys.stderr)
        raise
