# UIQA Model CoreML Conversion Guide

This guide describes the process of converting the UIQA PyTorch model to CoreML format.

## Environment Setup

1. Create Python 3.9 virtual environment:
```bash
python3.9 -m venv venv_py39_fresh
source venv_py39_fresh/bin/activate
```

2. Install dependencies from `requirements_convert_coreml.txt`:
```bash
pip install -r requirements_convert_coreml.txt
```

## Model Architecture

The UIQA model consists of three branches:
- Aesthetics branch: Takes 480x480 RGB input
- Distortion branch: Takes 480x480 RGB input, applies spatial fragments
- Saliency branch: Takes 480x480 RGB input

## Conversion Steps

1. **Model Preparation**
   - Load PyTorch model and weights
   - Create wrapper module for preprocessing
   - Handle normalization internally (mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
   - Implement spatial fragments for distortion branch (15 fragments, 32x32 size)

2. **Model Tracing**
   - Use `torch.jit.trace` with example inputs
   - Verify traced model outputs match original
   - Save traced model temporarily

3. **CoreML Conversion**
   - Use `coremltools.convert` with specific settings:
     - Input names: input_aesthetics, input_distortion, input_saliency
     - ImageType inputs with scale=1.0, bias=[0,0,0]
     - FP16 precision for mobile optimization
     - iOS16 minimum deployment target
     - MLProgram backend
     - All compute units enabled

4. **Model Metadata**
   - Set author, license, description
   - Set version number
   - Save as UIQAModel.mlpackage

## Optimization Settings

- **Compute Precision**: INT8 for maximum mobile performance and smallest model size
- **GPU Precision**: Forced to INT8 for consistent performance
- **Metal Device**: Any Metal device supported for INT8 operations
- **Compute Units**: ALL (CPU, GPU, Neural Engine)
- **Input Processing**: Handled internally by the model
- **Memory**: Skip model loading to avoid BlobWriter issues

## Verification

1. Check model inputs:
   - All inputs should be 480x480 RGB images
   - Normalization is handled by the model
   - Spatial fragments are computed internally

2. Test model outputs:
   - Single quality score output
   - Values should be in expected range
   - Performance should be optimized for mobile

## Common Issues

1. **BlobWriter Issues**
   - Use `skip_model_load=True` in conversion
   - Handle BlobWriter import gracefully

2. **Precision Warnings**
   - int64 to int32 conversion warnings are expected
   - No impact on model functionality

3. **Memory Usage**
   - Clean up temporary files after conversion
   - Monitor memory usage during conversion

## Integration

1. **Swift Integration**
   - Use UIQACoreMLPredictor.swift
   - Enable low precision GPU accumulation
   - Handle input/output properly

2. **Runtime Configuration**
   - Use all compute units
   - Enable FP16 precision
   - Handle errors gracefully
