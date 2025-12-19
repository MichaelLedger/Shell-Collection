#!/bin/bash
# strip_screenshot.sh - Remove screenshot metadata from PNG images
# Usage: ./strip_screenshot.sh [image.png | directory] [--replace]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/clean"
REPLACE_MODE=false

# Check for --replace flag
for arg in "$@"; do
    if [[ "$arg" == "--replace" ]]; then
        REPLACE_MODE=true
    fi
done

# Setup Python virtual environment if needed
setup_python() {
    if [[ ! -d "$SCRIPT_DIR/venv" ]]; then
        echo -e "${YELLOW}Setting up Python virtual environment...${NC}"
        python3 -m venv "$SCRIPT_DIR/venv"
        source "$SCRIPT_DIR/venv/bin/activate"
        pip install -q Pillow
    else
        source "$SCRIPT_DIR/venv/bin/activate"
    fi
}

strip_image() {
    local file="$1"
    local filename=$(basename "$file")
    local output_file
    
    if $REPLACE_MODE; then
        output_file="$file"
    else
        output_file="$OUTPUT_DIR/${filename%.png}_clean.png"
    fi
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File not found: $file${NC}"
        return 1
    fi
    
    # Check if it has screenshot metadata
    local has_screenshot=false
    if strings "$file" 2>/dev/null | grep -qi "screenshot"; then
        has_screenshot=true
    fi
    
    # Use Python to strip metadata
    python3 << EOF
from PIL import Image

img = Image.open('$file')
clean_img = Image.new(img.mode, img.size)
clean_img.putdata(list(img.getdata()))
clean_img.save('$output_file', 'PNG', dpi=(72, 72))
EOF
    
    if $has_screenshot; then
        echo -e "${GREEN}✅ Stripped:${NC} $filename ${RED}(had screenshot flag)${NC}"
    else
        echo -e "${GREEN}✅ Cleaned:${NC} $filename ${YELLOW}(no screenshot flag, normalized DPI)${NC}"
    fi
}

show_usage() {
    echo "Usage: $0 <image.png | directory> [--replace]"
    echo ""
    echo "Options:"
    echo "  --replace    Replace original files instead of creating *_clean.png versions"
    echo ""
    echo "Examples:"
    echo "  $0 image.png              # Create image_clean.png in ./clean/"
    echo "  $0 image.png --replace    # Replace original image"
    echo "  $0 .                       # Process all PNGs, output to ./clean/"
    echo "  $0 /path/to/images         # Process all PNGs in directory"
    echo ""
    echo "Output:"
    echo "  By default, clean versions are saved to: $OUTPUT_DIR/"
    echo "  With --replace, original files are modified in place"
    exit 1
}

# Main
if [[ $# -eq 0 ]]; then
    show_usage
fi

target="$1"

# Skip --replace in target
[[ "$target" == "--replace" ]] && target="${2:-.}"

# Setup
setup_python
if ! $REPLACE_MODE; then
    mkdir -p "$OUTPUT_DIR"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Screenshot Metadata Stripper${NC}"
if $REPLACE_MODE; then
    echo -e "${YELLOW}Mode: REPLACE (modifying originals)${NC}"
else
    echo -e "${GREEN}Mode: SAFE (output to $OUTPUT_DIR/)${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ -d "$target" ]]; then
    # Directory - process all PNGs
    count=0
    
    for file in "$target"/*.png; do
        [[ -f "$file" ]] || continue
        [[ "$file" == *_clean.png ]] && continue
        
        strip_image "$file"
        ((count++))
    done
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✨ Done! Processed $count images${NC}"
    if ! $REPLACE_MODE; then
        echo -e "${GREEN}   Clean versions saved to: $OUTPUT_DIR/${NC}"
    fi
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
elif [[ -f "$target" ]]; then
    # Single file
    strip_image "$target"
    
    echo ""
    echo -e "${GREEN}✨ Done!${NC}"
    if ! $REPLACE_MODE; then
        echo -e "${GREEN}   Clean version saved to: $OUTPUT_DIR/${NC}"
    fi
else
    echo -e "${RED}Error: Not a valid file or directory: $target${NC}"
    exit 1
fi

