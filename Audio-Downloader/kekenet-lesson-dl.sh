#!/usr/bin/env bash
# Download MP3 audio from a kekenet lesson page.
#
# Usage:
#   sh kekenet-lesson-dl.sh https://www.kekenet.com/lesson/16442-474658
#   sh kekenet-lesson-dl.sh 16442-474658
#   sh kekenet-lesson-dl.sh 474658                 # news_id only
#   sh kekenet-lesson-dl.sh URL -o ~/Downloads
#
set -euo pipefail

API="https://mob2015.kekenet.com/keke/mobile/index.php"
CDN="https://k6.kekenet.com"
AES_KEY="51E881E6F2A6Y9K8"
AES_IV="9F0885C2D686C418"

OUT_DIR="."
INPUT=""

usage() {
  cat <<'EOF'
Download MP3 audio from a kekenet lesson page.

Usage:
  kekenet-lesson-dl.sh https://www.kekenet.com/lesson/16442-474658
  kekenet-lesson-dl.sh 16442-474658
  kekenet-lesson-dl.sh 474658
  kekenet-lesson-dl.sh URL -o ~/Downloads
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    -o|--out) OUT_DIR="${2:?missing output dir}"; shift 2 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage 1
      ;;
    *)
      INPUT="$1"
      shift
      ;;
  esac
done

[[ -n "$INPUT" ]] || usage 1

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}
need curl
need jq
need openssl
need xxd

# Accept full URL, /lesson/catid-newsid, catid-newsid, or bare news_id
NEWS_ID="$(
  printf '%s' "$INPUT" \
    | sed -E 's#.*/lesson/##' \
    | sed -E 's#[?#].*$##' \
    | sed -E 's#.*/##' \
    | sed -E 's#^[0-9]+-([0-9]+)$#\1#' \
    | tr -d '[:space:]'
)"

if ! [[ "$NEWS_ID" =~ ^[0-9]+$ ]]; then
  echo "Could not parse lesson id from: $INPUT" >&2
  echo "Expected: https://www.kekenet.com/lesson/<catid>-<news_id>" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

APTIME="$(date +%s)000"
REQ="$(jq -nc \
  --arg id "$NEWS_ID" \
  --argjson aptime "$APTIME" \
  '{
    Method: "web_waikan_wkgetcontent",
    Params: { id: $id, version_flag: 1 },
    Token: "",
    Terminal: 13,
    Version: "4.0",
    UID: "",
    AppFlag: 18,
    Sign: "",
    ApTime: $aptime,
    ApVersionCode: 100
  }')"

curl -fsSL "$API" \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://www.kekenet.com' \
  -H 'Referer: https://www.kekenet.com/' \
  -A 'Mozilla/5.0' \
  --data-binary "$REQ" \
  >"$TMP/resp.json"

CODE="$(jq -r '.Code // .code // empty' "$TMP/resp.json")"
if [[ "$CODE" != "200" ]]; then
  echo "API error (Code=$CODE): $(jq -r '.Msg // .msg // empty' "$TMP/resp.json")" >&2
  exit 1
fi

KEY_HEX="$(printf '%s' "$AES_KEY" | xxd -p | tr -d '\n')"
IV_HEX="$(printf '%s' "$AES_IV" | xxd -p | tr -d '\n')"

IS_DECODE="$(jq -r '.IsDecode // 0' "$TMP/resp.json")"
DATA_FIELD="$(jq -r '.Data // empty' "$TMP/resp.json")"

if [[ "$IS_DECODE" == "1" ]]; then
  printf '%s' "$DATA_FIELD" | xxd -r -p \
    | openssl enc -d -aes-128-cbc -K "$KEY_HEX" -iv "$IV_HEX" \
    >"$TMP/data.json"
else
  # Data may already be a JSON object
  if jq -e 'type == "object"' <<<"$DATA_FIELD" >/dev/null 2>&1; then
    printf '%s' "$DATA_FIELD" >"$TMP/data.json"
  else
    jq -c '.Data' "$TMP/resp.json" >"$TMP/data.json"
  fi
fi

PLAY_PATH="$(jq -r '.playurl // .mp3 // empty' "$TMP/data.json")"
TITLE="$(jq -r '.title // empty' "$TMP/data.json")"
CATID="$(jq -r '.catid // empty' "$TMP/data.json")"

if [[ -z "$PLAY_PATH" || "$PLAY_PATH" == "null" ]]; then
  echo "No playurl/mp3 in lesson data for news_id=$NEWS_ID" >&2
  exit 1
fi

# Absolute URL for some types; otherwise CDN-relative path
if [[ "$PLAY_PATH" =~ ^https?:// ]]; then
  AUDIO_URL="$PLAY_PATH"
else
  AUDIO_URL="${CDN}/${PLAY_PATH#/}"
fi

# Keep the original CDN basename (e.g. friendss09e16a.mp3)
BASENAME="$(basename "${PLAY_PATH%%\?*}")"
[[ -n "$BASENAME" && "$BASENAME" != "/" && "$BASENAME" != "." ]] \
  || BASENAME="lesson-${NEWS_ID}.mp3"
OUT_FILE="${OUT_DIR%/}/${BASENAME}"

echo "Lesson : ${TITLE:-?} (catid=${CATID:-?}, news_id=$NEWS_ID)"
echo "URL    : $AUDIO_URL"
echo "Saving : $OUT_FILE"

curl -fL --progress-bar -A 'Mozilla/5.0' \
  -o "$OUT_FILE" \
  "$AUDIO_URL"

echo "Done."
