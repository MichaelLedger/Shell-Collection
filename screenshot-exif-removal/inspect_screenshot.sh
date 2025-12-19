#!/bin/bash
# inspect_screenshot.sh - Detect screenshot metadata in PNG images
# Usage: ./inspect_screenshot.sh [image.png | directory]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

inspect_image() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File not found: $file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Inspecting: ${NC}$file"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check for Screenshot string in file
    local has_screenshot=false
    if strings "$file" 2>/dev/null | grep -qi "screenshot"; then
        has_screenshot=true
    fi
    
    # Get image properties with sips
    echo -e "\n${YELLOW}Image Properties (sips):${NC}"
    sips -g pixelWidth -g pixelHeight -g dpiWidth -g dpiHeight -g hasAlpha -g profile "$file" 2>/dev/null | tail -n +2
    
    # Check DPI for Retina indicator
    local dpi=$(sips -g dpiWidth "$file" 2>/dev/null | grep dpiWidth | awk '{print $2}')
    if [[ -n "$dpi" ]]; then
        if (( $(echo "$dpi > 100" | bc -l) )); then
            echo -e "${YELLOW}  ⚠️  DPI $dpi suggests Retina/screen capture${NC}"
        fi
    fi
    
    # Summary
    echo ""
    if $has_screenshot; then
        echo -e "${RED}🔴 SCREENSHOT DETECTED${NC}"
        echo -e "${RED}   Contains 'Screenshot' in metadata${NC}"
        
        # Show where Screenshot string appears
        echo -e "\n${YELLOW}Screenshot references found:${NC}"
        strings "$file" 2>/dev/null | grep -i screenshot | head -5
    else
        echo -e "${GREEN}✅ NO SCREENSHOT FLAG${NC}"
        echo -e "${GREEN}   Image appears clean${NC}"
    fi
    
    echo ""
}

# Main
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <image.png | directory>"
    echo ""
    echo "Examples:"
    echo "  $0 image.png           # Inspect single image"
    echo "  $0 .                   # Inspect all PNGs in current directory"
    echo "  $0 /path/to/images     # Inspect all PNGs in directory"
    exit 1
fi

target="$1"

if [[ -d "$target" ]]; then
    # Directory - process all PNGs
    screenshot_count=0
    clean_count=0
    
    for file in "$target"/*.png; do
        [[ -f "$file" ]] || continue
        [[ "$file" == *_clean.png ]] && continue
        
        inspect_image "$file"
        
        if strings "$file" 2>/dev/null | grep -qi "screenshot"; then
            ((screenshot_count++))
        else
            ((clean_count++))
        fi
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Summary:${NC}"
    echo -e "  🔴 Screenshots: $screenshot_count"
    echo -e "  ✅ Clean: $clean_count"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    # Single file
    inspect_image "$target"
fi

