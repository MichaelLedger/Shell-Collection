# source ./venv_py39_fresh/bin/activate
# python3 convert_to_coreml.py
# ./venv_py39_fresh/bin/python convert_to_coreml.py

import sys
import os
import torch
import numpy as np
import coremltools as ct
import coremltools.optimize as cto
import logging
from models.UIQA import UIQA_Model, infer_num_branches_from_checkpoint

# Set up logging
logger = logging.getLogger(__name__)

def get_spatial_fragments(x: torch.Tensor, n_fragment: int = 15, fsize: int = 32) -> torch.Tensor:
    """Get spatial fragments for distortion analysis using vectorized operations"""
    B, C, H, W = x.shape[0], x.shape[1], x.shape[2], x.shape[3]
    
    # Calculate steps
    h_step = H // n_fragment
    w_step = W // n_fragment
    
    # Create position tensors
    h_starts = torch.arange(n_fragment, device=x.device) * h_step
    w_starts = torch.arange(n_fragment, device=x.device) * w_step
    
    # Clamp to valid positions
    h_starts = torch.clamp(h_starts, max=H - fsize)
    w_starts = torch.clamp(w_starts, max=W - fsize)
    
    # Create output tensor
    out_h = n_fragment * fsize
    out_w = n_fragment * fsize
    output = torch.zeros(B, C, out_h, out_w, device=x.device)
    
    # Use grid positions to extract and place fragments
    for i in range(n_fragment):
        h_start = h_starts[i]
        h_out = i * fsize
        for j in range(n_fragment):
            w_start = w_starts[j]
            w_out = j * fsize
            output[:, :, h_out:h_out+fsize, w_out:w_out+fsize] = x[
                :, :, h_start:h_start+fsize, w_start:w_start+fsize
            ]
    
    return output

class UIQAWrapper(torch.nn.Module):
    """Wrapper module for UIQA model with preprocessing (3- or 4-branch checkpoints)."""
    def __init__(self, base_model, num_branches=4):
        super().__init__()
        self.model = base_model
        self.num_branches = num_branches
        self.register_buffer('mean', torch.tensor([0.485, 0.456, 0.406]).reshape(1, 3, 1, 1))
        self.register_buffer('std', torch.tensor([0.229, 0.224, 0.225]).reshape(1, 3, 1, 1))
        self.eval()
    
    def normalize(self, x):
        x = x.float() / 255.0
        return (x - self.mean) / self.std
    
    def forward(self, x1, x2, x3, x4=None):
        with torch.no_grad():
            x1 = self.normalize(x1)
            x2 = get_spatial_fragments(self.normalize(x2))
            x3 = self.normalize(x3)
            if self.num_branches == 4:
                x4 = self.normalize(x4)
                return self.model(x1, x2, x3, x4)
            return self.model(x1, x2, x3)


def convert_uiqa_model_to_coreml():
    print('Starting UIQA model conversion to Core ML...')
    
    # pth_path = './backups/uhd-planetart/01-06/UIQA_UHD_IQA_V4__NR_epoch_44_SRCC_0.765663.pth'
    pth_path = './ckpts/v4-2026-05-25/UIQA_UHD_IQA_V4__NR_epoch_3_SRCC_0.736391.pth'
    checkpoint = torch.load(pth_path, map_location='cpu')
    try:
        num_branches = infer_num_branches_from_checkpoint(checkpoint)
    except ValueError as e:
        print(f'Error inferring architecture from checkpoint: {e}')
        sys.exit(1)
    print(f'Checkpoint fusion head implies {num_branches}-branch UIQA (Swin-T, 768-d per branch)')

    model = UIQA_Model(num_branches=num_branches)
    model.eval()
    
    # Load weights
    try:
        if isinstance(checkpoint, dict):
            if 'model_state_dict' in checkpoint:
                model.load_state_dict(checkpoint['model_state_dict'], strict=False)
            else:
                model.load_state_dict(checkpoint, strict=False)
        else:
            model.load_state_dict(checkpoint, strict=False)
        print(f'Successfully loaded model weights: {pth_path}')
    except Exception as e:
        print(f'Error loading model weights: {str(e)}')
        sys.exit(1)
    
    wrapped_model = UIQAWrapper(model, num_branches=num_branches)
    
    input_shape = (1, 3, 360, 360)
    example_inputs = [
        torch.rand(*input_shape),
        torch.rand(*input_shape),
        torch.rand(*input_shape),
    ]
    if num_branches == 4:
        example_inputs.append(torch.rand(*input_shape))
    
    # Trace model
    print('Tracing model...')
    try:
        # First trace the model
        traced_model = torch.jit.trace(wrapped_model, example_inputs)
        traced_model.eval()
        
        # Save traced model temporarily
        torch.jit.save(traced_model, 'traced_model.pt')
        
        # Verify outputs
        with torch.no_grad():
            traced_output = traced_model(*example_inputs)
            original_output = wrapped_model(*example_inputs)
            if not torch.allclose(traced_output, original_output, rtol=1e-3):
                print("Warning: Traced model outputs differ from original!")
                print(f"Original: {original_output.item():.6f}")
                print(f"Traced: {traced_output.item():.6f}")
        
        print('Successfully traced model')
    except Exception as e:
        print(f'Error tracing model: {str(e)}')
        sys.exit(1)
    
    # Convert to Core ML
    print('Converting to Core ML...')
    try:
        coreml_package_name = "UIQAModel.mlpackage"
        # Load traced model
        traced_model = torch.jit.load('traced_model.pt')
        
        input_desc = [
            ct.ImageType(
                name="input_aesthetics",
                shape=input_shape,
                color_layout=ct.colorlayout.RGB,
                scale=1.0,
                bias=[0, 0, 0]
            ),
            ct.ImageType(
                name="input_distortion",
                shape=input_shape,
                color_layout=ct.colorlayout.RGB,
                scale=1.0,
                bias=[0, 0, 0]
            ),
            ct.ImageType(
                name="input_saliency",
                shape=input_shape,
                color_layout=ct.colorlayout.RGB,
                scale=1.0,
                bias=[0, 0, 0]
            ),
        ]
        if num_branches == 4:
            input_desc.append(
                ct.ImageType(
                    name="input_content_value",
                    shape=input_shape,
                    color_layout=ct.colorlayout.RGB,
                    scale=1.0,
                    bias=[0, 0, 0]
                )
            )
        
        # Convert model with optimized settings
        mlmodel = ct.convert(
            traced_model,
            inputs=input_desc,
            outputs=[
                ct.TensorType(name="quality_score")
            ],
            minimum_deployment_target=ct.target.iOS16,
            convert_to="mlprogram",
            compute_units=ct.ComputeUnit.ALL  # Use all available compute units
        )
        
        # Add metadata
        mlmodel.author = "PlanetArt/GavinXiang"
        mlmodel.license = "MIT License"
        mlmodel.short_description = "UIQA model for ultra-high-definition image quality assessment"
        mlmodel.version = "1.0.0"
        
        print('Applying optimizations...')
        
        # Apply 8-bit quantization with per-channel granularity
        print('Applying 8-bit quantization...')
        op_config = cto.coreml.OpLinearQuantizerConfig(
            mode="linear_symmetric",  # Symmetric quantization for better efficiency
            weight_threshold=512  # Only quantize weights larger than this threshold
        )
        config = cto.coreml.OptimizationConfig(global_config=op_config)
        
        # Apply quantization
        mlmodel = cto.coreml.linear_quantize_weights(mlmodel, config=config)
        
        # Save model
        mlmodel.save(coreml_package_name)
        print('Successfully saved Core ML model')
        
        # Clean up temporary file
        if os.path.exists('traced_model.pt'):
            os.remove('traced_model.pt')
        
    except Exception as e:
        print(f'Error converting to Core ML: {str(e)}')
        # Clean up temporary file
        if os.path.exists('traced_model.pt'):
            os.remove('traced_model.pt')
        sys.exit(1)
    
    print(f'Conversion completed successfully: {coreml_package_name}!')

if __name__ == "__main__":
    convert_uiqa_model_to_coreml()