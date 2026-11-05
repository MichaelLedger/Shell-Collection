# Converting CUDA Models to MPS (Apple Silicon)

This guide explains how to convert PyTorch models trained with CUDA to work with Apple's Metal Performance Shaders (MPS) backend.

## Prerequisites

- macOS device with Apple Silicon (M1/M2/M3)
- Python 3.8 or higher
- PyTorch 2.0 or higher with MPS support

## Environment Setup

1. Create and activate a virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

2. Install PyTorch with MPS support:
```bash
pip3 install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cpu
```

3. Install other dependencies:
```bash
pip3 install numpy pandas Pillow opencv-python scipy
```

## Conversion Process

1. Create a conversion script (`convert_cuda_to_mps.py`):
```python
import torch
import models.UIQA as UIQA

def convert_model():
    print("Starting model conversion from CUDA to MPS...")
    
    # Create model
    model = UIQA.Model_SwinT()
    
    # Load CUDA weights with CPU
    print("Loading CUDA weights to CPU...")
    cuda_weights = torch.load('ckpts/Model_SwinT_AVA_epoch_10.pth', map_location='cpu')
    
    # Load weights into model
    print("Loading weights into model...")
    model.load_state_dict(cuda_weights)
    
    # Move model to MPS if available
    if torch.backends.mps.is_available():
        print("Moving model to MPS...")
        device = torch.device("mps")
        model = model.to(device)
        
        # Save MPS model
        print("Saving MPS-compatible model...")
        torch.save(model.state_dict(), 'ckpts/Model_SwinT_AVA_epoch_10_mps.pth')
        print("Successfully saved MPS-compatible model")
    else:
        print("MPS not available. Saving CPU model...")
        torch.save(model.state_dict(), 'ckpts/Model_SwinT_AVA_epoch_10_cpu.pth')
```

2. Run the conversion:
```bash
python3 convert_cuda_to_mps.py
```

## Verification

1. Create a verification script (`verify_mps_model.py`):
```python
import torch
import models.UIQA as UIQA

def verify_model():
    print("Verifying MPS model loading...")
    
    # Check MPS availability
    if torch.backends.mps.is_available():
        device = torch.device("mps")
        print("MPS is available")
    else:
        device = torch.device("cpu")
        print("MPS not available, using CPU")
    
    # Create model
    model = UIQA.Model_SwinT()
    
    # Load MPS weights
    print("Loading MPS weights...")
    mps_weights = torch.load('ckpts/Model_SwinT_AVA_epoch_10_mps.pth', map_location=device)
    
    # Load weights into model
    print("Loading weights into model...")
    model.load_state_dict(mps_weights)
    model = model.to(device)
    
    # Test with dummy input
    print("Testing model with dummy input...")
    dummy_input = torch.randn(1, 3, 224, 224).to(device)
    
    with torch.no_grad():
        output = model(dummy_input)
        print(f"Model output shape: {output.shape}")
        print(f"Model output value: {output.item():.4f}")
```

2. Run the verification:
```bash
python3 verify_mps_model.py
```

## Common Issues and Solutions

1. **CUDA Device Not Found Error**:
   - This is expected when loading CUDA models on macOS
   - Solution: Use `map_location='cpu'` when loading CUDA models

2. **Memory Issues**:
   - MPS may handle memory differently from CUDA
   - Solution: Use smaller batch sizes and monitor memory usage

3. **Performance Differences**:
   - MPS performance might differ from CUDA
   - Solution: Benchmark your model and adjust batch sizes accordingly

## Using the Converted Model

1. Update model loading code to use MPS:
```python
if torch.backends.mps.is_available():
    device = torch.device("mps")
else:
    device = torch.device("cpu")

model = YourModel()
weights = torch.load('model_mps.pth', map_location=device)
model.load_state_dict(weights)
model = model.to(device)
```

2. Ensure all inputs are moved to MPS device:
```python
input_tensor = input_tensor.to(device)
```

## Notes

- MPS backend is only available on macOS with Apple Silicon
- Some PyTorch operations might not be supported by MPS
- Keep CPU fallback as a backup option
- Monitor system temperature during training
- Consider using smaller batch sizes compared to CUDA training
