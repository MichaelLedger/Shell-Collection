# Screenshot Metadata Remover

A simple tool to remove screenshot-related EXIF/XMP metadata from PNG images, preventing them from being classified as "Screenshots" in iOS Photos app.

## Quick Start

```bash
# Inspect images for screenshot metadata
./inspect_screenshot.sh .

# Strip screenshot metadata (creates clean versions in ./clean/)
./strip_screenshot.sh .

# Strip and replace originals
./strip_screenshot.sh . --replace
```

## Problem

When you take a screenshot on iPhone/Mac, the system embeds metadata that marks the image as a screenshot:

- **EXIF UserComment**: `Screenshot`
- **XMP Metadata**: `<exif:UserComment>Screenshot</exif:UserComment>`
- **ICC Profile**: Apple Display profile
- **DPI**: 144 (Retina) or 216 (3x Retina)

This causes iOS Photos to automatically categorize these images in the "Screenshots" album, even after editing.

## Detecting Screenshot Metadata

### Using macOS Built-in Tools

```bash
# Check image properties with sips (macOS)
sips -g all image.png

# Example output for a screenshot:
# dpiWidth: 144.000    ← Retina display indicator
# dpiHeight: 144.000
# profile: U27P2G6B    ← Display-specific color profile
```

```bash
# Check Spotlight metadata
mdls image.png

# Look for kMDItemIsScreenCapture or kMDItemScreenCaptureType
```

### Using exiftool (if installed)

```bash
# Install exiftool
brew install exiftool

# View all metadata
exiftool image.png

# Check specifically for screenshot indicators
exiftool -UserComment -XMP:UserComment image.png

# Example output:
# User Comment: Screenshot
```

### Using Python (Pillow)

```python
from PIL import Image

img = Image.open('image.png')

# Check for screenshot flags
exif = img.info.get('exif', b'')
xmp = img.info.get('xmp', b'')

if b'Screenshot' in exif or b'Screenshot' in xmp:
    print("⚠️  Image has screenshot metadata!")
else:
    print("✅ No screenshot metadata found")

# Print all metadata
for key, value in img.info.items():
    print(f"{key}: {value[:100] if isinstance(value, bytes) else value}")
```

### Quick One-liner Check

```bash
# Check if PNG contains "Screenshot" string in metadata
strings image.png | grep -i screenshot && echo "Has screenshot flag" || echo "Clean"
```

## Solution

This tool strips all screenshot-identifying metadata and saves clean versions with:

- ❌ No EXIF "Screenshot" tag
- ❌ No XMP metadata
- ❌ No Apple Display ICC profile
- ✅ Standard 72 DPI

## Usage

### Using Shell Scripts (Recommended)

#### Inspect Images

```bash
# Inspect a single image
./inspect_screenshot.sh image.png

# Inspect all PNGs in current directory
./inspect_screenshot.sh .

# Inspect all PNGs in a specific directory
./inspect_screenshot.sh /path/to/images
```

**Output:**
- Shows image properties (size, DPI, profile)
- Detects "Screenshot" flag in metadata
- Summarizes findings with 🔴 or ✅ indicators

#### Strip Screenshot Metadata

```bash
# Process single image → creates ./clean/image_clean.png
./strip_screenshot.sh image.png

# Process all PNGs in current directory → outputs to ./clean/
./strip_screenshot.sh .

# Process and REPLACE original files (use with caution!)
./strip_screenshot.sh . --replace

# Process specific directory
./strip_screenshot.sh /path/to/images
```

**Features:**
- Automatically sets up Python virtual environment
- Removes all EXIF, XMP, ICC metadata
- Resets DPI to standard 72
- Creates clean versions in `./clean/` directory (or replaces originals with `--replace`)

### Manual Setup (Alternative)

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Pillow
pip install Pillow
```

### Python API

```python
from PIL import Image

# Open the original image
img = Image.open('screenshot.png')

# Create a clean copy without metadata
clean_img = Image.new(img.mode, img.size)
clean_img.putdata(list(img.getdata()))

# Save with standard 72 DPI
clean_img.save('clean.png', 'PNG', dpi=(72, 72))
```

### Batch Process with Python

```python
from PIL import Image
import os

for filename in os.listdir('.'):
    if filename.endswith('.png') and not filename.endswith('_clean.png'):
        img = Image.open(filename)
        clean_img = Image.new(img.mode, img.size)
        clean_img.putdata(list(img.getdata()))
        clean_img.save(filename.replace('.png', '_clean.png'), 'PNG', dpi=(72, 72))
```

## Directory Structure

```
issues/
├── *.png                   # Original images (with screenshot metadata)
├── clean/                  # Cleaned images (metadata removed)
│   └── *_clean.png
├── inspect_screenshot.sh   # Script to detect screenshot metadata
├── strip_screenshot.sh     # Script to remove screenshot metadata
├── venv/                   # Python virtual environment (auto-created)
└── README.md
```

## Shell Scripts for Batch Processing

### Remove Metadata with exiftool

```bash
# Strip ALL metadata from a single image
exiftool -all= image.png

# Strip all metadata from all PNGs in directory
exiftool -all= *.png

# Strip metadata and keep originals as backup
exiftool -all= -overwrite_original_in_place *.png
```

### Remove Metadata with sips (macOS)

```bash
# Reset DPI to standard 72
sips -s dpiWidth 72 -s dpiHeight 72 image.png

# Remove color profile
sips -d profile image.png

# Batch reset DPI for all PNGs
for f in *.png; do sips -s dpiWidth 72 -s dpiHeight 72 "$f"; done
```

### Complete Cleanup Script

```bash
#!/bin/bash
# clean_screenshots.sh - Remove screenshot metadata from all PNGs

mkdir -p clean

for file in *.png; do
    [[ "$file" == *_clean.png ]] && continue
    
    # Use sips to create clean copy with standard DPI
    sips -s dpiWidth 72 -s dpiHeight 72 "$file" --out "clean/${file%.png}_clean.png"
    
    echo "✅ Cleaned: $file"
done

echo "Done! Clean images are in ./clean/"
```

### Verify Cleanup

```bash
# Compare metadata before and after
echo "=== Original ===" && sips -g all original.png
echo "=== Clean ===" && sips -g all clean/original_clean.png

# Check no Screenshot string remains
strings clean/original_clean.png | grep -i screenshot || echo "✅ No screenshot flag"
```

## Requirements

- Python 3.x
- Pillow (`pip install Pillow`)
- Optional: exiftool (`brew install exiftool`)

