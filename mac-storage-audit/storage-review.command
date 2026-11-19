#!/bin/sh
# macOS storage review. This script only reads metadata and, in duplicate mode,
# compares known pairs of Git pack files. All output goes to the terminal.
set -u
export LC_ALL=C

data=/System/Volumes/Data
library="$HOME/Library"
xcode="$library/Developer/Xcode"
devices="$library/Developer/CoreSimulator/Devices"
assets="$data/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime"
cursor_state="$library/Application Support/Cursor/User/globalStorage"
dingtalk="$library/Application Support/DingTalkMac"
downloads="$HOME/Downloads"
recording="$library/ScreenRecordings/8ADB6F3E-FF99-4629-A940-CC1CB4E69308.mov"

usage() {
  cat <<'USAGE'
Storage review (read-only)

  storage-review.command               Show the main storage candidates
  storage-review.command --details     List the largest simulator devices,
                                       build folders and other subdirectories
  storage-review.command --duplicate   Compare three FreePrints Git pack pairs
  storage-review.command --help        Show usage

The script prints approximate allocated sizes in decimal GB. APFS shared blocks
and protected directories can affect measurements. No files are moved or deleted.
USAGE
}

section() {
  printf '\n%s\n' "$1"
}

size() (
  path=$1
  if [ ! -e "$path" ]; then
    printf '   unavailable  %s\n' "$path"
    return
  fi
  if ! result=$(/usr/bin/du -skx "$path"); then
    printf '   incomplete   %s\n' "$path"
    return
  fi
  printf '%s\n' "$result" |
    /usr/bin/awk -F '\t' 'NR == 1 {printf "%8.2f GB  %s\n", $1 * 1024 / 1000000000, $2}'
)

top_children() (
  path=$1
  [ -d "$path" ] || return 0
  if ! result=$(/usr/bin/du -kx -d 1 "$path"); then
    printf 'Some entries under %s could not be measured.\n' "$path" >&2
  fi
  printf '%s\n' "$result" |
    /usr/bin/sort -nr |
    /usr/bin/awk -F '\t' -v root="$path" '
      $2 && $2 != root && $1 > 0 && n++ < 12 {
        printf "%8.2f GB  %s\n", $1 * 1024 / 1000000000, $2
      }'
)

review_details() (
  section 'Largest simulator device directories'
  top_children "$devices" |
    while IFS= read -r record; do
      printf '%s\n' "$record"
      location=${record#*' GB  '}
      info="$location/device.plist"
      if [ -f "$info" ]; then
        name=$(/usr/bin/plutil -extract name raw -o - "$info" 2>/dev/null) || name='Unknown device'
        runtime=$(/usr/bin/plutil -extract runtime raw -o - "$info" 2>/dev/null) || runtime='Unknown runtime'
        printf '             %s | %s\n' "$name" "${runtime##*.}"
      else
        printf '             No readable device.plist\n'
      fi
    done

  section 'Simulator runtime assets by version and build'
  for info in "$assets"/*.asset/Info.plist; do
    [ -f "$info" ] || continue
    asset=${info%/Info.plist}
    version=$(/usr/bin/plutil -extract MobileAssetProperties.SimulatorVersion raw -o - "$info" 2>/dev/null) || version='unknown'
    build=$(/usr/bin/plutil -extract MobileAssetProperties.Build raw -o - "$info" 2>/dev/null) || build='unknown'
    printf 'iOS %s (%s)\n' "$version" "$build"
    size "$asset"
  done

  for location in "$xcode/DerivedData" "$xcode/iOS DeviceSupport" "$downloads"; do
    section "Largest directories in $location"
    top_children "$location"
  done
)

compare_pack() (
  relative=$1
  first="$downloads/freeprints_ios_2/$relative"
  second="$downloads/freeprints_ios_3/$relative"
  if [ ! -f "$first" ] || [ ! -f "$second" ] || [ -L "$first" ] || [ -L "$second" ]; then
    printf 'Both regular files must be present for %s.\n' "$relative" >&2
    return 1
  fi
  first_id=$(/usr/bin/stat -f '%d:%i' "$first") || return 1
  second_id=$(/usr/bin/stat -f '%d:%i' "$second") || return 1
  size "$first"
  size "$second"
  if [ "$first_id" = "$second_id" ]; then
    printf 'These names refer to the same inode.\n'
    return 0
  fi
  printf 'Comparing the contents of both files. This can take a minute.\n'
  /usr/bin/cmp -s "$first" "$second"
  status=$?
  case "$status" in
    0) printf 'Byte-identical files with distinct inodes. APFS block sharing is unknown. Preserve each Git object store.\n' ;;
    1) printf 'The files differ.\n' ;;
    *) printf 'The comparison could not be completed.\n' >&2 ;;
  esac
  return "$status"
)

review_duplicates() (
  result=0
  for relative in \
    '.git/objects/pack/pack-83e700986cc0fe9eef73da03fed0db5ebf3418e2.pack' \
    '.git/objects/pack/pack-fefbabf8a15f930abb3897cfc208438356043a00.pack' \
    '.git/modules/FreePrints/MyDealsSDK/objects/pack/pack-aa8d0a31c15f6d4273f3b9013c2b75f678c3564b.pack'; do
    compare_pack "$relative" || result=1
  done
  return "$result"
)

review() (
  section 'Startup volume and APFS snapshots'
  /bin/df -h "$data"
  /usr/sbin/diskutil apfs listSnapshots "$data" ||
    printf 'APFS snapshot listing unavailable. Check Disk Utility > View > Show APFS Snapshots.\n'

  section 'Rebuildable caches to review after closing their apps'
  for path in "$xcode/DerivedData" "$xcode/DocumentationCache" "$library/Caches/org.swift.swiftpm" \
    "$HOME/.cache/huggingface/hub" "$HOME/.cache/huggingface/xet" \
    "$library/Caches/vscode-cpptools" "$downloads/PRTBusinessUnit/.build" \
    "$downloads/common_ios_prt_select_photo/.build" "$downloads/fp_ios_address/.build"; do
    size "$path"
  done

  section 'Temporary Xcode build output and logs to review'
  for path in /private/tmp/pb-cover-offset-build /private/tmp/pinned-header-color-validation-20261118 \
    /private/tmp/codex-memories-wrenda.An9NlU /private/tmp/wbk-myprojects-navigation-build \
    /private/tmp/codex-pb-size-picker-build; do
    size "$path"
  done
  printf 'Review these individually after the corresponding builds and Codex jobs have finished.\n'

  section 'Xcode-managed components and simulator data'
  size "$devices"
  size "$assets"
  size "$xcode/iOS DeviceSupport"
  printf 'Review devices in Xcode > Window > Devices and Simulators. Review runtimes in Xcode > Settings > Components.\n'

  section 'User and app data to preserve or review in the owning app'
  for path in "$cursor_state/state.vscdb" "$cursor_state/state.vscdb.backup" \
    "$dingtalk" "$recording" "$downloads/freeprints_ios_2" "$downloads/freeprints_ios_3"; do
    size "$path"
  done
  printf 'To archive recordings or an inactive checkout, copy to an external drive and verify the copy before approving a move.\n'
)

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi
case "${1-}" in
  '') review ;;
  --details) review_details ;;
  --duplicate) review_duplicates ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
