#!/usr/bin/env bash
# adjust_exif.sh - Set unified create date (spread times) + GPS for photos in a directory
# Usage: ./adjust_exif.sh <dir> <date> <lat> <lon> [--dry-run] [--start-time HH:MM] [--step-minutes N]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
START_TIME="09:00"
STEP_MINUTES=2
DIR=""
DATE=""
LAT=""
LON=""

show_usage() {
    cat <<EOF
Usage: $0 <dir> <date> <lat> <lon> [options]

Arguments:
  dir              Directory of photos (top-level only)
  date             Create date as YYYY-MM-DD (e.g. 2024-06-30)
  lat              GPS latitude (e.g. 43.4835416)
  lon              GPS longitude (e.g. -1.56304953)

Options:
  --dry-run              Print planned changes without writing
  --start-time HH:MM     First photo time (default: 09:00)
  --step-minutes N       Minutes between photos (default: 2)

Examples:
  $0 ./beach 2024-06-30 43.4835416 -1.56304953
  $0 ./beach 2024-06-30 43.4835416 -1.56304953 --dry-run
  $0 ./beach 2024-06-30 43.4835416 -1.56304953 --start-time 10:30 --step-minutes 3
EOF
    exit 1
}

is_number() {
    [[ "$1" =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]
}

gps_ref_lat() {
    awk -v v="$1" 'BEGIN { if (v < 0) print "S"; else print "N" }'
}

gps_ref_lon() {
    awk -v v="$1" 'BEGIN { if (v < 0) print "W"; else print "E" }'
}

abs_coord() {
    awk -v v="$1" 'BEGIN { if (v < 0) print -v; else print v }'
}

# Add minutes to HH:MM; print "HH:MM:SS" (may exceed 24h — clamped later if needed)
add_minutes() {
    local base_hm="$1"
    local add="$2"
    local h m total
    h="${base_hm%%:*}"
    m="${base_hm##*:}"
    # strip leading zeros for arithmetic
    h=$((10#$h))
    m=$((10#$m))
    total=$((h * 60 + m + add))
    if (( total < 0 )); then
        total=0
    fi
    if (( total > 23 * 60 + 59 )); then
        total=$((23 * 60 + 59))
    fi
    printf "%02d:%02d:00" $((total / 60)) $((total % 60))
}

exiftool_datetime() {
    # YYYY-MM-DD + HH:MM:SS -> YYYY:MM:DD HH:MM:SS
    local d="$1"
    local t="$2"
    echo "${d//-/:} $t"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --start-time)
            [[ $# -ge 2 ]] || { echo -e "${RED}Error: --start-time needs a value${NC}"; exit 1; }
            START_TIME="$2"
            shift 2
            ;;
        --step-minutes)
            [[ $# -ge 2 ]] || { echo -e "${RED}Error: --step-minutes needs a value${NC}"; exit 1; }
            STEP_MINUTES="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        --*)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            show_usage
            ;;
        *)
            # Positionals (including negative lat/lon like -1.56)
            if [[ -z "$DIR" ]]; then
                DIR="$1"
            elif [[ -z "$DATE" ]]; then
                DATE="$1"
            elif [[ -z "$LAT" ]]; then
                LAT="$1"
            elif [[ -z "$LON" ]]; then
                LON="$1"
            else
                echo -e "${RED}Error: Unexpected argument: $1${NC}"
                show_usage
            fi
            shift
            ;;
    esac
done

[[ -n "$DIR" && -n "$DATE" && -n "$LAT" && -n "$LON" ]] || show_usage

if [[ ! -d "$DIR" ]]; then
    echo -e "${RED}Error: Directory not found: $DIR${NC}"
    exit 1
fi

if [[ ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo -e "${RED}Error: Date must be YYYY-MM-DD (got: $DATE)${NC}"
    exit 1
fi

if ! is_number "$LAT" || ! is_number "$LON"; then
    echo -e "${RED}Error: lat and lon must be numeric${NC}"
    exit 1
fi

if [[ ! "$START_TIME" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
    echo -e "${RED}Error: --start-time must be HH:MM (got: $START_TIME)${NC}"
    exit 1
fi

if ! [[ "$STEP_MINUTES" =~ ^[0-9]+$ ]] || (( STEP_MINUTES < 1 )); then
    echo -e "${RED}Error: --step-minutes must be a positive integer${NC}"
    exit 1
fi

if ! command -v exiftool >/dev/null 2>&1; then
    echo -e "${RED}Error: exiftool not found on PATH${NC}"
    echo -e "${YELLOW}Install with: brew install exiftool${NC}"
    exit 1
fi

LAT_REF="$(gps_ref_lat "$LAT")"
LON_REF="$(gps_ref_lon "$LON")"
LAT_ABS="$(abs_coord "$LAT")"
LON_ABS="$(abs_coord "$LON")"

# Collect matching files (top-level only)
files=()
while IFS= read -r -d '' f; do
    files+=("$f")
done < <(find "$DIR" -maxdepth 1 -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' -o -iname '*.heif' -o -iname '*.png' \
\) -print0 | sort -z)

updated=0
failed=0
skipped=0

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Image EXIF Adjuster${NC}"
echo -e "  Dir:         $DIR"
echo -e "  Date:        $DATE"
echo -e "  GPS:         $LAT, $LON ($LAT_REF/$LON_REF)"
echo -e "  Start/step:  $START_TIME / ${STEP_MINUTES}m"
if $DRY_RUN; then
    echo -e "  Mode:        ${YELLOW}DRY-RUN${NC}"
else
    echo -e "  Mode:        ${YELLOW}IN-PLACE (overwrite originals)${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ ${#files[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No matching photos (.jpg/.jpeg/.heic/.heif/.png) in $DIR${NC}"
    exit 0
fi

for i in "${!files[@]}"; do
    file="${files[$i]}"
    name="$(basename "$file")"
    offset=$((i * STEP_MINUTES))
    tod="$(add_minutes "$START_TIME" "$offset")"
    dt="$(exiftool_datetime "$DATE" "$tod")"

    if $DRY_RUN; then
        echo -e "${GREEN}[dry-run]${NC} $name → $dt | GPS $LAT,$LON"
        ((updated++)) || true
        continue
    fi

    if exiftool -q -overwrite_original \
        -DateTimeOriginal="$dt" \
        -CreateDate="$dt" \
        -ModifyDate="$dt" \
        -FileModifyDate="$dt" \
        -GPSLatitude="$LAT_ABS" \
        -GPSLongitude="$LON_ABS" \
        -GPSLatitudeRef="$LAT_REF" \
        -GPSLongitudeRef="$LON_REF" \
        "$file"; then
        echo -e "${GREEN}✅${NC} $name → $dt | GPS $LAT,$LON"
        ((updated++)) || true
    else
        echo -e "${RED}❌ Failed:${NC} $name"
        ((failed++)) || true
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Done.${NC} updated=$updated  failed=$failed  files=${#files[@]}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

[[ "$failed" -eq 0 ]]
